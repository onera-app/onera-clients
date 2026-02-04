//
//  PrivateInferenceClient.swift
//  Onera
//
//  WebSocket client for encrypted TEE inference using Noise Protocol
//  Matches Web implementation for compatibility
//

import Foundation
import Network
import os.log

/// WebSocket client for encrypted communication with TEE inference endpoints
/// Handles attestation verification, Noise Protocol handshake, and streaming inference
actor PrivateInferenceClient: Sendable {
    
    private let logger = Logger(subsystem: "chat.onera", category: "PrivateInference")
    private let attestationVerifier = AttestationVerifier()
    
    // Connection state
    private var webSocketTask: URLSessionWebSocketTask?
    private var noiseSession: NoiseSession?
    private var isConnected = false
    private var _isClosed = false
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    
    /// Whether the client is closed and cannot be reused
    var isClosed: Bool {
        _isClosed
    }
    
    // Message handling
    private var messageQueue: [Data] = []
    private var messageResolvers: [CheckedContinuation<Data, Error>] = []
    
    // MARK: - Public Interface
    
    /// Connects to a TEE endpoint with attestation verification and Noise handshake
    /// - Parameters:
    ///   - endpoint: WebSocket URL for the TEE service
    ///   - attestationEndpoint: URL to fetch attestation from
    /// - Throws: PrivateInferenceError if connection or handshake fails
    func connect(endpoint: URL, attestationEndpoint: URL) async throws {
        logger.info("Connecting to private inference endpoint: \(endpoint)")
        
        // Step 1: Verify attestation and get server public key
        let attestationResult = try await attestationVerifier.verify(attestationEndpoint: attestationEndpoint)
        
        guard attestationResult.isValid, let serverPublicKey = attestationResult.serverPublicKey else {
            throw PrivateInferenceError.attestationFailed(attestationResult.error ?? "Unknown error")
        }
        
        logger.info("Attestation verified successfully (\(attestationResult.attestationType))")
        
        // Step 2: Establish WebSocket connection
        try await establishWebSocketConnection(to: endpoint)
        
        // Step 3: Perform Noise Protocol handshake
        let handshakeResult = try await performNoiseHandshake(serverPublicKey: serverPublicKey)
        
        // Step 4: Initialize Noise session
        let session = NoiseSession()
        await session.initialize(with: handshakeResult)
        self.noiseSession = session
        
        logger.info("Private inference client connected and encrypted")
    }
    
    /// Sends a request and streams encrypted responses
    /// - Parameter request: The request data to send
    /// - Returns: AsyncThrowingStream of decrypted response chunks
    func sendAndStream(request: Data) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let session = noiseSession else {
                        continuation.finish(throwing: PrivateInferenceError.notConnected)
                        return
                    }
                    
                    // Check if session is closed (e.g., server closed connection)
                    if await session.isClosed {
                        continuation.finish(throwing: PrivateInferenceError.connectionClosed)
                        return
                    }
                    
                    // Encrypt and send request
                    let encryptedRequest = try await session.encrypt(request)
                    try await sendWebSocketMessage(encryptedRequest)
                    
                    logger.debug("Sent encrypted request (\(request.count) bytes)")
                    
                    // Stream responses
                    while isConnected {
                        do {
                            let encryptedResponse = try await receiveWebSocketMessage()
                            
                            // Empty message signals end of stream
                            if encryptedResponse.isEmpty {
                                logger.debug("Received end-of-stream signal")
                                break
                            }
                            
                            let decryptedResponse = try await session.decrypt(encryptedResponse)
                            continuation.yield(decryptedResponse)
                            
                        } catch {
                            logger.error("Error receiving response: \(error)")
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    logger.error("Error in sendAndStream: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Closes the connection and cleans up resources
    func close() {
        logger.info("Closing private inference client")
        
        isConnected = false
        _isClosed = true
        
        // Close WebSocket
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        // Clean up Noise session
        if let session = noiseSession {
            Task {
                await session.close()
            }
        }
        noiseSession = nil
        
        // Resolve any pending continuations
        connectionContinuation?.resume(throwing: PrivateInferenceError.connectionClosed)
        connectionContinuation = nil
        
        for resolver in messageResolvers {
            resolver.resume(throwing: PrivateInferenceError.connectionClosed)
        }
        messageResolvers.removeAll()
        messageQueue.removeAll()
    }
    
    // MARK: - Private Implementation
    
    /// Establishes WebSocket connection
    private func establishWebSocketConnection(to endpoint: URL) async throws {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: endpoint)
        
        // Start receiving messages
        startReceivingMessages()
        
        // Resume the task
        webSocketTask?.resume()
        
        // Wait for connection to be established
        try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            
            // Set a timeout
            Task {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if !self.isConnected {
                    continuation.resume(throwing: PrivateInferenceError.connectionTimeout)
                }
            }
        }
    }
    
    /// Performs Noise Protocol NK handshake over WebSocket
    private func performNoiseHandshake(serverPublicKey: Data) async throws -> HandshakeResult {
        return try await NoiseProtocol.performNKHandshake(
            serverPublicKey: serverPublicKey,
            send: { [weak self] message in
                guard let self = self else { throw PrivateInferenceError.connectionClosed }
                try await self.sendWebSocketMessage(message)
            },
            receive: { [weak self] in
                guard let self = self else { throw PrivateInferenceError.connectionClosed }
                return try await self.receiveWebSocketMessage()
            }
        )
    }
    
    /// Starts receiving WebSocket messages
    private func startReceivingMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        Task {
            do {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .data(let data):
                    await handleReceivedData(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        await handleReceivedData(data)
                    }
                @unknown default:
                    logger.warning("Received unknown WebSocket message type")
                }
                
                // Continue receiving if still connected
                if isConnected {
                    startReceivingMessages()
                }
                
            } catch {
                logger.error("WebSocket receive error: \(error)")
                await handleConnectionError(error)
            }
        }
    }
    
    /// Handles received data from WebSocket
    private func handleReceivedData(_ data: Data) async {
        // If this is the first message and we're waiting for connection
        if !isConnected {
            isConnected = true
            connectionContinuation?.resume()
            connectionContinuation = nil
        }
        
        // Handle message
        if let resolver = messageResolvers.first {
            messageResolvers.removeFirst()
            resolver.resume(returning: data)
        } else {
            messageQueue.append(data)
        }
    }
    
    /// Handles connection errors
    private func handleConnectionError(_ error: Error) async {
        isConnected = false
        
        if let continuation = connectionContinuation {
            connectionContinuation = nil
            continuation.resume(throwing: error)
        }
        
        for resolver in messageResolvers {
            resolver.resume(throwing: error)
        }
        messageResolvers.removeAll()
    }
    
    /// Sends a message over WebSocket
    private func sendWebSocketMessage(_ data: Data) async throws {
        guard let webSocketTask = webSocketTask else {
            throw PrivateInferenceError.notConnected
        }
        
        try await webSocketTask.send(.data(data))
    }
    
    /// Receives a message from WebSocket
    private func receiveWebSocketMessage() async throws -> Data {
        // Check if we have queued messages
        if !messageQueue.isEmpty {
            return messageQueue.removeFirst()
        }
        
        // Wait for next message
        return try await withCheckedThrowingContinuation { continuation in
            messageResolvers.append(continuation)
        }
    }
}

