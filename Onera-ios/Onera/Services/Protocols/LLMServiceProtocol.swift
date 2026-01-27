//
//  LLMServiceProtocol.swift
//  Onera
//
//  Protocol for LLM API service
//

import Foundation

// MARK: - Model Option

struct ModelOption: Identifiable, Equatable, Sendable {
    let id: String           // Format: credentialId:modelName
    let name: String
    let provider: LLMProvider
    let credentialId: String
    
    var displayName: String {
        name.isEmpty ? id : name
    }
    
    /// Parses a model ID into credential ID and model name
    static func parseModelId(_ modelId: String) -> (credentialId: String, modelName: String) {
        guard let colonIndex = modelId.firstIndex(of: ":") else {
            return ("", modelId)
        }
        let credentialId = String(modelId[..<colonIndex])
        let modelName = String(modelId[modelId.index(after: colonIndex)...])
        return (credentialId, modelName)
    }
    
    /// Creates a model ID from components
    static func createModelId(credentialId: String, modelName: String) -> String {
        "\(credentialId):\(modelName)"
    }
}

// MARK: - Chat Message (for LLM API)

struct ChatMessage: Codable, Sendable {
    let role: ChatRole
    let content: String
    var attachments: [ChatAttachment]?
    
    enum ChatRole: String, Codable, Sendable {
        case system
        case user
        case assistant
    }
    
    init(role: ChatRole, content: String, attachments: [ChatAttachment]? = nil) {
        self.role = role
        self.content = content
        self.attachments = attachments
    }
}

// MARK: - Chat Attachment (for multimodal)

struct ChatAttachment: Codable, Sendable {
    let type: ChatAttachmentType
    let data: String // Base64 encoded
    let mimeType: String
    let fileName: String?
    var extractedText: String? // For PDFs and text files
    
    enum ChatAttachmentType: String, Codable, Sendable {
        case image
        case document
        case text
    }
    
    init(type: ChatAttachmentType, data: String, mimeType: String, fileName: String? = nil, extractedText: String? = nil) {
        self.type = type
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
        self.extractedText = extractedText
    }
    
    /// Create from an Attachment model
    init(from attachment: Attachment, extractedText: String? = nil) {
        switch attachment.type {
        case .image:
            self.type = .image
        case .file:
            self.type = attachment.mimeType.starts(with: "application/pdf") ? .document : .text
        }
        self.data = attachment.data.base64EncodedString()
        self.mimeType = attachment.mimeType
        self.fileName = attachment.fileName
        self.extractedText = extractedText
    }
}

// MARK: - Stream Event

enum StreamEvent: Sendable {
    case text(String)
    case reasoning(String)
    case toolCall(String, String)  // name, arguments
    case error(Error)
    case done
}

// MARK: - LLM Service Protocol

protocol LLMServiceProtocol: Sendable {
    
    /// Streams a chat completion response
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - credential: The decrypted credential to use
    ///   - model: The model name to use
    ///   - systemPrompt: Optional system prompt
    ///   - maxTokens: Maximum tokens to generate
    ///   - onEvent: Callback for each stream event
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws
    
    /// Fetches available models for a credential
    /// - Parameter credential: The decrypted credential
    /// - Returns: Array of available model options
    func fetchModels(credential: DecryptedCredential) async throws -> [ModelOption]
    
    /// Cancels any ongoing stream
    func cancelStream()
}

// MARK: - LLM Error

enum LLMError: LocalizedError {
    case invalidCredential
    case networkError(underlying: Error)
    case streamError(message: String)
    case unsupportedProvider(String)
    case rateLimited(retryAfter: TimeInterval?)
    case authenticationFailed
    case modelNotFound(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid or missing API credential"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .streamError(let message):
            return "Stream error: \(message)"
        case .unsupportedProvider(let provider):
            return "Unsupported provider: \(provider)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Try again in \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .authenticationFailed:
            return "Authentication failed. Please check your API key."
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .cancelled:
            return "Request was cancelled"
        }
    }
}
