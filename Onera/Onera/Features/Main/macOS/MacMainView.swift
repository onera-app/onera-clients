//
//  MacMainView.swift
//  Onera (macOS)
//
//  Main window view with 2-column NavigationSplitView
//  Design inspired by ChatGPT macOS app - clean, minimal, native
//

#if os(macOS)
import SwiftUI
import AppKit
import AuthenticationServices

struct MacMainView: View {
    
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.theme) private var theme
    
    // Navigation state
    @State private var selectedFolder: String? = "all"
    @State private var selectedChatId: String?
    @State private var selectedNoteId: String?
    @State private var selectedPromptId: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""
    @State private var showSignOutConfirmation = false
    @State private var showGlobalSearch = false
    
    // View models
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var promptsViewModel: PromptsViewModel?
    
    // Scaled metrics for accessibility
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 28
    
    var body: some View {
        Group {
            switch coordinator.state {
            case .launching:
                MacLaunchView()
                
            case .unauthenticated:
                MacAuthView(coordinator: coordinator)
                
            case .authenticatedNeedsOnboarding,
                 .authenticatedNeedsE2EESetup,
                 .authenticatedNeedsE2EEUnlock,
                 .authenticatedNeedsAddApiKey:
                MacSetupFlowView(coordinator: coordinator)
                
            case .authenticated:
                authenticatedContent
            }
        }
        .task {
            await coordinator.determineInitialState()
            // Once auth state is determined, initialize if authenticated
            if case .authenticated = coordinator.state {
                await initializeViewModels()
            }
        }
        .onChange(of: coordinator.state) { _, newState in
            if case .authenticated = newState {
                Task { await initializeViewModels() }
            }
        }
    }
    
    // MARK: - Authenticated Content (2-column layout like ChatGPT)
    @ViewBuilder
    private var authenticatedContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Search + Navigation + List + User Profile
            sidebarColumn
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            // Detail: Chat or Note content
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            macToolbar
        }
        .onAppear {
            // Fallback: if view appears without task having fired (e.g., state restoration)
            if chatViewModel == nil {
                Task { await initializeViewModels() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.toggleSidebarNotification)) { _ in
            withAnimation {
                columnVisibility = columnVisibility == .all ? .detailOnly : .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.newChatNotification)) { _ in
            createNewChat()
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.quickMessageNotification)) { notification in
            handleQuickMessage(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.focusSearchNotification)) { _ in
            showGlobalSearch = true
        }
        // WebSocket sync: refetch when server pushes entity changes
        .onReceive(NotificationCenter.default.publisher(for: .syncChatsInvalidated)) { _ in
            Task { await chatListViewModel?.loadChats() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncNotesInvalidated)) { _ in
            Task { await notesViewModel?.loadNotes() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncFoldersInvalidated)) { _ in
            Task { await folderViewModel?.loadFolders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncPromptsInvalidated)) { _ in
            Task { await promptsViewModel?.loadPrompts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncCredentialsInvalidated)) { _ in
            Task {
                // Refetch credentials, then refresh available models
                let token = try? await dependencies.authService.getToken()
                if let token {
                    try? await dependencies.credentialService.fetchCredentials(token: token)
                    await chatViewModel?.modelSelector.fetchModels()
                }
            }
        }
        .sheet(isPresented: $showGlobalSearch) {
            GlobalSearchView(
                onSelectChat: { chatId in
                    selectedFolder = "all"
                    selectedChatId = chatId
                    selectChat(chatId)
                },
                onSelectNote: { noteId in
                    selectedFolder = "notes"
                    selectedNoteId = noteId
                    Task {
                        if let note = notesViewModel?.filteredNotes.first(where: { $0.id == noteId }) {
                            await notesViewModel?.editNote(note)
                        }
                    }
                },
                onSelectPrompt: { promptId in
                    selectedFolder = "prompts"
                    selectedPromptId = promptId
                    Task {
                        if let prompt = promptsViewModel?.filteredPrompts.first(where: { $0.id == promptId }) {
                            await promptsViewModel?.editPrompt(prompt)
                        }
                    }
                }
            )
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                dependencies.webSocketSyncService.disconnect()
                Task { await coordinator.handleSignOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Quick Message Handler
    
    private func handleQuickMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String else { return }
        
        Task {
            await chatViewModel?.createNewChat()
            chatViewModel?.inputText = message
            await chatViewModel?.sendMessage()
        }
    }
    
    // MARK: - Sidebar (Native macOS sidebar)
    
    @ViewBuilder
    private var sidebarColumn: some View {
        List(selection: currentListSelection) {
            // Navigation section
            Section {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarItem.chats)
                
                Label("Notes", systemImage: "note.text")
                    .tag(SidebarItem.notes)
                
                Label("Prompts", systemImage: "text.quote")
                    .tag(SidebarItem.prompts)
            }
            
            // Folder tree section (visible when viewing chats or notes)
            if !showingPrompts, let folderVM = folderViewModel {
                Section("Folders") {
                    FolderTreeView(
                        viewModel: folderVM,
                        selectedFolderId: selectedFolder == "all" ? nil : selectedFolder,
                        onSelectFolder: { folderId in
                            selectedFolder = folderId ?? "all"
                        },
                        showAllOption: true
                    )
                }
            }
            
            // Items section based on current view
            if showingNotes {
                notesListSection
            } else if showingPrompts {
                promptsListSection
            } else {
                chatsListSection
            }
        }
        .listStyle(.sidebar)
        .scrollIndicators(.hidden)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                userProfileButton
            }
            .background(.bar)
        }
    }
    
    // MARK: - Sidebar Selection Handling
    
    private enum SidebarItem: Hashable {
        case chats
        case notes
        case prompts
        case chat(String)
        case note(String)
        case prompt(String)
    }
    
    private var showingNotes: Bool {
        selectedFolder == "notes"
    }
    
    private var showingPrompts: Bool {
        selectedFolder == "prompts"
    }
    
    private var currentListSelection: Binding<SidebarItem?> {
        Binding(
            get: {
                if showingNotes {
                    if let noteId = selectedNoteId {
                        return .note(noteId)
                    }
                    return .notes
                } else if showingPrompts {
                    if let promptId = selectedPromptId {
                        return .prompt(promptId)
                    }
                    return .prompts
                } else {
                    if let chatId = selectedChatId {
                        return .chat(chatId)
                    }
                    return .chats
                }
            },
            set: { newValue in
                switch newValue {
                case .chats:
                    selectedFolder = "all"
                    selectedChatId = nil
                case .notes:
                    selectedFolder = "notes"
                    selectedNoteId = nil
                case .prompts:
                    selectedFolder = "prompts"
                    selectedPromptId = nil
                case .chat(let id):
                    selectedFolder = "all"
                    selectedChatId = id
                    selectChat(id)
                case .note(let id):
                    selectedFolder = "notes"
                    selectedNoteId = id
                    Task {
                        if let note = notesViewModel?.filteredNotes.first(where: { $0.id == id }) {
                            await notesViewModel?.editNote(note)
                        }
                    }
                case .prompt(let id):
                    selectedFolder = "prompts"
                    selectedPromptId = id
                    Task {
                        if let prompt = promptsViewModel?.filteredPrompts.first(where: { $0.id == id }) {
                            await promptsViewModel?.editPrompt(prompt)
                        }
                    }
                case .none:
                    break
                }
            }
        )
    }
    
    // MARK: - Chats List Section
    
    @ViewBuilder
    private var chatsListSection: some View {
        if let listViewModel = chatListViewModel {
            let grouped = filteredGroupedChats(from: listViewModel)
            if grouped.isEmpty {
                Section {
                    Text("No chats yet")
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                ForEach(grouped, id: \.0) { group, chats in
                    Section(group.displayName) {
                        ForEach(chats, id: \.id) { chat in
                            MacChatListRow(chat: chat)
                                .tag(SidebarItem.chat(chat.id))
                                .contextMenu {
                                    chatContextMenu(chat: chat, listViewModel: listViewModel)
                                }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Notes List Section
    
    @ViewBuilder
    private var notesListSection: some View {
        if let notesVM = notesViewModel {
            let notes = notesVM.filteredNotes
            if notes.isEmpty {
                Section {
                    Text("No notes yet")
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                Section("Notes") {
                    ForEach(notes) { note in
                        MacNoteListRow(note: note)
                            .tag(SidebarItem.note(note.id))
                            .contextMenu {
                                Button {
                                    Task { await notesVM.togglePinned(note) }
                                } label: {
                                    Label(note.pinned ? "Unpin" : "Pin", systemImage: note.pinned ? "pin.slash" : "pin")
                                }
                                
                                Button {
                                    Task { await notesVM.toggleArchived(note) }
                                } label: {
                                    Label(note.archived ? "Unarchive" : "Archive", systemImage: note.archived ? "tray.and.arrow.up" : "archivebox")
                                }
                                
                                if let folderVM = folderViewModel {
                                    Menu {
                                        Button {
                                            Task { await notesVM.moveToFolder(note, folderId: nil) }
                                        } label: {
                                            Label("No Folder", systemImage: "tray")
                                        }
                                        
                                        ForEach(folderVM.folders) { folder in
                                            Button {
                                                Task { await notesVM.moveToFolder(note, folderId: folder.id) }
                                            } label: {
                                                Label(folder.name, systemImage: "folder")
                                            }
                                        }
                                    } label: {
                                        Label("Move to Folder", systemImage: "folder")
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    Task { await notesVM.deleteNote(note) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Prompts List Section
    
    @ViewBuilder
    private var promptsListSection: some View {
        if let promptsVM = promptsViewModel {
            let prompts = promptsVM.filteredPrompts
            if prompts.isEmpty {
                Section {
                    Text("No prompts yet")
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            } else {
                Section("Prompts") {
                    ForEach(prompts) { prompt in
                        MacPromptListRow(prompt: prompt)
                            .tag(SidebarItem.prompt(prompt.id))
                            .contextMenu {
                                Button {
                                    Task { await promptsVM.editPrompt(prompt) }
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button {
                                    Task { await promptsVM.duplicatePrompt(prompt) }
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    Task { await promptsVM.deletePrompt(prompt) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - User Profile Button (ChatGPT style - just name with chevron)
    
    @ViewBuilder
    private var userProfileButton: some View {
        Menu {
            Button {
                openSettings()
            } label: {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: 10) {
                // Avatar circle with initials
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Text(currentUserInitials)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                
                // User name
                Text(currentUserName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
    
    private var currentUserName: String {
        dependencies.authService.currentUser?.displayName ?? "User"
    }
    
    private var currentUserInitials: String {
        dependencies.authService.currentUser?.initials ?? "U"
    }
    
    // MARK: - Detail Column
    
    @ViewBuilder
    private var detailColumn: some View {
        if showingNotes {
            notesDetailColumn
        } else if showingPrompts {
            promptsDetailColumn
        } else {
            chatsDetailColumn
        }
    }
    
    @ViewBuilder
    private var promptsDetailColumn: some View {
        if let promptsVM = promptsViewModel, promptsVM.editingPrompt != nil {
            PromptEditorView(viewModel: promptsVM)
        } else {
            promptsEmptyDetailView
        }
    }
    
    private var promptsEmptyDetailView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "text.quote")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(theme.textTertiary)
            
            Text("Select a prompt")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            
            Text("or create a new one")
                .font(.callout)
                .foregroundStyle(theme.textTertiary)
            
            Button {
                promptsViewModel?.createPrompt()
            } label: {
                Label("New Prompt", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var chatsDetailColumn: some View {
        if let viewModel = chatViewModel, viewModel.chat != nil || !viewModel.messages.isEmpty {
            HStack(spacing: 0) {
                MacChatView(
                    viewModel: viewModel,
                    promptSummaries: promptsViewModel?.prompts ?? [],
                    onFetchPromptContent: { summary in
                        await promptsViewModel?.usePrompt(summary)
                    }
                )
                
                if viewModel.showArtifactsPanel {
                    Divider()
                    
                    ArtifactsPanelView(
                        artifacts: ArtifactExtractor.extractArtifacts(from: viewModel.messages),
                        activeArtifactId: Binding(
                            get: { viewModel.activeArtifactId },
                            set: { viewModel.activeArtifactId = $0 }
                        ),
                        onClose: { viewModel.showArtifactsPanel = false }
                    )
                    .frame(width: 400)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showArtifactsPanel)
        } else {
            emptyDetailView
        }
    }
    
    @ViewBuilder
    private var notesDetailColumn: some View {
        if let notesVM = notesViewModel, notesVM.editingNote != nil {
            MacNoteEditorView(viewModel: notesVM)
        } else {
            notesEmptyDetailView
        }
    }
    
    private var notesEmptyDetailView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(theme.textTertiary)
            
            Text("Select a note")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            
            Text("or create a new one")
                .font(.callout)
                .foregroundStyle(theme.textTertiary)
            
            Button {
                notesViewModel?.createNote()
            } label: {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(theme.textTertiary)
            
            Text("Start a conversation")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
            
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("End-to-end encrypted")
            }
            .font(.caption)
            .foregroundStyle(theme.textTertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        // New chat/note/prompt button
        ToolbarItem(placement: .navigation) {
            Button {
                if showingNotes {
                    notesViewModel?.createNote()
                } else if showingPrompts {
                    promptsViewModel?.createPrompt()
                } else {
                    createNewChat()
                }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help(showingNotes ? "New Note (⌘N)" : showingPrompts ? "New Prompt (⌘N)" : "New Chat (⌘N)")
            .accessibilityLabel(showingNotes ? "New note" : showingPrompts ? "New prompt" : "New chat")
        }
        
        // Model selector (only for chats)
        ToolbarItem(placement: .principal) {
            if !showingNotes && !showingPrompts, let chatVM = chatViewModel {
                MacModelSelectorButton(viewModel: chatVM.modelSelector)
            }
        }
        
        // Artifacts toggle (only for chats with code)
        ToolbarItem(placement: .primaryAction) {
            if !showingNotes && !showingPrompts, let chatVM = chatViewModel,
               !ArtifactExtractor.extractArtifacts(from: chatVM.messages).isEmpty {
                Button {
                    withAnimation {
                        chatVM.showArtifactsPanel.toggle()
                    }
                } label: {
                    Image(systemName: chatVM.showArtifactsPanel ? "sidebar.trailing" : "sidebar.trailing")
                        .foregroundStyle(chatVM.showArtifactsPanel ? theme.accent : theme.textSecondary)
                }
                .help(chatVM.showArtifactsPanel ? "Hide Artifacts" : "Show Artifacts")
                .accessibilityLabel("Toggle artifacts panel")
            }
        }
        
        // Share menu (only when chat content is available)
        ToolbarItem(placement: .primaryAction) {
            if !showingNotes, chatViewModel?.chat != nil {
                Menu {
                    Button {
                        exportCurrentChatAsText()
                    } label: {
                        Label("Copy as Text", systemImage: "doc.text")
                    }
                    
                    Button {
                        exportCurrentChatAsMarkdown()
                    } label: {
                        Label("Copy as Markdown", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share")
                .accessibilityLabel("Share conversation")
            }
        }
    }
    
    // MARK: - Export Actions
    
    private func exportCurrentChatAsText() {
        guard let chat = chatViewModel?.chat else { return }
        let text = chat.messages.map { msg in
            let role = msg.isUser ? "You" : "Assistant"
            return "[\(role)]\n\(msg.content)\n"
        }.joined(separator: "\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    private func exportCurrentChatAsMarkdown() {
        guard let chat = chatViewModel?.chat else { return }
        let markdown = "# \(chat.title)\n\n" + chat.messages.map { msg in
            let role = msg.isUser ? "**You**" : "**Assistant**"
            return "\(role)\n\n\(msg.content)\n"
        }.joined(separator: "\n---\n\n")
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func chatContextMenu(chat: ChatSummary, listViewModel: ChatListViewModel) -> some View {
        // Primary actions
        Button {
            openWindow(value: chat.id)
        } label: {
            Label("Open in New Window", systemImage: "uiwindow.split.2x1")
        }
        
        Divider()
        
        // Pin / Archive
        Button {
            Task { await listViewModel.togglePinned(chat) }
        } label: {
            Label(chat.pinned ? "Unpin" : "Pin", systemImage: chat.pinned ? "pin.slash" : "pin")
        }
        
        Button {
            Task { await listViewModel.toggleArchived(chat) }
        } label: {
            Label(chat.archived ? "Unarchive" : "Archive", systemImage: chat.archived ? "tray.and.arrow.up" : "archivebox")
        }
        
        // Move to folder
        if let folderVM = folderViewModel {
            Menu {
                Button {
                    Task { await listViewModel.moveChatToFolder(chat, folderId: nil) }
                } label: {
                    Label("No Folder", systemImage: "tray")
                }
                
                ForEach(folderVM.folders) { folder in
                    Button {
                        Task { await listViewModel.moveChatToFolder(chat, folderId: folder.id) }
                    } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                }
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }
        }
        
        Divider()
        
        // Export actions
        Button {
            exportChatAsText(chat)
        } label: {
            Label("Export as Text", systemImage: "doc.text")
        }
        
        Button {
            exportChatAsMarkdown(chat)
        } label: {
            Label("Export as Markdown", systemImage: "doc.richtext")
        }
        
        Divider()
        
        // Destructive actions last - HIG
        Button(role: .destructive) {
            Task {
                await listViewModel.deleteChat(chat.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Context Menu Export Actions
    
    private func exportChatAsText(_ chat: ChatSummary) {
        Task {
            guard let fullChat = try? await dependencies.chatRepository.fetchChat(
                id: chat.id,
                token: try await dependencies.authService.getToken()
            ) else { return }
            
            let text = fullChat.messages.map { msg in
                let role = msg.isUser ? "You" : "Assistant"
                return "[\(role)]\n\(msg.content)\n"
            }.joined(separator: "\n")
            
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    }
    
    private func exportChatAsMarkdown(_ chat: ChatSummary) {
        Task {
            guard let fullChat = try? await dependencies.chatRepository.fetchChat(
                id: chat.id,
                token: try await dependencies.authService.getToken()
            ) else { return }
            
            let markdown = "# \(fullChat.title)\n\n" + fullChat.messages.map { msg in
                let role = msg.isUser ? "**You**" : "**Assistant**"
                return "\(role)\n\n\(msg.content)\n"
            }.joined(separator: "\n---\n\n")
            
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(markdown, forType: .string)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Idempotent initialization — safe to call multiple times (task + onAppear + onChange)
    private func initializeViewModels() async {
        if chatViewModel == nil {
            setupViewModels()
        }
        await chatViewModel?.loadModels()
        await chatListViewModel?.loadChats()
        await folderViewModel?.loadFolders()
        await notesViewModel?.loadNotes()
        await promptsViewModel?.loadPrompts()
        await connectWebSocket()
    }
    
    private func setupViewModels() {
        chatListViewModel = ChatListViewModel(
            authService: dependencies.authService,
            chatRepository: dependencies.chatRepository
        )
        
        chatViewModel = ChatViewModel(
            authService: dependencies.authService,
            chatRepository: dependencies.chatRepository,
            credentialService: dependencies.credentialService,
            llmService: dependencies.llmService,
            networkService: dependencies.networkService,
            speechService: dependencies.speechService,
            speechRecognitionService: dependencies.speechRecognitionService,
            onChatUpdated: { summary in
                chatListViewModel?.addOrUpdateChat(summary)
            }
        )
        
        folderViewModel = FolderViewModel(
            folderRepository: dependencies.folderRepository,
            authService: dependencies.authService,
            cryptoService: dependencies.extendedCryptoService,
            secureSession: dependencies.secureSession
        )
        
        notesViewModel = NotesViewModel(
            noteRepository: dependencies.noteRepository,
            authService: dependencies.authService
        )
        
        promptsViewModel = PromptsViewModel(
            promptRepository: dependencies.promptRepository,
            authService: dependencies.authService
        )
    }
    
    private func connectWebSocket() async {
        do {
            let token = try await dependencies.authService.getToken()
            dependencies.webSocketSyncService.connect(token: token)
        } catch {
            // Auth not available yet — WebSocket will connect later
        }
    }
    
    private func selectChat(_ id: String) {
        Task {
            await chatViewModel?.loadChat(id: id)
        }
    }
    
    private func createNewChat() {
        selectedChatId = nil
        Task {
            await chatViewModel?.createNewChat()
        }
    }
    
    private func filteredChats(from listViewModel: ChatListViewModel) -> [ChatSummary] {
        var chats = listViewModel.chats
        
        // Filter by folder
        if let folderId = selectedFolder, folderId != "all", folderId != "notes" {
            chats = chats.filter { $0.folderId == folderId }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            chats = chats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return chats
    }
    
    /// Returns chats grouped by time period (Today, Yesterday, Previous 7 Days, etc.)
    private func filteredGroupedChats(from listViewModel: ChatListViewModel) -> [(ChatGroup, [ChatSummary])] {
        let allGrouped = listViewModel.groupedChats
        
        // Apply folder and search filters to each group
        let hasFolder = selectedFolder != nil && selectedFolder != "all" && selectedFolder != "notes"
        let hasSearch = !searchText.isEmpty
        
        guard hasFolder || hasSearch else { return allGrouped }
        
        return allGrouped.compactMap { group, chats in
            var filtered = chats
            
            if hasFolder, let folderId = selectedFolder {
                filtered = filtered.filter { $0.folderId == folderId }
            }
            
            if hasSearch {
                filtered = filtered.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            }
            
            return filtered.isEmpty ? nil : (group, filtered)
        }
    }
    
}

// MARK: - Mac Chat List Row

struct MacChatListRow: View {
    let chat: ChatSummary
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title)
                    .lineLimit(1)
                
                Text(chat.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            
            Spacer()
            
            if chat.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.warning)
            }
            
            if chat.archived {
                Image(systemName: "archivebox.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - Mac Note List Row

struct MacNoteListRow: View {
    let note: NoteSummary
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .lineLimit(1)
                
                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            
            Spacer()
            
            if note.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.warning)
            }
        }
    }
}

// MARK: - Mac Prompt List Row

struct MacPromptListRow: View {
    let prompt: PromptSummary
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(prompt.name)
                .lineLimit(1)
            
            if let description = prompt.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            } else {
                Text(prompt.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - Mac Model Selector Button

struct MacModelSelectorButton: View {
    @Bindable var viewModel: ModelSelectorViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.theme) private var theme
    
    private var isPrivateSelected: Bool {
        viewModel.isPrivateModelSelected
    }
    
    var body: some View {
        Menu {
            if viewModel.isLoading {
                Section {
                    Label("Loading models...", systemImage: "arrow.trianglehead.2.clockwise")
                }
            } else if viewModel.allModels.isEmpty {
                Section {
                    Label("No models available", systemImage: "exclamationmark.triangle")
                    Button {
                        openSettings()
                    } label: {
                        Label("Add API Keys in Settings...", systemImage: "key")
                    }
                }
            } else {
                modelListContent
                
                Divider()
                
                managementMenus
            }
        } label: {
            triggerLabel
        }
        .fixedSize()
    }
    
    // MARK: - Trigger Label
    
    private var triggerLabel: some View {
        HStack(spacing: 4) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 12, height: 12)
            } else if isPrivateSelected {
                Image(systemName: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.success)
            }
            
            Text(viewModel.selectedModel?.displayName ?? "Select Model")
                .font(.subheadline.weight(.medium))
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Model List Content
    
    @ViewBuilder
    private var modelListContent: some View {
        // Pinned models
        if !viewModel.pinnedModels.isEmpty {
            Section("Pinned") {
                ForEach(viewModel.pinnedModels) { model in
                    modelButton(model)
                }
            }
        }
        
        // Recent models (excludes pinned)
        if !viewModel.recentModels.isEmpty {
            Section("Recent") {
                ForEach(viewModel.recentModels) { model in
                    modelButton(model)
                }
            }
        }
        
        // All models grouped by provider
        ForEach(viewModel.groupedModels, id: \.provider) { group in
            Section(group.provider.displayName) {
                ForEach(group.models) { model in
                    modelButton(model)
                }
            }
        }
    }
    
    // MARK: - Model Button
    
    @ViewBuilder
    private func modelButton(_ model: ModelOption) -> some View {
        Button {
            viewModel.selectModel(model)
        } label: {
            HStack(spacing: 6) {
                if model.provider == .private {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(theme.success)
                }
                
                Text(model.displayName)
                
                Spacer()
                
                if viewModel.isPinned(model.id) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.warning)
                }
                
                if viewModel.selectedModel?.id == model.id {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Management Submenus
    
    @ViewBuilder
    private var managementMenus: some View {
        // Provider filter
        if viewModel.availableProviders.count > 1 {
            Menu {
                Button {
                    viewModel.connectionFilter = nil
                } label: {
                    HStack {
                        Text("All Providers")
                        if viewModel.connectionFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
                
                ForEach(viewModel.availableProviders, id: \.self) { provider in
                    Button {
                        viewModel.connectionFilter = viewModel.connectionFilter == provider ? nil : provider
                    } label: {
                        HStack {
                            if provider == .private {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(theme.success)
                            }
                            Text(provider.displayName)
                            if viewModel.connectionFilter == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(
                    viewModel.connectionFilter?.displayName ?? "Filter by Provider",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }
        }
        
        // Pin management
        Menu {
            ForEach(viewModel.allModels) { model in
                Button {
                    viewModel.togglePin(model.id)
                } label: {
                    HStack {
                        if model.provider == .private {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(theme.success)
                        }
                        Text(model.displayName)
                        Spacer()
                        Image(systemName: viewModel.isPinned(model.id) ? "pin.slash" : "pin")
                    }
                }
            }
        } label: {
            Label("Manage Pinned", systemImage: "pin")
        }
    }
}

// MARK: - Launch View

struct MacLaunchView: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Auth View (Compact, centered - like native macOS login)

struct MacAuthView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    @State private var viewModel: AuthViewModel?
    @State private var isHoveringGoogle = false
    
    var body: some View {
        // Centered compact login card
        VStack(spacing: 32) {
            // Logo and title
            VStack(spacing: 16) {
                // App icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(theme.textPrimary)
                
                VStack(spacing: 4) {
                    Text("Onera")
                        .font(.title2.bold())
                    
                    Text("Private AI conversations")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .demoModeActivation()
            
            // Sign in buttons
            VStack(spacing: 10) {
                // Sign in with Apple
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.textPrimary)
                    
                    SignInWithAppleButton(.continue) { request in
                        viewModel?.configureAppleRequest(request)
                    } onCompletion: { result in
                        Task { await viewModel?.handleAppleSignIn(result: result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                }
                .frame(width: 240, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(viewModel?.isLoading ?? false)
                
                // Sign in with Google
                Button {
                    Task { await viewModel?.signInWithGoogle() }
                } label: {
                    HStack(spacing: 8) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                        Text("Continue with Google")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(width: 240, height: 40)
                    .foregroundStyle(theme.textPrimary)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel?.isLoading ?? false)
            }
            
            // Loading indicator
            if viewModel?.isLoading ?? false {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // Terms and privacy
            HStack(spacing: 4) {
                Link("Terms", destination: URL(string: "https://onera.app/terms")!)
                Text("·")
                    .foregroundStyle(theme.textTertiary)
                Link("Privacy", destination: URL(string: "https://onera.app/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(40)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.background)
                .shadow(color: theme.textPrimary.opacity(0.15), radius: 20, y: 10)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.tertiaryBackground)
        .onAppear {
            viewModel = AuthViewModel(
                authService: dependencies.authService,
                onSuccess: { await coordinator.handleAuthenticationSuccess() }
            )
        }
        .alert("Error", isPresented: .init(
            get: { viewModel?.showError ?? false },
            set: { if !$0 { viewModel?.clearError() } }
        )) {
            Button("OK") { viewModel?.clearError() }
        } message: {
            if let error = viewModel?.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Setup Flow View

struct MacSetupFlowView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    
    var body: some View {
        VStack {
            switch coordinator.state {
            case .authenticatedNeedsOnboarding:
                OnboardingView(onComplete: { coordinator.handleOnboardingComplete() })
                
            case .authenticatedNeedsE2EESetup:
                E2EESetupView(
                    viewModel: E2EESetupViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EESetupComplete() }
                    )
                )
                
            case .authenticatedNeedsE2EEUnlock:
                E2EEUnlockView(
                    viewModel: E2EEUnlockViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EEUnlockComplete() }
                    ),
                    onComplete: { coordinator.handleE2EEUnlockComplete() },
                    onSignOut: { Task { await coordinator.handleSignOut() } }
                )
                
            case .authenticatedNeedsAddApiKey:
                MacApiKeySetupView(coordinator: coordinator)
                
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - API Key Setup View

struct MacApiKeySetupView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    @Environment(\.theme) private var theme
    @State private var selectedProvider: LLMProvider?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Add an API Key")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose a provider to get started")
                .foregroundStyle(theme.textSecondary)
            
            // Provider selection would go here
            
            HStack {
                Button("Skip for Now") {
                    coordinator.handleAddApiKeyComplete()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
}

#endif // os(macOS)
