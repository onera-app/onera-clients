//
//  OneraApp.swift
//  Onera
//
//  Multiplatform app entry point
//

import SwiftUI
import Combine

@main
struct OneraApp: App {
    
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif
    
    @State private var coordinator: AppCoordinator
    @AppStorage("colorScheme") private var colorScheme = 0
    
    // Demo mode observation for live updates
    @State private var demoModeManager = DemoModeManager.shared
    
    #if os(macOS)
    // Window management
    @State private var windowManager = WindowManager.shared
    @State private var showSettings = false
    #endif
    
    /// Whether the app is running in UI testing mode
    private static var isUITesting: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--uitesting")
        #else
        return false
        #endif
    }
    
    init() {
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
        #if os(iOS)
        WindowGroup {
            RootView(coordinator: coordinator)
                .withDependencies(activeDependencies)
                .themed()
                .preferredColorScheme(preferredScheme)
                .transaction { transaction in
                    #if DEBUG
                    if CommandLine.arguments.contains("--disable-animations") {
                        transaction.animation = nil
                    }
                    #endif
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .demoModeActivated)) { _ in
                    handleDemoModeActivation()
                }
        }
        #elseif os(macOS)
        // Main Window
        WindowGroup {
            MacMainView(coordinator: coordinator)
                .withDependencies(activeDependencies)
                .themed()
                .preferredColorScheme(preferredScheme)
                .frame(minWidth: 800, minHeight: 500) // HIG: Allow smaller for 13" displays
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .demoModeActivated)) { _ in
                    handleDemoModeActivation()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentSize) // HIG: Let content influence sizing
        .commands {
            OneraCommands(
                showSettings: $showSettings,
                onNewChat: { windowManager.requestNewChat() },
                onNewNote: { windowManager.requestNewNote() },
                onToggleSidebar: { windowManager.toggleSidebar() },
                onSearch: { windowManager.focusSearch() }
            )
            
            CommandGroup(replacing: .help) {
                Link("Onera Help", destination: URL(string: "https://onera.chat/help")!)
                Divider()
                Button("Report a Problem...") {
                    windowManager.reportProblem()
                }
            }
        }
        
        // Settings Window
        Settings {
            MacSettingsView()
                .withDependencies(activeDependencies)
                .themed()
        }
        
        // Menu Bar Extra (Quick Chat)
        MenuBarExtra("Onera", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarView()
                .withDependencies(activeDependencies)
                .themed()
        }
        .menuBarExtraStyle(.window)
        
        // Detached Chat Window
        WindowGroup("Chat", for: String.self) { $chatId in
            if let id = chatId {
                DetachedChatView(chatId: id)
                    .withDependencies(activeDependencies)
                    .themed()
                    .frame(minWidth: 450, minHeight: 350) // HIG: Allow smaller pop-outs
            }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 650, height: 550)
        .windowResizability(.contentSize)
        
        // Detached Note Window
        WindowGroup("Note", for: String.self) { $noteId in
            if let id = noteId {
                DetachedNoteView(noteId: id)
                    .withDependencies(activeDependencies)
                    .themed()
                    .frame(minWidth: 350, minHeight: 250)
            }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 550, height: 450)
        .windowResizability(.contentSize)
        #endif
    }
    
    // MARK: - Helpers
    
    private var activeDependencies: DependencyContaining {
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
    
    private var preferredScheme: ColorScheme? {
        switch colorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        Task {
            let authService = DependencyContainer.shared.authService
            try? await authService.handleOAuthCallback(url: url)
        }
    }
    
    private func handleDemoModeActivation() {
        let newCoordinator = AppCoordinator(dependencies: DemoDependencyContainer.shared)
        coordinator = newCoordinator
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            let demoAuthService = DemoDependencyContainer.shared.demoAuthService
            do {
                try await demoAuthService.signInWithGoogle()
                await newCoordinator.handleAuthenticationSuccess()
                
                // Reconfigure WatchConnectivity with demo services so the watch gets an auth token
                #if os(iOS)
                let demoDeps = DemoDependencyContainer.shared
                iOSWatchConnectivityManager.shared.configure(
                    authService: demoDeps.authService,
                    chatRepository: demoDeps.chatRepository,
                    cryptoService: demoDeps.cryptoService,
                    secureSession: demoDeps.secureSession
                )
                await iOSWatchConnectivityManager.shared.syncToWatch()
                print("[DemoMode] Reconfigured WatchConnectivity with demo services and synced")
                #endif
            } catch {
                print("[DemoMode] Auto sign-in error: \(error)")
            }
        }
    }
}

