//
//  CredentialServiceProtocol.swift
//  Onera
//
//  Protocol for credential management service
//

import Foundation

// MARK: - LLM Provider

enum LLMProvider: String, Codable, CaseIterable, Sendable {
    case openai
    case anthropic
    case google
    case xai
    case groq
    case mistral
    case deepseek
    case openrouter
    case together
    case fireworks
    case ollama
    case lmstudio
    case custom
    
    nonisolated var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .xai: return "xAI"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        case .deepseek: return "DeepSeek"
        case .openrouter: return "OpenRouter"
        case .together: return "Together"
        case .fireworks: return "Fireworks"
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .custom: return "Custom"
        }
    }
    
    nonisolated var baseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .google: return "https://generativelanguage.googleapis.com"
        case .xai: return "https://api.x.ai/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .mistral: return "https://api.mistral.ai/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .together: return "https://api.together.xyz/v1"
        case .fireworks: return "https://api.fireworks.ai/inference/v1"
        case .ollama: return "http://localhost:11434"
        case .lmstudio: return "http://localhost:1234/v1"
        case .custom: return ""
        }
    }
    
    /// Whether this provider uses OpenAI-compatible API format
    nonisolated var isOpenAICompatible: Bool {
        switch self {
        case .openai, .groq, .deepseek, .openrouter, .together, .fireworks, .ollama, .lmstudio, .xai, .mistral, .custom:
            return true
        case .anthropic, .google:
            return false
        }
    }
}

// MARK: - Encrypted Credential (from server)

struct EncryptedCredential: Codable, Sendable {
    let id: String
    let userId: String
    
    // Encrypted name (XSalsa20-Poly1305 with master key)
    let encryptedName: String?
    let nameNonce: String?
    
    // Encrypted provider (XSalsa20-Poly1305 with master key)
    let encryptedProvider: String?
    let providerNonce: String?
    
    // Encrypted API key data
    let encryptedData: String  // Base64 encrypted JSON
    let iv: String             // Base64 nonce
    
    let createdAt: Int64
    let updatedAt: Int64
}

// MARK: - Encrypted Credential Name Data

struct EncryptedCredentialName: Codable, Sendable {
    let encryptedName: String
    let nameNonce: String
}

// MARK: - Encrypted Credential Provider Data

struct EncryptedCredentialProvider: Codable, Sendable {
    let encryptedProvider: String
    let providerNonce: String
}

// MARK: - Decrypted Credential Data (from encrypted JSON)

struct CredentialData: Codable, Sendable {
    let apiKey: String
    let baseUrl: String?
    let orgId: String?
    let config: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case baseUrl = "base_url"
        case orgId = "org_id"
        case config
    }
}

// MARK: - Decrypted Credential

struct DecryptedCredential: Identifiable, Equatable, Sendable {
    let id: String
    let provider: LLMProvider
    let name: String
    let apiKey: String
    let baseUrl: String?
    let orgId: String?
    let config: [String: String]?
    
    /// Returns the effective base URL (credential-specific or provider default)
    nonisolated var effectiveBaseURL: String {
        baseUrl ?? provider.baseURL
    }
    
    static func == (lhs: DecryptedCredential, rhs: DecryptedCredential) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Credential Service Protocol

@MainActor
protocol CredentialServiceProtocol: AnyObject {
    
    /// Currently cached decrypted credentials
    var credentials: [DecryptedCredential] { get }
    
    /// Whether credentials are currently loading
    var isLoading: Bool { get }
    
    /// Fetches and decrypts credentials from the server
    /// - Parameter token: The authentication token
    func fetchCredentials(token: String) async throws
    
    /// Refreshes credentials (re-fetches and decrypts)
    /// - Parameter token: The authentication token
    func refreshCredentials(token: String) async throws
    
    /// Clears the cached credentials (call on lock)
    func clearCredentials()
    
    /// Gets a credential by ID from cache
    /// - Parameter id: The credential ID
    /// - Returns: The decrypted credential if found
    func getCredential(byId id: String) -> DecryptedCredential?
    
    /// Gets credentials for a specific provider
    /// - Parameter provider: The LLM provider
    /// - Returns: Array of decrypted credentials for that provider
    func getCredentials(for provider: LLMProvider) -> [DecryptedCredential]
}
