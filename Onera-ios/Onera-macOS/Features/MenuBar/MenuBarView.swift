//
//  MenuBarView.swift
//  Onera (macOS)
//
//  Menu bar quick chat interface
//

import SwiftUI

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
                .foregroundStyle(.accent)
            
            Text("Onera")
                .font(.headline)
            
            Spacer()
            
            Button {
                NSApp.activate(ignoringOtherApps: true)
                // Open main window
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Main Window")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                            .foregroundStyle(.accent)
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
        HStack {
            Button {
                createNewChat()
            } label: {
                Label("New Chat", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Private Methods
    
    private func loadRecentChats() async {
        do {
            let token = try await dependencies.authService.getToken()
            let chats = try await dependencies.chatRepository.getChats(token: token)
            await MainActor.run {
                self.recentChats = chats
            }
        } catch {
            print("[MenuBarView] Failed to load chats: \(error)")
        }
    }
    
    private func sendQuickMessage() {
        guard !inputText.isEmpty else { return }
        
        isLoading = true
        let message = inputText
        inputText = ""
        
        Task {
            // Create new chat with this message
            // For now, just open main window
            await MainActor.run {
                isLoading = false
                createNewChat()
            }
        }
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
                    .foregroundStyle(viewModel.canSend ? .accent : .secondary)
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
                    .navigationTitle(viewModel.currentChat?.title ?? "Chat")
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
    
    var body: some View {
        Text("Note: \(noteId)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings View

struct MacSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = 0
    @AppStorage("selectedTheme") private var selectedTheme = AppTheme.system.rawValue
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            AppearanceSettingsView(colorScheme: $colorScheme, selectedTheme: $selectedTheme)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            CredentialsSettingsView()
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
            
            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 350)
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

struct AppearanceSettingsView: View {
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
    var body: some View {
        Form {
            Section("API Keys") {
                Text("Manage your API keys here")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SecuritySettingsView: View {
    var body: some View {
        Form {
            Section("Encryption") {
                Text("Your data is end-to-end encrypted")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview("Menu Bar") {
    MenuBarView()
        .frame(width: 320, height: 400)
}
