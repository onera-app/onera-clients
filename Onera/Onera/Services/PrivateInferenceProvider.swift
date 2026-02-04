//
//  PrivateInferenceProvider.swift
//  Onera
//
//  Creates a Swift AI SDK-compatible language model that communicates
//  with a TEE (Trusted Execution Environment) via Noise protocol.
//
//  Matches web's private-inference.ts for compatibility.
//

import Foundation
import os.log

// MARK: - Enclave Configuration

/// Configuration for private inference enclave
struct EnclaveConfig: Sendable, Codable {
    let id: String
    let name: String
    let endpoint: String          // HTTP endpoint for REST calls
    let wsEndpoint: String        // WebSocket endpoint for streaming
    let attestationEndpoint: String
    let allowUnverified: Bool     // Development only
    let expectedMeasurements: ExpectedMeasurements?
    
    struct ExpectedMeasurements: Sendable, Codable {
        let measurement: String?
        let hostData: String?
    }
}

// MARK: - Enclave API Types

/// Request to get an enclave assignment
struct RequestEnclaveInput: Encodable {
    let modelId: String
    let tier: String  // "shared" or "dedicated"
    let sessionId: String
}

/// Response from requesting an enclave
struct RequestEnclaveResponse: Decodable {
    let assignmentId: String
    let enclaveId: String
    let endpoint: EndpointInfo
    let wsEndpoint: String
    let attestationEndpoint: String
    let allowUnverified: Bool?
    
    struct EndpointInfo: Decodable {
        let id: String
        let host: String
        let port: Int
        let public_key: String?
        
        // Computed property for cleaner access
        var publicKey: String? { public_key }
    }
}

/// Private model info from server
struct PrivateModelInfo: Decodable, Identifiable {
    let id: String
    let name: String
    let displayName: String?
    let contextLength: Int?
    let provider: String?
    
    // Legacy field for backwards compatibility
    let enclaveId: String?
    let maxContextLength: Int?
    let capabilities: [String]?
    
    /// Returns the best display name available
    var effectiveDisplayName: String {
        displayName ?? name
    }
    
    /// Returns the context length from either field
    var effectiveContextLength: Int? {
        contextLength ?? maxContextLength
    }
}

/// Release enclave input
struct ReleaseEnclaveInput: Encodable {
    let assignmentId: String
}

// MARK: - Private Model Prefix

/// Prefix for private model IDs
nonisolated let PRIVATE_MODEL_PREFIX = "private:"

/// Check if a model ID is a private inference model
nonisolated func isPrivateModel(_ modelId: String) -> Bool {
    modelId.hasPrefix(PRIVATE_MODEL_PREFIX)
}

/// Parse model ID to extract components
/// Format: credentialId:modelName or private:modelId
nonisolated func parseModelId(_ modelId: String) -> (credentialId: String, modelName: String, isPrivate: Bool) {
    if modelId.hasPrefix(PRIVATE_MODEL_PREFIX) {
        return (
            credentialId: "",
            modelName: String(modelId.dropFirst(PRIVATE_MODEL_PREFIX.count)),
            isPrivate: true
        )
    }
    
    if let colonIndex = modelId.firstIndex(of: ":") {
        return (
            credentialId: String(modelId[..<colonIndex]),
            modelName: String(modelId[modelId.index(after: colonIndex)...]),
            isPrivate: false
        )
    }
    
    return (credentialId: "", modelName: modelId, isPrivate: false)
}

// MARK: - Private Inference Provider

