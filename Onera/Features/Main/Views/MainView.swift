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
    
    let onSignOut: () async -> Void
    
    // Drawer width calculation - 80% of screen width
    private var drawerWidth: CGFloat {
        UIScreen.main.bounds.width * 0.80
    }
    
    // Edge zone for opening drawer - narrow strip at left edge
    // Small enough to not conflict with chat action buttons
    private var edgeZoneWidth: CGFloat {
        20
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
                    .gesture(closeDrawerGesture) // Close gesture on sidebar
                    .accessibilityIdentifier("sidebarDrawer")
                }
                
                // Main chat content with slide effect
                ZStack {
                    chatContent
                        .allowsHitTesting(!isDrawerOpen)
                    
                    // Invisible edge zone for opening gesture - only when drawer is closed
                    if !isDrawerOpen {
                        HStack {
                            Color.clear
                                .frame(width: edgeZoneWidth)
                                .contentShape(Rectangle())
                                .gesture(edgeOpenGesture)
                            Spacer()
                        }
                        .allowsHitTesting(true)
                    }
                    
                    // Dimmed overlay - blocks chat interaction when open
                    Color.black.opacity(overlayOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(isDrawerOpen || isDragging)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDrawerOpen = false
                            }
                        }
                        .gesture(closeDrawerGesture) // Close gesture on overlay
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: currentOffset)
                .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: currentOffset)
            }
            .accessibilityIdentifier("mainView")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    authService: dependencies.authService,
                    e2eeService: dependencies.e2eeService,
                    secureSession: dependencies.secureSession,
                    credentialService: dependencies.credentialService,
                    networkService: dependencies.networkService,
                    cryptoService: dependencies.cryptoService,
                    extendedCryptoService: dependencies.extendedCryptoService,
                    onSignOut: onSignOut
                )
            )
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
    
    // Edge gesture for OPENING the drawer - only from left edge
    // Uses larger minimum distance to avoid conflicts with scrolling and text selection
    private var edgeOpenGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                // Only trigger from left edge zone when drawer is closed
                guard !isDrawerOpen else { return }
                
                let isFromLeftEdge = value.startLocation.x < edgeZoneWidth
                let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.5
                let isMovingRight = value.translation.width > 0
                
                if isFromLeftEdge && isHorizontalDrag && isMovingRight {
                    state = value.translation.width
                }
            }
            .onChanged { value in
                guard !isDrawerOpen else { return }
                
                let isFromLeftEdge = value.startLocation.x < edgeZoneWidth
                let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height) * 1.5
                let isMovingRight = value.translation.width > 0
                
                if isFromLeftEdge && isHorizontalDrag && isMovingRight {
                    isDragging = true
                }
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                
                let velocity = value.velocity.width
                let snapThreshold = drawerWidth * 0.3
                
                // Flick gesture - velocity overrides position
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
    
    // Close gesture - works from sidebar and overlay when drawer is open
    private var closeDrawerGesture: some Gesture {
        DragGesture(minimumDistance: 15, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                guard isDrawerOpen else { return }
                
                let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                let isMovingLeft = value.translation.width < 0
                
                if isHorizontalDrag && isMovingLeft {
                    state = value.translation.width
                }
            }
            .onChanged { value in
                guard isDrawerOpen else { return }
                
                let isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                let isMovingLeft = value.translation.width < 0
                
                if isHorizontalDrag && isMovingLeft {
                    isDragging = true
                }
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                
                let velocity = value.velocity.width
                let snapThreshold = drawerWidth * 0.3
                
                // Flick gesture - velocity overrides position
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
            }
    }
    
    // MARK: - Chat Content
    
    @ViewBuilder
    private var chatContent: some View {
        if let viewModel = chatViewModel {
            ChatView(
                viewModel: viewModel,
                onMenuTap: {
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
}

#Preview {
    MainView(onSignOut: {})
        .withDependencies(MockDependencyContainer())
}
