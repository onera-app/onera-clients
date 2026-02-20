//
//  MainView.swift
//  Onera
//
//  Main app view with drawer navigation and native toolbar (iPhone)
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MainView: View {
    
    @Environment(\.dependencies) private var dependencies
    @Environment(\.theme) private var theme
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var isDrawerOpen = false
    
    // Interactive drag state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var containerWidth: CGFloat = 0
    
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    @State private var promptsViewModel: PromptsViewModel?
    
    let onSignOut: () async -> Void
    
    // Drawer width - 80% of container
    private var drawerWidth: CGFloat {
        #if os(iOS)
        containerWidth * 0.80
        #elseif os(macOS)
        300
        #endif
    }
    
    // Current offset based on drawer state and drag
    private var currentOffset: CGFloat {
        let baseOffset = isDrawerOpen ? drawerWidth : 0
        let totalOffset = baseOffset + dragOffset
        return min(max(totalOffset, 0), drawerWidth)
    }
    
    // Sidebar offset
    private var sidebarOffset: CGFloat {
        guard drawerWidth > 0 else { return 0 }
        let progress = currentOffset / drawerWidth
        return -drawerWidth * (1 - progress)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Dark background matching Captions aesthetic
                theme.background
                    .ignoresSafeArea()
                    .onAppear {
                        containerWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        containerWidth = newWidth
                    }
                
                // Sidebar drawer
                if let listViewModel = chatListViewModel {
                    SidebarDrawerView(
                        isOpen: $isDrawerOpen,
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDrawerOpen = false
                            }
                        }
                    )
                    .frame(width: drawerWidth)
                    .offset(x: sidebarOffset)
                    .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: sidebarOffset)
                    .simultaneousGesture(fullScreenDrawerGesture)
                    .accessibilityIdentifier("sidebarDrawer")
                }
                
                // Main chat content + toolbar (slides together)
                ZStack {
                    NavigationStack {
                         chatContent
                            #if os(iOS)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button {
                                        dismissKeyboard()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            isDrawerOpen.toggle()
                                        }
                                    } label: {
                                        OneraIcon.sidebar.image
                                            .fontWeight(.bold)
                                            .symbolVariant(isDrawerOpen ? .fill : .none)
                                    }
                                    .accessibilityLabel("Toggle sidebar")
                                    .accessibilityHint("Shows or hides chat history")
                                }
                                
                                ToolbarItem(placement: .principal) {
                                    if let viewModel = chatViewModel {
                                        modelSelectorToolbarItem(viewModel: viewModel)
                                    }
                                }
                                
                                ToolbarItemGroup(placement: .navigationBarTrailing) {
                                    Button {
                                        createNewChat()
                                    } label: {
                                        OneraIcon.chatAdd.image
                                    }
                                    .accessibilityLabel("New chat")
                                    
                                    Button {
                                        showSettings = true
                                    } label: {
                                        let initial = dependencies.authService.currentUser?.displayName.prefix(1).uppercased() ?? "?"
                                        Text(initial)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 30, height: 30)
                                            .background(theme.accent)
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel("Profile and settings")
                                }
                            }
                            .toolbarBackground(.hidden, for: .navigationBar)
                            .navigationBarTitleDisplayMode(.inline)
                            #endif
                    }
                    .allowsHitTesting(!isDrawerOpen)
                    
                    // Tap/swipe-to-dismiss overlay (no dimming)
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .allowsHitTesting(isDrawerOpen || isDragging)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDrawerOpen = false
                            }
                        }
                        .gesture(fullScreenDrawerGesture)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: currentOffset)
                .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: currentOffset)
                .simultaneousGesture(fullScreenDrawerGesture)
            }
            .accessibilityIdentifier("mainView")
        }
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
    
    // MARK: - Drawer Gesture
    
    private var fullScreenDrawerGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                let isVeryHorizontal = abs(value.translation.width) > abs(value.translation.height) * 3
                let hasMinDistance = abs(value.translation.width) > 40
                
                guard isVeryHorizontal && hasMinDistance else { return }
                
                if isDrawerOpen {
                    if value.translation.width < 0 { state = value.translation.width }
                } else {
                    if value.translation.width > 0 { state = value.translation.width }
                }
            }
            .onChanged { value in
                let isVeryHorizontal = abs(value.translation.width) > abs(value.translation.height) * 3
                let hasMinDistance = abs(value.translation.width) > 40
                
                guard isVeryHorizontal && hasMinDistance else { return }
                
                if isDrawerOpen {
                    if value.translation.width < 0 { isDragging = true }
                } else {
                    if value.translation.width > 0 { isDragging = true }
                }
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                
                let velocity = value.velocity.width
                let snapThreshold = drawerWidth * 0.3
                
                if isDrawerOpen {
                    if velocity < -500 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isDrawerOpen = false
                        }
                        return
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isDrawerOpen = currentOffset > (drawerWidth - snapThreshold)
                    }
                } else {
                    if velocity > 500 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isDrawerOpen = true
                        }
                        return
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isDrawerOpen = currentOffset > snapThreshold
                    }
                }
            }
    }
    
    // MARK: - Chat Content
    
    @ViewBuilder
    private var chatContent: some View {
        if let viewModel = chatViewModel {
            ChatView(
                viewModel: viewModel,
                promptSummaries: promptsViewModel?.prompts ?? [],
                onFetchPromptContent: { summary in
                    await promptsViewModel?.usePrompt(summary)
                }
            )
        } else {
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, OneraSpacing.sm)
                Spacer()
            }
        }
    }
    
    // MARK: - Model Selector
    
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
                                        OneraIcon.checkSimple.image
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: OneraSpacing.sm) {
                if viewModel.modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(theme.goldAccent)
                        .accessibilityLabel("Loading models")
                } else {
                    // Gold sparkle icon like Captions "Get MAX" badge
                    OneraIcon.sparkle.image
                        .font(.caption)
                        .foregroundStyle(theme.goldAccent)
                    
                    Text(viewModel.modelSelector.selectedModel?.displayName ?? "Select Model")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.goldAccent)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(theme.goldAccent.opacity(0.15))
            .clipShape(Capsule())
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Select AI model")
        .accessibilityValue(viewModel.modelSelector.selectedModel?.displayName ?? "No model selected")
        .accessibilityHint("Opens menu to choose a different AI model")
    }
    
    // MARK: - Helpers
    
    private func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
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
