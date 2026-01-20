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
    @State private var showingError = false
    @State private var showingModelDropdown = false
    @State private var ttsStartTime: Date?
    
    var onMenuTap: (() -> Void)?
    var onNewConversation: (() -> Void)?
    var showCustomNavBar: Bool = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if showCustomNavBar {
                    CustomNavigationBar(
                        modelSelector: viewModel.modelSelector,
                        onMenuTap: { onMenuTap?() },
                        onNewConversation: { onNewConversation?() },
                        showingModelDropdown: $showingModelDropdown
                    )
                }
                
                ZStack {
                    // Tappable background to dismiss selection
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissSelection()
                        }
                    
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        messagesView
                    }
                }
                
                inputSection
            }
            
            // Model dropdown overlay - rendered at top level so it's not clipped
            if showingModelDropdown {
                modelDropdownOverlay
            }
            
            // TTS Player Overlay - shown when speaking
            if viewModel.isSpeaking {
                TTSPlayerOverlay(
                    isPlaying: viewModel.isSpeaking,
                    startTime: ttsStartTime,
                    onStop: {
                        viewModel.stopSpeaking()
                        ttsStartTime = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isSpeaking)
            }
        }
        .task {
            await viewModel.loadModels()
        }
        .onChange(of: viewModel.isSpeaking) { wasSpeaking, isSpeaking in
            if isSpeaking && !wasSpeaking {
                // Just started speaking - record start time
                ttsStartTime = Date()
            } else if !isSpeaking && wasSpeaking {
                // Stopped speaking - clear start time
                ttsStartTime = nil
            }
        }
    }
    
    // MARK: - Model Dropdown Overlay
    
    private var modelDropdownOverlay: some View {
        ZStack(alignment: .topLeading) {
            // Tap to dismiss background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingModelDropdown = false
                    }
                }
            
            // Dropdown menu
            ModelSelectorDropdownContent(
                viewModel: viewModel.modelSelector,
                onSelect: { model in
                    viewModel.modelSelector.selectModel(model)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingModelDropdown = false
                    }
                }
            )
            .frame(width: 280)
            .padding(.top, 60) // Below nav bar
            .padding(.leading, 16)
        }
        .transition(.opacity)
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(for: message)
                            .id(message.id)
                    }
                    
                    // Spacer at bottom to allow tapping to dismiss
                    Color.clear
                        .frame(height: 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissSelection()
                        }
                }
                .padding()
                // Background tap to dismiss selection
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissSelection()
                        }
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }
    
    // Dismiss any active text selection or keyboard
    private func dismissSelection() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Minimal icon
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("What's on your mind?")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                    Text("Encrypted and only accessible by you")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            dismissSelection()
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 0) {
            // Show error if any
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.clearError()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            
            // Show hint if no model selected
            if viewModel.modelSelector.selectedModel == nil && !viewModel.modelSelector.isLoading {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Tap the model name above to select a model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            
            MessageInputView(
                text: $viewModel.inputText,
                attachments: $viewModel.attachments,
                isSending: viewModel.isSending,
                isStreaming: viewModel.isStreaming,
                canSend: viewModel.canSend,
                onSend: { Task { await viewModel.sendMessage() } },
                onStop: { viewModel.stopStreaming() },
                isRecording: viewModel.isRecording,
                onStartRecording: { handleStartRecording() },
                onStopRecording: { viewModel.stopRecording() }
            )
            .focused($isInputFocused)
        }
        .background(Color(.systemBackground))
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = viewModel.messages.last?.id {
            withAnimation {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Message Bubble Builder
    
    @ViewBuilder
    private func messageBubble(for message: Message) -> some View {
        MessageBubbleView(
            message: message,
            onEdit: message.isUser ? { newContent, regenerate in
                handleEdit(messageId: message.id, newContent: newContent, regenerate: regenerate)
            } : nil,
            onRegenerate: message.isAssistant && !message.isStreaming ? {
                handleRegenerate(messageId: message.id)
            } : nil,
            onSpeak: message.isAssistant && !message.isStreaming ? { text in
                handleSpeak(text: text, messageId: message.id)
            } : nil,
            onStopSpeaking: message.isAssistant ? {
                viewModel.stopSpeaking()
            } : nil,
            isSpeaking: viewModel.speakingMessageId == message.id,
            branchInfo: message.isAssistant ? viewModel.getBranchInfo(for: message.id) : nil,
            onPreviousBranch: message.isAssistant ? {
                viewModel.switchToPreviousBranch(for: message.id)
            } : nil,
            onNextBranch: message.isAssistant ? {
                viewModel.switchToNextBranch(for: message.id)
            } : nil
        )
        .accessibilityIdentifier("message_\(message.id)")
    }
    
    private func handleEdit(messageId: String, newContent: String, regenerate: Bool) {
        Task {
            await viewModel.editMessage(messageId: messageId, newContent: newContent, regenerate: regenerate)
        }
    }
    
    private func handleRegenerate(messageId: String) {
        Task {
            await viewModel.regenerateMessage(messageId: messageId)
        }
    }
    
    private func handleSpeak(text: String, messageId: String) {
        Task {
            await viewModel.speak(text, messageId: messageId)
        }
    }
    
    private func handleStartRecording() {
        Task {
            await viewModel.startRecording()
        }
    }
}
