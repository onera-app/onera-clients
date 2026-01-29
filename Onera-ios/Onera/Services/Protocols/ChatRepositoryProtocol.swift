//
//  ChatRepositoryProtocol.swift
//  Onera
//
//  Protocol for chat data operations
//

import Foundation

// MARK: - Chat Repository Protocol

protocol ChatRepositoryProtocol: Sendable {
    
    // MARK: - Chat List
    
    /// Fetches all chat summaries
    func fetchChats(token: String) async throws -> [ChatSummary]
    
    // MARK: - Single Chat
    
    /// Fetches a complete chat by ID
    func fetchChat(id: String, token: String) async throws -> Chat
    
    /// Creates a new chat
    func createChat(_ chat: Chat, token: String) async throws -> String
    
    /// Updates an existing chat
    func updateChat(_ chat: Chat, token: String) async throws
    
    /// Updates a chat's folder assignment
    func updateChatFolder(chatId: String, folderId: String?, token: String) async throws
    
    /// Deletes a chat
    func deleteChat(id: String, token: String) async throws
    
    // MARK: - Chat Encryption
    
    /// Generates a new chat encryption key
    func generateChatKey() throws -> Data
}
