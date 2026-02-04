//
//  ChatRepository.swift
//  Onera
//
//  Chat data repository implementation with E2EE per-chat key encryption
//

import Foundation

final class ChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Chat Key Cache (matching web's LRU cache)
    
    private let chatKeyCache = ChatKeyCache(maxSize: 100, ttlSeconds: 600)
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.secureSession = secureSession
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            // Try to decode as milliseconds timestamp first (matching web's Int64 timestamps)
            if let milliseconds = try? container.decode(Int64.self) {
                return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
            }
            // Fall back to ISO8601
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
    }
    
    // MARK: - Chat List
    
    func fetchChats(token: String) async throws -> [ChatSummary] {
        guard let masterKey = secureSession.masterKey else {
            print("[ChatRepository] Session locked - no master key available")
            throw E2EEError.sessionLocked
        }
        
        print("[ChatRepository] Fetching encrypted chats from server...")
        let response: [EncryptedChatSummary] = try await networkService.call(
            procedure: APIEndpoint.Chats.list,
            token: token
        )
        print("[ChatRepository] Received \(response.count) encrypted chats")
        
        let decrypted = response.compactMap { encrypted -> ChatSummary? in
            do {
                let summary = try decryptChatSummary(encrypted, masterKey: masterKey)
                print("[ChatRepository] Decrypted chat: \(summary.title)")
                return summary
            } catch {
                print("[ChatRepository] Failed to decrypt chat \(encrypted.id): \(error)")
                return nil
            }
        }
        
        print("[ChatRepository] Successfully decrypted \(decrypted.count) chats")
        return decrypted
    }
    
    // MARK: - Single Chat
    
    func fetchChat(id: String, token: String) async throws -> Chat {
        guard let masterKey = secureSession.masterKey else {
            print("[ChatRepository] fetchChat: Session locked - no master key")
            throw E2EEError.sessionLocked
        }
        
        print("[ChatRepository] fetchChat: Fetching chat \(id)...")
        let response: ChatGetResponse = try await networkService.query(
            procedure: APIEndpoint.Chats.get,
            input: ChatGetRequest(chatId: id),
            token: token
        )
        print("[ChatRepository] fetchChat: Got response, decrypting...")
        
        do {
            let chat = try decryptChat(response, masterKey: masterKey)
            print("[ChatRepository] fetchChat: Decrypted chat with \(chat.messages.count) messages")
            return chat
        } catch {
            print("[ChatRepository] fetchChat: Failed to decrypt: \(error)")
            throw error
        }
    }
    
    func createChat(_ chat: Chat, token: String) async throws -> String {
        guard let masterKey = secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let encrypted = try encryptChat(chat, masterKey: masterKey)
        
        let response: ChatCreateResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.create,
            input: encrypted,
            token: token
        )
        
        // Cache the chat key
        if let chatKey = chat.encryptionKey {
            chatKeyCache.set(response.id, key: chatKey)
        }
        
        return response.id
    }
    
    func updateChat(_ chat: Chat, token: String) async throws {
        guard secureSession.masterKey != nil else {
            throw E2EEError.sessionLocked
        }
        
        // Get chat key from cache or chat object
        let chatKey: Data
        if let cachedKey = chatKeyCache.get(chat.id) {
            chatKey = cachedKey
        } else if let key = chat.encryptionKey {
            chatKey = key
        } else {
            throw ChatError.missingEncryptionKey
        }
        
        // Encrypt title and messages with chat key
        guard let titleData = chat.title.data(using: .utf8) else {
            throw ChatError.encryptionFailed
        }
        let (encryptedTitle, titleNonce) = try cryptoService.encrypt(
            plaintext: titleData,
            key: chatKey
        )
        
        let chatData = ChatData(messages: chat.messages)
        let messagesJson = try encoder.encode(chatData)
        let (encryptedChat, chatNonce) = try cryptoService.encrypt(
            plaintext: messagesJson,
            key: chatKey
        )
        
        let _: ChatUpdateResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.update,
            input: ChatUpdateRequest(
                chatId: chat.id,
                encryptedTitle: encryptedTitle.base64EncodedString(),
                titleNonce: titleNonce.base64EncodedString(),
                encryptedChat: encryptedChat.base64EncodedString(),
                chatNonce: chatNonce.base64EncodedString(),
                folderId: nil  // Don't update folder during content updates
            ),
            token: token
        )
    }
    
    func updateChatFolder(chatId: String, folderId: String?, token: String) async throws {
        let _: ChatUpdateResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.update,
            input: ChatUpdateRequest(
                chatId: chatId,
                encryptedTitle: nil,
                titleNonce: nil,
                encryptedChat: nil,
                chatNonce: nil,
                folderId: folderId
            ),
            token: token
        )
    }
    
    func deleteChat(id: String, token: String) async throws {
        let _: ChatDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.Chats.delete,
            input: ChatDeleteRequest(chatId: id),
            token: token
        )
        
        // Remove from cache
        chatKeyCache.remove(id)
    }
    
    // MARK: - Chat Encryption
    
    func generateChatKey() throws -> Data {
        try cryptoService.generateRandomBytes(count: Configuration.Security.masterKeyLength)
    }
    
    /// Clears the chat key cache (call on lock)
    func clearKeyCache() {
        chatKeyCache.clear()
    }
    
    // MARK: - Private Encryption Methods
    
    private func encryptChat(_ chat: Chat, masterKey: Data) throws -> ChatCreateRequest {
        // Generate or use existing chat key
        let chatKey = try chat.encryptionKey ?? generateChatKey()
        
        // Encrypt chat key with master key
        let (encryptedChatKey, chatKeyNonce) = try cryptoService.encrypt(
            plaintext: chatKey,
            key: masterKey
        )
        
        // Encrypt title with chat key
        guard let titleData = chat.title.data(using: .utf8) else {
            throw ChatError.encryptionFailed
        }
        let (encryptedTitle, titleNonce) = try cryptoService.encrypt(
            plaintext: titleData,
            key: chatKey
        )
        
        // Encrypt messages with chat key
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
            chatNonce: chatNonce.base64EncodedString(),
            folderId: chat.folderId
        )
    }
    
    private func getChatKey(
        chatId: String,
        encryptedChatKey: String,
        chatKeyNonce: String,
        masterKey: Data
    ) throws -> Data {
        // Check cache first
        if let cached = chatKeyCache.get(chatId) {
            return cached
        }
        
        // Decrypt chat key
        guard let encryptedData = Data(base64Encoded: encryptedChatKey),
              let nonceData = Data(base64Encoded: chatKeyNonce) else {
            throw ChatError.decryptionFailed
        }
        
        let chatKey = try cryptoService.decrypt(
            ciphertext: encryptedData,
            nonce: nonceData,
            key: masterKey
        )
        
        // Cache it
        chatKeyCache.set(chatId, key: chatKey)
        
        return chatKey
    }
    
    private func decryptChat(_ response: ChatGetResponse, masterKey: Data) throws -> Chat {
        // Get or decrypt chat key
        let chatKey = try getChatKey(
            chatId: response.id,
            encryptedChatKey: response.encryptedChatKey,
            chatKeyNonce: response.chatKeyNonce,
            masterKey: masterKey
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
            folderId: response.folderId,
            encryptionKey: chatKey
        )
    }
    
    private func decryptChatSummary(_ encrypted: EncryptedChatSummary, masterKey: Data) throws -> ChatSummary {
        // Get or decrypt chat key
        let chatKey = try getChatKey(
            chatId: encrypted.id,
            encryptedChatKey: encrypted.encryptedChatKey,
            chatKeyNonce: encrypted.chatKeyNonce,
            masterKey: masterKey
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
            updatedAt: encrypted.updatedAt,
            folderId: encrypted.folderId
        )
    }
}

