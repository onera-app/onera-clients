//
//  MainView.swift
//  Onera
//
//  Main app view with split navigation
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.dependencies) private var dependencies
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    @State private var chatListViewModel: ChatListViewModel?
    @State private var chatViewModel: ChatViewModel?
    
    let onSignOut: () async -> Void
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: SettingsViewModel(
                    authService: dependencies.authService,
                    e2eeService: dependencies.e2eeService,
                    secureSession: dependencies.secureSession,
                    onSignOut: onSignOut
                )
            )
        }
        .task {
            setupViewModels()
            await chatListViewModel?.loadChats()
        }
    }
    
    // MARK: - Sidebar
    
    @ViewBuilder
    private var sidebarContent: some View {
        if let viewModel = chatListViewModel {
            ChatListView(
                viewModel: viewModel,
                selectedChatId: $selectedChatId,
                onSelectChat: selectChat,
                onNewChat: createNewChat
            )
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } else {
            ProgressView()
        }
    }
    
    // MARK: - Detail
    
    @ViewBuilder
    private var detailContent: some View {
        if let viewModel = chatViewModel {
            ChatView(viewModel: viewModel)
        } else {
            ContentUnavailableView(
                "No Chat Selected",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Select a chat from the sidebar or create a new one")
            )
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
            onChatUpdated: { summary in
                chatListViewModel?.addOrUpdateChat(summary)
            }
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
