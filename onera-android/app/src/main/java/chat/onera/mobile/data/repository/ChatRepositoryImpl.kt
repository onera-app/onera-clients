package chat.onera.mobile.data.repository

import android.util.Log
import chat.onera.mobile.data.remote.api.ChatApiService
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.llm.ChatMessage
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.data.remote.llm.StreamEvent
import chat.onera.mobile.data.remote.private_inference.PrivateInferenceEvent
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.remote.trpc.ChatProcedures
import chat.onera.mobile.data.security.ChatKeyCache
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.data.security.KeyManager
import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.domain.repository.LLMRepository
import dagger.Lazy
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Chat Repository implementation - matches iOS ChatRepository.swift
 * 
 * Server-first approach (matching iOS):
 * - All create/update/delete operations call server FIRST
 * - Local state only updated AFTER server confirms success
 * - Throws exceptions on failure (caller handles UI feedback)
 * - No local database - uses in-memory state like iOS
 * - Messages stored within Chat objects
 */
@Singleton
class ChatRepositoryImpl @Inject constructor(
    private val chatApiService: ChatApiService,
    private val llmRepository: LLMRepository,
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager,
    private val keyManager: KeyManager,
    private val chatKeyCache: ChatKeyCache,
    private val e2eeRepository: E2EERepository,
    private val credentialRepositoryLazy: Lazy<CredentialRepository>
) : ChatRepository {
    
    // Use lazy to avoid circular dependency
    private val credentialRepository: CredentialRepository
        get() = credentialRepositoryLazy.get()
    
    companion object {
        private const val TAG = "ChatRepository"
        private const val DEFAULT_SYSTEM_PROMPT = "You are a helpful AI assistant."
    }
    
    private val json = Json { 
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    // In-memory chat storage (matching iOS approach)
    private val _chats = MutableStateFlow<List<Chat>>(emptyList())

    override fun observeChats(): Flow<List<Chat>> = _chats.asStateFlow()

    override suspend fun getChats(): List<Chat> = _chats.value

    override suspend fun getChat(chatId: String): Chat? {
        // Check local cache first
        _chats.value.find { it.id == chatId }?.let { return it }
        
        // Try to fetch from server
        return fetchChat(chatId)
    }

    /**
     * Create a chat - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun createChat(title: String): String {
        Log.d(TAG, "Creating chat...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot create chat")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Generate per-chat encryption key
        val chatKey = encryptionManager.generateChatKey()
        
        // Encrypt chat key with master key (XSalsa20-Poly1305)
        val (encryptedChatKey, chatKeyNonce) = encryptionManager.encryptSecretBox(chatKey, masterKey)
        
        // Encrypt title with chat key (XSalsa20-Poly1305)
        val (encryptedTitle, titleNonce) = encryptionManager.encryptSecretBoxString(title, chatKey)
        
        // Encrypt empty messages (new chat)
        val chatData = ChatData(messages = emptyList())
        val chatDataJson = json.encodeToString(chatData)
        val (encryptedChat, chatNonce) = encryptionManager.encryptSecretBoxString(chatDataJson, chatKey)
        
        val request = ChatCreateRequest(
            encryptedChatKey = encryptedChatKey,
            chatKeyNonce = chatKeyNonce,
            encryptedTitle = encryptedTitle,
            titleNonce = titleNonce,
            encryptedChat = encryptedChat,
            chatNonce = chatNonce
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<ChatCreateRequest, ChatCreateResponse>(
            ChatProcedures.CREATE,
            request
        )
        val response = result.getOrThrow()
        Log.d(TAG, "Chat created on server: ${response.id}")
        
        // Cache the chat key
        chatKeyCache.set(response.id, chatKey)
        
        // Only update local state AFTER server success
        val chat = Chat(
            id = response.id,
            title = title,
            messages = emptyList(),
            lastMessage = null,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            encryptionKey = chatKey
        )
        _chats.value = _chats.value + chat
        
        return response.id
    }

    /**
     * Update a chat - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun updateChat(chat: Chat) {
        Log.d(TAG, "Updating chat ${chat.id}...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot update chat")
        }
        
        // Get chat key from cache or chat object
        val chatKey = chatKeyCache.get(chat.id) 
            ?: chat.encryptionKey 
            ?: throw IllegalStateException("No encryption key for chat ${chat.id}")
        
        // Encrypt title with chat key
        val (encryptedTitle, titleNonce) = encryptionManager.encryptSecretBoxString(chat.title, chatKey)
        
        // Encrypt messages
        val chatData = ChatData(
            messages = chat.messages.map { msg ->
                ChatMessageDto(
                    id = msg.id,
                    role = msg.role.name.lowercase(),
                    content = msg.content,
                    parentMessageId = msg.parentMessageId,
                    branchIndex = msg.branchIndex,
                    siblingCount = msg.siblingCount,
                    createdAt = msg.createdAt
                )
            }
        )
        val chatDataJson = json.encodeToString(chatData)
        val (encryptedChat, chatNonce) = encryptionManager.encryptSecretBoxString(chatDataJson, chatKey)
        
        val request = ChatUpdateRequest(
            chatId = chat.id,
            encryptedTitle = encryptedTitle,
            titleNonce = titleNonce,
            encryptedChat = encryptedChat,
            chatNonce = chatNonce
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<ChatUpdateRequest, ChatUpdateResponse>(
            ChatProcedures.UPDATE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Chat updated on server: ${chat.id}")
        
        // Only update local state AFTER server success
        val updatedChat = chat.copy(updatedAt = System.currentTimeMillis())
        _chats.value = _chats.value.map { 
            if (it.id == chat.id) updatedChat else it 
        }
    }
    
    /**
     * Update a chat's folder assignment - Server First (matching iOS)
     */
    override suspend fun updateChatFolder(chatId: String, folderId: String?) {
        Log.d(TAG, "Moving chat $chatId to folder $folderId...")
        
        val request = ChatUpdateRequest(
            chatId = chatId,
            folderId = folderId
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<ChatUpdateRequest, ChatUpdateResponse>(
            ChatProcedures.UPDATE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Chat folder updated on server: $chatId -> $folderId")
        
        // Only update local state AFTER server success
        _chats.value = _chats.value.map { chat ->
            if (chat.id == chatId) chat.copy(folderId = folderId, updatedAt = System.currentTimeMillis()) else chat
        }
    }

    /**
     * Delete a chat - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun deleteChat(chatId: String) {
        Log.d(TAG, "Deleting chat $chatId...")
        
        val request = ChatRemoveRequest(chatId = chatId)
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<ChatRemoveRequest, ChatRemoveResponse>(
            ChatProcedures.REMOVE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Chat deleted from server: $chatId")
        
        // Only update local state AFTER server success
        _chats.value = _chats.value.filter { it.id != chatId }
        chatKeyCache.remove(chatId)
    }

    /**
     * Refresh chats from server.
     * Fetches chat list from server and updates local state.
     */
    override suspend fun refreshChats() {
        Log.d(TAG, "Refreshing chats from server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot decrypt chats")
            return
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Fetch from server
        val result = trpcClient.query<Unit, List<EncryptedChatSummary>>(
            ChatProcedures.LIST,
            Unit
        )
        
        val encryptedChats = result.getOrThrow()
        Log.d(TAG, "Received ${encryptedChats.size} encrypted chats from server")
        
        // Decrypt and update local state
        val decryptedChats = encryptedChats.mapNotNull { encrypted ->
            try {
                decryptChatSummary(encrypted, masterKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decrypt chat ${encrypted.id}", e)
                null
            }
        }
        
        _chats.value = decryptedChats
        Log.d(TAG, "Decrypted ${decryptedChats.size} chats")
    }
    
    /**
     * Fetch a specific chat from server with full content (including messages).
     */
    override suspend fun fetchChat(chatId: String): Chat? {
        Log.d(TAG, "Fetching chat $chatId from server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot fetch chat")
            return null
        }
        
        try {
            val masterKey = e2eeRepository.getMasterKey()
            val request = ChatGetRequest(chatId = chatId)
            
            val result = trpcClient.query<ChatGetRequest, ChatGetResponse>(
                ChatProcedures.GET,
                request
            )
            
            return result.fold(
                onSuccess = { response ->
                    Log.d(TAG, "Received encrypted chat from server, decrypting...")
                    val chat = decryptFullChat(response, masterKey)
                    // Update cache
                    if (chat != null) {
                        _chats.value = _chats.value.filter { it.id != chatId } + chat
                    }
                    chat
                },
                onFailure = { e ->
                    Log.e(TAG, "Failed to fetch chat from server", e)
                    null
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching chat", e)
            return null
        }
    }
    
    /**
     * Sync a chat to the server (used after message streaming completes).
     */
    override suspend fun syncChat(chatId: String) {
        Log.d(TAG, "Syncing chat $chatId to server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot sync chat")
            return
        }
        
        val chat = _chats.value.find { it.id == chatId }
        if (chat == null) {
            Log.w(TAG, "Chat $chatId not found in local state")
            return
        }
        
        try {
            updateChat(chat)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync chat $chatId", e)
        }
    }

    override suspend fun getChatMessages(chatId: String): List<Message> {
        return _chats.value.find { it.id == chatId }?.messages ?: emptyList()
    }

    override fun observeMessages(chatId: String): Flow<List<Message>> {
        return _chats.map { chats ->
            chats.find { it.id == chatId }?.messages ?: emptyList()
        }
    }

    override fun sendMessageStream(chatId: String?, message: String, model: String, images: List<ImageData>): Flow<String> = flow {
        Log.d(TAG, "sendMessageStream: chatId=$chatId, model=$model, images=${images.size}")

        // Parse model string - format can be:
        // - "credentialId:modelName" (standard models)
        // - "private:modelName" (TEE private inference models)
        // - "modelName" (fallback to first credential)
        val modelRoute = parseModelString(model)
        if (modelRoute is ParsedModelRoute.Standard && modelRoute.credentialId == null) {
            Log.e(TAG, "No credential ID found in model string: $model")
            emit("Error: Please add an API key in Settings > API Connections")
            return@flow
        }
        
        // Get conversation history if we have a chatId
        val conversationHistory = if (chatId != null) {
            try {
                getChatMessages(chatId).map { msg ->
                    ChatMessage(
                        role = when (msg.role) {
                            MessageRole.USER -> ChatMessage.ROLE_USER
                            MessageRole.ASSISTANT -> ChatMessage.ROLE_ASSISTANT
                            MessageRole.SYSTEM -> ChatMessage.ROLE_SYSTEM
                        },
                        content = msg.content
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load chat history", e)
                emptyList()
            }
        } else {
            emptyList()
        }
        
        // Add the current message to history
        val messages = conversationHistory + ChatMessage.user(message)
        
        Log.d(TAG, "Sending ${messages.size} messages to LLM with ${images.size} images")
        
        try {
            when (modelRoute) {
                is ParsedModelRoute.Private -> {
                    llmRepository.streamPrivateChat(
                        modelId = modelRoute.modelId,
                        messages = messages,
                        systemPrompt = DEFAULT_SYSTEM_PROMPT
                    ).collect { event ->
                        when (event) {
                            is PrivateInferenceEvent.TextDelta -> emit(event.text)
                            is PrivateInferenceEvent.Finish -> {
                                Log.d(TAG, "Private stream completed: ${event.reason}")
                                if (chatId != null) {
                                    syncChatAfterMessage(chatId)
                                }
                            }
                            is PrivateInferenceEvent.Error -> {
                                Log.e(TAG, "Private stream error: ${event.message}", event.cause)
                                emit("\n\nError: ${event.message}")
                            }
                        }
                    }
                    if (chatId != null) {
                        syncChatAfterMessage(chatId)
                    }
                }
                is ParsedModelRoute.Standard -> {
                    val credentialId = requireNotNull(modelRoute.credentialId) {
                        "Missing credential for non-private model"
                    }
                    llmRepository.streamChat(
                        credentialId = credentialId,
                        messages = messages,
                        model = modelRoute.modelName,
                        systemPrompt = DEFAULT_SYSTEM_PROMPT,
                        images = images
                    ).collect { event ->
                        when (event) {
                            is StreamEvent.Text -> emit(event.content)
                            is StreamEvent.Reasoning -> {
                                Log.d(TAG, "Reasoning: ${event.content}")
                            }
                            is StreamEvent.ToolCall -> {
                                Log.d(TAG, "Tool call: ${event.name}")
                            }
                            is StreamEvent.Done -> {
                                Log.d(TAG, "Stream completed")
                                if (chatId != null) {
                                    syncChatAfterMessage(chatId)
                                }
                            }
                            is StreamEvent.Error -> {
                                Log.e(TAG, "Stream error: ${event.message}", event.cause)
                                emit("\n\nError: ${event.message}")
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stream chat", e)
            emit("Error: ${e.message}")
        }
    }

    private suspend fun parseModelString(model: String): ParsedModelRoute {
        if (llmRepository.isPrivateModel(model)) {
            return ParsedModelRoute.Private(modelId = model)
        }

        if (model.contains(":")) {
            val parts = model.split(":", limit = 2)
            return ParsedModelRoute.Standard(
                credentialId = parts[0],
                modelName = parts[1]
            )
        }

        // Fallback to first server-synced credential
        val serverCredentials = try {
            credentialRepository.getCredentials()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get server credentials", e)
            emptyList()
        }
        val firstCredential = serverCredentials.firstOrNull()
        return ParsedModelRoute.Standard(
            credentialId = firstCredential?.id,
            modelName = model
        )
    }

    private suspend fun syncChatAfterMessage(chatId: String) {
        try {
            syncChat(chatId)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to sync chat after message", e)
        }
    }

    private sealed interface ParsedModelRoute {
        data class Standard(val credentialId: String?, val modelName: String) : ParsedModelRoute
        data class Private(val modelId: String) : ParsedModelRoute
    }

    /**
     * Save a message to the chat (in-memory, then sync to server).
     */
    override suspend fun saveMessage(message: Message) {
        Log.d(TAG, "Saving message ${message.id} to chat ${message.chatId}")
        
        // Update in-memory chat with new message
        _chats.value = _chats.value.map { chat ->
            if (chat.id == message.chatId) {
                chat.copy(
                    messages = chat.messages + message,
                    lastMessage = message.content,
                    updatedAt = System.currentTimeMillis()
                )
            } else {
                chat
            }
        }
        
        // Note: Server sync happens via syncChat() after streaming completes
    }

    override suspend fun deleteMessage(messageId: String) {
        Log.d(TAG, "Deleting message $messageId")
        
        // Remove message from in-memory chat
        _chats.value = _chats.value.map { chat ->
            val updatedMessages = chat.messages.filter { it.id != messageId }
            if (updatedMessages.size != chat.messages.size) {
                chat.copy(
                    messages = updatedMessages,
                    lastMessage = updatedMessages.lastOrNull()?.content,
                    updatedAt = System.currentTimeMillis()
                )
            } else {
                chat
            }
        }
    }
    
    override fun clearKeyCache() {
        chatKeyCache.clear()
        Log.d(TAG, "Chat key cache cleared")
    }
    
    // ===== Private Helpers =====
    
    private data class DecryptedChatSummary(
        val id: String,
        val title: String,
        val createdAt: Long,
        val updatedAt: Long
    )
    
    private fun decryptChatSummary(encrypted: EncryptedChatSummary, masterKey: ByteArray): Chat {
        // Get or decrypt chat key
        val chatKey = getChatKey(
            chatId = encrypted.id,
            encryptedChatKey = encrypted.encryptedChatKey,
            chatKeyNonce = encrypted.chatKeyNonce,
            masterKey = masterKey
        )
        
        // Decrypt title (XSalsa20-Poly1305)
        val title = encryptionManager.decryptSecretBoxString(
            encrypted.encryptedTitle,
            encrypted.titleNonce,
            chatKey
        )
        
        return Chat(
            id = encrypted.id,
            title = title,
            messages = emptyList(), // Messages not included in summary
            lastMessage = null,
            folderId = encrypted.folderId,
            pinned = encrypted.pinned,
            archived = encrypted.archived,
            createdAt = encrypted.createdAt,
            updatedAt = encrypted.updatedAt,
            encryptionKey = chatKey
        )
    }
    
    private fun decryptFullChat(response: ChatGetResponse, masterKey: ByteArray): Chat? {
        return try {
            // Get or decrypt chat key
            val chatKey = getChatKey(
                chatId = response.id,
                encryptedChatKey = response.encryptedChatKey,
                chatKeyNonce = response.chatKeyNonce,
                masterKey = masterKey
            )
            
            // Decrypt title (XSalsa20-Poly1305)
            val title = encryptionManager.decryptSecretBoxString(
                response.encryptedTitle,
                response.titleNonce,
                chatKey
            )
            
            // Decrypt messages (XSalsa20-Poly1305)
            val messagesJson = encryptionManager.decryptSecretBoxString(
                response.encryptedChat,
                response.chatNonce,
                chatKey
            )
            
            val chatData = json.decodeFromString<ChatData>(messagesJson)
            val messages = chatData.messages.map { dto ->
                Message(
                    id = dto.id,
                    chatId = response.id,
                    role = MessageRole.valueOf(dto.role.uppercase()),
                    content = dto.content,
                    parentMessageId = dto.parentMessageId,
                    branchIndex = dto.branchIndex,
                    siblingCount = dto.siblingCount,
                    createdAt = dto.createdAt
                )
            }
            
            Log.d(TAG, "Decrypted chat '$title' with ${messages.size} messages")
            
            Chat(
                id = response.id,
                title = title,
                messages = messages,
                lastMessage = messages.lastOrNull()?.content,
                folderId = response.folderId,
                pinned = response.pinned,
                archived = response.archived,
                createdAt = response.createdAt,
                updatedAt = response.updatedAt,
                encryptionKey = chatKey
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decrypt full chat", e)
            null
        }
    }
    
    private fun getChatKey(
        chatId: String,
        encryptedChatKey: String,
        chatKeyNonce: String,
        masterKey: ByteArray
    ): ByteArray {
        // Check cache first
        chatKeyCache.get(chatId)?.let { return it }
        
        // Decrypt chat key using master key (XSalsa20-Poly1305)
        val chatKey = encryptionManager.decryptSecretBox(
            encryptedChatKey,
            chatKeyNonce,
            masterKey
        )
        
        // Cache it
        chatKeyCache.set(chatId, chatKey)
        
        return chatKey
    }
}
