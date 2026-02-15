//
//  ChatListView.swift
//  Onera
//
//  Chat sidebar list view
//

import SwiftUI

struct ChatListView: View {
    
    @Bindable var viewModel: ChatListViewModel
    @Binding var selectedChatId: String?
    
    let onSelectChat: (String) -> Void
    let onNewChat: () -> Void
    
    var body: some View {
        List(selection: $selectedChatId) {
            ForEach(viewModel.groupedChats, id: \.0) { group, chats in
                Section(group.displayName) {
                    ForEach(chats) { chat in
                        ChatListRow(chat: chat, isSelected: selectedChatId == chat.id)
                            .tag(chat.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteChat(chat.id) }
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
            if viewModel.isEmpty {
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
        .onChange(of: selectedChatId) { _, newValue in
            if let id = newValue {
                onSelectChat(id)
            }
        }
    }
}

// MARK: - Chat List Row

struct ChatListRow: View {
    
    let chat: ChatSummary
    let isSelected: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .font(.body)
                .lineLimit(1)
            
            Text(chat.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChatListView(
            viewModel: {
                let vm = ChatListViewModel(
                    authService: MockAuthService(),
                    chatRepository: MockChatRepository()
                )
                return vm
            }(),
            selectedChatId: .constant(nil),
            onSelectChat: { _ in },
            onNewChat: {}
        )
    }
}
#endif