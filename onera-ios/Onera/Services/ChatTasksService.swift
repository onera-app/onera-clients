//
//  ChatTasksService.swift
//  Onera
//
//  AI task utilities for auto-generating chat titles and follow-ups
//

import Foundation

// MARK: - Protocol

protocol ChatTasksServiceProtocol: Sendable {
    func generateTitle(for messages: [ChatMessage], credential: DecryptedCredential, model: String) async -> String?
    func generateFollowUps(for messages: [ChatMessage], credential: DecryptedCredential, model: String, count: Int) async -> [String]
}

// MARK: - Implementation

actor ChatTasksService: ChatTasksServiceProtocol {
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Prompts
    
    private nonisolated static let titleGenerationPrompt = """
        ### Task:
        Generate a concise, 3-5 word title summarizing the chat conversation.
        
        ### Guidelines:
        - The title should clearly represent the main theme or subject of the conversation.
        - Keep it clear and simple, prioritize accuracy over creativity.
        - Write the title in the chat's primary language; default to English if multilingual.
        - Your response must be ONLY the JSON object, no other text.
        
        ### Output:
        JSON format: { "title": "your concise title here" }
        
        ### Examples:
        - { "title": "Stock Market Trends" }
        - { "title": "Perfect Chocolate Chip Recipe" }
        - { "title": "Python Debugging Help" }
        - { "title": "Travel Plans for Paris" }
        
        ### Chat History:
        """
    
    private nonisolated static let followUpGenerationPrompt = """
        ### Task:
        Suggest 3 relevant follow-up questions that the user might naturally ask next, based on the chat history.
        
        ### Guidelines:
        - Write all questions from the user's perspective, directed to the assistant.
        - Make questions concise, clear, and directly related to the discussed topic(s).
        - Do not repeat what was already covered in the conversation.
        - Use the conversation's primary language; default to English if multilingual.
        - Your response must be ONLY the JSON object, no other text.
        
        ### Output:
        JSON format: { "follow_ups": ["Question 1?", "Question 2?", "Question 3?"] }
        
        ### Chat History:
        """
    
    // MARK: - Title Generation
    
    func generateTitle(for messages: [ChatMessage], credential: DecryptedCredential, model: String) async -> String? {
        guard !messages.isEmpty else { return nil }
        
        let messagesText = formatMessages(messages, maxMessages: 4)
        let prompt = Self.titleGenerationPrompt + messagesText
        
        do {
            let response = try await callLLM(
                prompt: prompt,
                credential: credential,
                model: model,
                maxTokens: 200
            )
            
            return extractTitle(from: response)
        } catch {
            print("Title generation failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Follow-up Generation
    
    func generateFollowUps(for messages: [ChatMessage], credential: DecryptedCredential, model: String, count: Int = 3) async -> [String] {
        guard messages.count >= 2 else { return [] }
        
        let messagesText = formatMessages(messages, maxMessages: 6)
        let prompt = Self.followUpGenerationPrompt + messagesText
        
        do {
            let response = try await callLLM(
                prompt: prompt,
                credential: credential,
                model: model,
                maxTokens: 500
            )
            
            return extractFollowUps(from: response, count: count)
        } catch {
            print("Follow-up generation failed: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func formatMessages(_ messages: [ChatMessage], maxMessages: Int) -> String {
        let recentMessages = messages.suffix(maxMessages)
        return recentMessages.map { message in
            let content = String(message.content.prefix(500))
            return "\(message.role.rawValue): \(content)"
        }.joined(separator: "\n")
    }
    
    private func callLLM(prompt: String, credential: DecryptedCredential, model: String, maxTokens: Int) async throws -> String {
        // Use OpenAI-compatible API for all providers
        let baseURL = credential.effectiveBaseURL
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ChatTasksError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let orgId = credential.orgId, credential.provider == .openai {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        // Handle Anthropic differently
        if credential.provider == .anthropic {
            return try await callAnthropic(prompt: prompt, credential: credential, model: model, maxTokens: maxTokens)
        }
        
        // Handle Google differently
        if credential.provider == .google {
            return try await callGoogle(prompt: prompt, credential: credential, model: model, maxTokens: maxTokens)
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxTokens,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ChatTasksError.requestFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatTasksError.invalidResponse
        }
        
        return content
    }
    
    private func callAnthropic(prompt: String, credential: DecryptedCredential, model: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(credential.effectiveBaseURL)/v1/messages") else {
            throw ChatTasksError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(credential.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ChatTasksError.requestFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ChatTasksError.invalidResponse
        }
        
        return text
    }
    
    private func callGoogle(prompt: String, credential: DecryptedCredential, model: String, maxTokens: Int) async throws -> String {
        let baseURL = credential.effectiveBaseURL
        guard let url = URL(string: "\(baseURL)/v1beta/models/\(model):generateContent?key=\(credential.apiKey)") else {
            throw ChatTasksError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": maxTokens]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ChatTasksError.requestFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw ChatTasksError.invalidResponse
        }
        
        return text
    }
    
    // MARK: - Title Extraction
    
    private func extractTitle(from text: String) -> String? {
        let cleaned = stripThinkingTags(text)
        
        // Try JSON parsing first
        if let json = extractJSON(from: cleaned),
           let dict = json as? [String: Any],
           let title = dict["title"] as? String,
           !title.isEmpty {
            return String(title.prefix(100))
        }
        
        // Try to extract title from malformed JSON
        if let range = cleaned.range(of: #""title"\s*:\s*"([^"]+)"#, options: .regularExpression),
           let match = cleaned[range].range(of: #""([^"]+)$"#, options: .regularExpression) {
            return String(cleaned[match].dropFirst().dropLast())
        }
        
        // If response is short and clean, use it directly
        let trimmed = cleaned
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmed.isEmpty && trimmed.count < 100 && !trimmed.contains("\n") {
            return trimmed
        }
        
        return nil
    }
    
    // MARK: - Follow-up Extraction
    
    private func extractFollowUps(from text: String, count: Int) -> [String] {
        let cleaned = stripThinkingTags(text)
        
        // Try JSON parsing first
        if let json = extractJSON(from: cleaned),
           let dict = json as? [String: Any],
           let followUps = dict["follow_ups"] as? [String] {
            return Array(followUps.filter { !$0.isEmpty }.prefix(count))
        }
        
        // Try to extract from array in response
        if let arrayMatch = cleaned.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) {
            let arrayStr = String(cleaned[arrayMatch])
            if let data = arrayStr.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return Array(arr.filter { !$0.isEmpty }.prefix(count))
            }
        }
        
        // Fallback: extract lines that look like questions
        let lines = cleaned
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard line.count >= 10, line.count <= 200 else { return false }
                guard !line.hasPrefix("{"), !line.hasPrefix("[") else { return false }
                return line.hasSuffix("?") || line.first?.isNumber == true
            }
            .map { line in
                // Remove numbered prefixes like "1. "
                let cleaned = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        
        return Array(lines.prefix(count))
    }
    
    // MARK: - Helpers
    
    private func stripThinkingTags(_ text: String) -> String {
        var result = text
        let patterns = [
            #"<think>[\s\S]*?</think>"#,
            #"<thinking>[\s\S]*?</thinking>"#,
            #"<reflection>[\s\S]*?</reflection>"#
        ]
        
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractJSON(from text: String) -> Any? {
        // Try to find JSON object in the response
        if let range = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            let jsonStr = String(text[range])
            if let data = jsonStr.data(using: .utf8) {
                return try? JSONSerialization.jsonObject(with: data)
            }
        }
        
        // Try parsing the whole thing
        if let data = text.data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: data)
        }
        
        return nil
    }
}

// MARK: - Errors

enum ChatTasksError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .requestFailed:
            return "API request failed"
        case .invalidResponse:
            return "Invalid API response"
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
actor MockChatTasksService: ChatTasksServiceProtocol {
    
    var mockTitle: String? = "Mock Chat Title"
    var mockFollowUps: [String] = ["What else?", "Can you explain more?", "Any other tips?"]
    
    func generateTitle(for messages: [ChatMessage], credential: DecryptedCredential, model: String) async -> String? {
        mockTitle
    }
    
    func generateFollowUps(for messages: [ChatMessage], credential: DecryptedCredential, model: String, count: Int) async -> [String] {
        Array(mockFollowUps.prefix(count))
    }
}
#endif
