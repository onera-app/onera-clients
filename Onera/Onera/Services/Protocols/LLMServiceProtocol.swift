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
    nonisolated static func parseModelId(_ modelId: String) -> (credentialId: String, modelName: String) {
        guard let colonIndex = modelId.firstIndex(of: ":") else {
            return ("", modelId)
        }
        let credentialId = String(modelId[..<colonIndex])
        let modelName = String(modelId[modelId.index(after: colonIndex)...])
        return (credentialId, modelName)
    }
    
    /// Creates a model ID from components
    nonisolated static func createModelId(credentialId: String, modelName: String) -> String {
        "\(credentialId):\(modelName)"
    }
    
    /// Formats a model name for display
    /// Converts model IDs like "claude-3-opus-20240229" to "Claude 3 Opus"
    nonisolated static func formatModelName(_ model: String?) -> String {
        guard let model = model, !model.isEmpty else { return "Assistant" }
        
        // Handle private models (e.g., "private:qwen2.5-7b-instruct-q4_k_m.gguf")
        if model.hasPrefix("private:") {
            return formatPrivateModelName(String(model.dropFirst(8)))
        }
        
        // Handle provider:model format
        let parts = model.split(separator: ":")
        var name = parts.count > 1 ? String(parts[1]) : String(parts[0])
        
        // Remove date suffixes (e.g., -20240229, -2024-01-01)
        name = name.replacingOccurrences(of: #"-\d{8}$"#, with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: #"-\d{4}-\d{2}-\d{2}$"#, with: "", options: .regularExpression)
        
        // Handle specific model families
        let replacements: [(pattern: String, replacement: String)] = [
            // Claude models
            (#"^claude-(\d+)-(\d+)-"#, "Claude $1.$2 "),
            (#"^claude-(\d+)-"#, "Claude $1 "),
            (#"^claude-"#, "Claude "),
            // GPT models
            (#"^gpt-(\d+)o"#, "GPT-$1o"),
            (#"^gpt-(\d+)-"#, "GPT-$1 "),
            (#"^gpt-"#, "GPT-"),
            (#"^o(\d+)-"#, "o$1 "),
            // Llama models
            (#"^llama-(\d+)"#, "Llama $1"),
            (#"^llama(\d+)"#, "Llama $1"),
            // Mistral models
            (#"^mistral-"#, "Mistral "),
            (#"^mixtral-"#, "Mixtral "),
            // Gemini models
            (#"^gemini-(\d+)\.(\d+)"#, "Gemini $1.$2"),
            (#"^gemini-"#, "Gemini "),
            // Common suffixes
            (#"-turbo"#, " Turbo"),
            (#"-preview"#, " Preview"),
            (#"-latest"#, ""),
            (#"-instruct"#, " Instruct"),
            (#"-chat"#, ""),
            (#"-vision"#, " Vision"),
            (#"-mini"#, " Mini"),
            (#"-pro"#, " Pro"),
            (#"-flash"#, " Flash"),
            (#"-sonnet"#, " Sonnet"),
            (#"-opus"#, " Opus"),
            (#"-haiku"#, " Haiku"),
        ]
        
        for (pattern, replacement) in replacements {
            name = name.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        
        // Replace remaining dashes/underscores with spaces
        name = name.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
        
        // Capitalize words, preserving known acronyms
        let preservedAcronyms = ["GPT", "AI", "LLM", "API"]
        name = name.split(separator: " ")
            .map { word -> String in
                let upper = word.uppercased()
                // Preserve version numbers and known acronyms
                if word.range(of: #"^\d+(\.\d+)?[a-z]?$"#, options: .regularExpression) != nil {
                    return String(word)
                }
                if preservedAcronyms.contains(upper) {
                    return upper
                }
                if word.isEmpty { return String(word) }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
        
        // Clean up multiple spaces
        return name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }
    
    /// Formats private model name for display
    /// Converts IDs like "qwen2.5-7b-instruct-q4_k_m.gguf" to "Qwen 2.5 7B Instruct (Private)"
    private nonisolated static func formatPrivateModelName(_ id: String) -> String {
        // Remove file extension
        var name = id.replacingOccurrences(of: #"\.gguf$"#, with: "", options: [.regularExpression, .caseInsensitive])
        
        // Remove quantization suffixes (q4_k_m, q5_k_s, etc.)
        name = name.replacingOccurrences(of: #"[-_][qQ]\d+[-_][kK][-_]?[sSmMlL]$"#, with: "", options: .regularExpression)
        
        // Split into parts
        let parts = name.split(whereSeparator: { $0 == "-" || $0 == "_" })
        
        let formatted = parts
            .filter { !$0.isEmpty }
            .map { part -> String in
                let partStr = String(part)
                
                // Handle model names with versions (qwen2.5 -> Qwen 2.5, llama3.1 -> Llama 3.1)
                if let match = partStr.range(of: #"^([a-zA-Z]+)(\d+\.?\d*)$"#, options: .regularExpression) {
                    let namePart = partStr.prefix(while: { $0.isLetter })
                    let versionPart = partStr.dropFirst(namePart.count)
                    return "\(namePart.prefix(1).uppercased())\(namePart.dropFirst().lowercased()) \(versionPart)"
                }
                
                // Handle size indicators (7b -> 7B, 70b -> 70B)
                if let _ = partStr.range(of: #"^(\d+\.?\d*)[bB]$"#, options: .regularExpression) {
                    return partStr.uppercased()
                }
                
                // Title case other words
                return partStr.prefix(1).uppercased() + partStr.dropFirst().lowercased()
            }
            .joined(separator: " ")
        
        return "\(formatted) (Private)"
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
    func cancelStream() async
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
