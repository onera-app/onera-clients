//
//  OneraApp.swift
//  Onera (macOS)
//
//  macOS app entry point with menu bar and multi-window support
//

import SwiftUI
import Clerk

@main
struct OneraApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var clerk = Clerk.shared
    @State private var coordinator: AppCoordinator
    @AppStorage("colorScheme") private var colorScheme = 0
    
    // Window management
    @State private var windowManager = WindowManager.shared
    
    // Commands state
    @State private var showSettings = false
    
    init() {
        _coordinator = State(initialValue: AppCoordinator())
    }
    
    var body: some Scene {
        // Main Window
        WindowGroup {
            MacMainView(coordinator: coordinator)
                .environment(\.clerk, clerk)
                .withDependencies(DependencyContainer.shared)
                .themed()
                .preferredColorScheme(preferredScheme)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    clerk.configure(publishableKey: Configuration.clerkPublishableKey)
                    try? await clerk.load()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            OneraCommands(
                showSettings: $showSettings,
                onNewChat: { windowManager.requestNewChat() },
                onNewNote: { windowManager.requestNewNote() },
                onToggleSidebar: { windowManager.toggleSidebar() },
                onSearch: { windowManager.focusSearch() }
            )
            
            // Help menu
            CommandGroup(replacing: .help) {
                Link("Onera Help", destination: URL(string: "https://onera.app/help")!)
                Divider()
                Button("Report a Problem...") {
                    windowManager.reportProblem()
                }
            }
        }
        
        // Settings Window
        Settings {
            MacSettingsView()
                .withDependencies(DependencyContainer.shared)
                .themed()
        }
        
        // Menu Bar Extra (Quick Chat)
        MenuBarExtra("Onera", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarView()
                .withDependencies(DependencyContainer.shared)
                .themed()
        }
        .menuBarExtraStyle(.window)
        
        // Detached Chat Window
        WindowGroup("Chat", for: String.self) { $chatId in
            if let id = chatId {
                DetachedChatView(chatId: id)
                    .withDependencies(DependencyContainer.shared)
                    .themed()
                    .frame(minWidth: 500, minHeight: 400)
            }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 700, height: 600)
        
        // Detached Note Window
        WindowGroup("Note", for: String.self) { $noteId in
            if let id = noteId {
                DetachedNoteView(noteId: id)
                    .withDependencies(DependencyContainer.shared)
                    .themed()
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 600, height: 500)
    }
    
    private var preferredScheme: ColorScheme? {
        switch colorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure global appearance
        setupAppearance()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even when all windows closed
        false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
    
    private func setupAppearance() {
        // Any global appearance setup
    }
}

// MARK: - Window Manager

@MainActor
@Observable
final class WindowManager {
    static let shared = WindowManager()
    
    private(set) var openChatWindows: Set<String> = []
    private(set) var openNoteWindows: Set<String> = []
    
    // Notification names
    static let toggleSidebarNotification = Notification.Name("OneraToggleSidebar")
    static let focusSearchNotification = Notification.Name("OneraFocusSearch")
    static let newChatNotification = Notification.Name("OneraNewChat")
    static let newNoteNotification = Notification.Name("OneraNewNote")
    
    func requestNewChat() {
        NotificationCenter.default.post(name: Self.newChatNotification, object: nil)
    }
    
    func requestNewNote() {
        NotificationCenter.default.post(name: Self.newNoteNotification, object: nil)
    }
    
    func toggleSidebar() {
        NotificationCenter.default.post(name: Self.toggleSidebarNotification, object: nil)
        // Also use the system sidebar toggle
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
    
    func focusSearch() {
        NotificationCenter.default.post(name: Self.focusSearchNotification, object: nil)
    }
    
    func reportProblem() {
        if let url = URL(string: "https://onera.app/feedback") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openChatInWindow(chatId: String) {
        guard !openChatWindows.contains(chatId) else {
            // Window already open, focus it
            focusWindow(for: chatId)
            return
        }
        
        openChatWindows.insert(chatId)
        // The WindowGroup with String ID will handle opening
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
        // Find and focus the window with this ID
        for window in NSApp.windows {
            if window.title.contains(id) || window.identifier?.rawValue == id {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

// MARK: - Environment Key for Window Manager

private struct WindowManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: WindowManager = WindowManager.shared
}

extension EnvironmentValues {
    var windowManager: WindowManager {
        get { self[WindowManagerKey.self] }
        set { self[WindowManagerKey.self] = newValue }
    }
}
