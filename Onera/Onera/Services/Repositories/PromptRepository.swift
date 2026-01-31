//
//  PromptRepository.swift
//  Onera
//
//  Prompt data repository implementation with E2EE encryption
//  Prompts are encrypted directly with the master key (like notes)
//

import Foundation

// MARK: - Protocol

protocol PromptRepositoryProtocol: Sendable {
    func fetchPrompts(token: String) async throws -> [PromptSummary]
    func fetchPrompt(id: String, token: String) async throws -> Prompt
    func createPrompt(_ prompt: Prompt, token: String) async throws -> String
    func updatePrompt(_ prompt: Prompt, token: String) async throws
    func deletePrompt(id: String, token: String) async throws
}

// MARK: - Implementation

final class PromptRepository: PromptRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.secureSession = secureSession
        
        self.decoder = JSONDecoder()
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
    
    // MARK: - Prompts List
    
    func fetchPrompts(token: String) async throws -> [PromptSummary] {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let response: [EncryptedPromptResponse] = try await networkService.call(
            procedure: APIEndpoint.Prompts.list,
            token: token
        )
        
        return response.compactMap { encrypted in
            do {
                return try decryptPromptSummary(encrypted, masterKey: masterKey)
            } catch {
                print("Failed to decrypt prompt \(encrypted.id): \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Single Prompt
    
    func fetchPrompt(id: String, token: String) async throws -> Prompt {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let response: EncryptedPromptResponse = try await networkService.query(
            procedure: APIEndpoint.Prompts.get,
            input: PromptGetRequest(promptId: id),
            token: token
        )
        
        return try decryptPrompt(response, masterKey: masterKey)
    }
    
    func createPrompt(_ prompt: Prompt, token: String) async throws -> String {
        print("[PromptRepository] createPrompt: id=\(prompt.id), name='\(prompt.name)'")
        
        guard let masterKey = await secureSession.masterKey else {
            print("[PromptRepository] createPrompt: E2EE session locked")
            throw E2EEError.sessionLocked
        }
        
        let encrypted = try encryptPromptForCreate(prompt, masterKey: masterKey)
        print("[PromptRepository] createPrompt: Prompt encrypted, calling API...")
        
        let response: PromptCreateResponse = try await networkService.call(
            procedure: APIEndpoint.Prompts.create,
            input: encrypted,
            token: token
        )
        
        print("[PromptRepository] createPrompt: Success, new id=\(response.id)")
        return response.id
    }
    
    func updatePrompt(_ prompt: Prompt, token: String) async throws {
        print("[PromptRepository] updatePrompt: id=\(prompt.id), name='\(prompt.name)'")
        
        guard let masterKey = await secureSession.masterKey else {
            print("[PromptRepository] updatePrompt: E2EE session locked")
            throw E2EEError.sessionLocked
        }
        
        // Encrypt name with master key
        guard let nameData = prompt.name.data(using: .utf8) else {
            print("[PromptRepository] updatePrompt: Failed to encode name")
            throw PromptError.encryptionFailed
        }
        let (encryptedName, nameNonce) = try cryptoService.encrypt(
            plaintext: nameData,
            key: masterKey
        )
        
        // Encrypt description if present
        var encryptedDescription: String?
        var descriptionNonce: String?
        if let description = prompt.description {
            guard let descriptionData = description.data(using: .utf8) else {
                throw PromptError.encryptionFailed
            }
            let (encrypted, nonce) = try cryptoService.encrypt(
                plaintext: descriptionData,
                key: masterKey
            )
            encryptedDescription = encrypted.base64EncodedString()
            descriptionNonce = nonce.base64EncodedString()
        }
        
        // Encrypt content with master key
        guard let contentData = prompt.content.data(using: .utf8) else {
            print("[PromptRepository] updatePrompt: Failed to encode content")
            throw PromptError.encryptionFailed
        }
        let (encryptedContent, contentNonce) = try cryptoService.encrypt(
            plaintext: contentData,
            key: masterKey
        )
        
        print("[PromptRepository] updatePrompt: Prompt encrypted, calling API...")
        
        let _: PromptUpdateResponse = try await networkService.call(
            procedure: APIEndpoint.Prompts.update,
            input: PromptUpdateRequest(
                promptId: prompt.id,
                encryptedName: encryptedName.base64EncodedString(),
                nameNonce: nameNonce.base64EncodedString(),
                encryptedDescription: encryptedDescription,
                descriptionNonce: descriptionNonce,
                encryptedContent: encryptedContent.base64EncodedString(),
                contentNonce: contentNonce.base64EncodedString()
            ),
            token: token
        )
        
        print("[PromptRepository] updatePrompt: Success")
    }
    
    func deletePrompt(id: String, token: String) async throws {
        let _: PromptDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.Prompts.delete,
            input: PromptDeleteRequest(promptId: id),
            token: token
        )
    }
    
    // MARK: - Private Encryption Methods
    
    private func encryptPromptForCreate(_ prompt: Prompt, masterKey: Data) throws -> PromptCreateRequest {
        // Encrypt name with master key
        guard let nameData = prompt.name.data(using: .utf8) else {
            throw PromptError.encryptionFailed
        }
        let (encryptedName, nameNonce) = try cryptoService.encrypt(
            plaintext: nameData,
            key: masterKey
        )
        
        // Encrypt description if present
        var encryptedDescription: String?
        var descriptionNonce: String?
        if let description = prompt.description {
            guard let descriptionData = description.data(using: .utf8) else {
                throw PromptError.encryptionFailed
            }
            let (encrypted, nonce) = try cryptoService.encrypt(
                plaintext: descriptionData,
                key: masterKey
            )
            encryptedDescription = encrypted.base64EncodedString()
            descriptionNonce = nonce.base64EncodedString()
        }
        
        // Encrypt content with master key
        guard let contentData = prompt.content.data(using: .utf8) else {
            throw PromptError.encryptionFailed
        }
        let (encryptedContent, contentNonce) = try cryptoService.encrypt(
            plaintext: contentData,
            key: masterKey
        )
        
        return PromptCreateRequest(
            encryptedName: encryptedName.base64EncodedString(),
            nameNonce: nameNonce.base64EncodedString(),
            encryptedDescription: encryptedDescription,
            descriptionNonce: descriptionNonce,
            encryptedContent: encryptedContent.base64EncodedString(),
            contentNonce: contentNonce.base64EncodedString()
        )
    }
    
    private func decryptPrompt(_ encrypted: EncryptedPromptResponse, masterKey: Data) throws -> Prompt {
        // Decrypt name
        guard let encryptedName = Data(base64Encoded: encrypted.encryptedName),
              let nameNonce = Data(base64Encoded: encrypted.nameNonce) else {
            throw PromptError.decryptionFailed
        }
        
        let nameData = try cryptoService.decrypt(
            ciphertext: encryptedName,
            nonce: nameNonce,
            key: masterKey
        )
        
        guard let name = String(data: nameData, encoding: .utf8) else {
            throw PromptError.decryptionFailed
        }
        
        // Decrypt description if present
        var description: String?
        if let encryptedDescriptionStr = encrypted.encryptedDescription,
           let descriptionNonceStr = encrypted.descriptionNonce,
           let encryptedDescription = Data(base64Encoded: encryptedDescriptionStr),
           let descNonce = Data(base64Encoded: descriptionNonceStr) {
            let descriptionData = try cryptoService.decrypt(
                ciphertext: encryptedDescription,
                nonce: descNonce,
                key: masterKey
            )
            description = String(data: descriptionData, encoding: .utf8)
        }
        
        // Decrypt content
        guard let encryptedContent = Data(base64Encoded: encrypted.encryptedContent),
              let contentNonce = Data(base64Encoded: encrypted.contentNonce) else {
            throw PromptError.decryptionFailed
        }
        
        let contentData = try cryptoService.decrypt(
            ciphertext: encryptedContent,
            nonce: contentNonce,
            key: masterKey
        )
        
        guard let content = String(data: contentData, encoding: .utf8) else {
            throw PromptError.decryptionFailed
        }
        
        return Prompt(
            id: encrypted.id,
            name: name,
            description: description,
            content: content,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt
        )
    }
    
    private func decryptPromptSummary(_ encrypted: EncryptedPromptResponse, masterKey: Data) throws -> PromptSummary {
        // Decrypt name
        guard let encryptedName = Data(base64Encoded: encrypted.encryptedName),
              let nameNonce = Data(base64Encoded: encrypted.nameNonce) else {
            throw PromptError.decryptionFailed
        }
        
        let nameData = try cryptoService.decrypt(
            ciphertext: encryptedName,
            nonce: nameNonce,
            key: masterKey
        )
        
        guard let name = String(data: nameData, encoding: .utf8) else {
            throw PromptError.decryptionFailed
        }
        
        // Decrypt description if present
        var description: String?
        if let encryptedDescriptionStr = encrypted.encryptedDescription,
           let descriptionNonceStr = encrypted.descriptionNonce,
           let encryptedDescription = Data(base64Encoded: encryptedDescriptionStr),
           let descNonce = Data(base64Encoded: descriptionNonceStr) {
            let descriptionData = try cryptoService.decrypt(
                ciphertext: encryptedDescription,
                nonce: descNonce,
                key: masterKey
            )
            description = String(data: descriptionData, encoding: .utf8)
        }
        
        return PromptSummary(
            id: encrypted.id,
            name: name,
            description: description,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt
        )
    }
}

// MARK: - API Request/Response Models

private struct PromptGetRequest: Codable {
    let promptId: String
}

private struct EncryptedPromptResponse: Codable {
    let id: String
    let userId: String
    let encryptedName: String
    let nameNonce: String
    let encryptedDescription: String?
    let descriptionNonce: String?
    let encryptedContent: String
    let contentNonce: String
    let createdAt: Date
    let updatedAt: Date
}

private struct PromptCreateRequest: Codable {
    let encryptedName: String
    let nameNonce: String
    let encryptedDescription: String?
    let descriptionNonce: String?
    let encryptedContent: String
    let contentNonce: String
}

private struct PromptCreateResponse: Codable {
    let id: String
}

private struct PromptUpdateRequest: Codable {
    let promptId: String
    let encryptedName: String?
    let nameNonce: String?
    let encryptedDescription: String?
    let descriptionNonce: String?
    let encryptedContent: String?
    let contentNonce: String?
}

private struct PromptUpdateResponse: Codable {
    let id: String
}

private struct PromptDeleteRequest: Codable {
    let promptId: String
}

private struct PromptDeleteResponse: Codable {
    let success: Bool
}

// MARK: - Mock Implementation

#if DEBUG
final class MockPromptRepository: PromptRepositoryProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var mockPrompts: [PromptSummary] = []
    var mockPrompt: Prompt?
    
    func fetchPrompts(token: String) async throws -> [PromptSummary] {
        if shouldFail { throw PromptError.decryptionFailed }
        return mockPrompts
    }
    
    func fetchPrompt(id: String, token: String) async throws -> Prompt {
        if shouldFail { throw PromptError.promptNotFound }
        return mockPrompt ?? .mock()
    }
    
    func createPrompt(_ prompt: Prompt, token: String) async throws -> String {
        if shouldFail { throw PromptError.createFailed }
        return UUID().uuidString
    }
    
    func updatePrompt(_ prompt: Prompt, token: String) async throws {
        if shouldFail { throw PromptError.updateFailed }
    }
    
    func deletePrompt(id: String, token: String) async throws {
        if shouldFail { throw PromptError.deleteFailed }
    }
}
#endif
