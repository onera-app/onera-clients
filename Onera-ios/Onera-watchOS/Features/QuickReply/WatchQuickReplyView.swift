//
//  WatchQuickReplyView.swift
//  Onera Watch
//
//  Quick reply interface for watchOS
//

import SwiftUI

struct WatchQuickReplyView: View {
    
    @Environment(\.watchAppState) private var appState
    @State private var selectedChatId: String?
    @State private var showReplies = false
    
    var body: some View {
        NavigationStack {
            if appState.recentChats.isEmpty {
                emptyState
            } else {
                chatSelectionList
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            Text("No Chats")
                .font(.headline)
            
            Text("Start a chat on your iPhone to use Quick Reply")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Quick Reply")
    }
    
    // MARK: - Chat Selection
    
    private var chatSelectionList: some View {
        List {
            Section {
                ForEach(appState.recentChats.prefix(5)) { chat in
                    Button {
                        selectedChatId = chat.id
                        showReplies = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text(chat.lastMessageDate, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Select Chat")
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Quick Reply")
        .sheet(isPresented: $showReplies) {
            if let chatId = selectedChatId {
                QuickReplySelectionView(chatId: chatId)
            }
        }
    }
}

// MARK: - Quick Reply Selection

struct QuickReplySelectionView: View {
    let chatId: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.watchAppState) private var appState
    @State private var customReply = ""
    @State private var showDictation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // Preset replies
                    ForEach(appState.quickReplies, id: \.self) { reply in
                        QuickReplyButton(text: reply) {
                            sendReply(reply)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Custom reply with dictation
                    Button {
                        showDictation = true
                    } label: {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Dictate")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Reply")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDictation) {
                WatchDictationInputView { text in
                    sendReply(text)
                }
            }
        }
    }
    
    private func sendReply(_ text: String) {
        WatchConnectivityManager.shared.sendQuickReply(chatId: chatId, reply: text)
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}

// MARK: - Quick Reply Button

struct QuickReplyButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }
}

// MARK: - Dictation Input View

struct WatchDictationInputView: View {
    let onSend: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Text field with dictation support
                TextField("Speak or type...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
                    .padding()
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if !text.isEmpty {
                    HStack {
                        Button("Clear") {
                            text = ""
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                        
                        Button("Send") {
                            onSend(text)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
    WatchQuickReplyView()
}
