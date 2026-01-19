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
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    func call<Input: Encodable & Sendable, Output: Decodable & Sendable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        let request = try buildRequest(procedure: procedure, input: input, token: token)
        return try await execute(request)
    }
    
    func call<Output: Decodable & Sendable>(
        procedure: String,
        token: String?
    ) async throws -> Output {
        try await call(procedure: procedure, input: EmptyInput(), token: token)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest<Input: Encodable>(
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
        
        // tRPC expects { input: ... } wrapper for mutations
        let wrapper = TRPCInputWrapper(input: input)
        request.httpBody = try encoder.encode(wrapper)
        
        return request
    }
    
    private func execute<Output: Decodable>(_ request: URLRequest) async throws -> Output {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        try validateResponse(httpResponse, data: data)
        
        do {
            let trpcResponse = try decoder.decode(TRPCResponse<Output>.self, from: data)
            return trpcResponse.result.data
        } catch let decodingError {
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

private struct TRPCInputWrapper<T: Encodable>: Encodable {
    let input: T
    
    func encode(to encoder: Encoder) throws {
        if T.self == EmptyInput.self {
            // Empty object for no-input procedures
            var container = encoder.singleValueContainer()
            try container.encode([String: String]())
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(input, forKey: .input)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case input
    }
}

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
    
    func call<Input: Encodable & Sendable, Output: Decodable & Sendable>(
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
    
    func call<Output: Decodable & Sendable>(
        procedure: String,
        token: String?
    ) async throws -> Output {
        try await call(procedure: procedure, input: EmptyInput(), token: token)
    }
    
    func setMockResponse<T>(_ response: T, for procedure: String) {
        mockResponses[procedure] = response
    }
}
#endif
