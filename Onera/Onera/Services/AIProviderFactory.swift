//
//  AIProviderFactory.swift
//  Onera
//
//  Provider factory for Swift AI SDK - mirrors web's providers/index.ts
//

import Foundation
import AISDKProvider
import SwiftAISDK
import OpenAIProvider
import AnthropicProvider
import GoogleProvider
import GroqProvider
import XAIProvider
import DeepSeekProvider
import OpenAICompatibleProvider

/// Factory for creating AI SDK model instances from decrypted credentials
/// Matches the web client's `getModelForCredential` function
enum AIProviderFactory {
    
    // MARK: - Provider Cache
    
    /// Cache provider instances by credential ID for reuse
    /// Using nonisolated(unsafe) since access is protected by cacheLock
    private nonisolated(unsafe) static var providerCache: [String: Any] = [:]
    private static let cacheLock = NSLock()
    
    // MARK: - Public API
    
    /// Get or create a model instance for a credential
    /// - Parameters:
    ///   - credential: The decrypted credential with API key and settings
    ///   - modelName: The name of the model to use (e.g., "gpt-4o", "claude-3-opus")
    /// - Returns: A LanguageModelV3 instance ready for use with streamText/generateText
    nonisolated static func getModel(credential: DecryptedCredential, modelName: String) throws -> any LanguageModelV3 {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        switch credential.provider {
        case .openai:
            let provider = getOrCreateOpenAIProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .anthropic:
            let provider = getOrCreateAnthropicProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .google:
            let provider = getOrCreateGoogleProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .groq:
            let provider = getOrCreateGroqProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .xai:
            let provider = getOrCreateXAIProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .deepseek:
            let provider = getOrCreateDeepSeekProvider(credential: credential)
            return try provider.languageModel(modelId: modelName)
            
        case .mistral, .openrouter, .together, .fireworks, .ollama, .lmstudio, .custom:
            // Use OpenAI-compatible provider for these
            let provider = getOrCreateOpenAICompatibleProvider(credential: credential)
            return try provider.chatModel(modelId: modelName)
        }
    }
    
    /// Clear the provider cache
    /// Call on logout, lock, or credential changes
    nonisolated static func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        providerCache.removeAll()
    }
    
    // MARK: - Provider Creation Methods
    
    private nonisolated static func getOrCreateOpenAIProvider(credential: DecryptedCredential) -> OpenAIProvider {
        if let cached = providerCache[credential.id] as? OpenAIProvider {
            return cached
        }
        
        let settings = OpenAIProviderSettings(
            baseURL: credential.baseUrl,
            apiKey: credential.apiKey,
            organization: credential.orgId
        )
        
        let provider = createOpenAIProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateAnthropicProvider(credential: DecryptedCredential) -> AnthropicProvider {
        if let cached = providerCache[credential.id] as? AnthropicProvider {
            return cached
        }
        
        var headers = [String: String]()
        // Required header for direct client access (matches web)
        headers["anthropic-dangerous-direct-browser-access"] = "true"
        
        let settings = AnthropicProviderSettings(
            baseURL: credential.baseUrl,
            apiKey: credential.apiKey,
            headers: headers
        )
        
        let provider = createAnthropicProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateGoogleProvider(credential: DecryptedCredential) -> GoogleProvider {
        if let cached = providerCache[credential.id] as? GoogleProvider {
            return cached
        }
        
        let settings = GoogleProviderSettings(
            baseURL: credential.baseUrl,
            apiKey: credential.apiKey
        )
        
        let provider = createGoogleGenerativeAI(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateGroqProvider(credential: DecryptedCredential) -> GroqProvider {
        if let cached = providerCache[credential.id] as? GroqProvider {
            return cached
        }
        
        let settings = GroqProviderSettings(
            baseURL: credential.baseUrl,
            apiKey: credential.apiKey
        )
        
        let provider = createGroqProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateXAIProvider(credential: DecryptedCredential) -> XAIProvider {
        if let cached = providerCache[credential.id] as? XAIProvider {
            return cached
        }
        
        let settings = XAIProviderSettings(
            baseURL: credential.baseUrl,
            apiKey: credential.apiKey
        )
        
        let provider = createXAIProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateDeepSeekProvider(credential: DecryptedCredential) -> DeepSeekProvider {
        if let cached = providerCache[credential.id] as? DeepSeekProvider {
            return cached
        }
        
        let settings = DeepSeekProviderSettings(
            apiKey: credential.apiKey,
            baseURL: credential.baseUrl
        )
        
        let provider = createDeepSeekProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
    
    private nonisolated static func getOrCreateOpenAICompatibleProvider(credential: DecryptedCredential) -> OpenAICompatibleProvider {
        if let cached = providerCache[credential.id] as? OpenAICompatibleProvider {
            return cached
        }
        
        let defaultBaseURL: String
        switch credential.provider {
        case .mistral:
            defaultBaseURL = "https://api.mistral.ai/v1"
        case .openrouter:
            defaultBaseURL = "https://openrouter.ai/api/v1"
        case .together:
            defaultBaseURL = "https://api.together.xyz/v1"
        case .fireworks:
            defaultBaseURL = "https://api.fireworks.ai/inference/v1"
        case .ollama:
            defaultBaseURL = "http://localhost:11434/v1"
        case .lmstudio:
            defaultBaseURL = "http://localhost:1234/v1"
        default:
            defaultBaseURL = credential.effectiveBaseURL
        }
        
        let baseURL = credential.baseUrl ?? defaultBaseURL
        
        let settings = OpenAICompatibleProviderSettings(
            baseURL: baseURL,
            name: credential.provider.rawValue,
            apiKey: credential.apiKey.isEmpty ? credential.provider.rawValue : credential.apiKey
        )
        
        let provider = createOpenAICompatibleProvider(settings: settings)
        providerCache[credential.id] = provider
        return provider
    }
}

// MARK: - Default Base URLs

extension AIProviderFactory {
    
    /// Get the default base URL for a provider
    static func getDefaultBaseURL(for provider: LLMProvider) -> String {
        switch provider {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com"
        case .google:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .xai:
            return "https://api.x.ai/v1"
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .mistral:
            return "https://api.mistral.ai/v1"
        case .deepseek:
            return "https://api.deepseek.com"
        case .openrouter:
            return "https://openrouter.ai/api/v1"
        case .together:
            return "https://api.together.xyz/v1"
        case .fireworks:
            return "https://api.fireworks.ai/inference/v1"
        case .ollama:
            return "http://localhost:11434/v1"
        case .lmstudio:
            return "http://localhost:1234/v1"
        case .custom:
            return ""
        }
    }
}
