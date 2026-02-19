//
//  iOSWatchConnectivityManager.swift
//  Onera
//
//  iOS-side WatchConnectivity manager for syncing with Apple Watch
//

import Foundation

#if os(iOS)
import WatchConnectivity

@MainActor
@Observable
final class iOSWatchConnectivityManager: NSObject {
    
    static let shared = iOSWatchConnectivityManager()
    
    // State
    private(set) var isPaired = false
    private(set) var isReachable = false
    private(set) var isWatchAppInstalled = false
    
    // Dependencies
    private var authService: AuthServiceProtocol?
    private var chatRepository: ChatRepositoryProtocol?
    private var cryptoService: CryptoServiceProtocol?
    private var secureSession: SecureSessionProtocol?
    
    // Session
    private var session: WCSession?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    
    func configure(
        authService: AuthServiceProtocol,
        chatRepository: ChatRepositoryProtocol,
        cryptoService: CryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.authService = authService
        self.chatRepository = chatRepository
        self.cryptoService = cryptoService
        self.secureSession = secureSession
    }
    
    // MARK: - Activation
    
    func activate() {
        guard WCSession.isSupported() else {
            print("[iOSWatchConnectivity] WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Sync to Watch
    
    func syncToWatch() async {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled else {
            print("[iOSWatchConnectivity] Watch not available for sync")
            return
        }
        
        do {
            let payload = try await buildSyncPayload()
            let data = try JSONEncoder().encode(payload)
            
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // Use applicationContext for guaranteed delivery
            try session.updateApplicationContext(dict)
            print("[iOSWatchConnectivity] Sync payload sent to watch")
            
        } catch {
            print("[iOSWatchConnectivity] Sync error: \(error)")
        }
    }
    
    // MARK: - Build Sync Payload
    
    private func buildSyncPayload() async throws -> WatchSyncPayload {
        guard let authService = authService,
              let chatRepository = chatRepository else {
            throw WatchConnectivityError.notConfigured
        }
        
        // Get auth token (don't send if not authenticated)
        var authToken: String? = nil
        if authService.isAuthenticated {
            authToken = try? await authService.getToken()
        }
        
        // Get recent chats (titles are pre-decrypted by the repository)
        var recentChats: [WatchChatSummary] = []
        if let token = authToken {
            do {
                let chats = try await chatRepository.fetchChats(token: token)
                recentChats = chats.prefix(10).map { chat in
                    WatchChatSummary(
                        id: chat.id,
                        title: chat.title,
                        lastMessage: "", // Message content requires per-chat decryption; title is sufficient for Watch
                        lastMessageDate: chat.updatedAt,
                        unreadCount: 0
                    )
                }
            } catch {
                print("[iOSWatchConnectivity] Failed to fetch chats for Watch sync: \(error)")
                // Still send the payload with empty chats so auth state syncs
            }
        }
        
        // Quick replies (from user preferences or defaults)
        let quickReplies = UserDefaults.standard.stringArray(forKey: "watchQuickReplies") ?? [
            "Yes",
            "No",
            "On my way",
            "Thanks!",
            "I'll check later"
        ]
        
        return WatchSyncPayload(
            recentChats: recentChats,
            quickReplies: quickReplies,
            selectedModelName: UserDefaults.standard.string(forKey: "selectedModelName"),
            authToken: authToken,
            syncTimestamp: Date()
        )
    }
    
    // MARK: - Handle Incoming Messages
    
    private func handleIncomingMessage(_ message: WatchOutgoingMessage) async {
        switch message.type {
        case .requestSync:
            await syncToWatch()
            
        case .newMessage:
            if let chatId = message.chatId, let content = message.content {
                await sendMessageFromWatch(chatId: chatId, content: content)
            }
            
        case .quickReply:
            if let chatId = message.chatId, let reply = message.content {
                await sendMessageFromWatch(chatId: chatId, content: reply)
            }
            
        case .openChat:
            if let chatId = message.chatId {
                await openChatOnPhone(chatId: chatId)
            }
        }
    }
    
    private func sendMessageFromWatch(chatId: String, content: String) async {
        // This would integrate with ChatViewModel to send the message
        // For now, post a notification that the main app can handle
        NotificationCenter.default.post(
            name: .watchMessageReceived,
            object: nil,
            userInfo: [
                "chatId": chatId,
                "content": content
            ]
        )
    }
    
    private func openChatOnPhone(chatId: String) async {
        NotificationCenter.default.post(
            name: .watchOpenChatRequested,
            object: nil,
            userInfo: ["chatId": chatId]
        )
    }
    
    // MARK: - Send Chat Update to Watch
    
    func sendChatUpdate(chatId: String, messages: [Message]) {
        guard let session = session, session.isReachable else {
            return
        }
        
        let watchMessages = messages.suffix(20).map { message in
            WatchMessage(
                id: message.id,
                content: message.content,
                isUser: message.isUser,
                timestamp: message.createdAt
            )
        }
        
        let response = WatchIncomingMessage(
            type: .chatUpdate,
            chatId: chatId,
            messages: watchMessages,
            error: nil
        )
        
        do {
            let data = try JSONEncoder().encode(response)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                session.sendMessage(dict, replyHandler: nil, errorHandler: { error in
                    print("[iOSWatchConnectivity] Send error: \(error)")
                })
            }
        } catch {
            print("[iOSWatchConnectivity] Encode error: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension iOSWatchConnectivityManager: WCSessionDelegate {
    
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("[iOSWatchConnectivity] Activation error: \(error)")
                return
            }
            
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
            
            if activationState == .activated && session.isPaired {
                await self.syncToWatch()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    // Receive message from Watch
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let incoming = try? JSONDecoder().decode(WatchOutgoingMessage.self, from: data) else {
            return
        }
        
        Task { @MainActor in
            await self.handleIncomingMessage(incoming)
        }
    }
    
    // Receive message with reply handler
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        self.session(session, didReceiveMessage: message)
        
        let response = WatchIncomingMessage(
            type: .syncComplete,
            chatId: nil,
            messages: nil,
            error: nil
        )
        
        if let data = try? JSONEncoder().encode(response),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            replyHandler(dict)
        } else {
            replyHandler(["status": "received"])
        }
    }
}

// MARK: - Watch Connectivity Error

enum WatchConnectivityError: Error {
    case notConfigured
    case notPaired
    case notReachable
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchMessageReceived = Notification.Name("WatchMessageReceived")
    static let watchOpenChatRequested = Notification.Name("WatchOpenChatRequested")
}

// MARK: - Shared Models (also in watchOS target)

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
    let lastMessage: String
    let lastMessageDate: Date
    let unreadCount: Int
}

/// Message sent from Watch to iPhone
/// Using nonisolated since this needs to be decoded in nonisolated WCSession delegate callbacks
nonisolated struct WatchOutgoingMessage: Codable, Sendable {
    nonisolated enum MessageType: String, Codable, Sendable {
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
/// Using nonisolated since this needs to be encoded in nonisolated WCSession delegate callbacks
nonisolated struct WatchIncomingMessage: Codable, Sendable {
    nonisolated enum ResponseType: String, Codable, Sendable {
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
nonisolated struct WatchMessage: Codable, Identifiable, Sendable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
}

#endif
