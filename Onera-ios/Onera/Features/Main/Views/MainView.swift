//
//  MainView.swift
//  Onera
//
//  Main app view with drawer navigation
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.dependencies) private var dependencies
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var isDrawerOpen = false
    
    // Interactive drag state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    @State private var folderViewModel: FolderViewModel?
    @State private var notesViewModel: NotesViewModel?
    @State private var settingsViewModel: SettingsViewModel?
    
    let onSignOut: () async -> Void
    
    // Drawer width calculation - 80% of screen width
    private var drawerWidth: CGFloat {
        UIScreen.main.bounds.width * 0.80
    }
    
    // Current offset based on drawer state and drag
    private var currentOffset: CGFloat {
        let baseOffset = isDrawerOpen ? drawerWidth : 0
        let totalOffset = baseOffset + dragOffset
        // Clamp between 0 and drawerWidth
        return min(max(totalOffset, 0), drawerWidth)
    }
    
    // Overlay opacity based on current offset
    private var overlayOpacity: Double {
        Double(currentOffset / drawerWidth) * 0.3
    }
    
    // Sidebar offset - starts off-screen to the left, slides in as drawer opens
    private var sidebarOffset: CGFloat {
        // Sidebar starts at -drawerWidth (off-screen) and moves to 0 (visible)
        let progress = currentOffset / drawerWidth
        return -drawerWidth * (1 - progress)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Sidebar drawer - slides in from the left
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
                    .simultaneousGesture(fullScreenDrawerGesture) // Swipe gesture on sidebar
                    .accessibilityIdentifier("sidebarDrawer")
                }
                
                // Main chat content with slide effect
                ZStack {
                    chatContent
                        .allowsHitTesting(!isDrawerOpen)
                    
                    // Dimmed overlay - blocks chat interaction when open
                    Color.black.opacity(overlayOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(isDrawerOpen || isDragging)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDrawerOpen = false
                            }
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: currentOffset)
                .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: currentOffset)
                // Full-screen swipe gesture for opening/closing drawer
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
        }
    }
    
    // MARK: - Drawer Gestures
    
    // Full-screen gesture for opening AND closing the drawer
    // Uses strict horizontal detection to avoid conflicts with scrolling and text selection
    private var fullScreenDrawerGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                // Require very strongly horizontal movement (3x more horizontal than vertical)
                // This prevents interference with text selection and scrolling
                let isVeryHorizontal = abs(value.translation.width) > abs(value.translation.height) * 3
                
                // Also require minimum horizontal distance before activating
                let hasMinDistance = abs(value.translation.width) > 40
                
                if !isVeryHorizontal || !hasMinDistance {
                    return
                }
                
                if isDrawerOpen {
                    // Closing: only allow left swipe
                    if value.translation.width < 0 {
                        state = value.translation.width
                    }
                } else {
                    // Opening: only allow right swipe
                    if value.translation.width > 0 {
                        state = value.translation.width
                    }
                }
            }
            .onChanged { value in
                // Require very strongly horizontal movement
                let isVeryHorizontal = abs(value.translation.width) > abs(value.translation.height) * 3
                let hasMinDistance = abs(value.translation.width) > 40
                
                if !isVeryHorizontal || !hasMinDistance {
                    return
                }
                
                if isDrawerOpen {
                    // Closing: only allow left swipe
                    if value.translation.width < 0 {
                        isDragging = true
                    }
                } else {
                    // Opening: only allow right swipe
                    if value.translation.width > 0 {
                        isDragging = true
                    }
                }
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                
                let velocity = value.velocity.width
                let snapThreshold = drawerWidth * 0.3
                
                if isDrawerOpen {
                    // Closing logic
                    // Flick left to close
                    if velocity < -500 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isDrawerOpen = false
                        }
                        return
                    }
                    
                    // Snap based on position
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isDrawerOpen = currentOffset > (drawerWidth - snapThreshold)
                    }
                } else {
                    // Opening logic
                    // Flick right to open
                    if velocity > 500 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isDrawerOpen = true
                        }
                        return
                    }
                    
                    // Snap based on position
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
                onMenuTap: {
                    // Dismiss keyboard before opening drawer
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation(.easeOut(duration: 0.25)) {
                        isDrawerOpen = true
                    }
                },
                onNewConversation: createNewChat,
                showCustomNavBar: true
            )
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