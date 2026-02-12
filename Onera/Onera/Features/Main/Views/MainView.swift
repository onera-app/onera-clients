//
//  MainView.swift
//  Onera
//
//  Main app view with NavigationSplitView navigation (iPhone)
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MainView: View {
    
    @Environment(\.dependencies) private var dependencies
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    @State private var promptsViewModel: PromptsViewModel?
    
    let onSignOut: () async -> Void
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar — SidebarDrawerView content
            sidebarColumn
        } detail: {
            // Detail — Chat view with native toolbar
            chatDetailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) {
            if let viewModel = settingsViewModel {
                SettingsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showNotes) {
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
        .task {
            setupViewModels()
            await chatListViewModel?.loadChats()
            await promptsViewModel?.loadPrompts()
        }
    }
    
    // MARK: - Sidebar Column
    
    @ViewBuilder
    private var sidebarColumn: some View {
        if let listViewModel = chatListViewModel {
            SidebarDrawerView(
                isOpen: Binding(
                    get: { columnVisibility != .detailOnly },
                    set: { newValue in
                        withAnimation {
                            columnVisibility = newValue ? .all : .detailOnly
                        }
                    }
                ),
                selectedChatId: $selectedChatId,
                chats: listViewModel.chats,
                groupedChats: listViewModel.groupedChats,
                isLoading: listViewModel.isLoading,
                error: listViewModel.error,
                user: dependencies.authService.currentUser,
                folderViewModel: folderViewModel,
                onSelectChat: selectChat,
                onNewChat: createNewChat,
                onDeleteChat: { id in
                    await listViewModel.deleteChat(id)
                },
                onMoveChatToFolder: { chatId, folderId in
                    await moveChatToFolder(chatId: chatId, folderId: folderId)
                },
                onPinChat: { chatId, pinned in
                    if let chat = listViewModel.chats.first(where: { $0.id == chatId }) {
                        await listViewModel.togglePinned(chat)
                    }
                },
                onArchiveChat: { chatId, archived in
                    if let chat = listViewModel.chats.first(where: { $0.id == chatId }) {
                        await listViewModel.toggleArchived(chat)
                    }
                },
                onOpenSettings: {
                    showSettings = true
                },
                onRefresh: {
                    await listViewModel.loadChats()
                },
                onOpenNotes: {
                    showNotes = true
                    withAnimation {
                        columnVisibility = .detailOnly
                    }
                }
            )
        } else {
            ProgressView()
        }
    }
    
    // MARK: - Chat Detail Column
    
    @ViewBuilder
    private var chatDetailColumn: some View {
        if let viewModel = chatViewModel {
            ChatView(
                viewModel: viewModel,
                promptSummaries: promptsViewModel?.prompts ?? [],
                onFetchPromptContent: { summary in
                    await promptsViewModel?.usePrompt(summary)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    modelSelectorToolbarItem(viewModel: viewModel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New conversation")
                    .accessibilityHint("Starts a new chat")
                }
            }
        } else {
            // Loading state
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
        }
    }
    
    // MARK: - Model Selector (Toolbar)
    
    private func modelSelectorToolbarItem(viewModel: ChatViewModel) -> some View {
        Menu {
            if viewModel.modelSelector.isLoading {
                Text("Loading models...")
            } else if viewModel.modelSelector.groupedModels.isEmpty {
                Text("No models available")
                Text("Add API keys in Settings")
            } else {
                ForEach(viewModel.modelSelector.groupedModels, id: \.provider) { group in
                    Section(group.provider.displayName) {
                        ForEach(group.models) { model in
                            Button {
                                viewModel.modelSelector.selectedModel = model
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if viewModel.modelSelector.selectedModel?.id == model.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if viewModel.modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .accessibilityLabel("Loading models")
                } else {
                    Text(viewModel.modelSelector.selectedModel?.displayName ?? "Select Model")
                        .font(OneraTypography.navTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(OneraTypography.buttonSmall)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Select AI model")
        .accessibilityValue(viewModel.modelSelector.selectedModel?.displayName ?? "No model selected")
        .accessibilityHint("Opens menu to choose a different AI model")
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
            passkeyService: dependencies.passkeyService,
            onSignOut: onSignOut
        )
        
        promptsViewModel = PromptsViewModel(
            promptRepository: dependencies.promptRepository,
            authService: dependencies.authService
        )
    }
    
    private func selectChat(_ id: String) {
        selectedChatId = id
        withAnimation {
            columnVisibility = .detailOnly
        }
        Task {
            await chatViewModel?.loadChat(id: id)
        }
    }
    
    private func createNewChat() {
        selectedChatId = nil
        withAnimation {
            columnVisibility = .detailOnly
        }
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
            // Refresh the chat list to reflect the change
            await chatListViewModel?.loadChats()
        } catch {
            print("[MainView] Failed to move chat to folder: \(error)")
        }
    }
}

#if DEBUG
#Preview {
    MainView(
        onSignOut: {}
    )
    .withDependencies(MockDependencyContainer())
}
#endif
