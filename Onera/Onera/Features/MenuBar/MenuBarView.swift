//
//  MenuBarView.swift
//  Onera (macOS)
//
//  Menu bar quick chat interface
//

#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Menu Bar View

struct MenuBarView: View {
    
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openWindow) private var openWindow
    @State private var inputText = ""
    @State private var recentChats: [ChatSummary] = []
    @State private var isLoading = false
    @State private var chatViewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Quick input
            quickInputSection
            
            Divider()
            
            // Recent chats
            recentChatsSection
            
            Divider()
            
            // Footer actions
            footerActions
        }
        .frame(width: 320)
        .task {
            await loadRecentChats()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(Color.accentColor)
                .font(.title3)
            
            Text("Onera")
                .font(.headline)
            
            Spacer()
            
            // HIG: Use standard button style for menu bar
            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "macwindow")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Main Window")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial) // HIG: Use materials for depth
    }
    
    // MARK: - Quick Input
    
    private var quickInputSection: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Ask anything...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendQuickMessage()
                    }
                
                if !inputText.isEmpty {
                    Button {
                        sendQuickMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Recent Chats
    
    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            if recentChats.isEmpty {
                Text("No recent chats")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentChats.prefix(5)) { chat in
                    Button {
                        openChat(chat.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                
                                Text(chat.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Footer Actions
    
    private var footerActions: some View {
        HStack(spacing: 12) {
            Button {
                createNewChat()
            } label: {
                Label("New Chat", systemImage: "plus.bubble")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: .command)
            
            Button {
                WindowManager.shared.requestNewNote()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("New Note", systemImage: "note.text.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("n", modifiers: [.command, .shift])
            
            Spacer()
            
            // Settings - HIG: Provide quick access
            Button {
                // Open settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Private Methods
    
    private func loadRecentChats() async {
        do {
            let token = try await dependencies.authService.getToken()
            let chats = try await dependencies.chatRepository.fetchChats(token: token)
            await MainActor.run {
                self.recentChats = chats
            }
        } catch {
            print("[MenuBarView] Failed to load chats: \(error)")
        }
    }
    
    private func sendQuickMessage() {
        guard !inputText.isEmpty else { return }
        
        let message = inputText
        inputText = ""
        
        // Send quick message via WindowManager - main window will handle it
        WindowManager.shared.sendQuickMessage(message)
        WindowManager.shared.requestNewChat()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func openChat(_ chatId: String) {
        // Open chat in main window
        openWindow(value: chatId)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func createNewChat() {
        WindowManager.shared.requestNewChat()
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Mac Chat View

struct MacChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.theme) private var theme
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messagesScrollView
            }
            
            Divider()
            
            // Input
            inputArea
        }
        .background(theme.background)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 4) {
                Text("Start a conversation")
                    .font(.title3)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("End-to-end encrypted")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Messages
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MacMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...10)
                .focused($isInputFocused)
                .onSubmit {
                    if !viewModel.inputText.isEmpty {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(viewModel.canSend ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend && !viewModel.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}

// MARK: - Mac Message Bubble

struct MacMessageBubble: View {
    let message: Message
    @Environment(\.theme) private var theme
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Actions on hover
                if isHovering && !message.isStreaming {
                    HStack(spacing: 8) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Copy")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.isUser {
                theme.userBubble
            } else {
                theme.assistantBubble
            }
        }
    }
}

// MARK: - Detached Views

struct DetachedChatView: View {
    let chatId: String
    @Environment(\.dependencies) private var dependencies
    @State private var chatViewModel: ChatViewModel?
    
    var body: some View {
        Group {
            if let viewModel = chatViewModel {
                MacChatView(viewModel: viewModel)
                    .navigationTitle(viewModel.chat?.title ?? "Chat")
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            setupViewModel()
            await chatViewModel?.loadChat(id: chatId)
        }
    }
    
    private func setupViewModel() {
        chatViewModel = ChatViewModel(
            authService: dependencies.authService,
            chatRepository: dependencies.chatRepository,
            credentialService: dependencies.credentialService,
            llmService: dependencies.llmService,
            speechService: dependencies.speechService,
            speechRecognitionService: dependencies.speechRecognitionService,
            onChatUpdated: { _ in }
        )
    }
}

struct DetachedNoteView: View {
    let noteId: String
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var notesViewModel: NotesViewModel?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading note...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Failed to load note")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await loadNote() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let vm = notesViewModel, vm.editingNote != nil {
                MacNoteEditorView(viewModel: vm)
                    .navigationTitle(vm.editingNote?.title ?? "Note")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Note not found")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            setupViewModel()
            await loadNote()
        }
    }
    
    private func setupViewModel() {
        notesViewModel = NotesViewModel(
            noteRepository: dependencies.noteRepository,
            authService: dependencies.authService
        )
    }
    
    private func loadNote() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await dependencies.authService.getToken()
            let note = try await dependencies.noteRepository.fetchNote(id: noteId, token: token)
            await MainActor.run {
                notesViewModel?.editingNote = note
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
        }
    }
}

// MARK: - macOS Note Editor View

struct MacNoteEditorView: View {
    @Bindable var viewModel: NotesViewModel
    @Environment(\.theme) private var theme
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPinned: Bool = false
    @State private var isSaving = false
    @State private var lastSaveTime: Date?
    @State private var autoSaveTask: Task<Void, Never>?
    
    @FocusState private var isContentFocused: Bool
    
    private var hasChanges: Bool {
        guard let note = viewModel.editingNote else { return false }
        return title != note.title || content != note.content || isPinned != note.pinned
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar area
            HStack {
                // Pin toggle
                Button {
                    isPinned.toggle()
                    scheduleAutoSave()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin Note" : "Pin Note")
                
                Spacer()
                
                // Save indicator
                if isSaving {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Saving...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let lastSave = lastSaveTime {
                    Text("Saved \(lastSave, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                // Manual save button
                Button {
                    Task { await saveNote() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(isSaving || !hasChanges)
                .help("Save (⌘S)")
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Title
            TextField("Title", text: $title, axis: .vertical)
                .font(.title.bold())
                .textFieldStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 16)
                .onChange(of: title) { _, _ in scheduleAutoSave() }
            
            Divider()
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            // Content
            TextEditor(text: $content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .focused($isContentFocused)
                .onChange(of: content) { _, _ in scheduleAutoSave() }
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Start writing...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
        .background(theme.background)
        .onAppear {
            if let note = viewModel.editingNote {
                title = note.title
                content = note.content
                isPinned = note.pinned
            }
        }
        .onDisappear {
            autoSaveTask?.cancel()
            // Save on close if there are changes
            if hasChanges {
                Task { await saveNote() }
            }
        }
    }
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        
        guard !title.isEmpty else { return }
        
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            
            if let lastSave = lastSaveTime, Date().timeIntervalSince(lastSave) < 1.5 {
                return
            }
            
            await saveNote()
        }
    }
    
    private func saveNote() async {
        guard !title.isEmpty else { return }
        
        isSaving = true
        
        var note = viewModel.editingNote ?? Note()
        note.title = title
        note.content = content
        note.pinned = isPinned
        note.updatedAt = Date()
        
        _ = await viewModel.saveNote(note)
        
        isSaving = false
        lastSaveTime = Date()
    }
}

// MARK: - Settings View

enum MacSettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case credentials = "API Keys"
    case security = "Security"
    case advanced = "Advanced"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .credentials: return "key"
        case .security: return "lock.shield"
        case .advanced: return "slider.horizontal.3"
        }
    }
}

struct MacSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = 0
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.system.rawValue
    @State private var selectedTab: MacSettingsTab = .general
    
    var body: some View {
        // HIG: Use sidebar style for settings with many categories
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label(MacSettingsTab.general.rawValue, systemImage: MacSettingsTab.general.icon)
                }
                .tag(MacSettingsTab.general)
            
            MacAppearanceSettingsView(colorScheme: $colorScheme, selectedTheme: $selectedTheme)
                .tabItem {
                    Label(MacSettingsTab.appearance.rawValue, systemImage: MacSettingsTab.appearance.icon)
                }
                .tag(MacSettingsTab.appearance)
            
            CredentialsSettingsView()
                .tabItem {
                    Label(MacSettingsTab.credentials.rawValue, systemImage: MacSettingsTab.credentials.icon)
                }
                .tag(MacSettingsTab.credentials)
            
            SecuritySettingsView()
                .tabItem {
                    Label(MacSettingsTab.security.rawValue, systemImage: MacSettingsTab.security.icon)
                }
                .tag(MacSettingsTab.security)
            
            AdvancedSettingsView()
                .tabItem {
                    Label(MacSettingsTab.advanced.rawValue, systemImage: MacSettingsTab.advanced.icon)
                }
                .tag(MacSettingsTab.advanced)
        }
        .tabViewStyle(.sidebarAdaptable) // Modern macOS sidebar style
        .frame(minWidth: 600, minHeight: 400) // HIG: Allow adequate space
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("enableDeveloperMode") private var enableDeveloperMode = false
    @AppStorage("enableLogging") private var enableLogging = false
    
    var body: some View {
        Form {
            Section("Developer") {
                Toggle("Developer Mode", isOn: $enableDeveloperMode)
                Toggle("Enable Debug Logging", isOn: $enableLogging)
            }
            
            Section("Reset") {
                Button("Reset All Settings", role: .destructive) {
                    // Reset settings
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: .constant(false))
                Toggle("Show in menu bar", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct MacAppearanceSettingsView: View {
    @Binding var colorScheme: Int
    @Binding var selectedTheme: String
    
    var body: some View {
        Form {
            Section("Color Scheme") {
                Picker("Appearance", selection: $colorScheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Theme") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct CredentialsSettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: CredentialsViewModel?
    
    var body: some View {
        Group {
            if let vm = viewModel {
                MacCredentialsListView(viewModel: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            setupViewModel()
            await viewModel?.refreshCredentials()
        }
    }
    
    private func setupViewModel() {
        viewModel = CredentialsViewModel(
            credentialService: dependencies.credentialService,
            networkService: dependencies.networkService,
            cryptoService: dependencies.cryptoService,
            extendedCryptoService: dependencies.extendedCryptoService,
            secureSession: dependencies.secureSession,
            authService: dependencies.authService
        )
    }
}

// MARK: - macOS Credentials List View

private struct MacCredentialsListView: View {
    @Bindable var viewModel: CredentialsViewModel
    @State private var selectedCredentialId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("API Keys")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button {
                    Task { await viewModel.refreshCredentials() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
                
                Button {
                    viewModel.showAddCredential = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add API Key")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            if viewModel.credentials.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                credentialsList
            }
        }
        .sheet(isPresented: $viewModel.showAddCredential) {
            MacAddCredentialSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete API Key",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let credential = viewModel.credentialToDelete {
                    Task { await viewModel.deleteCredential(credential) }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.credentialToDelete = nil
            }
        } message: {
            if let credential = viewModel.credentialToDelete {
                Text("Are you sure you want to delete '\(credential.name)'? This cannot be undone.")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "key.horizontal")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No API Keys")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("Add your API keys to use AI models\nfrom different providers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                viewModel.showAddCredential = true
            } label: {
                Label("Add API Key", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var credentialsList: some View {
        List(selection: $selectedCredentialId) {
            ForEach(viewModel.credentials) { credential in
                MacCredentialRow(credential: credential)
                    .tag(credential.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.confirmDelete(credential)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - macOS Credential Row

private struct MacCredentialRow: View {
    let credential: DecryptedCredential
    
    var body: some View {
        HStack(spacing: 12) {
            // Provider icon
            ZStack {
                Circle()
                    .fill(providerColor.opacity(0.15))
                
                Text(credential.provider.displayName.prefix(1))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(providerColor)
            }
            .frame(width: 32, height: 32)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(credential.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(credential.provider.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Masked key
            Text(maskedApiKey)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var providerColor: Color {
        switch credential.provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .xai: return .purple
        case .groq: return .pink
        case .mistral: return .cyan
        case .deepseek: return .indigo
        case .openrouter: return .teal
        case .together: return .mint
        case .fireworks: return .red
        case .ollama: return .gray
        case .lmstudio: return .gray
        case .custom: return .secondary
        }
    }
    
    private var maskedApiKey: String {
        let key = credential.apiKey
        if key.count > 8 {
            return String(key.prefix(4)) + "••••" + String(key.suffix(4))
        }
        return "••••••••"
    }
}

// MARK: - macOS Add Credential Sheet

private struct MacAddCredentialSheet: View {
    @Bindable var viewModel: CredentialsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    viewModel.resetForm()
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Text("Add API Key")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        if await viewModel.saveCredential() {
                            dismiss()
                        }
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Form
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $viewModel.selectedProvider) {
                        ForEach(viewModel.providerGroups, id: \.0) { groupName, providers in
                            Section(groupName) {
                                ForEach(providers, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                        }
                    }
                    .labelsHidden()
                }
                
                Section("Credentials") {
                    TextField("Name (e.g., My OpenAI Key)", text: $viewModel.credentialName)
                    
                    SecureField("API Key", text: $viewModel.apiKey)
                    
                    if viewModel.showBaseUrlField {
                        TextField("Base URL (optional)", text: $viewModel.baseUrl)
                    }
                    
                    if viewModel.showOrgIdField {
                        TextField("Organization ID (optional)", text: $viewModel.orgId)
                    }
                }
                
                if let error = viewModel.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    Color.black.opacity(0.1)
                    ProgressView()
                }
            }
        }
        .frame(width: 450, height: 400)
    }
}

struct SecuritySettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var isCheckingStatus = true
    @State private var hasPasswordEncryption = false
    @State private var hasPasskeys = false
    @State private var isPasskeySupported = false
    @State private var showRecoveryPhrase = false
    @State private var recoveryPhrase: String?
    @State private var isLoadingRecovery = false
    @State private var showLockConfirmation = false
    @State private var error: Error?
    
    var body: some View {
        Form {
            // Status Section
            Section("Encryption Status") {
                HStack {
                    Label {
                        Text("End-to-End Encryption")
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                    }
                    
                    Spacer()
                    
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                HStack {
                    Text("Session Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if dependencies.secureSession.isUnlocked {
                        Text("Unlocked")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Locked")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                if dependencies.secureSession.isUnlocked {
                    HStack {
                        Text("Last Activity")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dependencies.secureSession.lastActivityDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Unlock Methods Section
            Section("Unlock Methods") {
                if isCheckingStatus {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Label("Password", systemImage: "key.fill")
                        Spacer()
                        if hasPasswordEncryption {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Not Set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if isPasskeySupported {
                        HStack {
                            Label("Passkey (Touch ID)", systemImage: "touchid")
                            Spacer()
                            if hasPasskeys {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not Set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Label("Recovery Phrase", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            
            // Recovery Section
            Section("Recovery") {
                Button {
                    showRecoveryPhrase = true
                } label: {
                    HStack {
                        Label("View Recovery Phrase", systemImage: "eye")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(!dependencies.secureSession.isUnlocked)
                
                Text("Keep your recovery phrase safe. It's the only way to recover your data if you lose access to all your devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Actions Section
            Section("Actions") {
                Button {
                    showLockConfirmation = true
                } label: {
                    Label("Lock Session Now", systemImage: "lock.fill")
                }
                .disabled(!dependencies.secureSession.isUnlocked)
            }
            
            // About Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About E2EE")
                        .font(.headline)
                    
                    Text("Onera uses end-to-end encryption to protect your conversations and notes. Your data is encrypted on your device before being sent to our servers, and can only be decrypted by you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("We cannot read your messages or notes, even if compelled to do so.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task {
            await checkStatus()
        }
        .sheet(isPresented: $showRecoveryPhrase) {
            MacRecoveryPhraseSheet(
                recoveryPhrase: recoveryPhrase,
                isLoading: isLoadingRecovery,
                onLoad: loadRecoveryPhrase
            )
        }
        .confirmationDialog(
            "Lock Session",
            isPresented: $showLockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lock Now", role: .destructive) {
                dependencies.secureSession.lock()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your password or recovery phrase to unlock again.")
        }
    }
    
    private func checkStatus() async {
        isCheckingStatus = true
        
        do {
            let token = try await dependencies.authService.getToken()
            hasPasswordEncryption = try await dependencies.e2eeService.hasPasswordEncryption(token: token)
            hasPasskeys = try await dependencies.e2eeService.hasPasskeys(token: token)
            isPasskeySupported = dependencies.e2eeService.isPasskeySupported()
        } catch {
            self.error = error
        }
        
        isCheckingStatus = false
    }
    
    private func loadRecoveryPhrase() async {
        isLoadingRecovery = true
        
        do {
            let token = try await dependencies.authService.getToken()
            recoveryPhrase = try await dependencies.e2eeService.getRecoveryPhrase(token: token)
        } catch {
            self.error = error
        }
        
        isLoadingRecovery = false
    }
}

// MARK: - Recovery Phrase Sheet

private struct MacRecoveryPhraseSheet: View {
    let recoveryPhrase: String?
    let isLoading: Bool
    let onLoad: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var hasCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recovery Phrase")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                VStack(spacing: 8) {
                    Text("Keep this phrase secret!")
                        .font(.headline)
                    
                    Text("Anyone with this phrase can access your encrypted data.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if isLoading {
                    ProgressView()
                } else if let phrase = recoveryPhrase {
                    // Recovery phrase display
                    VStack(spacing: 12) {
                        Text(phrase)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                        
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(phrase, forType: .string)
                            hasCopied = true
                            
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                hasCopied = false
                            }
                        } label: {
                            Label(hasCopied ? "Copied!" : "Copy to Clipboard", systemImage: hasCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Unable to load recovery phrase")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
        }
        .frame(width: 450, height: 400)
        .task {
            if recoveryPhrase == nil {
                await onLoad()
            }
        }
    }
}

// MARK: - Preview

#Preview("Menu Bar") {
    MenuBarView()
        .frame(width: 320, height: 400)
}

#endif // os(macOS)
