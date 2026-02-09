//
//  WebSocketSyncServiceProtocol.swift
//  Onera
//
//  Protocol for real-time WebSocket sync service
//  Listens to Socket.IO events from the server and posts
//  notifications to trigger cache invalidation (refetch).
//

import Foundation

// MARK: - Sync Event Types

/// Events received from the server via Socket.IO
enum SyncEvent: String, CaseIterable {
    case chatCreated = "chat:created"
    case chatUpdated = "chat:updated"
    case chatDeleted = "chat:deleted"
    case noteCreated = "note:created"
    case noteUpdated = "note:updated"
    case noteDeleted = "note:deleted"
    case folderCreated = "folder:created"
    case folderUpdated = "folder:updated"
    case folderDeleted = "folder:deleted"
    case credentialCreated = "credential:created"
    case credentialUpdated = "credential:updated"
    case credentialDeleted = "credential:deleted"
    case promptCreated = "prompt:created"
    case promptUpdated = "prompt:updated"
    case promptDeleted = "prompt:deleted"
}

/// Notification names posted when sync events are received.
/// Observers should refetch the relevant data when these fire.
extension Notification.Name {
    static let syncChatsInvalidated = Notification.Name("onera.sync.chats.invalidated")
    static let syncNotesInvalidated = Notification.Name("onera.sync.notes.invalidated")
    static let syncFoldersInvalidated = Notification.Name("onera.sync.folders.invalidated")
    static let syncCredentialsInvalidated = Notification.Name("onera.sync.credentials.invalidated")
    static let syncPromptsInvalidated = Notification.Name("onera.sync.prompts.invalidated")
}

// MARK: - Protocol

@MainActor
protocol WebSocketSyncServiceProtocol: AnyObject, Sendable {
    
    /// Whether the WebSocket is currently connected
    var isConnected: Bool { get }
    
    /// Connect to the WebSocket server with the given auth token
    func connect(token: String)
    
    /// Disconnect from the WebSocket server
    func disconnect()
}
