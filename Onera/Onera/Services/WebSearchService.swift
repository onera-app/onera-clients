//
//  WebSearchService.swift
//  Onera
//
//  Web search service for injecting search context into LLM conversations.
//  All API calls are made client-side for E2EE compliance.
//

import Foundation

// MARK: - Search Result

struct WebSearchResult: Sendable {
    let title: String
    let url: String
    let snippet: String
    let content: String?
    let publishedDate: String?
    let score: Double?
}

// MARK: - Search Execution Result

struct WebSearchExecutionResult: Sendable {
    let provider: SearchProvider
    let query: String
    let results: [WebSearchResult]
    let timestamp: Date
}

// MARK: - Web Search Service Protocol

protocol WebSearchServiceProtocol: Sendable {
    func search(query: String, provider: SearchProvider, apiKey: String, maxResults: Int) async throws -> WebSearchExecutionResult
}

// MARK: - Web Search Service

final class WebSearchService: WebSearchServiceProtocol, Sendable {
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func search(query: String, provider: SearchProvider, apiKey: String, maxResults: Int = 5) async throws -> WebSearchExecutionResult {
        let results: [WebSearchResult]
        
        switch provider {
        case .tavily:
            results = try await searchTavily(query: query, apiKey: apiKey, maxResults: maxResults)
        case .brave:
            results = try await searchBrave(query: query, apiKey: apiKey, maxResults: maxResults)
        case .serper:
            results = try await searchSerper(query: query, apiKey: apiKey, maxResults: maxResults)
        case .exa:
            results = try await searchExa(query: query, apiKey: apiKey, maxResults: maxResults)
        }
        
        return WebSearchExecutionResult(
            provider: provider,
            query: query,
            results: results,
            timestamp: Date()
        )
    }
    
    // MARK: - Tavily
    
    private func searchTavily(query: String, apiKey: String, maxResults: Int) async throws -> [WebSearchResult] {
        let url = URL(string: "https://api.tavily.com/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults,
            "include_answer": false,
            "include_raw_content": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WebSearchError.providerError("Tavily search failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.map { r in
            WebSearchResult(
                title: r["title"] as? String ?? "Untitled",
                url: r["url"] as? String ?? "",
                snippet: String((r["content"] as? String ?? "").prefix(300)),
                content: r["raw_content"] as? String,
                publishedDate: nil,
                score: r["score"] as? Double
            )
        }
    }
    
    // MARK: - Brave
    
    private func searchBrave(query: String, apiKey: String, maxResults: Int) async throws -> [WebSearchResult] {
        var components = URLComponents(string: "https://api.search.brave.com/res/v1/web/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(maxResults))
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WebSearchError.providerError("Brave search failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let web = json["web"] as? [String: Any],
              let results = web["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.map { r in
            WebSearchResult(
                title: r["title"] as? String ?? "Untitled",
                url: r["url"] as? String ?? "",
                snippet: r["description"] as? String ?? "",
                content: nil,
                publishedDate: r["age"] as? String,
                score: nil
            )
        }
    }
    
    // MARK: - Serper
    
    private func searchSerper(query: String, apiKey: String, maxResults: Int) async throws -> [WebSearchResult] {
        let url = URL(string: "https://google.serper.dev/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let body: [String: Any] = [
            "q": query,
            "num": maxResults
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WebSearchError.providerError("Serper search failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["organic"] as? [[String: Any]] else {
            return []
        }
        
        return results.map { r in
            WebSearchResult(
                title: r["title"] as? String ?? "Untitled",
                url: r["link"] as? String ?? "",
                snippet: r["snippet"] as? String ?? "",
                content: nil,
                publishedDate: r["date"] as? String,
                score: nil
            )
        }
    }
    
    // MARK: - Exa
    
    private func searchExa(query: String, apiKey: String, maxResults: Int) async throws -> [WebSearchResult] {
        let url = URL(string: "https://api.exa.ai/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let body: [String: Any] = [
            "query": query,
            "numResults": maxResults,
            "useAutoprompt": true,
            "type": "neural"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WebSearchError.providerError("Exa search failed")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.map { r in
            WebSearchResult(
                title: r["title"] as? String ?? "Untitled",
                url: r["url"] as? String ?? "",
                snippet: String((r["text"] as? String ?? "").prefix(300)),
                content: r["text"] as? String,
                publishedDate: r["publishedDate"] as? String,
                score: r["score"] as? Double
            )
        }
    }
    
    // MARK: - Format Results for Context
    
    /// Formats search results as context string to inject into the LLM prompt.
    /// Matches the web app's XML-like format.
    static func formatResultsForContext(results: [WebSearchResult], query: String) -> String {
        guard !results.isEmpty else { return "" }
        
        let formatted = results.enumerated().map { index, r in
            var result = "[\(index + 1)] \(r.title)\nURL: \(r.url)"
            if !r.snippet.isEmpty {
                result += "\n\(r.snippet)"
            }
            if let content = r.content, !content.isEmpty {
                let truncated = content.count > 500 ? String(content.prefix(500)) + "..." : content
                result += "\n\nContent:\n\(truncated)"
            }
            return result
        }.joined(separator: "\n\n---\n\n")
        
        return """
        <search_results query="\(query)">
        \(formatted)
        </search_results>
        """
    }
}

// MARK: - Web Search Error

enum WebSearchError: LocalizedError {
    case noProviderConfigured
    case noApiKey(String)
    case providerError(String)
    
    var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "No search provider configured"
        case .noApiKey(let provider):
            return "No API key configured for \(provider)"
        case .providerError(let message):
            return message
        }
    }
}
