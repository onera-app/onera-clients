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
    @Environment(\.openSettings) private var openSettings
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
            .accessibilityLabel("Open main window")
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
                    .accessibilityLabel("Send message")
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
                                    .font(.subheadline)
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
                #if os(macOS)
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
                #endif
            } label: {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
            .accessibilityLabel("Settings")
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
    
    // Prompt @mention support
    var promptSummaries: [PromptSummary] = []
    var onFetchPromptContent: ((PromptSummary) async -> String?)? = nil
    
    @State private var showMentionPopover = false
    @State private var mentionQuery = ""
    @State private var mentionSelectedIndex = 0
    @State private var pendingPrompt: PromptSummary? = nil
    @State private var pendingPromptVariables: [String] = []
    @State private var pendingPromptResolvedContent: String? = nil
    @State private var variableValues: [String: String] = [:]
    @State private var showVariableSheet = false
    
    /// Prompts filtered by the current @mention query
    private var filteredMentionPrompts: [PromptSummary] {
        if mentionQuery.isEmpty {
            return Array(promptSummaries.prefix(8))
        }
        return promptSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(mentionQuery)
        }.prefix(8).map { $0 }
    }
    
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
        .onChange(of: viewModel.inputText) { _, newValue in
            detectMention(in: newValue)
        }
        .sheet(isPresented: $showVariableSheet) {
            if let prompt = pendingPrompt {
                PromptVariableSheet(
                    promptName: prompt.name,
                    variables: pendingPromptVariables,
                    values: $variableValues,
                    onConfirm: {
                        insertPromptContent(prompt, variables: variableValues)
                        showVariableSheet = false
                        pendingPrompt = nil
                    },
                    onCancel: {
                        showVariableSheet = false
                        pendingPrompt = nil
                    }
                )
            }
        }
    }
    
    // MARK: - @Mention Detection
    
    private func detectMention(in text: String) {
        // Find the last "@" that starts a mention (not preceded by a word char)
        guard let atRange = text.range(of: "@", options: .backwards) else {
            showMentionPopover = false
            return
        }
        
        let afterAt = text[atRange.upperBound...]
        
        // If there's a newline or the mention was "completed" (no active query), hide
        if afterAt.contains("\n") {
            showMentionPopover = false
            return
        }
        
        // Check that @ is at start of text or preceded by whitespace
        if atRange.lowerBound != text.startIndex {
            let charBefore = text[text.index(before: atRange.lowerBound)]
            if !charBefore.isWhitespace && !charBefore.isNewline {
                showMentionPopover = false
                return
            }
        }
        
        mentionQuery = String(afterAt)
        mentionSelectedIndex = 0
        showMentionPopover = !filteredMentionPrompts.isEmpty
    }
    
    private func selectMentionPrompt(_ prompt: PromptSummary) {
        showMentionPopover = false
        
        Task {
            guard let content = await onFetchPromptContent?(prompt) else { return }
            
            // Check if the prompt has variables
            let variablePattern = "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}"
            let variables: [String]
            if let regex = try? NSRegularExpression(pattern: variablePattern) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, range: range)
                variables = matches.compactMap { match in
                    guard let r = Range(match.range(at: 1), in: content) else { return nil }
                    return String(content[r])
                }
            } else {
                variables = []
            }
            
            if variables.isEmpty {
                insertPromptContent(prompt, resolvedContent: content)
            } else {
                // Show variable input sheet
                pendingPrompt = prompt
                pendingPromptVariables = Array(Set(variables))
                pendingPromptResolvedContent = content
                variableValues = [:]
                showVariableSheet = true
            }
        }
    }
    
    private func insertPromptContent(_ prompt: PromptSummary, variables: [String: String] = [:], resolvedContent: String? = nil) {
        // Remove the @query from input text
        var text = viewModel.inputText
        if let atRange = text.range(of: "@", options: .backwards) {
            let charBeforeOk: Bool
            if atRange.lowerBound == text.startIndex {
                charBeforeOk = true
            } else {
                let c = text[text.index(before: atRange.lowerBound)]
                charBeforeOk = c.isWhitespace || c.isNewline
            }
            if charBeforeOk {
                text = String(text[..<atRange.lowerBound])
            }
        }
        
        if !variables.isEmpty, let resolved = resolvedContent ?? pendingPromptResolvedContent {
            // Apply variable substitution to the resolved content
            var content = resolved
            for (key, value) in variables {
                content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
                content = content.replacingOccurrences(of: "{{ \(key) }}", with: value)
            }
            viewModel.inputText = text + content
        } else if let resolved = resolvedContent {
            viewModel.inputText = text + resolved
        }
        
        pendingPromptResolvedContent = nil
    }
    
    // MARK: - Empty State
    
    private let starterPrompts: [(icon: String, title: String, prompt: String)] = [
        ("lightbulb", "Explain a concept", "Explain quantum computing in simple terms"),
        ("envelope", "Draft an email", "Help me write a professional email to my team about project updates"),
        ("terminal", "Write code", "Write a Python function that finds the longest palindromic substring"),
        ("chart.bar", "Analyze data", "What are the key metrics I should track for a SaaS product?"),
    ]
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.largeTitle.weight(.light))
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
            
            // Starter prompts grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(starterPrompts, id: \.title) { item in
                    Button {
                        viewModel.inputText = item.prompt
                        Task { await viewModel.sendMessage() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(item.prompt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Messages
    
    @AppStorage("chatDensity") private var chatDensity: String = "comfortable"
    
    private var messageSpacing: CGFloat {
        switch chatDensity {
        case "compact": return 8
        case "spacious": return 24
        default: return 16
        }
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: messageSpacing) {
                    ForEach(viewModel.messages) { message in
                        MacMessageBubble(
                            message: message,
                            onRegenerate: { modifier in
                                Task { await viewModel.regenerateMessage(messageId: message.id, modifier: modifier) }
                            },
                            onSpeak: { text in
                                Task { await viewModel.speak(text, messageId: message.id) }
                            },
                            onStopSpeaking: {
                                viewModel.stopSpeaking()
                            },
                            isSpeaking: viewModel.speakingMessageId == message.id,
                            onEdit: { newContent, shouldRegenerate in
                                Task { await viewModel.editMessage(messageId: message.id, newContent: newContent, regenerate: shouldRegenerate) }
                            },
                            onDelete: {
                                Task { await viewModel.deleteMessage(messageId: message.id) }
                            },
                            branchInfo: viewModel.getBranchInfo(for: message.id),
                            onPreviousBranch: {
                                viewModel.switchToPreviousBranch(for: message.id)
                            },
                            onNextBranch: {
                                viewModel.switchToNextBranch(for: message.id)
                            }
                        )
                        .id(message.id)
                    }
                    
                    // Follow-up suggestions after the last message
                    if !viewModel.followUps.isEmpty && !viewModel.isStreaming {
                        FollowUpsView(
                            followUps: viewModel.followUps,
                            onSelect: { followUp in
                                viewModel.inputText = followUp
                                Task { await viewModel.sendMessage() }
                            }
                        )
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
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
        VStack(spacing: 0) {
            // @mention prompt suggestions (above input)
            if showMentionPopover && !filteredMentionPrompts.isEmpty {
                PromptMentionList(
                    prompts: filteredMentionPrompts,
                    selectedIndex: mentionSelectedIndex,
                    onSelect: { prompt in
                        selectMentionPrompt(prompt)
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                // Search toggle — glass circle with provider picker
                searchToggleButton
                
                // Input field — glass pill
                HStack(spacing: 6) {
                    TextField("Ask anything...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .lineLimit(1...10)
                        .focused($isInputFocused)
                        .onSubmit {
                            if showMentionPopover && !filteredMentionPrompts.isEmpty {
                                let idx = min(mentionSelectedIndex, filteredMentionPrompts.count - 1)
                                selectMentionPrompt(filteredMentionPrompts[idx])
                            } else if !viewModel.inputText.isEmpty {
                                Task { await viewModel.sendMessage() }
                            }
                        }
                    
                    // Send / Stop button inside the pill
                    if viewModel.isStreaming {
                        Button {
                            viewModel.stopStreaming()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop generating")
                    } else if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            Task { await viewModel.sendMessage() }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(viewModel.canSend ? Color.accentColor : Color.secondary.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send message")
                        .disabled(!viewModel.canSend)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Search Toggle
    
    /// Whether any search provider is configured with an API key
    private var hasSearchProvider: Bool {
        let providerRaw = UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily"
        let apiKey = UserDefaults.standard.string(forKey: "search.\(providerRaw).apiKey") ?? ""
        return !apiKey.isEmpty
    }
    
    private var currentProviderName: String {
        let providerRaw = UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily"
        return SearchProvider(rawValue: providerRaw)?.displayName ?? "Tavily"
    }
    
    private var searchToggleButton: some View {
        Menu {
            // Toggle on/off
            Button {
                viewModel.searchEnabled.toggle()
            } label: {
                Label(
                    viewModel.searchEnabled ? "Disable Web Search" : "Enable Web Search",
                    systemImage: viewModel.searchEnabled ? "globe.badge.chevron.backward" : "globe"
                )
            }
            
            Divider()
            
            // Provider picker
            Text("Search Provider")
            ForEach(SearchProvider.allCases) { provider in
                Button {
                    UserDefaults.standard.set(provider.rawValue, forKey: "defaultSearchProvider")
                    if !viewModel.searchEnabled {
                        viewModel.searchEnabled = true
                    }
                } label: {
                    HStack {
                        Text(provider.displayName)
                        if provider.rawValue == (UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily") {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Group {
                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "globe")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(viewModel.searchEnabled ? Color.accentColor : .secondary)
                        .frame(width: 32, height: 32)
                }
            }
        } primaryAction: {
            if hasSearchProvider {
                viewModel.searchEnabled.toggle()
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .background(Color(.controlBackgroundColor))
        .clipShape(Circle())
        .help(
            !hasSearchProvider ? "Configure a search provider in Settings > Tools" :
            viewModel.searchEnabled ? "Web search enabled (\(currentProviderName))" : "Enable web search"
        )
        .opacity(hasSearchProvider ? 1.0 : 0.5)
    }
}

// MARK: - Mac Message Bubble

struct MacMessageBubble: View {
    let message: Message
    var onRegenerate: ((String?) -> Void)?
    var onSpeak: ((String) -> Void)?
    var onStopSpeaking: (() -> Void)?
    var isSpeaking: Bool = false
    
    // Edit support
    var onEdit: ((String, Bool) -> Void)?
    
    // Delete support
    var onDelete: (() -> Void)?
    
    // Branch navigation
    var branchInfo: (current: Int, total: Int)?
    var onPreviousBranch: (() -> Void)?
    var onNextBranch: (() -> Void)?
    
    @Environment(\.theme) private var theme
    @State private var showCopiedFeedback = false
    @State private var isRegenerating = false
    @State private var isEditing = false
    @State private var editText = ""
    
    /// Parse the message content for thinking tags
    private var parsedContent: ParsedMessageContent {
        ThinkingTagParser.parse(message.content)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
                userMessageView
            } else {
                assistantMessageView
                Spacer(minLength: 60)
            }
        }

    }
    
    // MARK: - User Message
    
    /// Filter attachments to only image types
    private var imageAttachments: [Attachment] {
        message.attachments.filter { $0.type == .image }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isEditing {
                // Edit mode
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $editText)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            isEditing = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Save & Regenerate") {
                            onEdit?(editText, true)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("Save") {
                            onEdit?(editText, false)
                            isEditing = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(theme.userBubble)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Normal display
                VStack(alignment: .trailing, spacing: 8) {
                    // Show attached images if any
                    if !imageAttachments.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(imageAttachments) { attachment in
                                if let nsImage = NSImage(data: attachment.data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .textSelection(.enabled)
                    
                    // Show edited indicator
                    if message.edited == true {
                        Text("edited")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(theme.userBubble)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Actions
                if !message.isStreaming {
                    userActionButtons
                }
            }
        }
    }
    
    // MARK: - Assistant Message
    
    private var assistantMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Reasoning view (if available)
            if let reasoning = parsedContent.thinkingContent, !reasoning.isEmpty {
                MacReasoningView(reasoning: reasoning, isStreaming: message.isStreaming && parsedContent.displayContent.isEmpty)
            }
            
            // Main content with markdown rendering
            if !parsedContent.displayContent.isEmpty || message.isStreaming {
                MarkdownContentView(content: parsedContent.displayContent, isStreaming: message.isStreaming)
                    .padding(12)
                    .background(theme.assistantBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Message metadata + branch navigation + actions (below bubble)
            if !message.isStreaming {
                HStack(spacing: 12) {
                    // Model name and timestamp
                    messageMetadata
                    
                    // Branch navigation (if branches exist)
                    if let info = branchInfo, info.total > 1 {
                        branchNavigationView(info: info)
                    }
                    
                    Spacer()
                    
                    // Actions
                    assistantActionButtons
                }
                .foregroundStyle(.secondary)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Message Metadata
    
    @ViewBuilder
    private var messageMetadata: some View {
        HStack(spacing: 6) {
            if let model = message.model {
                Text(ModelOption.formatModelName(model))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }
    
    // MARK: - Branch Navigation
    
    private func branchNavigationView(info: (current: Int, total: Int)) -> some View {
        HStack(spacing: 4) {
            Button {
                onPreviousBranch?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous response version")
            .disabled(info.current <= 1)
            
            Text("\(info.current)/\(info.total)")
                .font(.caption)
                .monospacedDigit()
            
            Button {
                onNextBranch?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next response version")
            .disabled(info.current >= info.total)
        }
        .foregroundStyle(.secondary)
    }
    
    // MARK: - Action Buttons
    
    private var userActionButtons: some View {
        HStack(spacing: 8) {
            copyButton
            
            if onEdit != nil {
                editButton
            }
            
            if onDelete != nil {
                deleteButton
            }
        }
        .foregroundStyle(.secondary)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var assistantActionButtons: some View {
        HStack(spacing: 8) {
            copyButton
            
            if onRegenerate != nil {
                regenerateButton
            }
            
            if onSpeak != nil {
                speakButton
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var copyButton: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                if showCopiedFeedback {
                    Text("Copied!")
                        .font(.caption)
                }
            }
            .foregroundStyle(showCopiedFeedback ? theme.success : .secondary)
        }
        .buttonStyle(.plain)
        .help(showCopiedFeedback ? "Copied!" : "Copy message")
        .accessibilityLabel("Copy message")
    }
    
    private var editButton: some View {
        Button {
            editText = message.content
            isEditing = true
        } label: {
            Image(systemName: "pencil")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Edit message")
        .accessibilityLabel("Edit message")
    }
    
    @State private var showDeleteConfirmation = false
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help("Delete message")
        .accessibilityLabel("Delete message")
        .confirmationDialog("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this message? This cannot be undone.")
        }
    }
    
    @State private var customRegeneratePrompt = ""
    
    private var regenerateButton: some View {
        Menu {
            Button {
                doRegenerate(modifier: nil)
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            Button {
                doRegenerate(modifier: "Please provide more details and expand on your explanation.")
            } label: {
                Label("Add Details", systemImage: "doc.text")
            }
            
            Button {
                doRegenerate(modifier: "Please be more concise and brief in your response.")
            } label: {
                Label("More Concise", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            
            Button {
                doRegenerate(modifier: "Please be more creative and think outside the box.")
            } label: {
                Label("Be Creative", systemImage: "sparkles")
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(isRegenerating ? 360 : 0))
                    .animation(isRegenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRegenerating)
                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
            }
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Regenerate response")
    }
    
    private var speakButton: some View {
        Button {
            doSpeak()
        } label: {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                .font(.caption)
                .foregroundStyle(isSpeaking ? theme.error : .secondary)
        }
        .buttonStyle(.plain)
        .help(isSpeaking ? "Stop speaking" : "Read aloud")
        .accessibilityLabel(isSpeaking ? "Stop speaking" : "Read aloud")
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        let contentToCopy = message.isUser ? message.content : parsedContent.displayContent
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contentToCopy, forType: .string)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
    
    private func doRegenerate(modifier: String? = nil) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRegenerating = true
        }
        
        onRegenerate?(modifier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeOut(duration: 0.2)) {
                isRegenerating = false
            }
        }
    }
    
    private func doSpeak() {
        if isSpeaking {
            onStopSpeaking?()
        } else {
            onSpeak?(parsedContent.displayContent)
        }
    }
    
}

// MARK: - Mac Reasoning View

struct MacReasoningView: View {
    let reasoning: String
    let isStreaming: Bool
    
    @Environment(\.theme) private var theme
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isStreaming ? "brain" : "lightbulb")
                        .font(.caption)
                        .foregroundStyle(theme.info)
                    
                    Text(isStreaming ? "Thinking..." : "Reasoning")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(theme.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.info.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            // Expandable content
            if isExpanded {
                Text(reasoning)
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(theme.secondaryBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
            networkService: dependencies.networkService,
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
                        .font(.largeTitle)
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
                        .font(.largeTitle)
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
                .accessibilityLabel(isPinned ? "Unpin note" : "Pin note")
                
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
                .accessibilityLabel("Save note")
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
            
            // Markdown formatting toolbar
            HStack(spacing: 2) {
                FormatButton(icon: "bold", help: "Bold (⌘B)") {
                    wrapSelection(prefix: "**", suffix: "**")
                }
                FormatButton(icon: "italic", help: "Italic (⌘I)") {
                    wrapSelection(prefix: "_", suffix: "_")
                }
                FormatButton(icon: "strikethrough", help: "Strikethrough") {
                    wrapSelection(prefix: "~~", suffix: "~~")
                }
                
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                FormatButton(icon: "number", help: "Heading") {
                    insertAtLineStart("# ")
                }
                FormatButton(icon: "list.bullet", help: "Bullet List") {
                    insertAtLineStart("- ")
                }
                FormatButton(icon: "list.number", help: "Numbered List") {
                    insertAtLineStart("1. ")
                }
                FormatButton(icon: "checklist", help: "Task List") {
                    insertAtLineStart("- [ ] ")
                }
                
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                FormatButton(icon: "chevron.left.forwardslash.chevron.right", help: "Inline Code") {
                    wrapSelection(prefix: "`", suffix: "`")
                }
                FormatButton(icon: "text.page", help: "Code Block") {
                    wrapSelection(prefix: "```\n", suffix: "\n```")
                }
                FormatButton(icon: "link", help: "Link") {
                    wrapSelection(prefix: "[", suffix: "](url)")
                }
                FormatButton(icon: "text.quote", help: "Blockquote") {
                    insertAtLineStart("> ")
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Content
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .focused($isContentFocused)
                .onChange(of: content) { _, _ in scheduleAutoSave() }
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Start writing in Markdown...")
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
    
    // MARK: - Markdown Formatting Helpers
    
    private func wrapSelection(prefix: String, suffix: String) {
        // Simple approach: insert at cursor position (end of content)
        content += prefix + suffix
    }
    
    private func insertAtLineStart(_ prefix: String) {
        if content.isEmpty || content.hasSuffix("\n") {
            content += prefix
        } else {
            content += "\n" + prefix
        }
    }
}

// MARK: - Format Button

private struct FormatButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    
    /// Accessibility label derived from help text, stripping keyboard shortcuts
    private var accessibilityText: String {
        help.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression)
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 26, height: 26)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(accessibilityText)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
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
            MenuBarGeneralSettingsView()
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
    @State private var showResetConfirmation = false
    
    var body: some View {
        Form {
            Section("Developer") {
                Toggle("Developer Mode", isOn: $enableDeveloperMode)
                Toggle("Enable Debug Logging", isOn: $enableLogging)
            }
            
            Section("Reset") {
                Button("Reset All Settings", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Reset All Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all preferences to their defaults. This cannot be undone.")
        }
    }
    
    private func resetAllSettings() {
        let keysToReset = [
            "systemPrompt", "streamResponse", "temperature", "topP", "topK",
            "maxTokens", "frequencyPenalty", "presencePenalty",
            "openai.reasoningEffort", "anthropic.extendedThinking",
            "enableDeveloperMode", "enableLogging",
            "colorScheme", "selectedTheme"
        ]
        let defaults = UserDefaults.standard
        for key in keysToReset {
            defaults.removeObject(forKey: key)
        }
    }
}

struct MenuBarGeneralSettingsView: View {
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    var body: some View {
        Form {
            Section("Startup") {
                #if os(macOS)
                LaunchAtLoginToggle()
                #endif
                Toggle("Show in menu bar", isOn: $showInMenuBar)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#if os(macOS)
import ServiceManagement

/// Native macOS launch-at-login toggle using SMAppService
private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        Toggle("Launch at login", isOn: $isEnabled)
            .onChange(of: isEnabled) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("[Settings] Failed to toggle launch at login: \(error)")
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}
#endif

struct MacAppearanceSettingsView: View {
    @Binding var colorScheme: Int
    @Binding var selectedTheme: String
    @AppStorage("uiScale") private var uiScale: Double = 1.0
    @AppStorage("chatDensity") private var chatDensity: String = "comfortable"
    @AppStorage("oledDark") private var oledDark: Bool = false
    
    var body: some View {
        Form {
            Section("Color Scheme") {
                Picker("Appearance", selection: $colorScheme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
                
                if colorScheme == 2 || colorScheme == 0 {
                    Toggle("OLED Black (true black backgrounds)", isOn: $oledDark)
                        .help("Uses pure black instead of dark gray for OLED displays")
                }
            }
            
            Section("Theme") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
            }
            
            Section("Chat Density") {
                Picker("Message Spacing", selection: $chatDensity) {
                    Text("Compact").tag("compact")
                    Text("Comfortable").tag("comfortable")
                    Text("Spacious").tag("spacious")
                }
                .pickerStyle(.segmented)
                
                Text(chatDensityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("UI Scale") {
                HStack {
                    Text("A")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $uiScale, in: 0.85...1.25, step: 0.05)
                    
                    Text("A")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("\(Int(uiScale * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if uiScale != 1.0 {
                        Button("Reset") {
                            uiScale = 1.0
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var chatDensityDescription: String {
        switch chatDensity {
        case "compact": return "Minimal spacing between messages"
        case "spacious": return "Extra breathing room between messages"
        default: return "Standard spacing between messages"
        }
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
                .accessibilityLabel("Refresh credentials")
                
                Button {
                    viewModel.showAddCredential = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add API Key")
                .accessibilityLabel("Add API key")
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
                .font(.largeTitle.weight(.light))
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
                    .font(.caption.bold())
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
        case .`private`: return .blue
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
    @State private var showResetConfirmation = false
    @State private var resetConfirmText = ""
    @State private var isResetting = false
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
                
                Divider()
                
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset Encryption", systemImage: "exclamationmark.triangle.fill")
                }
                .disabled(!dependencies.secureSession.isUnlocked)
                
                Text("Deletes all encryption keys. You will need to set up encryption again. All existing encrypted data will be lost.")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
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
        .sheet(isPresented: $showResetConfirmation) {
            MacResetEncryptionSheet(
                confirmText: $resetConfirmText,
                isResetting: isResetting,
                onReset: performEncryptionReset,
                onCancel: { showResetConfirmation = false }
            )
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
    
    private func performEncryptionReset() async {
        guard resetConfirmText == "RESET MY ENCRYPTION" else { return }
        isResetting = true
        
        do {
            let token = try await dependencies.authService.getToken()
            
            struct ResetInput: Encodable {
                let confirmPhrase: String
            }
            struct ResetResponse: Decodable {
                let success: Bool
            }
            
            let _: ResetResponse = try await dependencies.networkService.call(
                procedure: "keyShares.resetEncryption",
                input: ResetInput(confirmPhrase: "RESET MY ENCRYPTION"),
                token: token
            )
            
            // Clear local session and keychain data
            dependencies.secureSession.lock()
            dependencies.secureSession.clearPersistedSession()
            
            showResetConfirmation = false
            resetConfirmText = ""
        } catch {
            self.error = error
        }
        
        isResetting = false
    }
}

// MARK: - Reset Encryption Sheet

private struct MacResetEncryptionSheet: View {
    @Binding var confirmText: String
    let isResetting: Bool
    let onReset: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            
            Text("Reset Encryption")
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("This will permanently delete all your encryption keys.")
                    .font(.body)
                
                Text("All your encrypted chats and notes will become unreadable. This cannot be undone.")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Type **RESET MY ENCRYPTION** to confirm:")
                    .font(.callout)
                
                TextField("Confirmation", text: $confirmText)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(role: .destructive) {
                    Task { await onReset() }
                } label: {
                    if isResetting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Reset Encryption")
                    }
                }
                .disabled(confirmText != "RESET MY ENCRYPTION" || isResetting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 420)
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
                    .font(.largeTitle)
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

// MARK: - Prompt @Mention List

struct PromptMentionList: View {
    let prompts: [PromptSummary]
    let selectedIndex: Int
    let onSelect: (PromptSummary) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "at")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Prompts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                Button {
                    onSelect(prompt)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(prompt.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            if let desc = prompt.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}

// MARK: - Prompt Variable Sheet

struct PromptVariableSheet: View {
    let promptName: String
    let variables: [String]
    @Binding var values: [String: String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Text("Fill in Variables")
                    .font(.headline)
                
                Spacer()
                
                Button("Insert") { onConfirm() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section {
                    Text("Prompt: \(promptName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Section("Variables") {
                    ForEach(variables, id: \.self) { variable in
                        TextField(variable, text: Binding(
                            get: { values[variable] ?? "" },
                            set: { values[variable] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 400, height: 350)
    }
}

// MARK: - Preview

#Preview("Menu Bar") {
    MenuBarView()
        .frame(width: 320, height: 400)
}

#endif // os(macOS)
