//
//  CredentialService.swift
//  Onera
//
//  Credential management service for E2EE API credentials
//

import Foundation
import Observation

@MainActor
@Observable
final class CredentialService: CredentialServiceProtocol {
    
    // MARK: - State
    
    private(set) var credentials: [DecryptedCredential] = []
    private(set) var isLoading = false
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let secureSession: SecureSessionProtocol
    private let cryptoService: CryptoServiceProtocol
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        secureSession: SecureSessionProtocol,
        cryptoService: CryptoServiceProtocol
    ) {
        self.networkService = networkService
        self.secureSession = secureSession
        self.cryptoService = cryptoService
    }
    
    // MARK: - Public Methods
    
    func fetchCredentials(token: String) async throws {
        guard secureSession.isUnlocked else {
            throw CredentialError.sessionLocked
        }
        
        guard let masterKey = secureSession.masterKey else {
            throw CredentialError.noMasterKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch encrypted credentials from server
            let encryptedCredentials: [EncryptedCredential] = try await networkService.call(
                procedure: APIEndpoint.Credentials.list,
                token: token
            )
            
            // Decrypt each credential
            credentials = try encryptedCredentials.compactMap { encrypted in
                try decryptCredential(encrypted, masterKey: masterKey)
            }
        } catch {
            throw CredentialError.fetchFailed(underlying: error)
        }
    }
    
    func refreshCredentials(token: String) async throws {
        try await fetchCredentials(token: token)
    }
    
    func clearCredentials() {
        credentials = []
    }
    
    func getCredential(byId id: String) -> DecryptedCredential? {
        credentials.first { $0.id == id }
    }
    
    func getCredentials(for provider: LLMProvider) -> [DecryptedCredential] {
        credentials.filter { $0.provider == provider }
    }
    
    // MARK: - Private Methods
    
    private func decryptCredential(
        _ encrypted: EncryptedCredential,
        masterKey: Data
    ) throws -> DecryptedCredential? {
        // Decode base64 ciphertext and nonce
        guard let ciphertextData = Data(base64Encoded: encrypted.encryptedData),
              let nonceData = Data(base64Encoded: encrypted.iv) else {
            return nil
        }
        
        // Decrypt the credential data
        let plaintext: Data
        do {
            plaintext = try cryptoService.decrypt(
                ciphertext: ciphertextData,
                nonce: nonceData,
                key: masterKey
            )
        } catch {
            print("Failed to decrypt credential \(encrypted.id): \(error)")
            return nil
        }
        
        // Parse the decrypted JSON
        let decoder = JSONDecoder()
        let credentialData: CredentialData
        do {
            credentialData = try decoder.decode(CredentialData.self, from: plaintext)
        } catch {
            print("Failed to parse credential data \(encrypted.id): \(error)")
            return nil
        }
        
        // Parse provider
        guard let provider = LLMProvider(rawValue: encrypted.provider) else {
            print("Unknown provider: \(encrypted.provider)")
            // Default to custom for unknown providers
            return DecryptedCredential(
                id: encrypted.id,
                provider: .custom,
                name: encrypted.name,
                apiKey: credentialData.apiKey,
                baseUrl: credentialData.baseUrl,
                orgId: credentialData.orgId,
                config: credentialData.config
            )
        }
        
        return DecryptedCredential(
            id: encrypted.id,
            provider: provider,
            name: encrypted.name,
            apiKey: credentialData.apiKey,
            baseUrl: credentialData.baseUrl,
            orgId: credentialData.orgId,
            config: credentialData.config
        )
    }
}

// MARK: - Errors

enum CredentialError: LocalizedError {
    case sessionLocked
    case noMasterKey
    case fetchFailed(underlying: Error)
    case decryptionFailed
    case invalidCredentialData
    
    var errorDescription: String? {
        switch self {
        case .sessionLocked:
            return "Session is locked. Please unlock to access credentials."
        case .noMasterKey:
            return "Master key not available. Please unlock E2EE."
        case .fetchFailed(let underlying):
            return "Failed to fetch credentials: \(underlying.localizedDescription)"
        case .decryptionFailed:
            return "Failed to decrypt credential data."
        case .invalidCredentialData:
            return "Invalid credential data format."
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockCredentialService: CredentialServiceProtocol {
    
    var credentials: [DecryptedCredential] = []
    var isLoading = false
    var shouldFail = false
    
    func fetchCredentials(token: String) async throws {
        if shouldFail {
            throw CredentialError.fetchFailed(underlying: NSError(domain: "Mock", code: -1))
        }
        
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(300))
        
        credentials = [
            DecryptedCredential(
                id: "mock-openai",
                provider: .openai,
                name: "OpenAI",
                apiKey: "sk-mock-key",
                baseUrl: nil,
                orgId: nil,
                config: nil
            ),
            DecryptedCredential(
                id: "mock-anthropic",
                provider: .anthropic,
                name: "Anthropic",
                apiKey: "sk-ant-mock-key",
                baseUrl: nil,
                orgId: nil,
                config: nil
            )
        ]
    }
    
    func refreshCredentials(token: String) async throws {
        try await fetchCredentials(token: token)
    }
    
    func clearCredentials() {
        credentials = []
    }
    
    func getCredential(byId id: String) -> DecryptedCredential? {
        credentials.first { $0.id == id }
    }
    
    func getCredentials(for provider: LLMProvider) -> [DecryptedCredential] {
        credentials.filter { $0.provider == provider }
    }
}
#endif
