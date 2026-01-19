//
//  OneraApp.swift
//  Onera
//
//  App entry point
//

import SwiftUI

@main
struct OneraApp: App {
    // Register for push notifications, handle deep links, etc.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth callbacks and deep links
                    Task {
                        try? await AuthenticationManager.shared.handleOAuthCallback(url: url)
                    }
                }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Clerk SDK
        // Clerk.configure(publishableKey: Configuration.clerkPublishableKey)
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Handle push notification registration
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Handle push notification registration failure
    }
}
