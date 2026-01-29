//
//  OneraWatchApp.swift
//  Onera Watch
//
//  watchOS companion app entry point
//

import SwiftUI
import WatchKit

@main
struct OneraWatchApp: App {
    
    @State private var appState = WatchAppState.shared
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    
    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(\.watchAppState, appState)
        }
    }
}

// MARK: - App Delegate

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    func applicationDidFinishLaunching() {
        // Start WatchConnectivity
        WatchConnectivityManager.shared.activate()
    }
    
    func applicationDidBecomeActive() {
        // Request sync from iPhone
        WatchConnectivityManager.shared.requestSync()
    }
    
    func applicationWillResignActive() {
        // Save state
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Handle WatchConnectivity background task
                WatchConnectivityManager.shared.handleBackgroundTask()
                connectivityTask.setTaskCompletedWithSnapshot(false)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )
                
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

// MARK: - Root View

struct WatchRootView: View {
    @Environment(\.watchAppState) private var appState
    
    var body: some View {
        Group {
            if appState.isConnected && appState.isAuthenticated {
                WatchMainView()
            } else if !appState.isConnected {
                WatchDisconnectedView()
            } else {
                WatchUnauthenticatedView()
            }
        }
    }
}

// MARK: - Main View

struct WatchMainView: View {
    @Environment(\.watchAppState) private var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Recent Chats
            WatchChatListView()
                .tag(0)
            
            // Quick Reply
            WatchQuickReplyView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Disconnected View

struct WatchDisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("iPhone Required")
                .font(.headline)
            
            Text("Open Onera on your iPhone to sync")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Unauthenticated View

struct WatchUnauthenticatedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            
            Text("Sign In Required")
                .font(.headline)
            
            Text("Sign in to Onera on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    WatchRootView()
}
