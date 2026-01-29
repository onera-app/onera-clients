//
//  MacMainView.swift
//  Onera (macOS)
//
//  Main window view with 3-column NavigationSplitView
//

import SwiftUI

struct MacMainView: View {
    
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    @Environment(\.openWindow) private var openWindow
    
    // Navigation state
    @State private var selectedFolder: String? = "all"
    @State private var selectedChatId: String?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText = ""
    
    // View models
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    
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
        }
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private var authenticatedContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Folders
            sidebarColumn
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            // Content - Chat List
            contentColumn
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } detail: {
            // Detail - Active Chat
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .toolbar {
            macToolbar
        }
        .task {
            setupViewModels()
            await chatListViewModel?.loadChats()
            await folderViewModel?.loadFolders()
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.toggleSidebarNotification)) { _ in
            withAnimation {
                columnVisibility = columnVisibility == .all ? .detailOnly : .all
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: WindowManager.newChatNotification)) { _ in
            createNewChat()
        }
    }
    
    // MARK: - Sidebar Column (Folders)
    
    @ViewBuilder
    private var sidebarColumn: some View {
        List(selection: $selectedFolder) {
            Section("Library") {
                Label("All Chats", systemImage: "bubble.left.and.bubble.right")
                    .tag("all")
                
                Label("Notes", systemImage: "note.text")
                    .tag("notes")
            }
            
            if let folderVM = folderViewModel {
                Section("Folders") {
                    ForEach(folderVM.folders) { folder in
                        Label(folder.name, systemImage: folder.icon ?? "folder")
                            .tag(folder.id)
                            .contextMenu {
                                Button("Rename...") {
                                    // Rename folder
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    Task {
                                        await folderVM.deleteFolder(folder.id)
                                    }
                                }
                            }
                    }
                    
                    Button {
                        Task {
                            await folderVM.createFolder(name: "New Folder")
                        }
                    } label: {
                        Label("New Folder", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button {
                    Task {
                        await coordinator.handleSignOut()
                    }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }
    
    // MARK: - Content Column (Chat List)
    
    @ViewBuilder
    private var contentColumn: some View {
        if let listViewModel = chatListViewModel {
            List(selection: $selectedChatId) {
                ForEach(filteredChats(from: listViewModel), id: \.id) { chat in
                    ChatListRow(chat: chat)
                        .tag(chat.id)
                        .contextMenu {
                            Button("Open in New Window") {
                                openWindow(value: chat.id)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task {
                                    await listViewModel.deleteChat(chat.id)
                                }
                            }
                        }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .navigationTitle(selectedFolderTitle)
            .onChange(of: selectedChatId) { _, newId in
                if let id = newId {
                    selectChat(id)
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Detail Column (Chat)
    
    @ViewBuilder
    private var detailColumn: some View {
        if let viewModel = chatViewModel {
            MacChatView(viewModel: viewModel)
        } else {
            emptyDetailView
        }
    }
    
    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tertiary)
            
            Text("Select a conversation")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("or press ⌘N to start a new chat")
                .font(.callout)
                .foregroundStyle(.tertiary)
            
            Button {
                createNewChat()
            } label: {
                Text("New Chat")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                createNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Chat (⌘N)")
        }
        
        ToolbarItem(placement: .primaryAction) {
            if let chatVM = chatViewModel {
                MacModelSelectorButton(viewModel: chatVM.modelSelector)
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
    
    private var selectedFolderTitle: String {
        guard let folderId = selectedFolder else { return "Chats" }
        
        switch folderId {
        case "all": return "All Chats"
        case "notes": return "Notes"
        default:
            return folderViewModel?.folders.first { $0.id == folderId }?.name ?? "Chats"
        }
    }
}

// MARK: - Chat List Row

struct ChatListRow: View {
    let chat: ChatSummary
    
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
    }
}

// MARK: - Mac Model Selector Button

struct MacModelSelectorButton: View {
    @Bindable var viewModel: ModelSelectorViewModel
    
    var body: some View {
        Menu {
            ForEach(viewModel.availableModels, id: \.id) { model in
                Button {
                    viewModel.selectModel(model)
                } label: {
                    HStack {
                        Text(model.displayName)
                        if viewModel.selectedModel?.id == model.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedModel?.displayName ?? "Select Model")
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Launch View

struct MacLaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Auth View

struct MacAuthView: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            
            VStack(spacing: 8) {
                Text("Welcome to Onera")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Secure, encrypted AI conversations")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            AuthenticationView(
                viewModel: AuthViewModel(
                    authService: dependencies.authService,
                    onSuccess: { await coordinator.handleAuthenticationSuccess() }
                )
            )
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
                    authService: dependencies.authService,
                    e2eeService: dependencies.e2eeService,
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
    @State private var selectedProvider: LLMProvider?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Add an API Key")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose a provider to get started")
                .foregroundStyle(.secondary)
            
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