// MARK: - Errors

enum PrivateInferenceError: Error, LocalizedError {
    case attestationFailed(String)
    case connectionTimeout
    case connectionClosed
    case notConnected
    case handshakeFailed(String)
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .attestationFailed(let details):
            return "Attestation verification failed: \(details)"
        case .connectionTimeout:
            return "Connection timeout"
        case .connectionClosed:
            return "Connection closed"
        case .notConnected:
            return "Not connected to inference endpoint"
        case .handshakeFailed(let details):
            return "Noise handshake failed: \(details)"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
actor MockPrivateInferenceClient: Sendable {
    
    private let logger = Logger(subsystem: "chat.onera", category: "MockPrivateInference")
    private var isConnected = false
    var shouldFailConnection = false
    var shouldFailAttestation = false
    
    func connect(endpoint: URL, attestationEndpoint: URL) async throws {
        if shouldFailConnection {
            throw PrivateInferenceError.connectionTimeout
        }
        
        if shouldFailAttestation {
            throw PrivateInferenceError.attestationFailed("Mock attestation failure")
        }
        
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        isConnected = true
        logger.info("Mock private inference client connected")
    }
    
    func sendAndStream(request: Data) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard isConnected else {
                    continuation.finish(throwing: PrivateInferenceError.notConnected)
                    return
                }
                
                // Simulate streaming response
                let responses = [
                    "Mock response chunk 1".data(using: .utf8)!,
                    "Mock response chunk 2".data(using: .utf8)!,
                    "Mock response chunk 3".data(using: .utf8)!
                ]
                
                for response in responses {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    continuation.yield(response)
                }
                
                continuation.finish()
            }
        }
    }
    
    func close() {
        isConnected = false
        logger.info("Mock private inference client closed")
    }
}
#endif