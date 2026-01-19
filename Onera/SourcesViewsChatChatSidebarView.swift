//
//  ChatSidebarView.swift
//  Onera
//
//  Chat history sidebar with grouped chats
//

import SwiftUI

struct ChatSidebarView: View {
    @Bindable var viewModel: ChatViewModel
    let onSelectChat: (String) -> Void
    let onNewChat: () -> Void
    
    var body: some View {
        List {
            ForEach(viewModel.groupedChats, id: \.0) { group, chats in
                Section(group.displayName) {
                    ForEach(chats) { chat in
                        ChatRowView(chat: chat, isSelected: viewModel.currentChat?.id == chat.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectChat(chat.id)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteChat(id: chat.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .overlay {
            if viewModel.chats.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Chats Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Tap the compose button to start a new chat")
                )
            }
        }
        .refreshable {
            await viewModel.loadChats()
        }
    }
}

struct ChatRowView: View {
    let chat: ChatSummary
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(chat.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : nil)
    }
}

#Preview {
    NavigationStack {
        ChatSidebarView(
            viewModel: ChatViewModel(),
            onSelectChat: { _ in },
            onNewChat: {}
        )
    }
}
