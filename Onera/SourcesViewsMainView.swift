//
//  MainView.swift
//  Onera
//
//  Main app container with navigation
//

import SwiftUI

struct MainView: View {
    @State private var viewModel = ChatViewModel()
    @State private var selectedChatId: String?
    @State private var showSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            ChatSidebarView(
                viewModel: viewModel,
                onSelectChat: { id in
                    selectedChatId = id
                    Task {
                        await viewModel.loadChat(id: id)
                    }
                },
                onNewChat: {
                    selectedChatId = nil
                    Task {
                        await viewModel.createNewChat()
                    }
                }
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
        } detail: {
            // Chat view
            ChatView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            await viewModel.loadChats()
        }
    }
}

#Preview {
    MainView()
}