// MARK: - iOS App Delegate

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAppearance()
        configureWatchConnectivity()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Push token: \(tokenString)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for push notifications: \(error)")
    }
    
    private func configureAppearance() {
        // Configure global appearance
    }
    
    private func configureWatchConnectivity() {
        // Configure WatchConnectivity with dependencies
        let dependencies = DependencyContainer.shared
        iOSWatchConnectivityManager.shared.configure(
            authService: dependencies.authService,
            chatRepository: dependencies.chatRepository,
            cryptoService: dependencies.cryptoService,
            secureSession: dependencies.secureSession
        )
        // Activate the session
        iOSWatchConnectivityManager.shared.activate()
        print("[WatchConnectivity] Configured and activated")
    }
}
#endif

// MARK: - macOS App Delegate

#if os(macOS)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupAppearance()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app running in menu bar
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
    
    private func setupAppearance() {
        // Any global appearance setup
    }
}

// MARK: - Window Manager (macOS)

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    private(set) var openChatWindows: Set<String> = []
    private(set) var openNoteWindows: Set<String> = []
    
    static let toggleSidebarNotification = Notification.Name("OneraToggleSidebar")
    static let focusSearchNotification = Notification.Name("OneraFocusSearch")
    static let newChatNotification = Notification.Name("OneraNewChat")
    static let newNoteNotification = Notification.Name("OneraNewNote")
    static let quickMessageNotification = Notification.Name("OneraQuickMessage")
    
    func requestNewChat() {
        NotificationCenter.default.post(name: Self.newChatNotification, object: nil)
    }
    
    func sendQuickMessage(_ message: String) {
        NotificationCenter.default.post(
            name: Self.quickMessageNotification,
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    func requestNewNote() {
        NotificationCenter.default.post(name: Self.newNoteNotification, object: nil)
    }
    
    func toggleSidebar() {
        NotificationCenter.default.post(name: Self.toggleSidebarNotification, object: nil)
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
    
    func focusSearch() {
        NotificationCenter.default.post(name: Self.focusSearchNotification, object: nil)
    }
    
    func reportProblem() {
        if let url = URL(string: "https://onera.chat/feedback") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openChatInWindow(chatId: String) {
        guard !openChatWindows.contains(chatId) else {
            focusWindow(for: chatId)
            return
        }
        openChatWindows.insert(chatId)
    }
    
    func closeChatWindow(chatId: String) {
        openChatWindows.remove(chatId)
    }
    
    func openNoteInWindow(noteId: String) {
        guard !openNoteWindows.contains(noteId) else {
            focusWindow(for: noteId)
            return
        }
        openNoteWindows.insert(noteId)
    }
    
    func closeNoteWindow(noteId: String) {
        openNoteWindows.remove(noteId)
    }
    
    private func focusWindow(for id: String) {
        for window in NSApp.windows {
            if window.title.contains(id) || window.identifier?.rawValue == id {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

private struct WindowManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: WindowManager = WindowManager.shared
}

extension EnvironmentValues {
    var windowManager: WindowManager {
        get { self[WindowManagerKey.self] }
        set { self[WindowManagerKey.self] = newValue }
    }
}
#endif