// MARK: - Chat Key Cache (LRU with TTL)

private final class ChatKeyCache: @unchecked Sendable {
    private struct CacheEntry {
        let key: Data
        let timestamp: Date
    }
    
    private var cache: [String: CacheEntry] = [:]
    private let maxSize: Int
    private let ttlSeconds: TimeInterval
    private let lock = NSLock()
    
    init(maxSize: Int, ttlSeconds: TimeInterval) {
        self.maxSize = maxSize
        self.ttlSeconds = ttlSeconds
    }
    
    func get(_ chatId: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = cache[chatId] else { return nil }
        
        // Check TTL
        if Date().timeIntervalSince(entry.timestamp) > ttlSeconds {
            cache.removeValue(forKey: chatId)
            return nil
        }
        
        return entry.key
    }
    
    func set(_ chatId: String, key: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        // Evict oldest entries if at capacity
        while cache.count >= maxSize {
            if let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp }) {
                cache.removeValue(forKey: oldest.key)
            }
        }
        
        cache[chatId] = CacheEntry(key: key, timestamp: Date())
    }
    
    func remove(_ chatId: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: chatId)
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

// MARK: - API Request/Response Models (matching web's tRPC format)

struct EncryptedChatSummary: Codable {
    let id: String
    let userId: String
    let isEncrypted: Bool
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct ChatGetRequest: Codable {
    let chatId: String
}

struct ChatGetResponse: Codable {
    let id: String
    let userId: String
    let isEncrypted: Bool
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct ChatCreateRequest: Codable {
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
    let folderId: String?
}

struct ChatCreateResponse: Codable {
    let id: String
}

struct ChatUpdateRequest: Codable {
    let chatId: String
    let encryptedTitle: String?
    let titleNonce: String?
    let encryptedChat: String?
    let chatNonce: String?
    let folderId: String?
}

struct ChatUpdateResponse: Codable {
    let id: String
}

struct ChatDeleteRequest: Codable {
    let chatId: String
}

struct ChatDeleteResponse: Codable {
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
    
    func updateChatFolder(chatId: String, folderId: String?, token: String) async throws {
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
