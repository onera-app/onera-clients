//
//  WatchConnectivityManager.swift
//  Onera Watch
//
//  Handles communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity

// MARK: - Sync Payload Models

/// Data synced from iPhone to Watch
struct WatchSyncPayload: Codable {
    let recentChats: [WatchChatSummary]
    let quickReplies: [String]
    let selectedModelName: String?
    let authToken: String?
    let syncTimestamp: Date
}

/// Simplified chat summary for Watch
struct WatchChatSummary: Codable, Identifiable {
    let id: String
    let title: String
    let lastMessage: String          // Pre-decrypted on iPhone
    let lastMessageDate: Date
    let unreadCount: Int
}

/// Message sent from Watch to iPhone
struct WatchOutgoingMessage: Codable {
    enum MessageType: String, Codable {
        case newMessage
        case quickReply
        case requestSync
        case openChat
    }
    
    let type: MessageType
    let chatId: String?
    let content: String?
    let timestamp: Date
}

/// Response from iPhone to Watch
struct WatchIncomingMessage: Codable {
    enum ResponseType: String, Codable {
        case chatUpdate
        case syncComplete
        case error
    }
    
    let type: ResponseType
    let chatId: String?
    let messages: [WatchMessage]?
    let error: String?
}

/// Simplified message for Watch display
struct WatchMessage: Codable, Identifiable {
    let id: String
    let content: String              // Pre-decrypted
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Watch Connectivity Manager

@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    
    static let shared = WatchConnectivityManager()
    
    // State
    private(set) var isReachable = false
    private(set) var lastSyncDate: Date?
    private(set) var pendingMessages: [WatchOutgoingMessage] = []
    
    // Synced data
    private(set) var recentChats: [WatchChatSummary] = []
    private(set) var quickReplies: [String] = [
        "Yes",
        "No",
        "On my way",
        "Thanks!",
        "I'll check later"
    ]
    private(set) var selectedModelName: String?
    private(set) var authToken: String?
    
    // Session
    private var session: WCSession?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Activation
    
    func activate() {
        guard WCSession.isSupported() else {
            print("[WatchConnectivity] WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Sync
    
    func requestSync() {
        sendMessage(WatchOutgoingMessage(
            type: .requestSync,
            chatId: nil,
            content: nil,
            timestamp: Date()
        ))
    }
    
    // MARK: - Send Message
    
    func sendChatMessage(chatId: String, content: String) {
        let message = WatchOutgoingMessage(
            type: .newMessage,
            chatId: chatId,
            content: content,
            timestamp: Date()
        )
        sendMessage(message)
    }
    
    func sendQuickReply(chatId: String, reply: String) {
        let message = WatchOutgoingMessage(
            type: .quickReply,
            chatId: chatId,
            content: reply,
            timestamp: Date()
        )
        sendMessage(message)
    }
    
    func openChatOnPhone(chatId: String) {
        let message = WatchOutgoingMessage(
            type: .openChat,
            chatId: chatId,
            content: nil,
            timestamp: Date()
        )
        sendMessage(message)
    }
    
    // MARK: - Private Methods
    
    private func sendMessage(_ message: WatchOutgoingMessage) {
        guard let session = session else {
            pendingMessages.append(message)
            return
        }
        
        guard session.isReachable else {
            // Queue message for later
            pendingMessages.append(message)
            // Try to send via transferUserInfo for guaranteed delivery
            if let data = try? JSONEncoder().encode(message),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                session.transferUserInfo(dict)
            }
            return
        }
        
        // Send immediately
        do {
            let data = try JSONEncoder().encode(message)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                session.sendMessage(dict, replyHandler: { reply in
                    Task { @MainActor in
                        self.handleReply(reply)
                    }
                }, errorHandler: { error in
                    print("[WatchConnectivity] Send error: \(error)")
                    Task { @MainActor in
                        self.pendingMessages.append(message)
                    }
                })
            }
        } catch {
            print("[WatchConnectivity] Encode error: \(error)")
        }
    }
    
    private func handleReply(_ reply: [String: Any]) {
        // Handle immediate reply from iPhone
        guard let data = try? JSONSerialization.data(withJSONObject: reply),
              let response = try? JSONDecoder().decode(WatchIncomingMessage.self, from: data) else {
            return
        }
        
        processIncomingMessage(response)
    }
    
    private func processIncomingMessage(_ message: WatchIncomingMessage) {
        switch message.type {
        case .chatUpdate:
            // Update chat messages
            NotificationCenter.default.post(
                name: .watchChatUpdated,
                object: nil,
                userInfo: [
                    "chatId": message.chatId ?? "",
                    "messages": message.messages ?? []
                ]
            )
            
        case .syncComplete:
            lastSyncDate = Date()
            
        case .error:
            print("[WatchConnectivity] Error from iPhone: \(message.error ?? "Unknown")")
        }
    }
    
    private func processSyncPayload(_ payload: WatchSyncPayload) {
        recentChats = payload.recentChats
        quickReplies = payload.quickReplies
        selectedModelName = payload.selectedModelName
        authToken = payload.authToken
        lastSyncDate = payload.syncTimestamp
        
        // Notify state change
        WatchAppState.shared.isAuthenticated = authToken != nil
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .watchDataSynced, object: nil)
    }
    
    private func sendPendingMessages() {
        let messages = pendingMessages
        pendingMessages.removeAll()
        
        for message in messages {
            sendMessage(message)
        }
    }
    
    // MARK: - Background Task
    
    func handleBackgroundTask() {
        // Process any pending data
        if let context = session?.receivedApplicationContext,
           let data = try? JSONSerialization.data(withJSONObject: context),
           let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) {
            Task { @MainActor in
                self.processSyncPayload(payload)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("[WatchConnectivity] Activation error: \(error)")
                return
            }
            
            self.isReachable = session.isReachable
            WatchAppState.shared.isConnected = activationState == .activated
            
            if activationState == .activated {
                self.requestSync()
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            
            if session.isReachable {
                self.sendPendingMessages()
            }
        }
    }
    
    // Receive message from iPhone
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let incoming = try? JSONDecoder().decode(WatchIncomingMessage.self, from: data) else {
            return
        }
        
        Task { @MainActor in
            self.processIncomingMessage(incoming)
        }
    }
    
    // Receive message with reply handler
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        self.session(session, didReceiveMessage: message)
        replyHandler(["status": "received"])
    }
    
    // Receive application context (sync data)
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = try? JSONSerialization.data(withJSONObject: applicationContext),
              let payload = try? JSONDecoder().decode(WatchSyncPayload.self, from: data) else {
            return
        }
        
        Task { @MainActor in
            self.processSyncPayload(payload)
        }
    }
    
    // Receive user info transfer
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        // Handle user info transfers (guaranteed delivery)
        self.session(session, didReceiveApplicationContext: userInfo)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchDataSynced = Notification.Name("WatchDataSynced")
    static let watchChatUpdated = Notification.Name("WatchChatUpdated")
}
