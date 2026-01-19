//
//  OneraApp.swift
//  Onera
//
//  App entry point
//

import SwiftUI

@main
struct OneraApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle OAuth callbacks and other deep links
        Task {
            let authService = DependencyContainer.shared.authService
            try? await authService.handleOAuthCallback(url: url)
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAppearance()
        configureServices()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Register device token with backend
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Push token: \(tokenString)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for push notifications: \(error)")
    }
    
    // MARK: - Private
    
    private func configureAppearance() {
        // Configure global appearance
    }
    
    private func configureServices() {
        // Initialize Clerk SDK
        // Clerk.configure(publishableKey: Configuration.clerkPublishableKey)
    }
}
