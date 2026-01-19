//
//  APIClient.swift
//  Onera
//
//  tRPC API client for backend communication
//

import Foundation

/// tRPC-compatible API client
actor APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: config)
        self.baseURL = Configuration.apiBaseURL.appendingPathComponent(Configuration.trpcPath)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - tRPC Request
    
    /// Makes a tRPC procedure call
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String? = nil
    ) async throws -> Output {
        let url = baseURL.appendingPathComponent(procedure)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // tRPC expects input wrapped in an object
        let wrappedInput = TRPCInput(input: input)
        request.httpBody = try encoder.encode(wrappedInput)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200..<300:
            let trpcResponse = try decoder.decode(TRPCResponse<Output>.self, from: data)
            return trpcResponse.result.data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500..<600:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw APIError.invalidResponse
        }
    }
    
    /// Makes a tRPC procedure call with no input
    func call<Output: Decodable>(
        procedure: String,
        token: String? = nil
    ) async throws -> Output {
        try await call(procedure: procedure, input: EmptyInput(), token: token)
    }
}

// MARK: - tRPC Request/Response Types

private struct EmptyInput: Encodable {}

private struct TRPCInput<T: Encodable>: Encodable {
    let input: T
    
    // Handle empty input case
    func encode(to encoder: Encoder) throws {
        if T.self == EmptyInput.self {
            var container = encoder.singleValueContainer()
            try container.encode([String: String]())
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(input, forKey: .input)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case input
    }
}

private struct TRPCResponse<T: Decodable>: Decodable {
    let result: TRPCResult<T>
}

private struct TRPCResult<T: Decodable>: Decodable {
    let data: T
}

// MARK: - API Procedures

extension APIClient {
    
    // MARK: - Key Shares
    
    func checkKeyShares(token: String) async throws -> KeySharesCheckResponse {
        try await call(procedure: "keyShares.check", token: token)
    }
    
    func getKeyShares(token: String) async throws -> KeySharesGetResponse {
        try await call(procedure: "keyShares.get", token: token)
    }
    
    func createKeyShares(request: KeySharesCreateRequest, token: String) async throws -> KeySharesCreateResponse {
        try await call(procedure: "keyShares.create", input: request, token: token)
    }
    
    // MARK: - Devices
    
    func registerDevice(request: DeviceRegisterRequest, token: String) async throws -> DeviceRegisterResponse {
        try await call(procedure: "devices.register", input: request, token: token)
    }
    
    func getDeviceSecret(deviceId: String, token: String) async throws -> DeviceSecretResponse {
        try await call(procedure: "devices.getDeviceSecret", input: DeviceSecretRequest(deviceId: deviceId), token: token)
    }
    
    // MARK: - Chats
    
    func getChats(token: String) async throws -> ChatsListResponse {
        try await call(procedure: "chats.list", token: token)
    }
    
    func createChat(request: ChatCreateRequest, token: String) async throws -> ChatCreateResponse {
        try await call(procedure: "chats.create", input: request, token: token)
    }
    
    func updateChat(request: ChatUpdateRequest, token: String) async throws -> ChatUpdateResponse {
        try await call(procedure: "chats.update", input: request, token: token)
    }
    
    func getChat(id: String, token: String) async throws -> ChatGetResponse {
        try await call(procedure: "chats.get", input: ChatGetRequest(id: id), token: token)
    }
    
    func deleteChat(id: String, token: String) async throws -> ChatDeleteResponse {
        try await call(procedure: "chats.delete", input: ChatDeleteRequest(id: id), token: token)
    }
}

// MARK: - Request/Response Models

struct KeySharesCheckResponse: Decodable {
    let hasKeyShares: Bool
}

struct KeySharesGetResponse: Decodable {
    let authShare: String
    let encryptedRecoveryShare: String
    let recoveryShareNonce: String
    let publicKey: String
    let encryptedPrivateKey: String
    let privateKeyNonce: String
    let masterKeyRecovery: String
    let masterKeyRecoveryNonce: String
    let encryptedRecoveryKey: String
    let recoveryKeyNonce: String
}

struct KeySharesCreateRequest: Encodable {
    let authShare: String
    let encryptedRecoveryShare: String
    let recoveryShareNonce: String
    let publicKey: String
    let encryptedPrivateKey: String
    let privateKeyNonce: String
    let masterKeyRecovery: String
    let masterKeyRecoveryNonce: String
    let encryptedRecoveryKey: String
    let recoveryKeyNonce: String
}

struct KeySharesCreateResponse: Decodable {
    let success: Bool
}

struct DeviceRegisterRequest: Encodable {
    let deviceId: String
    let deviceName: String
    let platform: String
}

struct DeviceRegisterResponse: Decodable {
    let deviceSecret: String
}

struct DeviceSecretRequest: Encodable {
    let deviceId: String
}

struct DeviceSecretResponse: Decodable {
    let deviceSecret: String
}

// MARK: - Chat Models

struct ChatsListResponse: Decodable {
    let chats: [EncryptedChatSummary]
}

struct EncryptedChatSummary: Decodable, Identifiable {
    let id: String
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let createdAt: Date
    let updatedAt: Date
}

struct ChatCreateRequest: Encodable {
    let encryptedChatKey: String
    let chatKeyNonce: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedChat: String
    let chatNonce: String
}

struct ChatCreateResponse: Decodable {
    let id: String
}

struct ChatUpdateRequest: Encodable {
    let id: String
    let encryptedTitle: String?
    let titleNonce: String?
    let encryptedChat: String
    let chatNonce: String
}

struct ChatUpdateResponse: Decodable {
    let success: Bool
}

struct ChatGetRequest: Encodable {
    let id: String
}

struct ChatGetResponse: Decodable {
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

struct ChatDeleteRequest: Encodable {
    let id: String
}

struct ChatDeleteResponse: Decodable {
    let success: Bool
}
