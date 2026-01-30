//
//  WatchAppState.swift
//  Onera Watch
//
//  App state management for watchOS
//

import SwiftUI

// MARK: - Watch App State

@MainActor
@Observable
final class WatchAppState {
    
    static let shared = WatchAppState()
    
    // Connection state
    var isConnected = false
    var isAuthenticated = false
    var lastSyncDate: Date?
    
    // UI state
    var selectedChatId: String?
    var isLoading = false
    var error: String?
    
    private init() {}
    
    // MARK: - Convenience
    
    var recentChats: [WatchChatSummary] {
        WatchConnectivityManager.shared.recentChats
    }
    
    var quickReplies: [String] {
        WatchConnectivityManager.shared.quickReplies
    }
    
    var selectedModelName: String? {
        WatchConnectivityManager.shared.selectedModelName
    }
    
    // MARK: - Actions
    
    func refreshData() {
        isLoading = true
        WatchConnectivityManager.shared.requestSync()
        
        // Set a timeout for loading state
        Task {
            try? await Task.sleep(for: .seconds(5))
            isLoading = false
        }
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Environment Key

private struct WatchAppStateKey: EnvironmentKey {
    @MainActor static let defaultValue: WatchAppState = WatchAppState.shared
}

extension EnvironmentValues {
    var watchAppState: WatchAppState {
        get { self[WatchAppStateKey.self] }
        set { self[WatchAppStateKey.self] = newValue }
    }
}
