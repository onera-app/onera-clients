//
//  ChatView.swift
//  Onera
//
//  Main chat interface (ChatGPT-style)
//

import SwiftUI

struct ChatView: View {
    @State var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let chat = viewModel.currentChat {
                            ForEach(chat.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        } else {
                            emptyStateView
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentChat?.messages.count) { _, _ in
                    if let lastId = viewModel.currentChat?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            MessageInputView(
                text: $viewModel.inputText,
                attachments: $viewModel.attachments,
                isSending: viewModel.isSending,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
            .focused($isInputFocused)
        }
        .navigationTitle(viewModel.currentChat?.title ?? "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Share chat
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        if let id = viewModel.currentChat?.id {
                            Task {
                                await viewModel.deleteChat(id: id)
                            }
                        }
                    } label: {
                        Label("Delete Chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
            
            // Suggestion chips
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(suggestionPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.inputText = prompt
                        isInputFocused = true
                    } label: {
                        Text(prompt)
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
            
            Spacer()
        }
        .padding()
    }
    
    private var suggestionPrompts: [String] {
        [
            "Explain quantum computing",
            "Write a haiku about coding",
            "What's the best way to learn Swift?",
            "Help me debug my code"
        ]
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel())
    }
}
