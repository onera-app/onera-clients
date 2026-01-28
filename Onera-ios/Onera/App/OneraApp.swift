//
//  OneraApp.swift
//  Onera
//
//  App entry point
//

import SwiftUI
import Clerk
import Combine

@main
struct OneraApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var clerk = Clerk.shared
    @State private var coordinator: AppCoordinator
    @AppStorage("colorScheme") private var colorScheme = 0
    
    // Demo mode observation for live updates
    @State private var demoModeManager = DemoModeManager.shared
    
    /// Whether the app is running in UI testing mode
    private static var isUITesting: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--uitesting")
        #else
        return false
        #endif
    }
    
    init() {
        // Initialize the coordinator with the correct dependencies
        #if DEBUG
        if Self.isUITesting {
            _coordinator = State(initialValue: AppCoordinator(dependencies: TestDependencyContainer.shared))
        } else {
            _coordinator = State(initialValue: AppCoordinator())
        }
        #else
        _coordinator = State(initialValue: AppCoordinator())
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .environment(\.clerk, clerk)
                .withDependencies(activeDependencies)
                .themed()
                .preferredColorScheme(preferredScheme)
                .transaction { transaction in
                    // Disable animations in UI testing mode for more reliable tests
                    #if DEBUG
                    if CommandLine.arguments.contains("--disable-animations") {
                        transaction.animation = nil
                    }
                    #endif
                }
                .task {
                    // Skip Clerk configuration in UI testing and demo modes
                    if Self.isUITesting {
                        #if DEBUG
                        print("[UITesting] Running in UI testing mode")
                        #endif
                        return
                    }
                    
                    // Configure and load Clerk on app launch
                    clerk.configure(publishableKey: Configuration.clerkPublishableKey)
                    try? await clerk.load()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                // Listen for demo mode activation notification
                .onReceive(NotificationCenter.default.publisher(for: .demoModeActivated)) { _ in
                    handleDemoModeActivation()
                }
        }
    }
    
    /// Returns the active dependency container based on current mode
    private var activeDependencies: DependencyContaining {
        // Check demo mode first (can be activated at runtime)
        if demoModeManager.isActive {
            return DemoDependencyContainer.shared
        }
        
        #if DEBUG
        if Self.isUITesting {
            return TestDependencyContainer.shared
        }
        #endif
        return DependencyContainer.shared
    }
    
    /// Returns the preferred color scheme based on user settings
    /// - 0: System (nil - follows device setting)
    /// - 1: Light
    /// - 2: Dark
    private var preferredScheme: ColorScheme? {
        switch colorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle OAuth callbacks via Clerk
        Task {
            // Notify our auth service to update state
            let authService = DependencyContainer.shared.authService
            try? await authService.handleOAuthCallback(url: url)
        }
    }
    
    private func handleDemoModeActivation() {
        print("[DemoMode] Activation notification received")
        
        // Create new coordinator with demo dependencies
        let newCoordinator = AppCoordinator(dependencies: DemoDependencyContainer.shared)
        coordinator = newCoordinator
        print("[DemoMode] Coordinator reinitialized with demo dependencies")
        
        // Perform auto sign-in and navigation
        Task { @MainActor in
            // Brief delay for UI to update
            try? await Task.sleep(for: .milliseconds(300))
            
            // Sign in with demo service
            let demoAuthService = DemoDependencyContainer.shared.demoAuthService
            do {
                try await demoAuthService.signInWithGoogle()
                print("[DemoMode] Auto sign-in completed, navigating...")
                // Tell coordinator to handle the auth success
                await newCoordinator.handleAuthenticationSuccess()
            } catch {
                print("[DemoMode] Auto sign-in error: \(error)")
            }
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
}
