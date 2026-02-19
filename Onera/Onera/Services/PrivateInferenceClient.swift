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

// MARK: - WebSocket Delegate

/// Delegate to handle WebSocket connection events
/// Required because URLSessionWebSocketTask.resume() is async and doesn't block until connected
private final class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate, Sendable {
    private let onOpen: @Sendable () -> Void
    private let onClose: @Sendable (URLSessionWebSocketTask.CloseCode, Data?) -> Void
    private let onError: @Sendable (Error) -> Void
    
    init(
        onOpen: @escaping @Sendable () -> Void,
        onClose: @escaping @Sendable (URLSessionWebSocketTask.CloseCode, Data?) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        self.onError = onError
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen()
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose(closeCode, reason)
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            onError(error)
        }
    }
}

/// WebSocket client for encrypted communication with TEE inference endpoints
/// Handles attestation verification, Noise Protocol handshake, and streaming inference
actor PrivateInferenceClient: Sendable {
    
    private let logger = Logger(subsystem: "chat.onera", category: "PrivateInference")
    private let attestationVerifier = AttestationVerifier()
    
    // Connection state
    private var urlSession: URLSession?
    private var webSocketDelegate: WebSocketDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var noiseSession: NoiseSession?
    private var isConnected = false
    private var _isClosed = false
    
    // Connection open/error continuations
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
                            logger.debug("Waiting for encrypted response...")
                            let encryptedResponse = try await receiveWebSocketMessage()
                            logger.debug("Received encrypted response: \(encryptedResponse.count) bytes")
                            
                            // Empty message signals end of stream (server-side signal)
                            if encryptedResponse.isEmpty {
                                logger.info("Received end-of-stream signal (empty message), breaking receive loop")
                                break
                            }
                            
                            let decryptedResponse = try await session.decrypt(encryptedResponse)
                            logger.debug("Decrypted response: \(decryptedResponse.count) bytes")
                            continuation.yield(decryptedResponse)
                            
                            // Check response content to detect end of stream
                            // This handles servers that don't send empty end-of-stream message
                            if let json = try? JSONSerialization.jsonObject(with: decryptedResponse) as? [String: Any] {
                                // Streaming finish signal: {"type": "finish", ...}
                                if let type = json["type"] as? String, type == "finish" {
                                    logger.info("Received finish signal in response, breaking receive loop")
                                    break
                                }
                                // Streaming error signal: {"type": "error", ...}
                                if let type = json["type"] as? String, type == "error" {
                                    logger.info("Received error signal in response, breaking receive loop")
                                    break
                                }
                                // Non-streaming response: {"content": "...", ...}
                                if json["content"] != nil {
                                    logger.info("Received non-streaming response with content, breaking receive loop")
                                    break
                                }
                            }
                            
                        } catch {
                            logger.error("Error receiving response: \(error)")
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    logger.info("Stream receive loop ended, finishing continuation")
                    
                    continuation.finish()
                    
                } catch {
                    logger.error("Error in sendAndStream: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Closes the connection and cleans up resources
    func close() async {
        logger.info("Closing private inference client")
        
        isConnected = false
        _isClosed = true
        
        // Cancel any pending connection continuation
        connectionContinuation?.resume(throwing: PrivateInferenceError.connectionClosed)
        connectionContinuation = nil
        
        // Close WebSocket
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        // Invalidate URLSession
        urlSession?.invalidateAndCancel()
        urlSession = nil
        webSocketDelegate = nil
        
        // Clean up Noise session
        if let session = noiseSession {
            await session.close()
        }
        noiseSession = nil
        
        // Resolve any pending message continuations
        for resolver in messageResolvers {
            resolver.resume(throwing: PrivateInferenceError.connectionClosed)
        }
        messageResolvers.removeAll()
        messageQueue.removeAll()
    }
    
    // MARK: - Private Implementation
    
    /// Establishes WebSocket connection with proper open/close/error handling
    /// Uses URLSessionWebSocketDelegate to wait for actual connection before proceeding
    private func establishWebSocketConnection(to endpoint: URL) async throws {
        logger.debug("Connecting WebSocket to \(endpoint)...")
        
        // Create delegate to handle connection events
        // We need to capture self weakly and handle actor isolation
        let delegate = WebSocketDelegate(
            onOpen: { [weak self] in
                Task { [weak self] in
                    await self?.handleConnectionOpened()
                }
            },
            onClose: { [weak self] code, reason in
                Task { [weak self] in
                    await self?.handleConnectionClosed(code: code, reason: reason)
                }
            },
            onError: { [weak self] error in
                Task { [weak self] in
                    await self?.handleConnectionError(error)
                }
            }
        )
        self.webSocketDelegate = delegate
        
        // Create session with delegate
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.urlSession = session
        
        // Create WebSocket task
        webSocketTask = session.webSocketTask(with: endpoint)
        
        // Wait for connection to open with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Wait for connection open callback
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    Task { [weak self] in
                        await self?.setConnectionContinuation(continuation)
                    }
                }
            }
            
            // Task 2: Timeout after 30 seconds
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                throw PrivateInferenceError.connectionTimeout
            }
            
            // Start the connection AFTER setting up the continuation
            // Small delay to ensure continuation is set
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            webSocketTask?.resume()
            
            // Wait for either connection or timeout
            do {
                try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
        
        // Start the continuous receive loop
        startReceivingMessages()
        
        // Mark as connected
        isConnected = true
        
        logger.debug("WebSocket connection established successfully")
    }
    
    /// Sets the connection continuation for async waiting
    private func setConnectionContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        self.connectionContinuation = continuation
    }
    
    /// Called when WebSocket connection opens
    private func handleConnectionOpened() {
        logger.debug("WebSocket didOpen callback received")
        connectionContinuation?.resume()
        connectionContinuation = nil
    }
    
    /// Called when WebSocket connection closes
    private func handleConnectionClosed(code: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.debug("WebSocket closed with code: \(code.rawValue)")
        isConnected = false
        _isClosed = true
        
        // If we're still waiting for connection, fail it
        connectionContinuation?.resume(throwing: PrivateInferenceError.connectionClosed)
        connectionContinuation = nil
        
        // Fail any pending message receivers
        for resolver in messageResolvers {
            resolver.resume(throwing: PrivateInferenceError.connectionClosed)
        }
        messageResolvers.removeAll()
    }
    
    /// Performs Noise Protocol NK handshake over WebSocket
    /// Uses direct WebSocket receive instead of the message queue for handshake messages
    /// This avoids race conditions with the background receive loop
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
    
    /// Starts the continuous receive loop for WebSocket messages
    /// Messages are either resolved immediately if a caller is waiting, or queued
    private func startReceivingMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        Task { [weak self] in
            guard let self = self else { return }
            
            self.logger.debug("Starting WebSocket receive loop")
            
            while await self.isConnected {
                do {
                    let message = try await webSocketTask.receive()
                    
                    switch message {
                    case .data(let data):
                        self.logger.debug("WebSocket raw receive: .data(\(data.count) bytes)")
                        await self.handleReceivedData(data)
                    case .string(let string):
                        self.logger.debug("WebSocket raw receive: .string(\(string.count) chars)")
                        if let data = string.data(using: .utf8) {
                            await self.handleReceivedData(data)
                        }
                    @unknown default:
                        self.logger.warning("Received unknown WebSocket message type")
                    }
                    
                } catch {
                    self.logger.error("WebSocket receive error: \(error)")
                    await self.handleConnectionError(error)
                    break
                }
            }
            self.logger.debug("WebSocket receive loop ended")
        }
    }
    
    /// Handles received data from WebSocket
    private func handleReceivedData(_ data: Data) async {
        logger.debug("WebSocket received data: \(data.count) bytes, resolvers waiting: \(self.messageResolvers.count)")
        // Handle message
        if let resolver = messageResolvers.first {
            messageResolvers.removeFirst()
            resolver.resume(returning: data)
        } else {
            messageQueue.append(data)
            logger.debug("Queued message, queue size: \(self.messageQueue.count)")
        }
    }
    
    /// Handles connection errors from delegate or receive loop
    private func handleConnectionError(_ error: Error) {
        logger.error("Connection error: \(error)")
        isConnected = false
        _isClosed = true
        
        // If we're still waiting for connection, fail it
        connectionContinuation?.resume(throwing: error)
        connectionContinuation = nil
        
        // Fail any pending message receivers
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
    
    func close() async {
        isConnected = false
        logger.info("Mock private inference client closed")
    }
}
#endif