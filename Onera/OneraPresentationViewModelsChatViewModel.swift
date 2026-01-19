//
//  ChatViewModel.swift
//  Onera
//
//  Individual chat view model
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
    
    var inputText = ""
    var attachments: [Attachment] = []
    
    var title: String {
        chat?.title ?? "New Chat"
    }
    
    var messages: [Message] {
        chat?.messages ?? []
    }
    
    var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !attachments.isEmpty
        return (hasText || hasAttachments) && !isSending
    }
    
    var isNewChat: Bool {
        chat == nil || chat?.messages.isEmpty == true
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let chatRepository: ChatRepositoryProtocol
    private let onChatUpdated: (ChatSummary) -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        chatRepository: ChatRepositoryProtocol,
        onChatUpdated: @escaping (ChatSummary) -> Void
    ) {
        self.authService = authService
        self.chatRepository = chatRepository
        self.onChatUpdated = onChatUpdated
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
    
    func sendMessage() async {
        guard canSend else { return }
        
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
        
        // Generate title from first message
        if chat?.title == "New Chat" {
            chat?.title = generateTitle(from: messageContent)
        }
        
        isSending = true
        error = nil
        
        do {
            // Save chat
            try await saveChat()
            
            // Add streaming assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: "",
                isStreaming: true
            )
            chat?.messages.append(assistantMessage)
            
            // Simulate streaming response
            // TODO: Replace with actual AI backend integration
            isStreaming = true
            await simulateStreamingResponse()
            isStreaming = false
            
            // Mark message as complete
            if let lastIndex = chat?.messages.indices.last {
                chat?.messages[lastIndex].isStreaming = false
            }
            
            // Save final state
            try await saveChat()
            
        } catch {
            self.error = error
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
    
    // MARK: - Private Methods
    
    private func saveChat() async throws {
        guard var currentChat = chat else { return }
        
        let token = try await authService.getToken()
        
        // Create or update
        if currentChat.id.isEmpty || isNewChat {
            let newId = try await chatRepository.createChat(currentChat, token: token)
            currentChat = Chat(
                id: newId,
                title: currentChat.title,
                messages: currentChat.messages,
                createdAt: currentChat.createdAt,
                updatedAt: currentChat.updatedAt,
                encryptionKey: currentChat.encryptionKey
            )
            chat = currentChat
        } else {
            try await chatRepository.updateChat(currentChat, token: token)
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
    
    private func simulateStreamingResponse() async {
        // Placeholder streaming simulation
        let response = "This is a simulated AI response. In production, this would stream from your AI backend with proper E2EE handling."
        
        for char in response {
            try? await Task.sleep(milliseconds: 20)
            
            if let lastIndex = chat?.messages.indices.last {
                chat?.messages[lastIndex].content.append(char)
            }
        }
    }
}
