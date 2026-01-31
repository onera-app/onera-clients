//
//  ChatView.swift
//  Onera
//
//  Main chat conversation view
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ChatView: View {
    
    @Bindable var viewModel: ChatViewModel
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isInputFocused: Bool
    @State private var showingError = false
    @State private var ttsStartTime: Date?
    
    var onMenuTap: (() -> Void)?
    var onNewConversation: (() -> Void)?
    var showCustomNavBar: Bool = false
    
    /// Max width for message content on larger screens (iPad)
    private var maxMessageWidth: CGFloat? {
        horizontalSizeClass == .regular ? 720 : nil
    }
    
    /// Max width for the entire content area on iPad
    private var maxContentWidth: CGFloat? {
        horizontalSizeClass == .regular ? 800 : nil
    }
    
    var body: some View {
        ZStack {
            // Background color
            theme.background
                .ignoresSafeArea()
            
            // Main content - messages scroll behind header and input
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty {
                    emptyStateView
                } else {
                    messagesView
                        .tint(.blue) // Blue text selection color
                }
            }
            // Add padding for header and input areas so content doesn't start under them
            .safeAreaInset(edge: .top) {
                if showCustomNavBar {
                    CustomNavigationBar(
                        modelSelector: viewModel.modelSelector,
                        onMenuTap: { onMenuTap?() },
                        onNewConversation: { onNewConversation?() }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputSection
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
        .sensoryFeedback(.success, trigger: viewModel.messages.count)
        .sensoryFeedback(.start, trigger: viewModel.isStreaming)
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
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(for: message)
                            .frame(maxWidth: maxMessageWidth)
                            .id(message.id)
                    }
                    
                    // Large tappable spacer at bottom to dismiss selection
                    Color.clear
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissSelection()
                        }
                }
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity) // Center the constrained content
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }
    
    // Dismiss any active text selection or keyboard
    private func dismissSelection() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #elseif os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
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
        .background(
            LinearGradient(
                colors: [theme.background.opacity(0), theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
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
