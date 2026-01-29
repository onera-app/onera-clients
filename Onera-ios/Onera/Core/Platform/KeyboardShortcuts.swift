//
//  KeyboardShortcuts.swift
//  Onera
//
//  Centralized keyboard shortcut definitions for iPad and macOS
//

import SwiftUI

// MARK: - Keyboard Shortcut Definitions

/// Centralized keyboard shortcuts used across iPad and macOS
enum OneraKeyboardShortcut {
    case newChat
    case newNote
    case toggleSidebar
    case openModelSelector
    case sendMessage
    case search
    case settings
    case closeWindow
    case previousChat
    case nextChat
    
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .newChat: return "n"
        case .newNote: return "n"
        case .toggleSidebar: return "["
        case .openModelSelector: return "k"
        case .sendMessage: return .return
        case .search: return "f"
        case .settings: return ","
        case .closeWindow: return "w"
        case .previousChat: return "["
        case .nextChat: return "]"
        }
    }
    
    var modifiers: EventModifiers {
        switch self {
        case .newChat: return .command
        case .newNote: return [.command, .shift]
        case .toggleSidebar: return .command
        case .openModelSelector: return .command
        case .sendMessage: return .command
        case .search: return .command
        case .settings: return .command
        case .closeWindow: return .command
        case .previousChat: return [.command, .option]
        case .nextChat: return [.command, .option]
        }
    }
    
    var label: String {
        switch self {
        case .newChat: return "New Chat"
        case .newNote: return "New Note"
        case .toggleSidebar: return "Toggle Sidebar"
        case .openModelSelector: return "Select Model"
        case .sendMessage: return "Send Message"
        case .search: return "Search"
        case .settings: return "Settings"
        case .closeWindow: return "Close Window"
        case .previousChat: return "Previous Chat"
        case .nextChat: return "Next Chat"
        }
    }
}

// MARK: - Keyboard Shortcut Commands (for macOS/iPadOS)

struct OneraCommands: Commands {
    @Binding var showSettings: Bool
    
    let onNewChat: () -> Void
    let onNewNote: () -> Void
    let onToggleSidebar: () -> Void
    let onSearch: () -> Void
    
    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Button(OneraKeyboardShortcut.newChat.label) {
                onNewChat()
            }
            .keyboardShortcut(
                OneraKeyboardShortcut.newChat.keyEquivalent,
                modifiers: OneraKeyboardShortcut.newChat.modifiers
            )
            
            Button(OneraKeyboardShortcut.newNote.label) {
                onNewNote()
            }
            .keyboardShortcut(
                OneraKeyboardShortcut.newNote.keyEquivalent,
                modifiers: OneraKeyboardShortcut.newNote.modifiers
            )
        }
        
        // View menu additions
        CommandGroup(after: .sidebar) {
            Button(OneraKeyboardShortcut.toggleSidebar.label) {
                onToggleSidebar()
            }
            .keyboardShortcut(
                OneraKeyboardShortcut.toggleSidebar.keyEquivalent,
                modifiers: OneraKeyboardShortcut.toggleSidebar.modifiers
            )
        }
        
        // Edit menu - search
        CommandGroup(after: .textEditing) {
            Button(OneraKeyboardShortcut.search.label) {
                onSearch()
            }
            .keyboardShortcut(
                OneraKeyboardShortcut.search.keyEquivalent,
                modifiers: OneraKeyboardShortcut.search.modifiers
            )
        }
        
        #if os(macOS)
        // Settings (macOS uses its own Settings scene, but we can add a shortcut)
        CommandGroup(replacing: .appSettings) {
            Button(OneraKeyboardShortcut.settings.label) {
                showSettings = true
            }
            .keyboardShortcut(
                OneraKeyboardShortcut.settings.keyEquivalent,
                modifiers: OneraKeyboardShortcut.settings.modifiers
            )
        }
        #endif
    }
}

// MARK: - View Extension for Keyboard Shortcuts

extension View {
    /// Add a keyboard shortcut using OneraKeyboardShortcut
    func oneraShortcut(_ shortcut: OneraKeyboardShortcut) -> some View {
        self.keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
    }
    
    /// Conditionally add keyboard shortcuts only on iPad/Mac
    @ViewBuilder
    func withKeyboardShortcuts(_ enabled: Bool = true) -> some View {
        #if os(iOS)
        if enabled && UIDevice.current.userInterfaceIdiom == .pad {
            self
        } else {
            self
        }
        #elseif os(macOS)
        self
        #else
        self
        #endif
    }
}

// MARK: - Focus Management for Keyboard Navigation

/// Observable object to manage keyboard focus state
@MainActor
@Observable
final class KeyboardFocusManager {
    var isSearchFocused = false
    var isInputFocused = false
    var selectedChatIndex: Int?
    
    func focusSearch() {
        isSearchFocused = true
        isInputFocused = false
    }
    
    func focusInput() {
        isInputFocused = true
        isSearchFocused = false
    }
    
    func clearFocus() {
        isSearchFocused = false
        isInputFocused = false
    }
    
    func selectPreviousChat(totalChats: Int) {
        guard totalChats > 0 else { return }
        if let current = selectedChatIndex {
            selectedChatIndex = max(0, current - 1)
        } else {
            selectedChatIndex = 0
        }
    }
    
    func selectNextChat(totalChats: Int) {
        guard totalChats > 0 else { return }
        if let current = selectedChatIndex {
            selectedChatIndex = min(totalChats - 1, current + 1)
        } else {
            selectedChatIndex = 0
        }
    }
}

// MARK: - Environment Key for Focus Manager

private struct KeyboardFocusManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: KeyboardFocusManager = KeyboardFocusManager()
}

extension EnvironmentValues {
    @MainActor
    var keyboardFocusManager: KeyboardFocusManager {
        get { self[KeyboardFocusManagerKey.self] }
        set { self[KeyboardFocusManagerKey.self] = newValue }
    }
}
