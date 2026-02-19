package chat.onera.mobile.presentation.features.main

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.demo.DemoData
import chat.onera.mobile.demo.DemoModeManager
import chat.onera.mobile.demo.DemoRepositoryContainer
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.data.remote.ChatTasksService
import chat.onera.mobile.data.remote.llm.ChatMessage
import chat.onera.mobile.data.remote.llm.DecryptedCredential
import chat.onera.mobile.domain.model.PromptSummary
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.FoldersRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.domain.repository.PromptRepository
import chat.onera.mobile.data.remote.private_inference.EnclaveService
import chat.onera.mobile.data.remote.private_inference.PRIVATE_MODEL_PREFIX
import chat.onera.mobile.data.remote.trpc.AuthTokenProvider
import chat.onera.mobile.data.remote.websocket.WebSocketService
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.features.main.handlers.AttachmentProcessor
import chat.onera.mobile.presentation.features.main.handlers.TTSHandler
import chat.onera.mobile.presentation.features.main.handlers.VoiceInputEvent
import chat.onera.mobile.presentation.features.main.handlers.VoiceInputHandler
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import chat.onera.mobile.presentation.features.main.model.ModelOption
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import timber.log.Timber
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val chatRepository: ChatRepository,
    private val credentialRepository: CredentialRepository,
    private val foldersRepository: FoldersRepository,
    private val llmRepository: LLMRepository,
    private val enclaveService: EnclaveService,
    private val webSocketService: WebSocketService,
    private val authTokenProvider: AuthTokenProvider,
    private val voiceInputHandler: VoiceInputHandler,
    private val ttsHandler: TTSHandler,
    private val attachmentProcessor: AttachmentProcessor,
    private val chatTasksService: ChatTasksService,
    private val promptRepository: PromptRepository
) : BaseViewModel<MainState, MainIntent, MainEffect>(MainState()) {

    private var streamingJob: Job? = null
    private var followUpJob: Job? = null
    
    /**
     * Get the effective chat repository - demo or real based on mode.
     */
    private val effectiveChatRepository: ChatRepository
        get() = if (DemoModeManager.isActiveNow()) {
            DemoRepositoryContainer.chatRepository
        } else {
            chatRepository
        }

    init {
        loadInitialData()
        observeChats()
        observeFolders()
        observePrompts()
        setupVoiceInputHandler()
        setupTTSHandler()
        setupWebSocket()
    }
    
    // MARK: - Handler Setup
    
    private fun setupVoiceInputHandler() {
        voiceInputHandler.observeState(viewModelScope) { state ->
            updateState { 
                copy(chatState = chatState.copy(
                    isRecording = state.isRecording,
                    transcribedText = state.transcribedText
                ))
            }
        }
        // Observe voice input events (errors)
        viewModelScope.launch {
            voiceInputHandler.events.collect { event ->
                when (event) {
                    is VoiceInputEvent.Error -> sendEffect(MainEffect.ShowError(event.message))
                    is VoiceInputEvent.TranscriptionResult -> { /* handled via callback */ }
                }
            }
        }
    }
    
    private fun setupTTSHandler() {
        ttsHandler.observeState(viewModelScope) { state ->
            updateState {
                copy(chatState = chatState.copy(
                    isSpeaking = state.isSpeaking,
                    speakingMessageId = state.speakingMessageId,
                    speakingStartTime = state.speakingStartTime
                ))
            }
        }
    }
    
    private fun setupWebSocket() {
        // Skip WebSocket in demo mode
        if (DemoModeManager.isActiveNow()) {
            Timber.d("Demo mode: skipping WebSocket setup")
            return
        }
        
        viewModelScope.launch {
            try {
                // Get auth token and configure WebSocket
                val token = authTokenProvider.getToken()
                if (token != null) {
                    webSocketService.setAuthToken(token)
                    webSocketService.connect()
                    Timber.d("WebSocket connected with auth token")
                } else {
                    Timber.w("No auth token available for WebSocket")
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to setup WebSocket")
            }
        }
        
        // Collect WebSocket messages for real-time sync
        viewModelScope.launch {
            webSocketService.messages.collect { message ->
                Timber.d("WebSocket message received: type=${message.type}")
                when (message.type) {
                    "chat_sync" -> {
                        Timber.d("Chat sync event, refreshing chats")
                        refreshChats()
                    }
                    "note_sync" -> {
                        Timber.d("Note sync event received")
                        // Notes are handled by NotesViewModel, but refresh chats in case of related changes
                    }
                    "folder_sync" -> {
                        Timber.d("Folder sync event, refreshing folders")
                        loadFolders()
                    }
                }
            }
        }
    }
    
    private fun cleanupWebSocket() {
        webSocketService.disconnect()
        Timber.d("WebSocket disconnected")
    }
    
    override fun onCleared() {
        super.onCleared()
        cleanupWebSocket()
    }

    override fun handleIntent(intent: MainIntent) {
        when (intent) {
            is MainIntent.RefreshChats -> refreshChats()
            is MainIntent.SelectChat -> selectChat(intent.chatId)
            is MainIntent.CreateNewChat -> createNewChat()
            is MainIntent.DeleteChat -> deleteChat(intent.chatId)
            is MainIntent.UpdateSearchQuery -> updateSearchQuery(intent.query)
            is MainIntent.SendMessage -> sendMessage(intent.content)
            is MainIntent.UpdateChatInput -> updateChatInput(intent.input)
            is MainIntent.StopStreaming -> stopStreaming()
            is MainIntent.RegenerateResponse -> regenerateResponse(intent.messageId)
            is MainIntent.CopyMessage -> copyMessage(intent.content)
            is MainIntent.SelectModel -> selectModel(intent.model)
            is MainIntent.EditMessage -> editMessage(intent.messageId, intent.newContent, intent.regenerate)
            is MainIntent.StartRecording -> startRecording()
            is MainIntent.StopRecording -> stopRecording()
            is MainIntent.SpeakMessage -> speakMessage(intent.text, intent.messageId)
            is MainIntent.StopSpeaking -> stopSpeaking()
            is MainIntent.AddAttachment -> addAttachment(intent.attachment)
            is MainIntent.RemoveAttachment -> removeAttachment(intent.attachmentId)
            is MainIntent.ClearAttachments -> clearAttachments()
            is MainIntent.NavigateToPreviousBranch -> navigateToPreviousBranch(intent.messageId)
            is MainIntent.NavigateToNextBranch -> navigateToNextBranch(intent.messageId)
            is MainIntent.SignOut -> signOut()
            is MainIntent.OnE2EEUnlocked -> onE2EEUnlocked()
            // Folder intents
            is MainIntent.LoadFolders -> loadFolders()
            is MainIntent.CreateFolder -> createFolder(intent.name, intent.parentId)
            is MainIntent.DeleteFolder -> deleteFolder(intent.folderId)
            is MainIntent.RenameFolder -> renameFolder(intent.folderId, intent.newName)
            is MainIntent.SelectFolder -> selectFolder(intent.folderId)
            is MainIntent.MoveChatToFolder -> moveChatToFolder(intent.chatId, intent.folderId)
            is MainIntent.ToggleFolderExpanded -> toggleFolderExpanded(intent.folderId)
            is MainIntent.SelectFollowUp -> selectFollowUp(intent.text)
            is MainIntent.ToggleArtifactsPanel -> toggleArtifactsPanel()
            is MainIntent.ClearError -> updateState { copy(error = null) }
        }
    }
    
    private fun onE2EEUnlocked() {
        Timber.d("E2EE unlocked, refreshing all data...")
        viewModelScope.launch {
            try {
                // Refresh chats from server
                refreshChats()
                // Refresh credentials from server and wait for completion
                refreshCredentialsAndWait()
                // Reload models (now with credentials available)
                loadModels()
                Timber.d("Data refresh after E2EE unlock complete")
            } catch (e: Exception) {
                Timber.e(e, "Failed to refresh data after E2EE unlock")
            }
        }
    }
    
    private fun signOut() {
        viewModelScope.launch {
            try {
                if (DemoModeManager.isActiveNow()) {
                    // Demo mode: just deactivate and navigate
                    DemoModeManager.deactivate()
                    sendEffect(MainEffect.SignOutComplete)
                    return@launch
                }
                
                // Clear encryption key cache
                chatRepository.clearKeyCache()
                // Sign out from Supabase
                authRepository.signOut()
                // Notify UI to navigate to auth screen
                sendEffect(MainEffect.SignOutComplete)
            } catch (e: Exception) {
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to sign out"))
            }
        }
    }
    
    private fun navigateToPreviousBranch(messageId: String) {
        val message = currentState.chatState.allMessages.find { it.id == messageId } ?: return
        val parentId = message.parentMessageId ?: return
        
        val currentIndex = currentState.chatState.selectedBranches[parentId] ?: message.branchIndex
        if (currentIndex > 0) {
            updateState {
                copy(
                    chatState = chatState.copy(
                        selectedBranches = chatState.selectedBranches + (parentId to (currentIndex - 1))
                    )
                )
            }
        }
    }
    
    private fun navigateToNextBranch(messageId: String) {
        val message = currentState.chatState.allMessages.find { it.id == messageId } ?: return
        val parentId = message.parentMessageId ?: return
        
        // Find all siblings to get the total count
        val siblings = currentState.chatState.allMessages.filter { it.parentMessageId == parentId }
        val currentIndex = currentState.chatState.selectedBranches[parentId] ?: message.branchIndex
        
        if (currentIndex < siblings.size - 1) {
            updateState {
                copy(
                    chatState = chatState.copy(
                        selectedBranches = chatState.selectedBranches + (parentId to (currentIndex + 1))
                    )
                )
            }
        }
    }
    
    private fun addAttachment(attachment: chat.onera.mobile.domain.model.Attachment) {
        Timber.d("Adding attachment: ${attachment.fileName}, uri: ${attachment.uri}")
        updateState {
            copy(
                chatState = chatState.copy(
                    attachments = chatState.attachments + attachment
                )
            )
        }
        Timber.d("Total attachments now: ${currentState.chatState.attachments.size}")
    }
    
    private fun removeAttachment(attachmentId: String) {
        updateState {
            copy(
                chatState = chatState.copy(
                    attachments = chatState.attachments.filter { it.id != attachmentId }
                )
            )
        }
    }
    
    private fun clearAttachments() {
        updateState {
            copy(
                chatState = chatState.copy(attachments = emptyList())
            )
        }
    }

    // MARK: - Voice Input Methods
    
    private fun startRecording() {
        voiceInputHandler.startRecording { result ->
            updateState { 
                copy(
                    chatState = chatState.copy(
                        inputText = chatState.inputText + (if (chatState.inputText.isBlank()) "" else " ") + result
                    )
                ) 
            }
        }
    }

    private fun stopRecording() {
        val result = voiceInputHandler.stopRecording()
        if (result.isNotBlank() && result != currentState.chatState.inputText) {
            updateState { 
                copy(
                    chatState = chatState.copy(
                        inputText = chatState.inputText + (if (chatState.inputText.isBlank()) "" else " ") + result
                    )
                ) 
            }
        }
    }
    
    // MARK: - TTS Methods

    private fun speakMessage(text: String, messageId: String) {
        ttsHandler.speak(text, messageId)
    }

    private fun stopSpeaking() {
        ttsHandler.stop()
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            try {
                // Check for demo mode
                if (DemoModeManager.isActiveNow()) {
                    Timber.d("Demo mode active, loading demo data")
                    updateState { copy(currentUser = DemoData.demoUser) }
                    loadDemoChats()
                    loadModels() // Will use demo models
                    return@launch
                }
                
                val user = authRepository.getCurrentUser()
                updateState { copy(currentUser = user) }
                refreshChats()
                // Await credentials before loading models (fixes race condition)
                refreshCredentialsAndWait()
                loadModels()
            } catch (e: Exception) {
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to load data"))
            }
        }
    }
    
    /**
     * Load demo chats for demo mode.
     */
    private fun loadDemoChats() {
        val demoChats = DemoData.demoChatSummaries
        val grouped = groupChatsByDate(demoChats)
        updateState { 
            copy(
                chats = demoChats,
                groupedChats = grouped,
                isLoadingChats = false
            ) 
        }
    }
    
    /**
     * Refresh credentials and wait for completion.
     * This ensures loadModels() has credentials available.
     */
    private suspend fun refreshCredentialsAndWait() {
        try {
            credentialRepository.refreshCredentials()
            Timber.d("Credentials refreshed successfully")
        } catch (e: Exception) {
            // Silently fail - credentials might not be available yet (E2EE locked)
            Timber.w(e, "Failed to refresh credentials")
        }
    }

    private fun observeChats() {
        // Skip observing chats in demo mode - we load them directly
        if (DemoModeManager.isActiveNow()) {
            Timber.d("Demo mode: skipping chat observation")
            return
        }
        
        chatRepository.observeChats()
            .onEach { chats ->
                val summaries = chats.map { chat ->
                    ChatSummary(
                        id = chat.id,
                        title = chat.title,
                        lastMessage = chat.lastMessage,
                        updatedAt = chat.updatedAt,
                        isEncrypted = true
                    )
                }
                val grouped = groupChatsByDate(summaries)
                updateState { 
                    copy(
                        chats = summaries,
                        groupedChats = grouped,
                        isLoadingChats = false
                    ) 
                }
            }
            .catch { e ->
                updateState { copy(isLoadingChats = false) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to observe chats"))
            }
            .launchIn(viewModelScope)
    }

    private fun refreshChats() {
        viewModelScope.launch {
            // In demo mode, just reload demo chats
            if (DemoModeManager.isActiveNow()) {
                loadDemoChats()
                return@launch
            }
            
            updateState { copy(isLoadingChats = true) }
            try {
                chatRepository.refreshChats()
                // Set loading to false after refresh completes (even if E2EE is locked and returns early)
                updateState { copy(isLoadingChats = false) }
            } catch (e: Exception) {
                updateState { copy(isLoadingChats = false) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to refresh chats"))
            }
        }
    }

    private fun selectChat(chatId: String) {
        viewModelScope.launch {
            updateState { 
                copy(
                    selectedChatId = chatId,
                    chatState = chatState.copy(isLoading = true)
                ) 
            }
            try {
                // First try to get messages from local database
                var messages = effectiveChatRepository.getChatMessages(chatId)
                var chat = effectiveChatRepository.getChat(chatId)
                
                // If no messages locally, fetch from server with decryption
                if (messages.isEmpty()) {
                    val fetchedChat = effectiveChatRepository.fetchChat(chatId)
                    if (fetchedChat != null) {
                        messages = fetchedChat.messages
                        chat = fetchedChat
                    }
                }
                
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            chatId = chatId,
                            chatTitle = chat?.title ?: "Chat",
                            allMessages = messages,
                            selectedBranches = emptyMap(),
                            isLoading = false
                        )
                    ) 
                }
            } catch (e: Exception) {
                updateState { copy(chatState = chatState.copy(isLoading = false)) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to load chat"))
            }
        }
    }

    private fun createNewChat() {
        updateState { 
            copy(
                selectedChatId = null,
                chatState = ChatState(
                    chatTitle = "New chat",
                    allMessages = emptyList(),
                    selectedBranches = emptyMap(),
                    // Preserve model selection when creating new chat
                    selectedModel = chatState.selectedModel,
                    availableModels = chatState.availableModels
                )
            ) 
        }
    }

    private fun deleteChat(chatId: String) {
        viewModelScope.launch {
            try {
                effectiveChatRepository.deleteChat(chatId)
                if (currentState.selectedChatId == chatId) {
                    createNewChat()
                }
            } catch (e: Exception) {
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to delete chat"))
            }
        }
    }

    private fun updateSearchQuery(query: String) {
        updateState { copy(searchQuery = query) }
    }
    
    // MARK: - Prompt Methods
    
    private fun observePrompts() {
        // Skip in demo mode
        if (DemoModeManager.isActiveNow()) {
            Timber.d("Demo mode: skipping prompt observation")
            return
        }
        
        promptRepository.observePrompts()
            .onEach { prompts ->
                val summaries = prompts.map { PromptSummary(it.id, it.name, it.description) }
                updateState { copy(promptSummaries = summaries) }
            }
            .catch { e ->
                Timber.e(e, "Failed to observe prompts")
            }
            .launchIn(viewModelScope)
        
        // Initial refresh
        viewModelScope.launch {
            try {
                promptRepository.refreshPrompts()
            } catch (e: Exception) {
                Timber.w(e, "Failed to refresh prompts")
            }
        }
    }
    
    /**
     * Fetch the full content of a prompt by its summary.
     * Used by the @mention system in MessageInputBar.
     */
    suspend fun fetchPromptContent(summary: PromptSummary): String? {
        return try {
            promptRepository.getPrompt(summary.id)?.content
        } catch (e: Exception) {
            Timber.e(e, "Failed to fetch prompt content for ${summary.id}")
            null
        }
    }
    
    // MARK: - Folder Methods
    
    private fun observeFolders() {
        // Skip observing folders in demo mode
        if (DemoModeManager.isActiveNow()) {
            Timber.d("Demo mode: skipping folder observation")
            return
        }
        
        foldersRepository.observeFolders()
            .onEach { folders ->
                updateState { copy(folders = folders, isLoadingFolders = false) }
            }
            .catch { e ->
                Timber.e(e, "Failed to observe folders")
                updateState { copy(isLoadingFolders = false) }
            }
            .launchIn(viewModelScope)
    }
    
    private fun loadFolders() {
        viewModelScope.launch {
            updateState { copy(isLoadingFolders = true) }
            try {
                foldersRepository.refreshFolders()
                updateState { copy(isLoadingFolders = false) }
            } catch (e: Exception) {
                Timber.e(e, "Failed to load folders")
                updateState { copy(isLoadingFolders = false) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to load folders"))
            }
        }
    }
    
    private fun createFolder(name: String, parentId: String?) {
        viewModelScope.launch {
            try {
                foldersRepository.createFolder(name, parentId)
                Timber.d("Folder created: $name")
            } catch (e: Exception) {
                Timber.e(e, "Failed to create folder")
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to create folder"))
            }
        }
    }
    
    private fun deleteFolder(folderId: String) {
        viewModelScope.launch {
            try {
                foldersRepository.deleteFolder(folderId)
                // If the deleted folder was selected, clear selection
                if (currentState.selectedFolderId == folderId) {
                    updateState { copy(selectedFolderId = null) }
                }
                Timber.d("Folder deleted: $folderId")
            } catch (e: Exception) {
                Timber.e(e, "Failed to delete folder")
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to delete folder"))
            }
        }
    }
    
    private fun renameFolder(folderId: String, newName: String) {
        viewModelScope.launch {
            try {
                val folder = currentState.folders.find { it.id == folderId }
                if (folder != null) {
                    foldersRepository.updateFolder(folder.copy(name = newName))
                    Timber.d("Folder renamed: $folderId -> $newName")
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to rename folder")
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to rename folder"))
            }
        }
    }
    
    private fun selectFolder(folderId: String?) {
        updateState { 
            copy(
                // Toggle: if same folder selected, deselect to show all
                selectedFolderId = if (selectedFolderId == folderId) null else folderId
            ) 
        }
    }
    
    private fun toggleFolderExpanded(folderId: String) {
        updateState {
            copy(
                expandedFolderIds = if (folderId in expandedFolderIds) {
                    expandedFolderIds - folderId
                } else {
                    expandedFolderIds + folderId
                }
            )
        }
    }
    
    private fun moveChatToFolder(chatId: String, folderId: String?) {
        viewModelScope.launch {
            try {
                effectiveChatRepository.updateChatFolder(chatId, folderId)
                // Refresh chats to reflect the change
                refreshChats()
                Timber.d("Chat $chatId moved to folder $folderId")
            } catch (e: Exception) {
                Timber.e(e, "Failed to move chat to folder")
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to move chat to folder"))
            }
        }
    }

    /**
     * Convert an attachment URI to ImageData (base64)
     */
    private suspend fun convertAttachmentToImageData(attachment: chat.onera.mobile.domain.model.Attachment) =
        attachmentProcessor.convertToImageData(attachment)

    private fun sendMessage(content: String, parentMessageId: String? = null, branchIndex: Int = 0, siblingCount: Int = 1) {
        // Allow sending if there's text OR attachments
        val hasAttachments = currentState.chatState.attachments.isNotEmpty()
        if (content.isBlank() && !hasAttachments) return
        
        // Prevent duplicate sends - check isSending and isStreaming SYNCHRONOUSLY before launching coroutine
        if (currentState.chatState.isSending || currentState.chatState.isStreaming) return
        
        val selectedModel = currentState.chatState.selectedModel
        if (selectedModel == null) {
            sendEffect(MainEffect.ShowError("Please select a model first"))
            return
        }

        // Set isSending synchronously BEFORE launching coroutine to prevent race condition
        // Clear follow-ups when sending a new message
        followUpJob?.cancel()
        updateState { copy(chatState = chatState.copy(isSending = true, followUps = emptyList())) }

        // Capture attachments before clearing
        val attachmentsToSend = currentState.chatState.attachments.toList()

        viewModelScope.launch {
            val userMessageId = "user_${System.currentTimeMillis()}"
            
            // Convert attachments to ImageData
            val images = attachmentsToSend.mapNotNull { attachment ->
                convertAttachmentToImageData(attachment)
            }
            Timber.d("Converted ${images.size} images for LLM")
            
            // Create chat on server FIRST if this is a new chat (matching iOS behavior)
            var chatId = currentState.chatState.chatId
            if (chatId == null) {
                try {
                    Timber.d("Creating new chat on server...")
                    // Use first part of message as title (max 50 chars)
                    val title = content.take(50).ifBlank { "Image chat" }
                    chatId = effectiveChatRepository.createChat(title)
                    Timber.d("Chat created: $chatId")
                    updateState { 
                        copy(
                            selectedChatId = chatId,
                            chatState = chatState.copy(chatId = chatId, chatTitle = title)
                        ) 
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Failed to create chat")
                    updateState { copy(chatState = chatState.copy(isSending = false)) }
                    sendEffect(MainEffect.ShowError("Failed to create chat: ${e.message}"))
                    return@launch
                }
            }
            
            // Prepare message content (include image indicator if images present)
            val messageContent = if (images.isNotEmpty() && content.isBlank()) {
                "What's in this image?"
            } else {
                content
            }
            
            // Add user message (only if not a regeneration from existing user message)
            if (parentMessageId == null) {
                // Collect image URIs for display in the chat
                val imageUriStrings = attachmentsToSend.map { it.uri.toString() }
                
                val userMessage = Message(
                    id = userMessageId,
                    chatId = chatId,
                    content = messageContent,
                    role = chat.onera.mobile.domain.model.MessageRole.USER,
                    createdAt = System.currentTimeMillis(),
                    imageUris = imageUriStrings
                )
                
                // Save user message to repository
                effectiveChatRepository.saveMessage(userMessage)
                
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            allMessages = chatState.allMessages + userMessage,
                            inputText = "",
                            attachments = emptyList(), // Clear attachments after sending
                            isSending = false,
                            isStreaming = true,
                            streamingMessage = ""
                        )
                    ) 
                }
            } else {
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            isSending = false,
                            isStreaming = true,
                            streamingMessage = "",
                            attachments = emptyList() // Clear attachments
                        )
                    ) 
                }
            }
            
            try {
                // Stream response - use apiModelId which includes credentialId
                streamingJob = effectiveChatRepository.sendMessageStream(
                    chatId = chatId,
                    message = messageContent,
                    model = selectedModel.apiModelId,
                    images = images
                )
                    .onEach { chunk ->
                        updateState { 
                            copy(
                                chatState = chatState.copy(
                                    streamingMessage = chatState.streamingMessage + chunk
                                )
                            ) 
                        }
                    }
                    .catch { e ->
                        updateState { copy(chatState = chatState.copy(isStreaming = false)) }
                        sendEffect(MainEffect.ShowError(e.message ?: "Failed to send message"))
                    }
                    .launchIn(viewModelScope)
                
                streamingJob?.join()
                
                // The actual parent for the assistant message
                val actualParentId = parentMessageId ?: userMessageId
                
                // Add assistant message when done
                val assistantMessage = Message(
                    id = "assistant_${System.currentTimeMillis()}",
                    chatId = chatId,
                    content = currentState.chatState.streamingMessage,
                    role = chat.onera.mobile.domain.model.MessageRole.ASSISTANT,
                    createdAt = System.currentTimeMillis(),
                    parentMessageId = actualParentId,
                    branchIndex = branchIndex,
                    siblingCount = siblingCount
                )
                
                // Save assistant message to repository
                effectiveChatRepository.saveMessage(assistantMessage)
                
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            allMessages = chatState.allMessages + assistantMessage,
                            isStreaming = false,
                            streamingMessage = "",
                            // Select the new branch if it's a regeneration
                            selectedBranches = if (parentMessageId != null) {
                                chatState.selectedBranches + (actualParentId to branchIndex)
                            } else {
                                chatState.selectedBranches
                            }
                        )
                    ) 
                }
                
                // Sync the chat with messages to server
                try {
                    effectiveChatRepository.syncChat(chatId)
                    Timber.d("Chat synced to server: $chatId")
                } catch (e: Exception) {
                    Timber.w(e, "Failed to sync chat")
                }
                
                // Generate follow-up suggestions in background
                generateFollowUps()
            } catch (e: Exception) {
                updateState { copy(chatState = chatState.copy(isStreaming = false)) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to send message"))
            }
        }
    }

    private fun selectFollowUp(text: String) {
        // Clear follow-ups and send the selected text as a message
        updateState { copy(chatState = chatState.copy(followUps = emptyList())) }
        sendMessage(text)
    }
    
    private fun toggleArtifactsPanel() {
        updateState {
            copy(chatState = chatState.copy(showArtifactsPanel = !chatState.showArtifactsPanel))
        }
    }
    
    // MARK: - Follow-up Generation
    
    private fun generateFollowUps() {
        // Cancel any existing follow-up job
        followUpJob?.cancel()
        
        val selectedModel = currentState.chatState.selectedModel ?: return
        // Skip for private models (no credential)
        if (selectedModel.provider == ModelProvider.PRIVATE) return
        val credentialId = selectedModel.credentialId ?: return
        
        followUpJob = viewModelScope.launch {
            try {
                // Get the decrypted credential
                val credential = credentialRepository.getCredential(credentialId) ?: return@launch
                
                val llmProvider = chat.onera.mobile.data.remote.llm.LLMProvider.fromName(credential.provider.name)
                    ?: chat.onera.mobile.data.remote.llm.LLMProvider.OPENAI
                
                val decrypted = DecryptedCredential(
                    id = credential.id,
                    provider = llmProvider,
                    apiKey = credential.apiKey,
                    name = credential.name,
                    baseUrl = credential.baseUrl
                )
                
                // Convert recent messages to ChatMessage format
                val recentMessages = currentState.chatState.messages.takeLast(6).map { msg ->
                    when (msg.role) {
                        chat.onera.mobile.domain.model.MessageRole.USER -> ChatMessage.user(msg.content)
                        chat.onera.mobile.domain.model.MessageRole.ASSISTANT -> ChatMessage.assistant(msg.content)
                        chat.onera.mobile.domain.model.MessageRole.SYSTEM -> ChatMessage.system(msg.content)
                    }
                }
                
                val followUps = chatTasksService.generateFollowUps(
                    recentMessages = recentMessages,
                    credential = decrypted,
                    model = selectedModel.id
                )
                
                if (followUps.isNotEmpty()) {
                    updateState {
                        copy(chatState = chatState.copy(followUps = followUps))
                    }
                }
            } catch (e: Exception) {
                Timber.w(e, "Failed to generate follow-ups")
            }
        }
    }

    private fun updateChatInput(input: String) {
        updateState { copy(chatState = chatState.copy(inputText = input)) }
    }

    private fun stopStreaming() {
        streamingJob?.cancel()
        streamingJob = null
        
        // If we have partial content, save it as a message
        if (currentState.chatState.streamingMessage.isNotBlank()) {
            // Find the last user message to use as parent
            val lastUserMessage = currentState.chatState.allMessages
                .lastOrNull { it.role == chat.onera.mobile.domain.model.MessageRole.USER }
            
            val assistantMessage = Message(
                id = "assistant_${System.currentTimeMillis()}",
                chatId = currentState.chatState.chatId ?: "",
                content = currentState.chatState.streamingMessage,
                role = chat.onera.mobile.domain.model.MessageRole.ASSISTANT,
                createdAt = System.currentTimeMillis(),
                parentMessageId = lastUserMessage?.id
            )
            
            updateState { 
                copy(
                    chatState = chatState.copy(
                        allMessages = chatState.allMessages + assistantMessage,
                        isStreaming = false,
                        streamingMessage = ""
                    )
                ) 
            }
        } else {
            updateState { copy(chatState = chatState.copy(isStreaming = false)) }
        }
    }

    private fun regenerateResponse(messageId: String) {
        viewModelScope.launch {
            try {
                // Find the assistant message to regenerate
                val assistantMessage = currentState.chatState.allMessages.find { it.id == messageId }
                if (assistantMessage == null || assistantMessage.role != chat.onera.mobile.domain.model.MessageRole.ASSISTANT) {
                    return@launch
                }
                
                // Find the parent user message
                val parentId = assistantMessage.parentMessageId
                val userMessage = if (parentId != null) {
                    currentState.chatState.allMessages.find { it.id == parentId }
                } else {
                    // Fallback: find user message by position (for legacy messages without parentId)
                    val messages = currentState.chatState.messages
                    val msgIndex = messages.indexOfFirst { it.id == messageId }
                    if (msgIndex > 0) messages[msgIndex - 1] else null
                }
                
                if (userMessage == null || userMessage.role != chat.onera.mobile.domain.model.MessageRole.USER) {
                    return@launch
                }
                
                // Find all existing siblings for this parent
                val existingSiblings = currentState.chatState.allMessages.filter { 
                    it.parentMessageId == userMessage.id && 
                    it.role == chat.onera.mobile.domain.model.MessageRole.ASSISTANT 
                }
                
                val newBranchIndex = existingSiblings.size
                val newSiblingCount = newBranchIndex + 1
                
                // Update siblingCount on all existing siblings
                val updatedMessages = currentState.chatState.allMessages.map { msg ->
                    if (msg.parentMessageId == userMessage.id && msg.role == chat.onera.mobile.domain.model.MessageRole.ASSISTANT) {
                        msg.copy(siblingCount = newSiblingCount)
                    } else {
                        msg
                    }
                }
                
                updateState {
                    copy(
                        chatState = chatState.copy(
                            allMessages = updatedMessages
                        )
                    )
                }
                
                // Generate new response as a new sibling
                sendMessage(
                    content = userMessage.content,
                    parentMessageId = userMessage.id,
                    branchIndex = newBranchIndex,
                    siblingCount = newSiblingCount
                )
            } catch (e: Exception) {
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to regenerate"))
            }
        }
    }

    private fun copyMessage(content: String) {
        sendEffect(MainEffect.CopyToClipboard(content))
    }

    private fun selectModel(model: ModelOption) {
        updateState { copy(chatState = chatState.copy(selectedModel = model)) }
    }

    private fun editMessage(messageId: String, newContent: String, regenerate: Boolean) {
        val trimmedContent = newContent.trim()
        if (trimmedContent.isBlank()) return
        
        val allMessages = currentState.chatState.allMessages
        val messageIndex = allMessages.indexOfFirst { it.id == messageId }
        if (messageIndex < 0) return
        
        val message = allMessages[messageIndex]
        if (message.role != chat.onera.mobile.domain.model.MessageRole.USER) return
        
        // Update the message with edited content
        val editedMessage = message.copy(
            content = trimmedContent,
            edited = true,
            editedAt = System.currentTimeMillis()
        )
        
        if (regenerate) {
            // Keep all messages but remove any that are "after" this user message
            // (i.e., messages with this as parent or descendants)
            val messagesBeforeEdit = allMessages
                .take(messageIndex)
                .plus(editedMessage)
            
            updateState { 
                copy(
                    chatState = chatState.copy(
                        allMessages = messagesBeforeEdit,
                        selectedBranches = emptyMap() // Reset branch selections
                    )
                ) 
            }
            
            // Trigger new response
            sendMessage(trimmedContent)
        } else {
            // Just update the message in place without regenerating
            val updatedMessages = allMessages.toMutableList()
            updatedMessages[messageIndex] = editedMessage
            
            updateState { 
                copy(
                    chatState = chatState.copy(
                        allMessages = updatedMessages
                    )
                ) 
            }
        }
    }

    private fun loadModels() {
        viewModelScope.launch {
            try {
                // Check for demo mode first
                if (DemoModeManager.isActiveNow()) {
                    Timber.d("Demo mode active, using demo models")
                    val demoModels = DemoData.demoModels
                    updateState { 
                        copy(
                            chatState = chatState.copy(
                                availableModels = demoModels,
                                selectedModel = demoModels.firstOrNull()
                            )
                        ) 
                    }
                    return@launch
                }
                
                val allModels = mutableListOf<ModelOption>()

                // Regular API models from user credentials
                val serverCredentials = try {
                    credentialRepository.getCredentials()
                } catch (e: Exception) {
                    Timber.w(e, "Failed to load credentials for model list")
                    emptyList()
                }

                Timber.d("Loading models for ${serverCredentials.size} credentials")
                for (credential in serverCredentials) {
                    val provider = try {
                        ModelProvider.valueOf(credential.provider.name)
                    } catch (e: Exception) {
                        ModelProvider.OPENAI
                    }
                    
                    // Use default models for each provider
                    allModels.addAll(getDefaultModelsForProvider(provider, credential.id))
                }

                // Private TEE models (do not require a credential)
                val privateModels = try {
                    enclaveService.listModels().map { model ->
                        val modelId = "$PRIVATE_MODEL_PREFIX${model.id}"
                        val displayName = model.displayName?.takeIf { it.isNotBlank() }
                            ?: "${model.name} (Private)"
                        ModelOption(
                            id = modelId,
                            displayName = displayName,
                            provider = ModelProvider.PRIVATE,
                            credentialId = null
                        )
                    }
                } catch (e: Exception) {
                    Timber.w(e, "Failed to load private models")
                    emptyList()
                }
                allModels.addAll(privateModels)

                val dedupedModels = allModels.distinctBy { it.id }
                val selected = dedupedModels.find { it.id == currentState.chatState.selectedModel?.id }
                    ?: dedupedModels.firstOrNull()

                Timber.d("Loaded ${dedupedModels.size} models (${privateModels.size} private)")
                
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            availableModels = dedupedModels,
                            selectedModel = selected
                        )
                    ) 
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to load models")
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to load models"))
            }
        }
    }
    
    private fun getDefaultModelsForProvider(provider: ModelProvider, credentialId: String): List<ModelOption> {
        return when (provider) {
            ModelProvider.OPENAI -> listOf(
                ModelOption("gpt-4o", "GPT-4o", provider, credentialId),
                ModelOption("gpt-4o-mini", "GPT-4o Mini", provider, credentialId),
                ModelOption("gpt-4-turbo", "GPT-4 Turbo", provider, credentialId)
            )
            ModelProvider.ANTHROPIC -> listOf(
                ModelOption("claude-sonnet-4-20250514", "Claude Sonnet 4", provider, credentialId),
                ModelOption("claude-3-5-sonnet-20241022", "Claude 3.5 Sonnet", provider, credentialId),
                ModelOption("claude-3-5-haiku-20241022", "Claude 3.5 Haiku", provider, credentialId)
            )
            ModelProvider.GOOGLE -> listOf(
                ModelOption("gemini-2.0-flash", "Gemini 2.0 Flash", provider, credentialId),
                ModelOption("gemini-1.5-pro", "Gemini 1.5 Pro", provider, credentialId)
            )
            ModelProvider.GROQ -> listOf(
                ModelOption("llama-3.3-70b-versatile", "Llama 3.3 70B", provider, credentialId),
                ModelOption("llama-3.1-8b-instant", "Llama 3.1 8B", provider, credentialId),
                ModelOption("mixtral-8x7b-32768", "Mixtral 8x7B", provider, credentialId)
            )
            ModelProvider.MISTRAL -> listOf(
                ModelOption("mistral-large-latest", "Mistral Large", provider, credentialId),
                ModelOption("mistral-medium-latest", "Mistral Medium", provider, credentialId)
            )
            ModelProvider.DEEPSEEK -> listOf(
                ModelOption("deepseek-chat", "DeepSeek Chat", provider, credentialId),
                ModelOption("deepseek-reasoner", "DeepSeek Reasoner", provider, credentialId)
            )
            ModelProvider.XAI -> listOf(
                ModelOption("grok-2", "Grok 2", provider, credentialId),
                ModelOption("grok-2-mini", "Grok 2 Mini", provider, credentialId)
            )
            else -> listOf(
                ModelOption("default", provider.displayName, provider, credentialId)
            )
        }
    }

    private fun groupChatsByDate(chats: List<ChatSummary>): List<Pair<ChatGroup, List<ChatSummary>>> {
        val now = LocalDate.now()
        
        return chats
            .groupBy { chat ->
                val chatDate = Instant.ofEpochMilli(chat.updatedAt)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                
                val daysDiff = ChronoUnit.DAYS.between(chatDate, now)
                
                when {
                    daysDiff == 0L -> ChatGroup.TODAY
                    daysDiff == 1L -> ChatGroup.YESTERDAY
                    daysDiff <= 7L -> ChatGroup.PREVIOUS_7_DAYS
                    daysDiff <= 30L -> ChatGroup.PREVIOUS_30_DAYS
                    else -> ChatGroup.OLDER
                }
            }
            .toSortedMap(compareBy { it.ordinal })
            .map { (group, groupChats) -> 
                group to groupChats.sortedByDescending { it.updatedAt }
            }
    }
}

enum class ModelProvider(val displayName: String) {
    OPENAI("OpenAI"),
    ANTHROPIC("Anthropic"),
    GOOGLE("Google"),
    XAI("xAI"),
    GROQ("Groq"),
    MISTRAL("Mistral"),
    DEEPSEEK("DeepSeek"),
    OPENROUTER("OpenRouter"),
    TOGETHER("Together"),
    FIREWORKS("Fireworks"),
    OLLAMA("Ollama"),
    LMSTUDIO("LM Studio"),
    PRIVATE("Private (E2EE)"),
    CUSTOM("Custom")
}
