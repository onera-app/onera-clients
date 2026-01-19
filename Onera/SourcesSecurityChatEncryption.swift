//
//  ChatEncryption.swift
//  Onera
//
//  Chat-specific encryption operations
//

import Foundation

/// Handles encryption/decryption of chat data
struct ChatEncryption {
    private let crypto = CryptoManager.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Chat Key Management
    
    /// Generates a new chat encryption key
    func generateChatKey() throws -> Data {
        try crypto.generateRandomBytes(count: Configuration.masterKeyLength)
    }
    
    /// Encrypts a chat key with the master key
    func encryptChatKey(_ chatKey: Data, with masterKey: Data) throws -> (encrypted: Data, nonce: Data) {
        try crypto.encrypt(plaintext: chatKey, key: masterKey)
    }
    
    /// Decrypts a chat key using the master key
    func decryptChatKey(encrypted: Data, nonce: Data, with masterKey: Data) throws -> Data {
        try crypto.decrypt(ciphertext: encrypted, nonce: nonce, key: masterKey)
    }
    
    // MARK: - Chat Content Encryption
    
    /// Encrypts chat title
    func encryptTitle(_ title: String, with chatKey: Data) throws -> (encrypted: Data, nonce: Data) {
        guard let titleData = title.data(using: .utf8) else {
            throw CryptoError.encryptionFailed
        }
        return try crypto.encrypt(plaintext: titleData, key: chatKey)
    }
    
    /// Decrypts chat title
    func decryptTitle(encrypted: Data, nonce: Data, with chatKey: Data) throws -> String {
        let titleData = try crypto.decrypt(ciphertext: encrypted, nonce: nonce, key: chatKey)
        guard let title = String(data: titleData, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        return title
    }
    
    /// Encrypts chat messages
    func encryptMessages(_ messages: [Message], with chatKey: Data) throws -> (encrypted: Data, nonce: Data) {
        let chatData = ChatData(messages: messages)
        let jsonData = try encoder.encode(chatData)
        return try crypto.encrypt(plaintext: jsonData, key: chatKey)
    }
    
    /// Decrypts chat messages
    func decryptMessages(encrypted: Data, nonce: Data, with chatKey: Data) throws -> [Message] {
        let jsonData = try crypto.decrypt(ciphertext: encrypted, nonce: nonce, key: chatKey)
        let chatData = try decoder.decode(ChatData.self, from: jsonData)
        return chatData.messages
    }
    
    // MARK: - Full Chat Encryption
    
    /// Encrypts a complete chat for server storage
    func encryptChat(_ chat: Chat, masterKey: Data) throws -> EncryptedChat {
        // Generate or use existing chat key
        let chatKey = try chat.chatKey ?? generateChatKey()
        
        // Encrypt chat key
        let (encryptedChatKey, chatKeyNonce) = try encryptChatKey(chatKey, with: masterKey)
        
        // Encrypt title
        let (encryptedTitle, titleNonce) = try encryptTitle(chat.title, with: chatKey)
        
        // Encrypt messages
        let (encryptedMessages, messagesNonce) = try encryptMessages(chat.messages, with: chatKey)
        
        return EncryptedChat(
            id: chat.id,
            encryptedChatKey: encryptedChatKey.base64EncodedString(),
            chatKeyNonce: chatKeyNonce.base64EncodedString(),
            encryptedTitle: encryptedTitle.base64EncodedString(),
            titleNonce: titleNonce.base64EncodedString(),
            encryptedChat: encryptedMessages.base64EncodedString(),
            chatNonce: messagesNonce.base64EncodedString(),
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt
        )
    }
    
    /// Decrypts a complete chat from server
    func decryptChat(_ encrypted: EncryptedChat, masterKey: Data) throws -> Chat {
        // Decrypt chat key
        guard let encryptedChatKey = Data(base64Encoded: encrypted.encryptedChatKey),
              let chatKeyNonce = Data(base64Encoded: encrypted.chatKeyNonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let chatKey = try decryptChatKey(
            encrypted: encryptedChatKey,
            nonce: chatKeyNonce,
            with: masterKey
        )
        
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: encrypted.encryptedTitle),
              let titleNonce = Data(base64Encoded: encrypted.titleNonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let title = try decryptTitle(
            encrypted: encryptedTitle,
            nonce: titleNonce,
            with: chatKey
        )
        
        // Decrypt messages
        guard let encryptedMessages = Data(base64Encoded: encrypted.encryptedChat),
              let messagesNonce = Data(base64Encoded: encrypted.chatNonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let messages = try decryptMessages(
            encrypted: encryptedMessages,
            nonce: messagesNonce,
            with: chatKey
        )
        
        return Chat(
            id: encrypted.id,
            title: title,
            messages: messages,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt,
            chatKey: chatKey
        )
    }
    
    /// Decrypts just the title (for chat list display)
    func decryptChatSummary(_ summary: EncryptedChatSummary, masterKey: Data) throws -> ChatSummary {
        // Decrypt chat key
        guard let encryptedChatKey = Data(base64Encoded: summary.encryptedChatKey),
              let chatKeyNonce = Data(base64Encoded: summary.chatKeyNonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let chatKey = try decryptChatKey(
            encrypted: encryptedChatKey,
            nonce: chatKeyNonce,
            with: masterKey
        )
        
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: summary.encryptedTitle),
              let titleNonce = Data(base64Encoded: summary.titleNonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let title = try decryptTitle(
            encrypted: encryptedTitle,
            nonce: titleNonce,
            with: chatKey
        )
        
        return ChatSummary(
            id: summary.id,
            title: title,
            createdAt: summary.createdAt,
            updatedAt: summary.updatedAt
        )
    }
}

// MARK: - Encrypted Chat Model

struct EncryptedChat {
    let id: String
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Chat Summary (Decrypted)

struct ChatSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    
    var group: ChatGroup {
        ChatGroup.group(for: updatedAt)
    }
}
