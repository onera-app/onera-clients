//
//  ChatViewModel.swift
//  Onera
//
//  Chat state management and business logic
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State
    
    private(set) var chats: [ChatSummary] = []
    private(set) var currentChat: Chat?
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var isStreaming = false
    private(set) var error: Error?
    
    var inputText = ""
    var attachments: [Attachment] = []
    
    // Grouped chats for sidebar
    var groupedChats: [(ChatGroup, [ChatSummary])] {
        let grouped = Dictionary(grouping: chats) { $0.group }
        let order: [ChatGroup] = [.today, .yesterday, .previousSevenDays, .previousThirtyDays]
        
        var result: [(ChatGroup, [ChatSummary])] = []
        
        for group in order {
            if let items = grouped[group], !items.isEmpty {
                result.append((group, items.sorted { $0.updatedAt > $1.updatedAt }))
            }
        }
        
        // Add older months
        let olderGroups = grouped.keys.compactMap { group -> (ChatGroup, [ChatSummary])? in
            if case .older = group, let items = grouped[group] {
                return (group, items.sorted { $0.updatedAt > $1.updatedAt })
            }
            return nil
        }.sorted { lhs, rhs in
            guard case .older(let month1) = lhs.0, case .older(let month2) = rhs.0 else {
                return false
            }
            return month1 > month2
        }
        
        result.append(contentsOf: olderGroups)
        
        return result
    }
    
    // MARK: - Dependencies
    
    private let api = APIClient.shared
    private let session = SecureSession.shared
    private let chatEncryption = ChatEncryption()
    
    // MARK: - Chat List Operations
    
    /// Loads all chats from server
    func loadChats() async {
        guard session.isUnlocked, let masterKey = session.masterKey else {
            error = CryptoError.decryptionFailed
            return
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let token = try await AuthenticationManager.shared.getToken()
            let response = try await api.getChats(token: token)
            
            // Decrypt all chat summaries
            chats = try response.chats.compactMap { encrypted in
                try chatEncryption.decryptChatSummary(encrypted, masterKey: masterKey)
            }
        } catch {
            self.error = error
        }
    }
    
    /// Loads a specific chat
    func loadChat(id: String) async {
        guard session.isUnlocked, let masterKey = session.masterKey else {
            error = CryptoError.decryptionFailed
            return
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let token = try await AuthenticationManager.shared.getToken()
            let response = try await api.getChat(id: id, token: token)
            
            let encrypted = EncryptedChat(
                id: response.id,
                encryptedChatKey: response.encryptedChatKey,
                chatKeyNonce: response.chatKeyNonce,
                encryptedTitle: response.encryptedTitle,
                titleNonce: response.titleNonce,
                encryptedChat: response.encryptedChat,
                chatNonce: response.chatNonce,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt
            )
            
            currentChat = try chatEncryption.decryptChat(encrypted, masterKey: masterKey)
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Chat Operations
    
    /// Creates a new chat
    func createNewChat() async {
        guard session.isUnlocked, let masterKey = session.masterKey else {
            error = CryptoError.decryptionFailed
            return
        }
        
        do {
            let chatKey = try chatEncryption.generateChatKey()
            currentChat = Chat(chatKey: chatKey)
            
            // Don't save to server until first message
        } catch {
            self.error = error
        }
    }
    
    /// Sends a message and gets AI response
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard session.isUnlocked, let masterKey = session.masterKey else {
            error = CryptoError.decryptionFailed
            return
        }
        
        let messageContent = inputText
        inputText = ""
        
        // Create user message
        let userMessage = Message(
            role: .user,
            content: messageContent,
            attachments: attachments
        )
        attachments = []
        
        // Add to current chat
        if currentChat == nil {
            await createNewChat()
        }
        
        currentChat?.messages.append(userMessage)
        currentChat?.updatedAt = Date()
        
        isSending = true
        error = nil
        
        do {
            // Save chat state
            try await saveCurrentChat(masterKey: masterKey)
            
            // Create placeholder for assistant response
            let assistantMessage = Message(role: .assistant, content: "")
            currentChat?.messages.append(assistantMessage)
            
            // TODO: Implement streaming AI response
            // For now, simulate a response
            isStreaming = true
            
            // Simulate streaming
            let response = "This is a simulated AI response. In production, this would stream from your AI backend."
            
            for char in response {
                try await Task.sleep(nanoseconds: 20_000_000) // 20ms per character
                if let lastIndex = currentChat?.messages.indices.last {
                    currentChat?.messages[lastIndex].content.append(char)
                }
            }
            
            isStreaming = false
            
            // Save final state
            try await saveCurrentChat(masterKey: masterKey)
            
        } catch {
            self.error = error
        }
        
        isSending = false
    }
    
    /// Saves current chat to server
    private func saveCurrentChat(masterKey: Data) async throws {
        guard var chat = currentChat else { return }
        
        let token = try await AuthenticationManager.shared.getToken()
        
        // Generate title from first message if needed
        if chat.title == "New Chat" && !chat.messages.isEmpty {
            chat.title = generateTitle(from: chat.messages)
            currentChat?.title = chat.title
        }
        
        let encrypted = try chatEncryption.encryptChat(chat, masterKey: masterKey)
        
        // Check if this is a new chat or update
        if chats.contains(where: { $0.id == chat.id }) {
            // Update existing
            let request = ChatUpdateRequest(
                id: chat.id,
                encryptedTitle: encrypted.encryptedTitle,
                titleNonce: encrypted.titleNonce,
                encryptedChat: encrypted.encryptedChat,
                chatNonce: encrypted.chatNonce
            )
            _ = try await api.updateChat(request: request, token: token)
        } else {
            // Create new
            let request = ChatCreateRequest(
                encryptedChatKey: encrypted.encryptedChatKey,
                chatKeyNonce: encrypted.chatKeyNonce,
                encryptedTitle: encrypted.encryptedTitle,
                titleNonce: encrypted.titleNonce,
                encryptedChat: encrypted.encryptedChat,
                chatNonce: encrypted.chatNonce
            )
            let response = try await api.createChat(request: request, token: token)
            currentChat?.id = response.id
            
            // Add to chats list
            let summary = ChatSummary(
                id: response.id,
                title: chat.title,
                createdAt: chat.createdAt,
                updatedAt: Date()
            )
            chats.insert(summary, at: 0)
        }
    }
    
    /// Deletes a chat
    func deleteChat(id: String) async {
        do {
            let token = try await AuthenticationManager.shared.getToken()
            _ = try await api.deleteChat(id: id, token: token)
            
            chats.removeAll { $0.id == id }
            
            if currentChat?.id == id {
                currentChat = nil
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Helpers
    
    private func generateTitle(from messages: [Message]) -> String {
        guard let firstUserMessage = messages.first(where: { $0.role == .user }) else {
            return "New Chat"
        }
        
        let content = firstUserMessage.content
        let maxLength = 50
        
        if content.count <= maxLength {
            return content
        }
        
        // Truncate at word boundary
        let truncated = String(content.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        
        return truncated + "..."
    }
}

// MARK: - Chat Extension for ID mutation

extension Chat {
    var id: String {
        get { _id }
        set { _id = newValue }
    }
    
    private var _id: String {
        get { Mirror(reflecting: self).children.first { $0.label == "id" }?.value as? String ?? "" }
        set {
            // This is a workaround - in production, use a class or properly mutable struct
        }
    }
}
