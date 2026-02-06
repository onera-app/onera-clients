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
        WatchConnectivityManager.shared.activate()
    }
    
    func applicationDidBecomeActive() {
        WatchConnectivityManager.shared.requestSync()
    }
    
    func applicationWillResignActive() {
        // Save state
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
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
    @State private var demoModeActive = false
    
    var body: some View {
        if demoModeActive {
            // Demo mode: show chat list directly to avoid NavigationStack nesting crash
            WatchChatListView()
        } else if appState.isConnected && appState.isAuthenticated {
            WatchMainView()
        } else {
            WatchPlaceholderView(onDemoActivated: activateDemoMode)
        }
    }
    
    private func activateDemoMode() {
        // Populate demo data directly on the watch
        WatchConnectivityManager.shared.loadDemoData()
        
        let state = WatchAppState.shared
        state.isConnected = true
        state.isAuthenticated = true
        demoModeActive = true
    }
}

// MARK: - Placeholder View (Disconnected / Unauthenticated with Demo Activation)

struct WatchPlaceholderView: View {
    var onDemoActivated: (() -> Void)?
    @Environment(\.watchAppState) private var appState
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    
    private var isDisconnected: Bool { !appState.isConnected }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isDisconnected ? "iphone.slash" : "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(isDisconnected ? .orange : .yellow)
            
            Text(isDisconnected ? "iPhone Required" : "Sign In Required")
                .font(.headline)
            
            Text(isDisconnected ? "Open Onera on your iPhone to sync" : "Sign in to Onera on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onTapGesture {
            handleDemoTap()
        }
    }
    
    private func handleDemoTap() {
        let now = Date()
        if let last = lastTapTime, now.timeIntervalSince(last) > 1.5 {
            tapCount = 0
        }
        tapCount += 1
        lastTapTime = now
        if tapCount >= 5 {
            tapCount = 0
            WKInterfaceDevice.current().play(.success)
            onDemoActivated?()
        }
    }
}

// MARK: - Main View

struct WatchMainView: View {
    @Environment(\.watchAppState) private var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WatchChatListView()
                .tag(0)
            
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

#Preview {
    WatchRootView()
}
