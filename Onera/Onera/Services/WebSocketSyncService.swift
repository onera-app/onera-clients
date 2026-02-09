//
//  WebSocketSyncService.swift
//  Onera
//
//  Real-time sync via Socket.IO.
//  Connects to the server, listens for entity events, and posts
//  notifications so view models can refetch their data.
//
//  Strategy mirrors the web client: one-way sync (server→client),
//  ignore encrypted payloads, just invalidate caches.
//

import Foundation
import SocketIO
import os.log

// MARK: - WebSocket Sync Service

@MainActor
final class WebSocketSyncService: WebSocketSyncServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private(set) var isConnected = false
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    private let logger = Logger(subsystem: "chat.onera", category: "WebSocketSync")
    
    // Reconnection state
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let baseReconnectDelay: TimeInterval = 1.0
    
    // MARK: - Connect
    
    func connect(token: String) {
        // Tear down any existing connection
        disconnect()
        
        let url = Configuration.wsBaseURL
        logger.info("Connecting to WebSocket at \(url.absoluteString)")
        
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(false), // Allow polling fallback like web client
                .connectParams(["token": token]),
                .extraHeaders(["Authorization": "Bearer \(token)"])
            ]
        )
        
        socket = manager?.defaultSocket
        
        setupEventHandlers()
        socket?.connect()
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0
        
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        manager?.disconnect()
        manager = nil
        isConnected = false
    }
    
    // MARK: - Event Handlers
    
    private func setupEventHandlers() {
        guard let socket else { return }
        
        // Connection lifecycle
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = true
                self.reconnectAttempts = 0
                self.logger.info("WebSocket connected")
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = false
                self.logger.info("WebSocket disconnected")
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, _ in
            Task { @MainActor in
                guard let self else { return }
                self.logger.error("WebSocket error: \(String(describing: data))")
            }
        }
        
        socket.on(clientEvent: .reconnectAttempt) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.reconnectAttempts += 1
                self.logger.info("WebSocket reconnect attempt \(self.reconnectAttempts)")
            }
        }
        
        // Entity events — mirrors web client's useRealtimeUpdates.ts
        // Chat events
        for event in [SyncEvent.chatCreated, .chatUpdated, .chatDeleted] {
            socket.on(event.rawValue) { [weak self] _, _ in
                Task { @MainActor in
                    self?.logger.debug("Sync event: \(event.rawValue)")
                    NotificationCenter.default.post(name: .syncChatsInvalidated, object: nil)
                }
            }
        }
        
        // Note events
        for event in [SyncEvent.noteCreated, .noteUpdated, .noteDeleted] {
            socket.on(event.rawValue) { [weak self] _, _ in
                Task { @MainActor in
                    self?.logger.debug("Sync event: \(event.rawValue)")
                    NotificationCenter.default.post(name: .syncNotesInvalidated, object: nil)
                }
            }
        }
        
        // Folder events
        for event in [SyncEvent.folderCreated, .folderUpdated, .folderDeleted] {
            socket.on(event.rawValue) { [weak self] _, _ in
                Task { @MainActor in
                    self?.logger.debug("Sync event: \(event.rawValue)")
                    NotificationCenter.default.post(name: .syncFoldersInvalidated, object: nil)
                }
            }
        }
        
        // Credential events
        for event in [SyncEvent.credentialCreated, .credentialUpdated, .credentialDeleted] {
            socket.on(event.rawValue) { [weak self] _, _ in
                Task { @MainActor in
                    self?.logger.debug("Sync event: \(event.rawValue)")
                    NotificationCenter.default.post(name: .syncCredentialsInvalidated, object: nil)
                }
            }
        }
        
        // Prompt events
        for event in [SyncEvent.promptCreated, .promptUpdated, .promptDeleted] {
            socket.on(event.rawValue) { [weak self] _, _ in
                Task { @MainActor in
                    self?.logger.debug("Sync event: \(event.rawValue)")
                    NotificationCenter.default.post(name: .syncPromptsInvalidated, object: nil)
                }
            }
        }
    }
}
