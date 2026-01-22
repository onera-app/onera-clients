//
//  CredentialsViewModel.swift
//  Onera
//
//  ViewModel for managing API credentials
//  Note: Credential names and providers are encrypted client-side using E2EE
//

import Foundation
import Observation

@MainActor
@Observable
final class CredentialsViewModel {
    
    // MARK: - State
    
    private(set) var credentials: [DecryptedCredential] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var showAddCredential = false
    var showDeleteConfirmation = false
    var credentialToDelete: DecryptedCredential?
    
    // MARK: - Add Credential State
    
    var selectedProvider: LLMProvider = .openai
    var credentialName = ""
    var apiKey = ""
    var baseUrl = ""
    var orgId = ""
    var isSaving = false
    
    // MARK: - Dependencies
    
    private let credentialService: CredentialServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let extendedCryptoService: ExtendedCryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(
        credentialService: CredentialServiceProtocol,
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        extendedCryptoService: ExtendedCryptoServiceProtocol,
        secureSession: SecureSessionProtocol,
        authService: AuthServiceProtocol
    ) {
        self.credentialService = credentialService
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.extendedCryptoService = extendedCryptoService
        self.secureSession = secureSession
        self.authService = authService
    }
    
    // MARK: - Public Methods
    
    func loadCredentials() {
        credentials = credentialService.credentials
    }
    
    func refreshCredentials() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await credentialService.refreshCredentials(token: token)
            credentials = credentialService.credentials
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func saveCredential() async -> Bool {
        guard !apiKey.isEmpty else {
            error = CredentialSaveError.missingApiKey
            return false
        }
        
        guard !credentialName.isEmpty else {
            error = CredentialSaveError.missingName
            return false
        }
        
        guard let masterKey = secureSession.masterKey else {
            error = E2EEError.sessionLocked
            return false
        }
        
        isSaving = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            
            // Build credential data JSON
            var credentialData: [String: Any] = [
                "api_key": apiKey
            ]
            
            if !baseUrl.isEmpty {
                credentialData["base_url"] = baseUrl
            }
            
            if !orgId.isEmpty {
                credentialData["org_id"] = orgId
            }
            
            // Encrypt the credential data (API key, etc.)
            let jsonData = try JSONSerialization.data(withJSONObject: credentialData)
            let (encryptedData, nonce) = try cryptoService.encrypt(plaintext: jsonData, key: masterKey)
            
            // Encrypt the credential name
            let (encryptedNameCiphertext, nameNonce) = try extendedCryptoService.encryptString(credentialName, key: masterKey)
            
            // Encrypt the provider
            let (encryptedProviderCiphertext, providerNonce) = try extendedCryptoService.encryptString(selectedProvider.rawValue, key: masterKey)
            
            // Send to server with encrypted fields
            let request = CreateCredentialRequest(
                encryptedName: encryptedNameCiphertext,
                nameNonce: nameNonce,
                encryptedProvider: encryptedProviderCiphertext,
                providerNonce: providerNonce,
                encryptedData: encryptedData.base64EncodedString(),
                iv: nonce.base64EncodedString()
            )
            
            let _: CreateCredentialResponse = try await networkService.call(
                procedure: APIEndpoint.Credentials.create,
                input: request,
                token: token
            )
            
            // Refresh credentials list
            try await credentialService.refreshCredentials(token: token)
            credentials = credentialService.credentials
            
            // Reset form
            resetForm()
            
            isSaving = false
            return true
            
        } catch {
            self.error = error
            isSaving = false
            return false
        }
    }
    
    func deleteCredential(_ credential: DecryptedCredential) async {
        do {
            let token = try await authService.getToken()
            
            let request = DeleteCredentialRequest(credentialId: credential.id)
            let _: DeleteCredentialResponse = try await networkService.call(
                procedure: APIEndpoint.Credentials.remove,
                input: request,
                token: token
            )
            
            // Refresh credentials list
            try await credentialService.refreshCredentials(token: token)
            credentials = credentialService.credentials
            
        } catch {
            self.error = error
        }
        
        credentialToDelete = nil
    }
    
    func confirmDelete(_ credential: DecryptedCredential) {
        credentialToDelete = credential
        showDeleteConfirmation = true
    }
    
    func resetForm() {
        selectedProvider = .openai
        credentialName = ""
        apiKey = ""
        baseUrl = ""
        orgId = ""
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Computed Properties
    
    var canSave: Bool {
        !apiKey.isEmpty && !credentialName.isEmpty
    }
    
    var showBaseUrlField: Bool {
        selectedProvider == .custom || selectedProvider == .ollama || selectedProvider == .lmstudio
    }
    
    var showOrgIdField: Bool {
        selectedProvider == .openai
    }
    
    var providerGroups: [(String, [LLMProvider])] {
        [
            ("Cloud Providers", [.openai, .anthropic, .google, .xai, .groq, .mistral, .deepseek]),
            ("Aggregators", [.openrouter, .together, .fireworks]),
            ("Local", [.ollama, .lmstudio]),
            ("Other", [.custom])
        ]
    }
}

// MARK: - Error Types

enum CredentialSaveError: LocalizedError {
    case missingApiKey
    case missingName
    case encryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "API key is required"
        case .missingName:
            return "Credential name is required"
        case .encryptionFailed:
            return "Failed to encrypt credential"
        }
    }
}

// MARK: - API Request/Response Models

private struct CreateCredentialRequest: Codable {
    // Encrypted name (XSalsa20-Poly1305 with master key)
    let encryptedName: String
    let nameNonce: String
    
    // Encrypted provider (XSalsa20-Poly1305 with master key)
    let encryptedProvider: String
    let providerNonce: String
    
    // Encrypted API key data
    let encryptedData: String
    let iv: String
}

private struct CreateCredentialResponse: Codable {
    let id: String
}

private struct DeleteCredentialRequest: Codable {
    let credentialId: String
}

private struct DeleteCredentialResponse: Codable {
    let success: Bool
}
