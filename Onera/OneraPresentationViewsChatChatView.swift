//
//  ChatView.swift
//  Onera
//
//  Main chat conversation view
//

import SwiftUI

struct ChatView: View {
    
    @Bindable var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            messagesView
            Divider()
            MessageInputView(
                text: $viewModel.inputText,
                attachments: $viewModel.attachments,
                isSending: viewModel.isSending,
                onSend: { Task { await viewModel.sendMessage() } }
            )
            .focused($isInputFocused)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteCurrentChat() }
                    } label: {
                        Label("Delete Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Start a Conversation")
                    .font(.title2.bold())
                
                Text("Your messages are end-to-end encrypted")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            suggestionChips
            
            Spacer()
        }
        .padding()
    }
    
    private var suggestionChips: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    viewModel.inputText = suggestion
                    isInputFocused = true
                } label: {
                    Text(suggestion)
                        .font(.callout)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top)
    }
    
    private var suggestions: [String] {
        [
            "Explain quantum computing",
            "Write a haiku about coding",
            "What's the best way to learn Swift?",
            "Help me debug my code"
        ]
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = viewModel.messages.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            viewModel: ChatViewModel(
                authService: MockAuthService(),
                chatRepository: MockChatRepository(),
                onChatUpdated: { _ in }
            )
        )
    }
}
