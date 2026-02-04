//
//  AdaptiveMainView.swift
//  Onera
//
//  Adaptive navigation that switches between drawer (iPhone) and split view (iPad/Mac)
//

import SwiftUI

/// Navigation mode for iPad sidebar
enum SidebarSection: String, CaseIterable, Identifiable {
    case chats = "Chats"
    case notes = "Notes"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right"
        case .notes: return "note.text"
        }
    }
}

struct AdaptiveMainView: View {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dependencies) private var dependencies
    
    // Shared state across both navigation modes
    @State private var selectedChatId: String?
    @State private var selectedNoteId: String?
    @State private var showSettings = false
    @State private var showNotes = false // Only used for iPhone
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // iPad: Track which section is active (Chats or Notes)
    @State private var selectedSection: SidebarSection = .chats
    
    // View models (shared)
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    
    let onSignOut: () async -> Void
    
    /// Detect if running on iPad
    private var isIPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            // macOS always uses split view
            splitNavigationView
            #else
            // iOS/iPadOS: Adaptive based on size class
            if horizontalSizeClass == .compact {
                // iPhone: Use drawer navigation
                drawerNavigationView
            } else {
                // iPad: Use split view
                splitNavigationView
            }
            #endif
        }
        // iPad: Use popover for Settings (per Apple HIG)
        // iPhone/macOS: Use sheet
        #if os(iOS)
        .popover(isPresented: $showSettings, arrowEdge: .leading) {
            if let viewModel = settingsViewModel {
                if isIPad {
                    SettingsView(viewModel: viewModel)
                        .frame(minWidth: 400, idealWidth: 450, minHeight: 600, idealHeight: 700)
                } else {
                    SettingsView(viewModel: viewModel)
                }
            }
        }
        #else
        .sheet(isPresented: $showSettings) {
            if let viewModel = settingsViewModel {
                SettingsView(viewModel: viewModel)
            }
        }
        #endif
        // iPhone only: Use sheet for Notes (iPad uses integrated navigation)
        #if os(iOS)
        .sheet(isPresented: $showNotes) {
            notesSheet
        }
        #else
        .sheet(isPresented: $showNotes) {
            notesSheet
        }
        #endif
        .task {
            setupViewModels()
            await chatListViewModel?.loadChats()
        }
    }
    
    // MARK: - Drawer Navigation (iPhone)
    
    @ViewBuilder
    private var drawerNavigationView: some View {
        MainView(onSignOut: onSignOut)
    }
    
    // MARK: - Split Navigation (iPad/Mac)
    
    @ViewBuilder
    private var splitNavigationView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Section selector and folders
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } content: {
            // Content - Chat list or Notes list based on selection
            Group {
                if selectedSection == .chats {
                    if let listViewModel = chatListViewModel {
                        chatListContent(listViewModel)
                    }
                } else {
                    if let notesVM = notesViewModel {
                        notesListContent(notesVM)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            // Detail - Active chat or note based on selection
            if selectedSection == .chats {
                chatDetailContent
            } else {
                noteDetailContent
            }
        }
        .navigationSplitViewStyle(.balanced)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                keyboardToolbar
            }
        }
        #endif
    }
    
    // MARK: - Sidebar Content
    
    @ViewBuilder
    private var sidebarContent: some View {
        if let folderVM = folderViewModel {
            SidebarView(
                folderViewModel: folderVM,
                selectedChatId: $selectedChatId,
                selectedSection: $selectedSection,
                onNewChat: createNewChat,
                onOpenSettings: { showSettings = true },
                onNewNote: { notesViewModel?.createNote() },
                user: dependencies.authService.currentUser,
                onMoveChat: { chatId, folderId in
                    Task {
                        await moveChatToFolder(chatId: chatId, folderId: folderId)
                    }
                }
            )
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if selectedSection == .chats {
                            createNewChat()
                        } else {
                            notesViewModel?.createNote()
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help(selectedSection == .chats ? "New Chat" : "New Note")
                    .oneraShortcut(.newChat)
                }
            }
            #endif
        } else {
            ProgressView()
        }
    }
    
    // MARK: - Chat List Content
    
    @ViewBuilder
    private func chatListContent(_ listViewModel: ChatListViewModel) -> some View {
        List(selection: $selectedChatId) {
            ForEach(listViewModel.groupedChats, id: \.0) { group, chats in
                Section(group.displayName) {
                    ForEach(chats) { chat in
                        ChatRowView(chat: chat, isSelected: selectedChatId == chat.id)
                            .tag(chat.id)
                            .contextMenu {
                                chatContextMenu(for: chat, listViewModel: listViewModel)
                            } preview: {
                                // iPad: Context menu preview
                                ChatPreviewView(chat: chat)
                            }
                    }
                }
            }
        }
        .listStyle(.plain) // HIG: Middle column uses plain style, not sidebar
        .navigationTitle("Chats")
        .refreshable {
            await listViewModel.loadChats()
        }
        #if os(iOS)
        .searchable(text: .constant(""), placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
        #else
        .searchable(text: .constant(""), prompt: "Search chats")
        #endif
        .onChange(of: selectedChatId) { _, newId in
            if let id = newId {
                selectChat(id)
            }
        }
        // iPad/macOS: Keyboard navigation
        #if os(iOS)
        .focusable()
        .onKeyPress(.upArrow) {
            navigateToPreviousChat(in: listViewModel)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateToNextChat(in: listViewModel)
            return .handled
        }
        .onKeyPress(.return) {
            // Enter key opens selected chat (already handled by selection)
            return .handled
        }
        #endif
    }
    
    /// Navigate to previous chat in the list
    private func navigateToPreviousChat(in listViewModel: ChatListViewModel) {
        let allChats = listViewModel.groupedChats.flatMap { $0.1 }
        guard !allChats.isEmpty else { return }
        
        if let currentId = selectedChatId,
           let currentIndex = allChats.firstIndex(where: { $0.id == currentId }),
           currentIndex > 0 {
            selectedChatId = allChats[currentIndex - 1].id
        } else if selectedChatId == nil {
            selectedChatId = allChats.first?.id
        }
    }
    
    /// Navigate to next chat in the list
    private func navigateToNextChat(in listViewModel: ChatListViewModel) {
        let allChats = listViewModel.groupedChats.flatMap { $0.1 }
        guard !allChats.isEmpty else { return }
        
        if let currentId = selectedChatId,
           let currentIndex = allChats.firstIndex(where: { $0.id == currentId }),
           currentIndex < allChats.count - 1 {
            selectedChatId = allChats[currentIndex + 1].id
        } else if selectedChatId == nil {
            selectedChatId = allChats.first?.id
        }
    }
    
    // MARK: - Chat Detail Content
    
    @ViewBuilder
    private var chatDetailContent: some View {
        if let viewModel = chatViewModel {
            ChatView(
                viewModel: viewModel,
                onMenuTap: {
                    withAnimation {
                        columnVisibility = .all
                    }
                },
                onNewConversation: createNewChat,
                showCustomNavBar: false // iPad/Mac uses native nav
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Toggle sidebar/columns button
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation {
                            toggleColumnVisibility()
                        }
                    } label: {
                        Image(systemName: columnVisibility == .detailOnly ? "sidebar.left" : "sidebar.squares.left")
                    }
                    .accessibilityLabel(columnVisibility == .detailOnly ? "Show sidebar" : "Hide sidebar")
                }
                
                // Center: Model selector
                ToolbarItem(placement: .principal) {
                    modelSelectorButton
                }
                
                // Trailing: New chat
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            #endif
        } else {
            emptyDetailView
        }
    }
    
    /// Toggle between showing all columns and detail-only
    private func toggleColumnVisibility() {
        if columnVisibility == .detailOnly {
            columnVisibility = .all
        } else {
            columnVisibility = .detailOnly
        }
    }
    
    // MARK: - Empty Detail View
    
    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("Select a chat or start a new conversation")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Button {
                createNewChat()
            } label: {
                Label("New Chat", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .oneraShortcut(.newChat)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Model Selector Button
    
    @ViewBuilder
    private var modelSelectorButton: some View {
        if let chatVM = chatViewModel {
            Button {
                // Open model selector
            } label: {
                HStack(spacing: 4) {
                    Text(chatVM.modelSelector.selectedModel?.displayName ?? "Select Model")
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Keyboard Toolbar
    
    private var keyboardToolbar: some View {
        HStack {
            Spacer()
            Button("Done") {
                KeyboardService.shared.dismiss()
            }
        }
    }
    
    // MARK: - Notes List Content (iPad - middle column)
    
    @ViewBuilder
    private func notesListContent(_ notesVM: NotesViewModel) -> some View {
        NotesListView(
            viewModel: notesVM,
            folderViewModel: folderViewModel,
            showEditorInSheet: false // iPad uses detail column for note editor
        )
        .navigationTitle("Notes")
    }
    
    // MARK: - Note Detail Content (iPad - detail column)
    
    @ViewBuilder
    private var noteDetailContent: some View {
        if let notesVM = notesViewModel, notesVM.showNoteEditor {
            NoteEditorView(viewModel: notesVM, folderViewModel: folderViewModel)
        } else {
            // Empty state for notes
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.5))
                
                Text("Select a note or create a new one")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Button {
                    notesViewModel?.createNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Notes Sheet (iPhone only)
    
    @ViewBuilder
    private var notesSheet: some View {
        if let notesVM = notesViewModel {
            NavigationStack {
                NotesListView(
                    viewModel: notesVM,
                    folderViewModel: folderViewModel
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showNotes = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func chatContextMenu(for chat: ChatSummary, listViewModel: ChatListViewModel) -> some View {
        Button {
            Task {
                await listViewModel.deleteChat(chat.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        if let folderVM = folderViewModel, !folderVM.folders.isEmpty {
            Menu("Move to Folder") {
                Button("No Folder") {
                    Task {
                        await moveChatToFolder(chatId: chat.id, folderId: nil)
                    }
                }
                Divider()
                ForEach(folderVM.folders) { folder in
                    Button(folder.name) {
                        Task {
                            await moveChatToFolder(chatId: chat.id, folderId: folder.id)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
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
        
        settingsViewModel = SettingsViewModel(
            authService: dependencies.authService,
            e2eeService: dependencies.e2eeService,
            secureSession: dependencies.secureSession,
            credentialService: dependencies.credentialService,
            networkService: dependencies.networkService,
            cryptoService: dependencies.cryptoService,
            extendedCryptoService: dependencies.extendedCryptoService,
            onSignOut: onSignOut
        )
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
    
    private func moveChatToFolder(chatId: String, folderId: String?) async {
        do {
            let token = try await dependencies.authService.getToken()
            try await dependencies.chatRepository.updateChatFolder(
                chatId: chatId,
                folderId: folderId,
                token: token
            )
            await chatListViewModel?.loadChats()
        } catch {
            print("[AdaptiveMainView] Failed to move chat to folder: \(error)")
        }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chat: ChatSummary
    let isSelected: Bool
    
    @Environment(\.theme) private var theme
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(chat.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        // iPad/macOS: Hover effect for trackpad/mouse users
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .onHover { hovering in
            isHovered = hovering
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered && !isSelected ? theme.secondaryBackground.opacity(0.5) : Color.clear)
        )
        // iPad/macOS: Drag and drop support
        .draggable(chat.id) {
            // Drag preview
            HStack {
                Image(systemName: "bubble.left.fill")
                    .foregroundStyle(.secondary)
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Chat Preview View (Context Menu Preview)

/// Preview view shown when long-pressing a chat on iPad (context menu preview)
struct ChatPreviewView: View {
    let chat: ChatSummary
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "bubble.left.fill")
                    .foregroundStyle(theme.accent)
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
            }
            
            Divider()
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text("Updated \(chat.updatedAt, style: .relative)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("Created \(chat.createdAt, style: .date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 280, height: 160)
        .background(theme.background)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("iPad Split View") {
    AdaptiveMainView(onSignOut: {})
        .withDependencies(MockDependencyContainer())
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone Drawer") {
    AdaptiveMainView(onSignOut: {})
        .withDependencies(MockDependencyContainer())
        .environment(\.horizontalSizeClass, .compact)
}
#endif
