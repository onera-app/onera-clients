//
//  LLMService.swift
//  Onera
//
//  LLM API service using Swift AI SDK for streaming
//

import Foundation
import SwiftAISDK
import AISDKProvider

actor LLMService: LLMServiceProtocol {
    
    // MARK: - Properties
    
    private var currentTask: Task<Void, Error>?
    private let session: URLSession
    
    // MARK: - Model Cache
    
    /// Cache entry for models with TTL
    private struct ModelCacheEntry {
        let models: [ModelOption]
        let fetchedAt: Date
    }
    
    /// Cache TTL: 5 minutes (matches web implementation)
    private nonisolated static let modelCacheTTL: TimeInterval = 5 * 60
    
    /// Model cache keyed by credential ID
    private var modelCache: [String: ModelCacheEntry] = [:]
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Cache Management
    
    /// Invalidates model cache for a specific credential or all credentials
    func invalidateModelCache(credentialId: String? = nil) {
        if let id = credentialId {
            modelCache.removeValue(forKey: id)
        } else {
            modelCache.removeAll()
        }
    }
    
    // MARK: - Streaming Chat (Swift AI SDK)
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // Cancel any existing stream
        currentTask?.cancel()
        
        let task = Task {
            try await performStreamChat(
                messages: messages,
                credential: credential,
                model: model,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        }
        
        currentTask = task
        
        do {
            try await task.value
        } catch is CancellationError {
            onEvent(.done)
            throw LLMError.cancelled
        }
    }
    
    private func performStreamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // Get the model from the provider factory
        let languageModel: any LanguageModelV3
        do {
            languageModel = try AIProviderFactory.getModel(credential: credential, modelName: model)
        } catch {
            throw LLMError.invalidCredential
        }
        
        // Convert our ChatMessage array to Swift AI SDK ModelMessage array
        var sdkMessages: [ModelMessage] = []
        
        for message in messages {
            switch message.role {
            case .user:
                // Check if message has attachments - include context as text
                if let attachments = message.attachments, !attachments.isEmpty {
                    var fullContent = message.content
                    
                    // Add document/text content from attachments
                    for attachment in attachments {
                        if let extractedText = attachment.extractedText, !extractedText.isEmpty {
                            let context = "\n\n[Document: \(attachment.fileName ?? "file")]\n\(extractedText)"
                            fullContent += context
                        } else if attachment.type == .image {
                            // Note that an image is attached (some models can see it via vision)
                            let imageName = attachment.fileName ?? "image"
                            fullContent += "\n\n[Image attached: \(imageName)]"
                        }
                    }
                    
                    sdkMessages.append(.user(fullContent))
                } else {
                    sdkMessages.append(.user(message.content))
                }
            case .assistant:
                sdkMessages.append(.assistant(message.content))
            case .system:
                // System messages are handled separately via the system parameter
                continue
            }
        }
        
        // Configure call settings
        let settings = CallSettings(
            maxOutputTokens: maxTokens
        )
        
        // Create the stream using Swift AI SDK
        let result: DefaultStreamTextResult<JSONValue, JSONValue> = try streamText(
            model: .v3(languageModel),
            system: systemPrompt,
            messages: sdkMessages,
            settings: settings
        )
        
        // Iterate over the full stream to get all events
        for try await part in result.fullStream {
            try Task.checkCancellation()
            
            switch part {
            case .textDelta(_, let text, _):
                onEvent(.text(text))
                
            case .reasoningDelta(_, let text, _):
                onEvent(.reasoning(text))
                
            case .toolCall(let toolCall):
                // Handle tool calls
                switch toolCall {
                case .static(let staticCall):
                    if let inputData = try? JSONEncoder().encode(staticCall.input),
                       let inputString = String(data: inputData, encoding: .utf8) {
                        onEvent(.toolCall(staticCall.toolName, inputString))
                    }
                case .dynamic(let dynamicCall):
                    if let inputData = try? JSONEncoder().encode(dynamicCall.input),
                       let inputString = String(data: inputData, encoding: .utf8) {
                        onEvent(.toolCall(dynamicCall.toolName, inputString))
                    }
                }
                
            default:
                // Ignore other events (textStart, textEnd, reasoningStart, reasoningEnd, etc.)
                break
            }
        }
        
        onEvent(.done)
    }
    
    // MARK: - Fetch Models
    
    func fetchModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        // Check cache first
        if let cached = modelCache[credential.id] {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < Self.modelCacheTTL {
                return cached.models
            }
        }
        
        // Fetch from provider
        let models: [ModelOption]
        do {
            switch credential.provider {
            case .anthropic:
                models = try await fetchAnthropicModels(credential: credential)
            case .google:
                models = try await fetchGoogleModels(credential: credential)
            case .ollama:
                models = try await fetchOllamaModels(credential: credential)
            default:
                models = try await fetchOpenAICompatibleModels(credential: credential)
            }
            
            // Cache the results
            modelCache[credential.id] = ModelCacheEntry(models: models, fetchedAt: Date())
            return models
            
        } catch {
            // On error, return stale cache if available (better UX)
            if let cached = modelCache[credential.id] {
                return cached.models
            }
            throw error
        }
    }
    
    private func fetchOllamaModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        // Ollama uses /api/tags endpoint instead of /models
        let baseURL = credential.effectiveBaseURL.replacingOccurrences(of: "/v1", with: "")
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw LLMError.invalidCredential
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(underlying: URLError(.badServerResponse))
        }
        
        try validateResponse(httpResponse)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        
        return models.compactMap { model -> ModelOption? in
            guard let name = model["name"] as? String else { return nil }
            let modelId = model["model"] as? String ?? name
            
            return ModelOption(
                id: ModelOption.createModelId(credentialId: credential.id, modelName: modelId),
                name: name,
                provider: credential.provider,
                credentialId: credential.id
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func fetchOpenAICompatibleModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        let baseURL = credential.effectiveBaseURL
        guard let url = URL(string: "\(baseURL)/models") else {
            throw LLMError.invalidCredential
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let orgId = credential.orgId, credential.provider == .openai {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(underlying: URLError(.badServerResponse))
        }
        
        try validateResponse(httpResponse)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            return []
        }
        
        // Filter out non-chat models for OpenAI
        let excludedPatterns = ["babbage", "davinci", "embedding", "tts", "whisper", "dall-e"]
        
        return models.compactMap { model -> ModelOption? in
            guard let id = model["id"] as? String else { return nil }
            
            // Filter for OpenAI
            if credential.provider == .openai {
                let lowercased = id.lowercased()
                if excludedPatterns.contains(where: { lowercased.contains($0) }) {
                    return nil
                }
            }
            
            return ModelOption(
                id: ModelOption.createModelId(credentialId: credential.id, modelName: id),
                name: id,
                provider: credential.provider,
                credentialId: credential.id
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func fetchAnthropicModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        guard let url = URL(string: "\(credential.effectiveBaseURL)/v1/models") else {
            throw LLMError.invalidCredential
        }
        
        var request = URLRequest(url: url)
        request.setValue(credential.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(underlying: URLError(.badServerResponse))
        }
        
        try validateResponse(httpResponse)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            // Return hardcoded models if API doesn't return list
            return defaultAnthropicModels(credential: credential)
        }
        
        return models.compactMap { model -> ModelOption? in
            guard let id = model["id"] as? String,
                  id.contains("claude") else { return nil }
            
            let displayName = model["display_name"] as? String ?? id
            
            return ModelOption(
                id: ModelOption.createModelId(credentialId: credential.id, modelName: id),
                name: displayName,
                provider: credential.provider,
                credentialId: credential.id
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func defaultAnthropicModels(credential: DecryptedCredential) -> [ModelOption] {
        let models = [
            "claude-sonnet-4-20250514",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
            "claude-3-opus-20240229"
        ]
        
        return models.map { model in
            ModelOption(
                id: ModelOption.createModelId(credentialId: credential.id, modelName: model),
                name: model,
                provider: .anthropic,
                credentialId: credential.id
            )
        }
    }
    
    private func fetchGoogleModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        guard let url = URL(string: "\(credential.effectiveBaseURL)/v1beta/models?key=\(credential.apiKey)") else {
            throw LLMError.invalidCredential
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError(underlying: URLError(.badServerResponse))
        }
        
        try validateResponse(httpResponse)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        
        return models.compactMap { model -> ModelOption? in
            guard let name = model["name"] as? String,
                  let supportedMethods = model["supportedGenerationMethods"] as? [String],
                  supportedMethods.contains("generateContent") else {
                return nil
            }
            
            let modelId = name.replacingOccurrences(of: "models/", with: "")
            let displayName = model["displayName"] as? String ?? modelId
            
            return ModelOption(
                id: ModelOption.createModelId(credentialId: credential.id, modelName: modelId),
                name: displayName,
                provider: credential.provider,
                credentialId: credential.id
            )
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Streaming Chat with Private Inference Support
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential?,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        enclaveConfig: EnclaveConfig?,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // Check if this is a private inference model
        let isPrivate = isPrivateModel(model)
        let modelName: String
        if isPrivate {
            modelName = String(model.dropFirst(PRIVATE_MODEL_PREFIX.count))
        } else {
            let (_, name) = ModelOption.parseModelId(model)
            modelName = name
        }
        
        if isPrivate {
            // Private inference requires enclave config
            guard let config = enclaveConfig else {
                throw LLMError.invalidCredential
            }
            
            try await performPrivateInferenceStream(
                messages: messages,
                modelId: modelName,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                enclaveConfig: config,
                onEvent: onEvent
            )
        } else {
            // Regular inference requires credential
            guard let credential = credential else {
                throw LLMError.invalidCredential
            }
            
            try await streamChat(
                messages: messages,
                credential: credential,
                model: modelName,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        }
    }
    
    /// Performs streaming inference through the private TEE enclave
    private func performPrivateInferenceStream(
        messages: [ChatMessage],
        modelId: String,
        systemPrompt: String?,
        maxTokens: Int,
        enclaveConfig: EnclaveConfig,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // Cancel any existing stream
        currentTask?.cancel()
        
        let task = Task {
            // Get or create private inference provider
            let provider = await PrivateInferenceProviderCache.shared.getOrCreate(
                config: enclaveConfig,
                modelId: modelId
            )
            
            // Convert messages to provider format
            var sdkMessages: [[String: Any]] = []
            
            // Add system prompt if present
            if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                sdkMessages.append([
                    "role": "system",
                    "content": systemPrompt
                ])
            }
            
            // Convert chat messages
            for message in messages {
                var content = message.content
                
                // Include attachment context
                if let attachments = message.attachments, !attachments.isEmpty {
                    for attachment in attachments {
                        if let extractedText = attachment.extractedText, !extractedText.isEmpty {
                            content += "\n\n[Document: \(attachment.fileName ?? "file")]\n\(extractedText)"
                        }
                    }
                }
                
                sdkMessages.append([
                    "role": message.role.rawValue,
                    "content": content
                ])
            }
            
            // Stream from private inference provider directly
            for try await chunk in await provider.streamChat(
                modelId: modelId,
                messages: sdkMessages,
                temperature: 0.7,
                maxTokens: maxTokens
            ) {
                try Task.checkCancellation()
                
                switch chunk {
                case .textDelta(let text):
                    onEvent(.text(text))
                case .finish(_, _, _):
                    // Finish is handled by stream completion
                    break
                }
            }
            
            onEvent(.done)
        }
        
        currentTask = task
        
        do {
            try await task.value
        } catch is CancellationError {
            onEvent(.done)
            throw LLMError.cancelled
        }
    }
    
    // MARK: - Cancel
    
    func cancelStream() async {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Helpers
    
    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw LLMError.authenticationFailed
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw LLMError.rateLimited(retryAfter: retryAfter)
        default:
            throw LLMError.networkError(underlying: URLError(.badServerResponse))
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
actor MockLLMService: LLMServiceProtocol {
    
    var shouldFail = false
    var mockModels: [ModelOption] = []
    var mockResponseText = "This is a mock AI response."
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        if shouldFail {
            throw LLMError.networkError(underlying: URLError(.notConnectedToInternet))
        }
        
        // Simulate streaming with delays
        for char in mockResponseText {
            try await Task.sleep(for: .milliseconds(20))
            onEvent(.text(String(char)))
        }
        
        onEvent(.done)
    }
    
    func fetchModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        if shouldFail {
            throw LLMError.networkError(underlying: URLError(.notConnectedToInternet))
        }
        
        if !mockModels.isEmpty {
            return mockModels
        }
        
        // Return mock models based on provider
        switch credential.provider {
        case .openai:
            return [
                ModelOption(
                    id: "\(credential.id):gpt-4o",
                    name: "gpt-4o",
                    provider: .openai,
                    credentialId: credential.id
                ),
                ModelOption(
                    id: "\(credential.id):gpt-4o-mini",
                    name: "gpt-4o-mini",
                    provider: .openai,
                    credentialId: credential.id
                )
            ]
        case .anthropic:
            return [
                ModelOption(
                    id: "\(credential.id):claude-sonnet-4-20250514",
                    name: "claude-sonnet-4-20250514",
                    provider: .anthropic,
                    credentialId: credential.id
                )
            ]
        default:
            return []
        }
    }
    
    func cancelStream() async {
        // No-op for mock
    }
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential?,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        enclaveConfig: EnclaveConfig?,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // For private inference mock
        let isPrivate = isPrivateModel(model)
        
        if isPrivate {
            if shouldFail {
                throw LLMError.networkError(underlying: URLError(.notConnectedToInternet))
            }
            
            // Simulate private inference streaming
            let privateResponse = "[Private] \(mockResponseText)"
            for char in privateResponse {
                try await Task.sleep(for: .milliseconds(20))
                onEvent(.text(String(char)))
            }
            onEvent(.done)
        } else {
            // Delegate to regular streamChat
            guard let credential = credential else {
                throw LLMError.invalidCredential
            }
            try await streamChat(
                messages: messages,
                credential: credential,
                model: model,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        }
    }
}
#endif
