//
//  ChatViewModel.swift
//  Onera
//
//  Individual chat view model with real LLM streaming integration
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    
    // MARK: - State
    
    private(set) var chat: Chat?
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var isStreaming = false
    private(set) var error: Error?
    private(set) var isSpeaking = false
    private(set) var speakingMessageId: String?
    private(set) var isRecording = false
    
    var inputText = ""
    var attachments: [Attachment] = []
    
    var title: String {
        chat?.title ?? "New Chat"
    }
    
    var messages: [Message] {
        guard var msgs = chat?.messages else { return [] }
        
        // If streaming, inject the buffered content into the last message for display
        if isStreaming, !msgs.isEmpty, let lastIndex = msgs.indices.last {
            var lastMsg = msgs[lastIndex]
            if lastMsg.isStreaming {
                lastMsg.content = streamingContentBuffer
                if !streamingReasoningBuffer.isEmpty {
                    lastMsg.reasoning = streamingReasoningBuffer
                }
                msgs[lastIndex] = lastMsg
            }
        }
        
        return msgs
    }
    
    var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !attachments.isEmpty
        let hasModel = modelSelector.selectedModel != nil
        return (hasText || hasAttachments) && hasModel && !isSending
    }
    
    var isNewChat: Bool {
        chat == nil || !(chat?.isPersisted ?? false)
    }
    
    /// Whether there are credentials configured
    var hasCredentials: Bool {
        !credentialService.credentials.isEmpty
    }
    
    /// Whether credentials are loading
    var isLoadingCredentials: Bool {
        credentialService.isLoading
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let chatRepository: ChatRepositoryProtocol
    private let credentialService: CredentialServiceProtocol
    private let llmService: LLMServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let speechService: SpeechServiceProtocol
    private var speechRecognitionService: SpeechRecognitionServiceProtocol
    let modelSelector: ModelSelectorViewModel
    private let onChatUpdated: (ChatSummary) -> Void
    
    private var streamingTask: Task<Void, Never>?
    
    // MARK: - Streaming Buffer (to avoid exclusivity violations)
    
    /// Buffer for accumulating streamed content - accessed only from main queue callbacks
    private var streamingContentBuffer: String = ""
    private var streamingReasoningBuffer: String = ""
    private var streamingError: Error?
    private var streamingDone: Bool = false
    
    // MARK: - Response Branching
    
    /// Stores alternative responses for each user message (indexed by user message ID)
    /// Each entry contains alternative assistant responses that are not currently displayed
    private var responseBranches: [String: [Message]] = [:]
    
    /// Tracks which response version is currently displayed for each user message
    /// Key: user message ID, Value: index in the full list of responses (0 = first response)
    private var currentBranchIndex: [String: Int] = [:]
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        chatRepository: ChatRepositoryProtocol,
        credentialService: CredentialServiceProtocol,
        llmService: LLMServiceProtocol,
        networkService: NetworkServiceProtocol,
        speechService: SpeechServiceProtocol,
        speechRecognitionService: SpeechRecognitionServiceProtocol,
        onChatUpdated: @escaping (ChatSummary) -> Void
    ) {
        self.authService = authService
        self.chatRepository = chatRepository
        self.credentialService = credentialService
        self.llmService = llmService
        self.networkService = networkService
        self.speechService = speechService
        self.speechRecognitionService = speechRecognitionService
        self.modelSelector = ModelSelectorViewModel(
            credentialService: credentialService,
            llmService: llmService,
            networkService: networkService,
            authService: authService
        )
        self.onChatUpdated = onChatUpdated
        
        // Set up transcription callback
        self.speechRecognitionService.onTranscriptionUpdate = { [weak self] text in
            Task { @MainActor in
                self?.inputText = text
            }
        }
    }
    
    // MARK: - Actions
    
    func loadChat(id: String) async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            chat = try await chatRepository.fetchChat(id: id, token: token)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createNewChat() async {
        do {
            let chatKey = try chatRepository.generateChatKey()
            chat = Chat(encryptionKey: chatKey)
        } catch {
            self.error = error
        }
    }
    
    /// Load credentials and available models
    func loadModels() async {
        do {
            print("[ChatViewModel] Loading models...")
            let token = try await authService.getToken()
            print("[ChatViewModel] Got token, fetching credentials...")
            try await credentialService.fetchCredentials(token: token)
            print("[ChatViewModel] Got \(credentialService.credentials.count) credentials, fetching models...")
            await modelSelector.fetchModels()
            print("[ChatViewModel] Models loaded")
        } catch {
            print("[ChatViewModel] Error loading models: \(error)")
            self.error = error
        }
    }
    
    func sendMessage() async {
        guard canSend else { return }
        guard let selectedModel = modelSelector.selectedModel else {
            error = LLMError.invalidCredential
            return
        }
        
        // Validate we have either a credential (regular) or can get enclave (private)
        let isPrivate = modelSelector.isPrivateModelSelected
        let credential = modelSelector.getCredentialForSelectedModel()
        
        if !isPrivate && credential == nil {
            error = LLMError.invalidCredential
            return
        }
        
        let messageContent = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageAttachments = attachments
        
        // Clear input
        inputText = ""
        attachments = []
        
        // Create user message
        let userMessage = Message(
            role: .user,
            content: messageContent,
            attachments: messageAttachments
        )
        
        // Ensure we have a chat
        if chat == nil {
            await createNewChat()
        }
        
        // Add user message
        chat?.messages.append(userMessage)
        chat?.updatedAt = Date()
        
        // Generate title from first message if this is a new chat
        if chat?.title == "New Chat" {
            chat?.title = generateTitle(from: messageContent)
        }
        
        isSending = true
        error = nil
        
        do {
            // Save chat first
            try await saveChat()
            
            // Reset streaming buffers
            resetStreamingBuffers()
            
            // Add streaming assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: "",
                isStreaming: true
            )
            chat?.messages.append(assistantMessage)
            
            // Stream response from LLM
            isStreaming = true
            
            // Convert messages to LLM format with attachments (capture before streaming)
            let chatMessages = messages.dropLast().map { msg -> ChatMessage in
                let chatAttachments = msg.attachments.map { attachment in
                    ChatAttachment(from: attachment)
                }
                return ChatMessage(
                    role: msg.role == .user ? .user : .assistant,
                    content: msg.content,
                    attachments: chatAttachments.isEmpty ? nil : chatAttachments
                )
            }
            
            // Get enclave config for private models
            var enclaveConfig: EnclaveConfig? = nil
            if isPrivate, let chatId = chat?.id {
                enclaveConfig = try await modelSelector.requestEnclaveForCurrentModel(sessionId: chatId)
            }
            
            // Stream to buffers (callback only touches buffers, not chat)
            try await llmService.streamChat(
                messages: Array(chatMessages),
                credential: credential,
                model: selectedModel.id,
                systemPrompt: nil,
                maxTokens: 4096,
                enclaveConfig: enclaveConfig
            ) { [weak self] event in
                DispatchQueue.main.async {
                    self?.bufferStreamEvent(event)
                }
            }
            
            // Small delay to ensure all queued events are processed
            try? await Task.sleep(for: .milliseconds(100))
            
            // Apply buffered content to chat (safe - no concurrent access)
            applyStreamingBuffers()
            
            isStreaming = false
            
            // Save final state
            try await saveChat()
            
        } catch is CancellationError {
            // User cancelled - apply whatever we have
            applyStreamingBuffers()
            isStreaming = false
        } catch {
            self.error = error
            // Remove the empty assistant message on error
            if let lastIndex = chat?.messages.indices.last,
               chat?.messages[lastIndex].role == .assistant,
               chat?.messages[lastIndex].content.isEmpty == true {
                chat?.messages.removeLast()
            }
            isStreaming = false
        }
        
        isSending = false
    }
    
    /// Stop the current streaming response
    func stopStreaming() {
        Task {
            await llmService.cancelStream()
        }
        isStreaming = false
        
        // Mark the message as complete
        if let lastIndex = chat?.messages.indices.last {
            chat?.messages[lastIndex].isStreaming = false
        }
    }
    
    /// Regenerate the last assistant response
    func regenerate() async {
        guard !isSending, !isStreaming else { return }
        
        // Find the last assistant message
        guard let lastIndex = chat?.messages.indices.last,
              chat?.messages[lastIndex].role == .assistant else {
            return
        }
        
        await regenerateMessage(messageId: chat!.messages[lastIndex].id)
    }
    
    /// Regenerate a specific assistant message (preserves old response as alternative branch)
    func regenerateMessage(messageId: String) async {
        guard !isSending, !isStreaming else { return }
        guard var chat = chat,
              let index = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[index].role == .assistant else {
            return
        }
        
        // Find the user message before this assistant message
        let userMessageIndex = index - 1
        guard userMessageIndex >= 0, chat.messages[userMessageIndex].role == .user else {
            return
        }
        
        let userMessage = chat.messages[userMessageIndex]
        let oldResponse = chat.messages[index]
        
        // Save the old response to branches
        var existingBranches = responseBranches[userMessage.id] ?? []
        
        // If this is the first regeneration, add the original response first
        if existingBranches.isEmpty {
            existingBranches.append(oldResponse)
        }
        responseBranches[userMessage.id] = existingBranches
        
        // Remove the assistant message and everything after it from chat
        // but keep the user message
        chat.messages = Array(chat.messages.prefix(index))
        self.chat = chat
        
        // Stream the new response (streamLLMResponse creates the assistant message)
        await streamLLMResponse()
        
        // After streaming completes, store the new response in branches
        if let lastMessage = self.chat?.messages.last, lastMessage.role == .assistant {
            var branches = responseBranches[userMessage.id] ?? []
            branches.append(lastMessage)
            responseBranches[userMessage.id] = branches
            // Set current index to the newest response
            currentBranchIndex[userMessage.id] = branches.count - 1
        }
    }
    
    // MARK: - Branch Navigation
    
    /// Get branch info for a message (returns nil if no branches)
    /// Returns tuple: (currentIndex: 1-based, totalCount)
    func getBranchInfo(for messageId: String) -> (current: Int, total: Int)? {
        guard let chat = chat,
              let messageIndex = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[messageIndex].role == .assistant,
              messageIndex > 0 else {
            return nil
        }
        
        let userMessageId = chat.messages[messageIndex - 1].id
        guard let branches = responseBranches[userMessageId], branches.count > 1 else {
            return nil
        }
        
        let currentIdx = currentBranchIndex[userMessageId] ?? (branches.count - 1)
        return (current: currentIdx + 1, total: branches.count)
    }
    
    /// Switch to previous response branch
    func switchToPreviousBranch(for messageId: String) {
        guard var chat = chat,
              let messageIndex = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[messageIndex].role == .assistant,
              messageIndex > 0 else {
            return
        }
        
        let userMessageId = chat.messages[messageIndex - 1].id
        guard let branches = responseBranches[userMessageId], branches.count > 1 else {
            return
        }
        
        var currentIdx = currentBranchIndex[userMessageId] ?? (branches.count - 1)
        guard currentIdx > 0 else { return }
        
        currentIdx -= 1
        currentBranchIndex[userMessageId] = currentIdx
        
        // Replace the current response with the previous branch
        chat.messages[messageIndex] = branches[currentIdx]
        self.chat = chat
    }
    
    /// Switch to next response branch
    func switchToNextBranch(for messageId: String) {
        guard var chat = chat,
              let messageIndex = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[messageIndex].role == .assistant,
              messageIndex > 0 else {
            return
        }
        
        let userMessageId = chat.messages[messageIndex - 1].id
        guard let branches = responseBranches[userMessageId], branches.count > 1 else {
            return
        }
        
        var currentIdx = currentBranchIndex[userMessageId] ?? (branches.count - 1)
        guard currentIdx < branches.count - 1 else { return }
        
        currentIdx += 1
        currentBranchIndex[userMessageId] = currentIdx
        
        // Replace the current response with the next branch
        chat.messages[messageIndex] = branches[currentIdx]
        self.chat = chat
    }
    
    /// Edit a user message with optional regeneration
    /// - Parameters:
    ///   - messageId: The ID of the message to edit
    ///   - newContent: The new content for the message
    ///   - regenerate: Whether to regenerate the assistant response after editing (default: true)
    func editMessage(messageId: String, newContent: String, regenerate: Bool = true) async {
        guard !isSending, !isStreaming else { return }
        guard var chat = chat,
              let index = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[index].role == .user else {
            return
        }
        
        // Update the message content and mark as edited
        chat.messages[index].content = newContent
        chat.messages[index].edited = true
        chat.messages[index].editedAt = Date()
        
        if regenerate {
            // Remove all messages after the edited message (assistant response will be regenerated)
            chat.messages = Array(chat.messages.prefix(through: index))
        }
        self.chat = chat
        
        // Save the edit
        do {
            try await saveChat()
        } catch {
            self.error = error
            return
        }
        
        // Stream new response from LLM if requested
        if regenerate {
            await streamLLMResponse()
        }
    }
    
    /// Stream LLM response for current messages (used after edit/regenerate)
    private func streamLLMResponse() async {
        guard let selectedModel = modelSelector.selectedModel else {
            error = LLMError.invalidCredential
            return
        }
        
        // Validate we have either a credential (regular) or can get enclave (private)
        let isPrivate = modelSelector.isPrivateModelSelected
        let credential = modelSelector.getCredentialForSelectedModel()
        
        if !isPrivate && credential == nil {
            error = LLMError.invalidCredential
            return
        }
        
        isSending = true
        error = nil
        
        do {
            // Reset streaming buffers
            resetStreamingBuffers()
            
            // Add streaming assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: "",
                isStreaming: true
            )
            chat?.messages.append(assistantMessage)
            
            // Stream response from LLM
            isStreaming = true
            
            // Convert messages to LLM format with attachments (exclude the empty assistant message)
            let chatMessages = messages.dropLast().map { msg -> ChatMessage in
                let chatAttachments = msg.attachments.map { attachment in
                    ChatAttachment(from: attachment)
                }
                return ChatMessage(
                    role: msg.role == .user ? .user : .assistant,
                    content: msg.content,
                    attachments: chatAttachments.isEmpty ? nil : chatAttachments
                )
            }
            
            // Get enclave config for private models
            var enclaveConfig: EnclaveConfig? = nil
            if isPrivate, let chatId = chat?.id {
                enclaveConfig = try await modelSelector.requestEnclaveForCurrentModel(sessionId: chatId)
            }
            
            // Stream to buffers (callback only touches buffers, not chat)
            try await llmService.streamChat(
                messages: Array(chatMessages),
                credential: credential,
                model: selectedModel.id,
                systemPrompt: nil,
                maxTokens: 4096,
                enclaveConfig: enclaveConfig
            ) { [weak self] event in
                DispatchQueue.main.async {
                    self?.bufferStreamEvent(event)
                }
            }
            
            // Small delay to ensure all queued events are processed
            try? await Task.sleep(for: .milliseconds(100))
            
            // Apply buffered content to chat (safe - no concurrent access)
            applyStreamingBuffers()
            
            isStreaming = false
            
            // Save final state
            try await saveChat()
            
        } catch is CancellationError {
            applyStreamingBuffers()
            isStreaming = false
        } catch {
            self.error = error
            // Remove the empty assistant message on error
            if let lastIndex = chat?.messages.indices.last,
               chat?.messages[lastIndex].role == .assistant,
               chat?.messages[lastIndex].content.isEmpty == true {
                chat?.messages.removeLast()
            }
            isStreaming = false
        }
        
        isSending = false
    }
    
    func deleteCurrentChat() async {
        guard let chatId = chat?.id else { return }
        
        do {
            let token = try await authService.getToken()
            try await chatRepository.deleteChat(id: chatId, token: token)
            chat = nil
        } catch {
            self.error = error
        }
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Speech Actions
    
    /// Speak the given text using TTS
    func speak(_ text: String, messageId: String) async {
        stopSpeaking()
        
        isSpeaking = true
        speakingMessageId = messageId
        
        await speechService.speak(text)
        
        isSpeaking = false
        speakingMessageId = nil
    }
    
    /// Stop any current speech
    func stopSpeaking() {
        speechService.stop()
        isSpeaking = false
        speakingMessageId = nil
    }
    
    // MARK: - Speech Recognition Actions
    
    /// Start voice recording for speech-to-text
    func startRecording() async {
        guard !isRecording else { return }
        
        // Request authorization if needed
        if !speechRecognitionService.isAuthorized {
            let authorized = await speechRecognitionService.requestAuthorization()
            guard authorized else {
                error = SpeechRecognitionError.notAuthorized
                return
            }
        }
        
        do {
            try await speechRecognitionService.startRecording()
            isRecording = true
        } catch {
            self.error = error
        }
    }
    
    /// Stop voice recording and use transcribed text
    func stopRecording() {
        guard isRecording else { return }
        
        let transcribedText = speechRecognitionService.stopRecording()
        isRecording = false
        
        // Ensure the final transcribed text is in the input field
        // (the live callback may have already set it, but use the final result as fallback)
        if let text = transcribedText, !text.isEmpty, inputText.isEmpty {
            inputText = text
        }
    }
    
    // MARK: - Private Methods
    
    /// Reset streaming buffers before starting a new stream
    private func resetStreamingBuffers() {
        streamingContentBuffer = ""
        streamingReasoningBuffer = ""
        streamingError = nil
        streamingDone = false
    }
    
    /// Buffer stream events without touching chat property
    private func bufferStreamEvent(_ event: StreamEvent) {
        switch event {
        case .text(let text):
            streamingContentBuffer.append(text)
            
        case .reasoning(let reasoning):
            streamingReasoningBuffer.append(reasoning)
            
        case .toolCall(let name, let arguments):
            print("Tool call: \(name)(\(arguments))")
            
        case .error(let streamError):
            streamingError = streamError
            
        case .done:
            streamingDone = true
        }
    }
    
    /// Apply buffered content to chat - called after streaming completes
    private func applyStreamingBuffers() {
        guard let lastIndex = chat?.messages.indices.last else { return }
        
        // Apply content
        if !streamingContentBuffer.isEmpty {
            chat?.messages[lastIndex].content = streamingContentBuffer
        }
        
        // Apply reasoning
        if !streamingReasoningBuffer.isEmpty {
            chat?.messages[lastIndex].reasoning = streamingReasoningBuffer
        }
        
        // Apply error
        if let err = streamingError {
            error = err
        }
        
        // Mark as complete
        chat?.messages[lastIndex].isStreaming = false
    }
    
    private func saveChat() async throws {
        guard var currentChat = chat else { 
            print("[ChatViewModel] saveChat: No chat to save")
            return 
        }
        
        let token = try await authService.getToken()
        
        // Create or update based on whether chat is persisted to server
        if !currentChat.isPersisted {
            print("[ChatViewModel] Creating new chat (not yet persisted)...")
            let newId = try await chatRepository.createChat(currentChat, token: token)
            print("[ChatViewModel] Chat created with ID: \(newId)")
            currentChat.id = newId
            chat = currentChat
        } else {
            print("[ChatViewModel] Updating existing chat: \(currentChat.id)")
            try await chatRepository.updateChat(currentChat, token: token)
            print("[ChatViewModel] Chat updated")
        }
        
        // Notify list of update
        let summary = ChatSummary(
            id: currentChat.id,
            title: currentChat.title,
            createdAt: currentChat.createdAt,
            updatedAt: currentChat.updatedAt
        )
        onChatUpdated(summary)
    }
    
    private func generateTitle(from content: String) -> String {
        let maxLength = 50
        
        if content.count <= maxLength {
            return content
        }
        
        return content.truncatedAtWord(to: maxLength)
    }
}
