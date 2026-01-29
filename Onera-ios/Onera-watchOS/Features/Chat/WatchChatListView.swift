//
//  WatchChatListView.swift
//  Onera Watch
//
//  Recent chats list for watchOS
//

import SwiftUI

struct WatchChatListView: View {
    
    @Environment(\.watchAppState) private var appState
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.recentChats.isEmpty {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshChats()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            Text("No Chats")
                .font(.headline)
            
            Text("Start a conversation on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                refreshChats()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Chat List
    
    private var chatList: some View {
        List {
            ForEach(appState.recentChats) { chat in
                NavigationLink(destination: WatchChatView(chat: chat)) {
                    WatchChatRow(chat: chat)
                }
            }
        }
        .listStyle(.carousel)
    }
    
    // MARK: - Refresh
    
    private func refreshChats() {
        isRefreshing = true
        appState.refreshData()
        
        // Reset after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            isRefreshing = false
        }
    }
}

// MARK: - Chat Row

struct WatchChatRow: View {
    let chat: WatchChatSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(chat.lastMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(chat.lastMessageDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                if chat.unreadCount > 0 {
                    Spacer()
                    Text("\(chat.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.accent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chat View

struct WatchChatView: View {
    let chat: WatchChatSummary
    
    @Environment(\.watchAppState) private var appState
    @State private var messages: [WatchMessage] = []
    @State private var showDictation = false
    @State private var showQuickReplies = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        WatchMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastId = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // Quick reply button
                Button {
                    showQuickReplies = true
                } label: {
                    Image(systemName: "bolt.fill")
                }
                
                Spacer()
                
                // Dictation button
                Button {
                    showDictation = true
                } label: {
                    Image(systemName: "mic.fill")
                }
                
                Spacer()
                
                // Open on iPhone
                Button {
                    WatchConnectivityManager.shared.openChatOnPhone(chatId: chat.id)
                } label: {
                    Image(systemName: "iphone")
                }
            }
        }
        .sheet(isPresented: $showQuickReplies) {
            WatchQuickReplySheet(chatId: chat.id)
        }
        .sheet(isPresented: $showDictation) {
            WatchDictationView(chatId: chat.id) { text in
                sendMessage(text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchChatUpdated)) { notification in
            if let chatId = notification.userInfo?["chatId"] as? String,
               chatId == chat.id,
               let newMessages = notification.userInfo?["messages"] as? [WatchMessage] {
                messages = newMessages
            }
        }
        .task {
            // Initial message is the last message preview
            if !chat.lastMessage.isEmpty {
                messages = [
                    WatchMessage(
                        id: "preview",
                        content: chat.lastMessage,
                        isUser: false,
                        timestamp: chat.lastMessageDate
                    )
                ]
            }
        }
    }
    
    private func sendMessage(_ text: String) {
        // Add optimistic message
        let newMessage = WatchMessage(
            id: UUID().uuidString,
            content: text,
            isUser: true,
            timestamp: Date()
        )
        messages.append(newMessage)
        
        // Send to iPhone
        WatchConnectivityManager.shared.sendChatMessage(chatId: chat.id, content: text)
    }
}

// MARK: - Message Bubble

struct WatchMessageBubble: View {
    let message: WatchMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 20)
            }
            
            Text(message.content)
                .font(.caption)
                .padding(8)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if !message.isUser {
                Spacer(minLength: 20)
            }
        }
    }
    
    private var bubbleColor: Color {
        message.isUser ? .accentColor.opacity(0.3) : Color(white: 0.2)
    }
}

// MARK: - Quick Reply Sheet

struct WatchQuickReplySheet: View {
    let chatId: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.watchAppState) private var appState
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.quickReplies, id: \.self) { reply in
                    Button {
                        sendQuickReply(reply)
                    } label: {
                        Text(reply)
                    }
                }
            }
            .navigationTitle("Quick Reply")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendQuickReply(_ reply: String) {
        WatchConnectivityManager.shared.sendQuickReply(chatId: chatId, reply: reply)
        dismiss()
    }
}

// MARK: - Dictation View

struct WatchDictationView: View {
    let chatId: String
    let onSend: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var dictatedText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Text input with dictation
                TextField("Message", text: $dictatedText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding()
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if !dictatedText.isEmpty {
                    Button {
                        onSend(dictatedText)
                        dismiss()
                    } label: {
                        Label("Send", systemImage: "arrow.up.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Dictate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WatchChatListView()
}