/// Provider for private inference models through TEE
actor PrivateInferenceProvider {
    
    private let logger = Logger(subsystem: "chat.onera", category: "PrivateInferenceProvider")
    private let config: EnclaveConfig
    private var client: PrivateInferenceClient?
    private var isConnected = false
    
    init(config: EnclaveConfig) {
        self.config = config
    }
    
    /// Ensures connection is established with attestation and Noise handshake
    func ensureConnection() async throws {
        if isConnected, let existingClient = client, await !existingClient.isClosed {
            return
        }
        
        logger.info("Establishing private inference connection to \(self.config.name)")
        
        guard let wsURL = URL(string: config.wsEndpoint),
              let attestationURL = URL(string: config.attestationEndpoint) else {
            throw PrivateInferenceError.connectionTimeout
        }
        
        let newClient = PrivateInferenceClient()
        try await newClient.connect(endpoint: wsURL, attestationEndpoint: attestationURL)
        
        client = newClient
        isConnected = true
        
        logger.info("Private inference connection established")
    }
    
    /// Streams a chat completion through the encrypted channel
    func streamChat(
        modelId: String,
        messages: [[String: Any]],
        temperature: Double?,
        maxTokens: Int?
    ) -> AsyncThrowingStream<PrivateInferenceChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await ensureConnection()
                    
                    guard let client = client else {
                        continuation.finish(throwing: PrivateInferenceError.notConnected)
                        return
                    }
                    
                    // Build request matching server's expected format
                    let request: [String: Any] = [
                        "model": modelId,
                        "messages": messages,
                        "stream": true,
                        "temperature": temperature ?? 0.7,
                        "max_tokens": maxTokens ?? 4096
                    ]
                    
                    let requestData = try JSONSerialization.data(withJSONObject: request)
                    
                    logger.debug("Sending encrypted inference request for model: \(modelId)")
                    
                    // Stream responses
                    for try await chunk in await client.sendAndStream(request: requestData) {
                        // Parse decrypted response chunk
                        if let json = try? JSONSerialization.jsonObject(with: chunk) as? [String: Any] {
                            
                            // Handle streaming text-delta format
                            if let type = json["type"] as? String {
                                switch type {
                                case "text-delta":
                                    if let text = json["text"] as? String {
                                        continuation.yield(.textDelta(text))
                                    }
                                case "finish":
                                    let finishReason = json["finishReason"] as? String ?? "stop"
                                    let usage = json["usage"] as? [String: Any]
                                    continuation.yield(.finish(
                                        reason: finishReason,
                                        promptTokens: usage?["promptTokens"] as? Int ?? 0,
                                        completionTokens: usage?["completionTokens"] as? Int ?? 0
                                    ))
                                default:
                                    break
                                }
                            }
                            // Handle single response format (non-streaming server response)
                            else if let content = json["content"] as? String {
                                continuation.yield(.textDelta(content))
                                continuation.yield(.finish(
                                    reason: json["finish_reason"] as? String ?? "stop",
                                    promptTokens: 0,
                                    completionTokens: 0
                                ))
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    logger.error("Private inference error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Closes the connection
    func close() async {
        if let client = client {
            await client.close()
        }
        client = nil
        isConnected = false
        logger.info("Private inference connection closed")
    }
}

// MARK: - Stream Chunk Types

enum PrivateInferenceChunk: Sendable {
    case textDelta(String)
    case finish(reason: String, promptTokens: Int, completionTokens: Int)
}

// MARK: - Provider Cache

actor PrivateInferenceProviderCache {
    static let shared = PrivateInferenceProviderCache()
    
    private var providers: [String: PrivateInferenceProvider] = [:]
    
    func getOrCreate(config: EnclaveConfig, modelId: String) -> PrivateInferenceProvider {
        let cacheKey = "\(config.id):\(modelId)"
        
        if let existing = providers[cacheKey] {
            return existing
        }
        
        let provider = PrivateInferenceProvider(config: config)
        providers[cacheKey] = provider
        return provider
    }
    
    func clear() async {
        for provider in providers.values {
            await provider.close()
        }
        providers.removeAll()
    }
}

// MARK: - Public Helper Functions

/// Clear all private inference connections and cache
func clearPrivateInferenceCache() async {
    await PrivateInferenceProviderCache.shared.clear()
}
