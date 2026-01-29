package chat.onera.mobile.presentation.features.main

import android.content.Context
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.demo.DemoData
import chat.onera.mobile.demo.DemoModeManager
import chat.onera.mobile.demo.DemoRepositoryContainer
import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.data.speech.SpeechRecognitionManager
import chat.onera.mobile.data.speech.TextToSpeechManager
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.FoldersRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import chat.onera.mobile.presentation.features.main.model.ModelOption
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val authRepository: AuthRepository,
    private val chatRepository: ChatRepository,
    private val credentialRepository: CredentialRepository,
    private val foldersRepository: FoldersRepository,
    private val llmRepository: LLMRepository,
    private val speechRecognitionManager: SpeechRecognitionManager,
    private val textToSpeechManager: TextToSpeechManager
) : BaseViewModel<MainState, MainIntent, MainEffect>(MainState()) {

    private var streamingJob: Job? = null
    
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
        observeSpeechRecognition()
        observeTextToSpeech()
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
                // Sign out from Clerk
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

    private fun observeTextToSpeech() {
        viewModelScope.launch {
            textToSpeechManager.isSpeaking.collect { isSpeaking ->
                updateState { copy(chatState = chatState.copy(isSpeaking = isSpeaking)) }
            }
        }
        viewModelScope.launch {
            textToSpeechManager.speakingMessageId.collect { messageId ->
                updateState { copy(chatState = chatState.copy(speakingMessageId = messageId)) }
            }
        }
        viewModelScope.launch {
            textToSpeechManager.speakingStartTime.collect { startTime ->
                updateState { copy(chatState = chatState.copy(speakingStartTime = startTime)) }
            }
        }
    }

    private fun speakMessage(text: String, messageId: String) {
        textToSpeechManager.speak(text, messageId)
    }

    private fun stopSpeaking() {
        textToSpeechManager.stop()
    }

    private fun observeSpeechRecognition() {
        viewModelScope.launch {
            speechRecognitionManager.isListening.collect { isRecording ->
                updateState { copy(chatState = chatState.copy(isRecording = isRecording)) }
            }
        }
        viewModelScope.launch {
            speechRecognitionManager.transcribedText.collect { text ->
                updateState { copy(chatState = chatState.copy(transcribedText = text)) }
            }
        }
        // Observe speech recognition errors and show them to the user
        viewModelScope.launch {
            speechRecognitionManager.error.collect { error ->
                if (error != null) {
                    Timber.e("Speech recognition error: $error")
                    sendEffect(MainEffect.ShowError(error))
                }
            }
        }
    }

    private fun startRecording() {
        // Clear any previous error before starting
        speechRecognitionManager.clearError()
        
        speechRecognitionManager.startListening { result ->
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
        val result = speechRecognitionManager.stopListening()
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
    private suspend fun convertAttachmentToImageData(attachment: chat.onera.mobile.domain.model.Attachment): ImageData? {
        return withContext(Dispatchers.IO) {
            try {
                if (attachment.uri == Uri.EMPTY) return@withContext null
                
                context.contentResolver.openInputStream(attachment.uri)?.use { inputStream ->
                    val bytes = inputStream.readBytes()
                    val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                    ImageData(
                        base64Data = base64,
                        mimeType = attachment.mimeType
                    )
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to convert attachment: ${attachment.fileName}")
                null
            }
        }
    }

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
        updateState { copy(chatState = chatState.copy(isSending = true)) }

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
            } catch (e: Exception) {
                updateState { copy(chatState = chatState.copy(isStreaming = false)) }
                sendEffect(MainEffect.ShowError(e.message ?: "Failed to send message"))
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
                
                // Get credentials from server-synced repository
                val serverCredentials = credentialRepository.getCredentials()
                
                if (serverCredentials.isEmpty()) {
                    // No credentials, show message to add API keys
                    Timber.d("No credentials found for models")
                    updateState { 
                        copy(chatState = chatState.copy(availableModels = emptyList())) 
                    }
                    return@launch
                }
                
                Timber.d("Loading models for ${serverCredentials.size} credentials")
                
                // For each credential, use default models for this provider
                val allModels = mutableListOf<ModelOption>()
                
                for (credential in serverCredentials) {
                    val provider = try {
                        ModelProvider.valueOf(credential.provider.name)
                    } catch (e: Exception) {
                        ModelProvider.OPENAI
                    }
                    
                    // Use default models for each provider
                    allModels.addAll(getDefaultModelsForProvider(provider, credential.id))
                }
                
                Timber.d("Loaded ${allModels.size} models")
                
                updateState { 
                    copy(
                        chatState = chatState.copy(
                            availableModels = allModels,
                            selectedModel = allModels.firstOrNull()
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
    CUSTOM("Custom")
}
