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
                .background(theme.secondaryBackground)
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
    
    // MARK: - Sidebar (Codex-style navigation)
    
    @ViewBuilder
    private var sidebarColumn: some View {
        List(selection: currentListSelection) {
            // Navigation items
            Section {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarItem.chats)
                
                Label("Notes", systemImage: "note.text")
                    .tag(SidebarItem.notes)
                
                Label("Prompts", systemImage: "text.quote")
                    .tag(SidebarItem.prompts)
            }
            
            // Content: Notes, Prompts, or Chats
            if showingNotes {
                notesListSection
            } else if showingPrompts {
                promptsListSection
            } else {
                // Chats section with project grouping
                Section {
                    projectThreadsSections
                } header: {
                    Text("Chats")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.textTertiary)
                }
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
        .background(theme.background)
        .sheet(isPresented: Binding(
            get: { folderViewModel?.isCreatingFolder ?? false },
            set: { if !$0 { folderViewModel?.cancelCreatingFolder() } }
        )) {
            newProjectSheet
        }
    }
    
    // MARK: - User Profile Button (ChatGPT style)
    
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
            HStack(spacing: OneraSpacing.sm) {
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
            .padding(.horizontal, OneraSpacing.md)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
    
    // MARK: - Project/Threads Sections (T3 Code style)
    
    @ViewBuilder
    private var projectThreadsSections: some View {
        if let listViewModel = chatListViewModel, let folderVM = folderViewModel {
            // Group chats by folder (project)
            let projectGroups = projectGroupedChats(
                chats: filteredChats(from: listViewModel),
                folders: folderVM.folders
            )
            
            // Each folder = a project section with disclosure
            ForEach(Array(projectGroups.enumerated()), id: \.offset) { _, group in
                Section(isExpanded: projectExpandedBinding(for: group.folder?.id)) {
                    ForEach(group.chats, id: \.id) { chat in
                        MacThreadListRow(
                            chat: chat,
                            isSelected: selectedChatId == chat.id
                        )
                        .tag(SidebarItem.chat(chat.id))
                        .contextMenu {
                            chatContextMenu(chat: chat, listViewModel: listViewModel)
                        }
                    }
                    
                    // "+ New Chat" button inside each project
                    Button {
                        createNewChatInFolder(group.folder?.id)
                    } label: {
                        HStack(spacing: OneraSpacing.xxs) {
                            OneraIcon.plus.image
                                .font(.caption2)
                            Text("New Chat")
                                .font(.caption)
                        }
                        .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                } header: {
                    HStack {
                        if let folder = group.folder {
                            Text(folder.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textPrimary)
                        } else {
                            Text("Threads")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                        
                        Spacer()
                        
                        Text("\(group.chats.count)")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
        }
    }
    
    // MARK: - New Project Sheet
    
    private var newProjectSheet: some View {
        VStack(spacing: OneraSpacing.lg) {
            Text("New Project")
                .font(.headline)
            
            TextField("Project name", text: Binding(
                get: { folderViewModel?.newFolderName ?? "" },
                set: { folderViewModel?.newFolderName = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    folderViewModel?.cancelCreatingFolder()
                }
                .keyboardShortcut(.escape)
                
                Button("Create") {
                    Task { await folderViewModel?.createFolder() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(folderViewModel?.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
        }
        .padding(OneraSpacing.lg)
        .frame(width: 300)
    }
    
    // MARK: - Project Grouping
    
    struct ProjectGroup {
        let folder: Folder?
        let chats: [ChatSummary]
    }
    
    private func projectGroupedChats(chats: [ChatSummary], folders: [Folder]) -> [ProjectGroup] {
        var groups: [ProjectGroup] = []
        
        // Group chats by folderId
        let chatsByFolder = Dictionary(grouping: chats) { $0.folderId }
        
        // Create a group for each folder that has chats or exists
        for folder in folders.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let folderChats = (chatsByFolder[folder.id] ?? [])
                .sorted { $0.updatedAt > $1.updatedAt }
            // Show folder even if empty (user created it as a project)
            groups.append(ProjectGroup(folder: folder, chats: folderChats))
        }
        
        // Unfiled chats (no folder)
        let unfiledChats = (chatsByFolder[nil] ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
        if !unfiledChats.isEmpty {
            groups.append(ProjectGroup(folder: nil, chats: unfiledChats))
        }
        
        return groups
    }
    
    @State private var expandedProjects: Set<String> = []
    
    private func projectExpandedBinding(for folderId: String?) -> Binding<Bool> {
        let key = folderId ?? "__unfiled__"
        return Binding(
            get: { expandedProjects.contains(key) || expandedProjects.isEmpty },
            set: { isExpanded in
                // Initialize all as expanded on first interaction
                if expandedProjects.isEmpty {
                    let allKeys = (folderViewModel?.folders.map(\.id) ?? []) + ["__unfiled__"]
                    expandedProjects = Set(allKeys)
                }
                if isExpanded {
                    expandedProjects.insert(key)
                } else {
                    expandedProjects.remove(key)
                }
            }
        )
    }
    
    private func createNewChatInFolder(_ folderId: String?) {
        selectedChatId = nil
        Task {
            await chatViewModel?.createNewChat()
            if let folderId, let chatId = chatViewModel?.chat?.id {
                await chatListViewModel?.moveChatToFolder(
                    ChatSummary(id: chatId, title: "New Chat", createdAt: Date(), updatedAt: Date(), folderId: folderId),
                    folderId: folderId
                )
            }
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
                        .padding(.vertical, OneraSpacing.xl)
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
                        .padding(.vertical, OneraSpacing.xl)
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
                        .padding(.vertical, OneraSpacing.xl)
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
        VStack(spacing: OneraSpacing.md) {
            Spacer()
            
            OneraIcon.quote.image
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
        VStack(spacing: OneraSpacing.md) {
            Spacer()
            
            OneraIcon.note.image
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
        VStack(spacing: OneraSpacing.md) {
            Spacer()
            
            OneraIcon.chatWithText.image
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.textTertiary)
            
            VStack(spacing: OneraSpacing.xxs) {
                Text("Select a thread")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
                
                Text("or create a new one to get started")
                    .font(.callout)
                    .foregroundStyle(theme.textTertiary)
            }
            
            Button {
                createNewChat()
            } label: {
                HStack(spacing: OneraSpacing.xxs) {
                    OneraIcon.plus.image
                        .font(.caption)
                    Text("New Thread")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
            HStack(spacing: OneraSpacing.xxs) {
                OneraIcon.lock.solidImage
                    .font(.caption2)
                Text("End-to-end encrypted")
            }
            .font(.caption)
            .foregroundStyle(theme.textTertiary)
            .padding(.top, OneraSpacing.sm)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar (Codex style: "New Chat" left, title center, actions right)
    
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        // Left: "New Chat" button in toolbar
        ToolbarItem(placement: .navigation) {
            Button {
                createNewChat()
            } label: {
                Text("New Chat")
                    .font(.subheadline)
            }
        }
        
        // Center: Thread title + project badge
        ToolbarItem(placement: .principal) {
            if !showingNotes && !showingPrompts, let chatVM = chatViewModel {
                HStack(spacing: OneraSpacing.xs) {
                    Text(chatVM.chat?.title ?? "New Thread")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Project badge (folder name)
                    if let folderId = chatVM.chat?.folderId,
                       let folder = folderViewModel?.getFolder(id: folderId) {
                        Text(folder.name)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, OneraSpacing.xs)
                            .padding(.vertical, 2)
                            .background(theme.accent.opacity(0.15))
                            .foregroundStyle(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.xs, style: .continuous))
                            .layoutPriority(-1)
                    }
                }
                .frame(maxWidth: 400)
            } else if showingNotes {
                Text("Notes")
                    .font(.subheadline.weight(.medium))
            } else if showingPrompts {
                Text("Prompts")
                    .font(.subheadline.weight(.medium))
            }
        }
        
        // Right: Open dropdown + more actions
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: OneraSpacing.sm) {
                if !showingNotes && !showingPrompts {
                    // "Open" dropdown (Codex style)
                    if let chatVM = chatViewModel, chatVM.chat != nil {
                        Menu {
                            Button {
                                if let chatId = chatVM.chat?.id {
                                    openWindow(value: chatId)
                                }
                            } label: {
                                Label("Open in New Window", systemImage: "uiwindow.split.2x1")
                            }
                            
                            if !ArtifactExtractor.extractArtifacts(from: chatVM.messages).isEmpty {
                                Button {
                                    withAnimation { chatVM.showArtifactsPanel.toggle() }
                                } label: {
                                    Label(
                                        chatVM.showArtifactsPanel ? "Hide Artifacts" : "Show Artifacts",
                                        systemImage: "sidebar.trailing"
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: OneraSpacing.xxs) {
                                OneraIcon.openInApp.image
                                    .font(.caption)
                                Text("Open")
                                    .font(.caption)
                            }
                            .padding(.horizontal, OneraSpacing.xs)
                            .padding(.vertical, OneraSpacing.xxs)
                            .background(theme.tertiaryBackground)
                            .clipShape(Capsule())
                        }
                        .menuIndicator(.hidden)
                    }
                    
                    // Export/share
                    if let chatVM = chatViewModel, chatVM.chat != nil {
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
                            OneraIcon.share.image
                                .font(.subheadline)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .menuIndicator(.hidden)
                    }
                }
                
                // Global search
                Button {
                    showGlobalSearch = true
                } label: {
                    OneraIcon.search.image
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                .help("Search (⌘F)")
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

// MARK: - Mac Chat List Row (legacy)

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
                OneraIcon.pin.solidImage
                    .font(.caption2)
                    .foregroundStyle(theme.warning)
            }
            
            if chat.archived {
                OneraIcon.archive.solidImage
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - Mac Thread List Row (T3 Code style)

struct MacThreadListRow: View {
    let chat: ChatSummary
    let isSelected: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: OneraSpacing.xs) {
            Text(chat.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            
            Spacer()
            
            Text(chat.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, OneraSpacing.xxxs)
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
                OneraIcon.pin.solidImage
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
        HStack(spacing: OneraSpacing.xxs) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: OneraIconSize.xs, height: OneraIconSize.xs)
            } else if isPrivateSelected {
                OneraIcon.shield.solidImage
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
            HStack(spacing: OneraSpacing.xs) {
                if model.provider == .private {
                    OneraIcon.shield.solidImage
                        .font(.caption)
                        .foregroundStyle(theme.success)
                }
                
                Text(model.displayName)
                
                Spacer()
                
                if viewModel.isPinned(model.id) {
                    OneraIcon.pin.solidImage
                        .font(.caption2)
                        .foregroundStyle(theme.warning)
                }
                
                if viewModel.selectedModel?.id == model.id {
                    OneraIcon.checkSimple.image
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
                            OneraIcon.checkSimple.image
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
                                OneraIcon.shield.solidImage
                                    .foregroundStyle(theme.success)
                            }
                            Text(provider.displayName)
                            if viewModel.connectionFilter == provider {
                                OneraIcon.checkSimple.image
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
                            OneraIcon.shield.solidImage
                                .foregroundStyle(theme.success)
                        }
                        Text(model.displayName)
                        Spacer()
                        (viewModel.isPinned(model.id) ? OneraIcon.pinOff.image : OneraIcon.pin.image)
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
        VStack(spacing: OneraSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Auth View (Codex-style: full-window dark, centered, large pill buttons)

struct MacAuthView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    @State private var viewModel: AuthViewModel?
    @State private var isHoveringGoogle = false
    @State private var isHoveringApple = false
    
    // Dark background color matching Codex welcome screen
    private var authBackground: Color { theme.onboardingSheetBackground }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: OneraSpacing.xl) {
                // App icon
                OneraIcon.chat.solidImage
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(theme.onboardingTextPrimary)
                    .demoModeActivation()
                
                // Title + subtitle
                VStack(spacing: OneraSpacing.sm) {
                    Text("Welcome to Onera")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(theme.onboardingTextPrimary)
                    
                    Text("The best way to chat with AI, privately")
                        .font(.title3)
                        .foregroundStyle(theme.onboardingTextSecondary)
                }
                
                // Large pill sign-in buttons
                VStack(spacing: OneraSpacing.sm) {
                    // Continue with Apple — native SignInWithAppleButton overlaid on custom style
                    ZStack {
                        // Visual layer: custom styled button
                        HStack(spacing: OneraSpacing.sm) {
                            Image(systemName: "apple.logo")
                                .font(.body.weight(.medium))
                            Text("Continue with Apple")
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(.black)
                        .frame(width: 340, height: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous))
                        
                        // Functional layer: native Apple sign-in (handles auth correctly)
                        SignInWithAppleButton(.continue) { request in
                            viewModel?.configureAppleRequest(request)
                        } onCompletion: { result in
                            Task { await viewModel?.handleAppleSignIn(result: result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .blendMode(.overlay)
                        .opacity(0.02)
                        .allowsHitTesting(true)
                    }
                    .frame(width: 340, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous))
                    .scaleEffect(isHoveringApple ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringApple)
                    .onHover { isHoveringApple = $0 }
                    .disabled(viewModel?.isLoading ?? false)
                    
                    // Continue with Google - bordered pill
                    Button {
                        Task { await viewModel?.signInWithGoogle() }
                    } label: {
                        HStack(spacing: OneraSpacing.sm) {
                            Image("google")
                                .resizable()
                                .scaledToFit()
                                .frame(width: OneraIconSize.sm, height: OneraIconSize.sm)
                            Text("Continue with Google")
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(theme.onboardingTextPrimary)
                        .frame(width: 340, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: OneraRadius.xxl, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isHoveringGoogle ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringGoogle)
                    .onHover { isHoveringGoogle = $0 }
                    .disabled(viewModel?.isLoading ?? false)
                }
                
                // Loading indicator
                if viewModel?.isLoading ?? false {
                    ProgressView()
                        .tint(theme.onboardingTextPrimary)
                        .scaleEffect(0.8)
                }
            }
            
            Spacer()
            
            // Terms at very bottom
            HStack(spacing: OneraSpacing.xs) {
                Link("Terms", destination: URL(string: "https://onera.chat/terms")!)
                Text("·")
                Link("Privacy", destination: URL(string: "https://onera.chat/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(theme.onboardingTextTertiary)
            .padding(.bottom, OneraSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(authBackground)
        .ignoresSafeArea(.all)
        .toolbarBackground(.hidden, for: .windowToolbar)
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
        VStack(spacing: OneraSpacing.lg) {
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
        .padding(OneraSpacing.xxl)
    }
}

#endif // os(macOS)
