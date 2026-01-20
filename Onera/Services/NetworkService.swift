//
//  NetworkService.swift
//  Onera
//
//  tRPC-compatible network service implementation
//

import Foundation

final class NetworkService: NetworkServiceProtocol, @unchecked Sendable {
    
    private let session: URLSession
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(
        session: URLSession = .shared,
        baseURL: URL = Configuration.apiBaseURL
    ) {
        self.session = session
        self.baseURL = baseURL.appendingPathComponent(Configuration.trpcPath)
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        // Handle both millisecond timestamps (number) and ISO8601 strings
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Try to decode as milliseconds timestamp first (server returns Int64 timestamps)
            if let milliseconds = try? container.decode(Int64.self) {
                return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
            }
            
            // Try to decode as Double (some APIs return seconds as double)
            if let seconds = try? container.decode(Double.self) {
                // If it looks like milliseconds (> year 2001 in ms), convert
                if seconds > 1_000_000_000_000 {
                    return Date(timeIntervalSince1970: seconds / 1000)
                }
                return Date(timeIntervalSince1970: seconds)
            }
            
            // Fall back to ISO8601 string
            let string = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) {
                return date
            }
            
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(string)"
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Call a tRPC mutation (POST with input in body)
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        let request = try buildMutationRequest(procedure: procedure, input: input, token: token)
        return try await execute(request)
    }
    
    /// Call a tRPC query with no input (GET)
    func call<Output: Decodable>(
        procedure: String,
        token: String?
    ) async throws -> Output {
        let request = try buildQueryRequest(procedure: procedure, input: Optional<EmptyInput>.none, token: token)
        return try await execute(request)
    }
    
    /// Call a tRPC query with input (GET with input in query params)
    func query<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        let request = try buildQueryRequest(procedure: procedure, input: input, token: token)
        return try await execute(request)
    }
    
    // MARK: - Private Methods
    
    /// Build a tRPC mutation request (POST)
    private func buildMutationRequest<Input: Encodable>(
        procedure: String,
        input: Input,
        token: String?
    ) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(procedure)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // tRPC mutations expect JSON body
        request.httpBody = try encoder.encode(input)
        
        return request
    }
    
    /// Build a tRPC query request (GET)
    private func buildQueryRequest<Input: Encodable>(
        procedure: String,
        input: Input?,
        token: String?
    ) throws -> URLRequest {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(procedure), resolvingAgainstBaseURL: true)!
        
        // Add input as query parameter if provided
        if let input = input {
            let inputData = try encoder.encode(input)
            if let inputString = String(data: inputData, encoding: .utf8), inputString != "{}" {
                urlComponents.queryItems = [URLQueryItem(name: "input", value: inputString)]
            }
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func execute<Output: Decodable>(_ request: URLRequest) async throws -> Output {
        print("[NetworkService] Request: \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("[NetworkService] Response: \(httpResponse.statusCode)")
        
        do {
            try validateResponse(httpResponse, data: data)
        } catch {
            print("[NetworkService] Validation error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[NetworkService] Response body: \(responseString.prefix(500))")
            }
            throw error
        }
        
        do {
            let trpcResponse = try decoder.decode(TRPCResponse<Output>.self, from: data)
            return trpcResponse.result.data
        } catch let decodingError {
            print("[NetworkService] Decoding error: \(decodingError)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[NetworkService] Response body: \(responseString.prefix(500))")
            }
            throw NetworkError.decodingFailed(underlying: decodingError)
        }
    }
    
    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 405:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(statusCode: 405, message: message ?? "Method not allowed")
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 500..<600:
            throw NetworkError.serverError(statusCode: response.statusCode)
        default:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(statusCode: response.statusCode, message: message)
        }
    }
}

// MARK: - tRPC Request/Response Types

private struct EmptyInput: Encodable {}

private struct TRPCResponse<T: Decodable>: Decodable {
    let result: TRPCResult<T>
}

private struct TRPCResult<T: Decodable>: Decodable {
    let data: T
}

// MARK: - Mock Implementation

#if DEBUG
final class MockNetworkService: NetworkServiceProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var mockResponses: [String: Any] = [:]
    
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        if shouldFail {
            throw NetworkError.serverError(statusCode: 500)
        }
        
        if let response = mockResponses[procedure] as? Output {
            return response
        }
        
        throw NetworkError.notFound
    }
    
    func call<Output: Decodable>(
        procedure: String,
        token: String?
    ) async throws -> Output {
        if shouldFail {
            throw NetworkError.serverError(statusCode: 500)
        }
        
        if let response = mockResponses[procedure] as? Output {
            return response
        }
        
        throw NetworkError.notFound
    }
    
    func query<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        try await call(procedure: procedure, token: token)
    }
    
    func setMockResponse<T>(_ response: T, for procedure: String) {
        mockResponses[procedure] = response
    }
}
#endif
