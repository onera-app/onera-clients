//
//  AdaptiveMainView.swift
//  Onera
//
//  Adaptive navigation that switches between drawer (iPhone) and split view (iPad/Mac)
//

import SwiftUI

struct AdaptiveMainView: View {
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dependencies) private var dependencies
    
    // Shared state across both navigation modes
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    // View models (shared)
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    
    let onSignOut: () async -> Void
    
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
        .sheet(isPresented: $showSettings) {
            if let viewModel = settingsViewModel {
                SettingsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showNotes) {
            notesSheet
        }
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
            // Sidebar - Folders and Chat List
            sidebarContent
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } content: {
            // Content - Chat list within selected folder (optional middle column)
            if let listViewModel = chatListViewModel {
                chatListContent(listViewModel)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
            }
        } detail: {
            // Detail - Active chat
            chatDetailContent
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
                onNewChat: createNewChat,
                onOpenSettings: { showSettings = true },
                onOpenNotes: { showNotes = true },
                user: dependencies.authService.currentUser
            )
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New Chat")
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
            ForEach(listViewModel.groupedChats.keys.sorted(), id: \.self) { group in
                Section(group.displayName) {
                    if let chats = listViewModel.groupedChats[group] {
                        ForEach(chats) { chat in
                            ChatRowView(chat: chat, isSelected: selectedChatId == chat.id)
                                .tag(chat.id)
                                .contextMenu {
                                    chatContextMenu(for: chat, listViewModel: listViewModel)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chats")
        .refreshable {
            await listViewModel.loadChats()
        }
        .searchable(text: .constant(""), prompt: "Search chats")
        .onChange(of: selectedChatId) { _, newId in
            if let id = newId {
                selectChat(id)
            }
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
                ToolbarItem(placement: .principal) {
                    modelSelectorButton
                }
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
    
    // MARK: - Notes Sheet
    
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
