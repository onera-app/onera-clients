//
//  ChatRepository.swift
//  Onera
//
//  Chat data repository implementation
//

import Foundation

final class ChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.secureSession = secureSession
    }
    
    // MARK: - Chat List
    
    func fetchChats(token: String) async throws -> [ChatSummary] {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let response: ChatsListResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.list,
            token: token
        )
        
        return try response.chats.compactMap { encrypted in
            try decryptChatSummary(encrypted, masterKey: masterKey)
        }
    }
    
    // MARK: - Single Chat
    
    func fetchChat(id: String, token: String) async throws -> Chat {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let response: ChatGetResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.get,
            input: ChatGetRequest(id: id),
            token: token
        )
        
        return try decryptChat(response, masterKey: masterKey)
    }
    
    func createChat(_ chat: Chat, token: String) async throws -> String {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let encrypted = try encryptChat(chat, masterKey: masterKey)
        
        let response: ChatCreateResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.create,
            input: encrypted,
            token: token
        )
        
        return response.id
    }
    
    func updateChat(_ chat: Chat, token: String) async throws {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let encrypted = try encryptChat(chat, masterKey: masterKey)
        
        let _: ChatUpdateResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.update,
            input: ChatUpdateRequest(
                id: chat.id,
                encryptedTitle: encrypted.encryptedTitle,
                titleNonce: encrypted.titleNonce,
                encryptedChat: encrypted.encryptedChat,
                chatNonce: encrypted.chatNonce
            ),
            token: token
        )
    }
    
    func deleteChat(id: String, token: String) async throws {
        let _: ChatDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.delete,
            input: ChatDeleteRequest(id: id),
            token: token
        )
    }
    
    // MARK: - Chat Encryption
    
    func generateChatKey() throws -> Data {
        try cryptoService.generateRandomBytes(count: Configuration.Security.masterKeyLength)
    }
    
    // MARK: - Private Encryption Methods
    
    private func encryptChat(_ chat: Chat, masterKey: Data) throws -> ChatCreateRequest {
        // Generate or use existing chat key
        let chatKey = try chat.encryptionKey ?? generateChatKey()
        
        // Encrypt chat key
        let (encryptedChatKey, chatKeyNonce) = try cryptoService.encrypt(
            plaintext: chatKey,
            key: masterKey
        )
        
        // Encrypt title
        guard let titleData = chat.title.data(using: .utf8) else {
            throw ChatError.encryptionFailed
        }
        let (encryptedTitle, titleNonce) = try cryptoService.encrypt(
            plaintext: titleData,
            key: chatKey
        )
        
        // Encrypt messages
        let chatData = ChatData(messages: chat.messages)
        let messagesJson = try encoder.encode(chatData)
        let (encryptedChat, chatNonce) = try cryptoService.encrypt(
            plaintext: messagesJson,
            key: chatKey
        )
        
        return ChatCreateRequest(
            encryptedChatKey: encryptedChatKey.base64EncodedString(),
            chatKeyNonce: chatKeyNonce.base64EncodedString(),
            encryptedTitle: encryptedTitle.base64EncodedString(),
            titleNonce: titleNonce.base64EncodedString(),
            encryptedChat: encryptedChat.base64EncodedString(),
            chatNonce: chatNonce.base64EncodedString()
        )
    }
    
    private func decryptChat(_ response: ChatGetResponse, masterKey: Data) throws -> Chat {
        // Decrypt chat key
        guard let encryptedChatKey = Data(base64Encoded: response.encryptedChatKey),
              let chatKeyNonce = Data(base64Encoded: response.chatKeyNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let chatKey = try cryptoService.decrypt(
            ciphertext: encryptedChatKey,
            nonce: chatKeyNonce,
            key: masterKey
        )
        
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: response.encryptedTitle),
              let titleNonce = Data(base64Encoded: response.titleNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let titleData = try cryptoService.decrypt(
            ciphertext: encryptedTitle,
            nonce: titleNonce,
            key: chatKey
        )
        
        guard let title = String(data: titleData, encoding: .utf8) else {
            throw ChatError.decryptionFailed
        }
        
        // Decrypt messages
        guard let encryptedChat = Data(base64Encoded: response.encryptedChat),
              let chatNonce = Data(base64Encoded: response.chatNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let messagesJson = try cryptoService.decrypt(
            ciphertext: encryptedChat,
            nonce: chatNonce,
            key: chatKey
        )
        
        let chatData = try decoder.decode(ChatData.self, from: messagesJson)
        
        return Chat(
            id: response.id,
            title: title,
            messages: chatData.messages,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt,
            encryptionKey: chatKey
        )
    }
    
    private func decryptChatSummary(_ encrypted: EncryptedChatSummary, masterKey: Data) throws -> ChatSummary {
        // Decrypt chat key
        guard let encryptedChatKey = Data(base64Encoded: encrypted.encryptedChatKey),
              let chatKeyNonce = Data(base64Encoded: encrypted.chatKeyNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let chatKey = try cryptoService.decrypt(
            ciphertext: encryptedChatKey,
            nonce: chatKeyNonce,
            key: masterKey
        )
        
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: encrypted.encryptedTitle),
              let titleNonce = Data(base64Encoded: encrypted.titleNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let titleData = try cryptoService.decrypt(
            ciphertext: encryptedTitle,
            nonce: titleNonce,
            key: chatKey
        )
        
        guard let title = String(data: titleData, encoding: .utf8) else {
            throw ChatError.decryptionFailed
        }
        
        return ChatSummary(
            id: encrypted.id,
            title: title,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt
        )
    }
}

// MARK: - API Request/Response Models

struct ChatsListResponse: Decodable, Sendable {
    let chats: [EncryptedChatSummary]
}

struct EncryptedChatSummary: Decodable, Sendable {
    let id: String
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let createdAt: Date
    let updatedAt: Date
}

struct ChatGetRequest: Encodable, Sendable {
    let id: String
}

struct ChatGetResponse: Decodable, Sendable {
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

struct ChatCreateRequest: Encodable, Sendable {
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
}

struct ChatCreateResponse: Decodable, Sendable {
    let id: String
}

struct ChatUpdateRequest: Encodable, Sendable {
    let id: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
}

struct ChatUpdateResponse: Decodable, Sendable {
    let success: Bool
}

struct ChatDeleteRequest: Encodable, Sendable {
    let id: String
}

struct ChatDeleteResponse: Decodable, Sendable {
    let success: Bool
}

// MARK: - Mock Implementation

#if DEBUG
final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var mockChats: [ChatSummary] = []
    var mockChat: Chat?
    
    func fetchChats(token: String) async throws -> [ChatSummary] {
        if shouldFail { throw ChatError.decryptionFailed }
        return mockChats
    }
    
    func fetchChat(id: String, token: String) async throws -> Chat {
        if shouldFail { throw ChatError.chatNotFound }
        return mockChat ?? .mock()
    }
    
    func createChat(_ chat: Chat, token: String) async throws -> String {
        if shouldFail { throw ChatError.createFailed }
        return UUID().uuidString
    }
    
    func updateChat(_ chat: Chat, token: String) async throws {
        if shouldFail { throw ChatError.updateFailed }
    }
    
    func deleteChat(id: String, token: String) async throws {
        if shouldFail { throw ChatError.deleteFailed }
    }
    
    func generateChatKey() throws -> Data {
        Data(repeating: 0xAB, count: 32)
    }
}
#endif
