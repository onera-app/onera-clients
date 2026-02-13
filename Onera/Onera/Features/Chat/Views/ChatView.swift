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
    @State private var messageSentTrigger = false
    @State private var isNewChatSendAnimating = false
    @State private var firstMessageAnimationComplete = false

    #if os(iOS)
    @State private var showArtifacts = false
    @State private var activeArtifactId: String?
    #endif
    
    // @mention prompt support
    var promptSummaries: [PromptSummary] = []
    var onFetchPromptContent: ((PromptSummary) async -> String?)? = nil
    
    /// Max width for message content on larger screens (iPad)
    private var maxMessageWidth: CGFloat? {
        horizontalSizeClass == .regular ? 720 : nil
    }
    
    /// Max width for the entire content area on iPad
    private var maxContentWidth: CGFloat? {
        horizontalSizeClass == .regular ? 800 : nil
    }
    
    #if os(iOS)
    private var artifacts: [CodeArtifact] {
        ArtifactExtractor.extractArtifacts(from: viewModel.messages)
    }
    #endif
    
    var body: some View {
        ZStack {
            // Background color – dark like Captions home screen
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
        .modifier(MessageListFeedback(
            messageSentTrigger: messageSentTrigger,
            isStreaming: viewModel.isStreaming
        ))
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
        #if os(iOS)
        .toolbar {
            if !artifacts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showArtifacts = true
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .accessibilityLabel("View code artifacts")
                }
            }
        }
        .sheet(isPresented: $showArtifacts) {
            iOSArtifactsSheet(
                artifacts: artifacts,
                activeArtifactId: $activeArtifactId,
                onClose: { showArtifacts = false }
            )
        }
        #endif
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                    messageBubble(for: message)
                        .frame(maxWidth: maxMessageWidth, alignment: message.isUser ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
                        .id(message.id)
                        .modifier(NewChatMessageAnimator(
                            index: index,
                            isUser: message.isUser,
                            isNewChatSendAnimating: isNewChatSendAnimating,
                            firstMessageAnimationComplete: $firstMessageAnimationComplete,
                            onAnimationDone: {
                                isNewChatSendAnimating = false
                            }
                        ))
                        .modifier(MessageScrollFade())
                        .transition(
                            message.isUser
                                ? .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                  )
                                : .opacity
                        )
                }
                
                // Small spacer for visual breathing room
                // (safeAreaInset handles the input area spacing)
                Color.clear
                    .frame(height: 16)
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
        .modifier(ScrollToBottomOnNewMessage(
            messageCount: viewModel.messages.count,
            lastMessageId: viewModel.messages.last?.id
        ))
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
        VStack(spacing: OneraSpacing.xxl) {
            Spacer()
            
            // Centered icon/illustration area (like Captions' tilted photo stack)
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 100, height: 100)
                .background(theme.onboardingPill)
                .clipShape(RoundedRectangle(cornerRadius: OneraRadius.xlarge, style: .continuous))
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
            
            // Pill-shaped quick action buttons (like Captions' "Import video", "AI Edit")
            VStack(spacing: OneraSpacing.md) {
                HStack(spacing: OneraSpacing.md) {
                    Button {
                        createNewChatAction()
                    } label: {
                        HStack(spacing: OneraSpacing.sm) {
                            Image(systemName: "plus")
                            Text("New Chat")
                        }
                    }
                    .buttonStyle(CaptionsPillChipStyle())
                    
                    Button {
                        // Could trigger AI-specific action
                    } label: {
                        Text("Quick Ask")
                    }
                    .buttonStyle(CaptionsPillChipStyle())
                }
            }
            
            HStack(spacing: OneraSpacing.xxs) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("End-to-end encrypted")
            }
            .font(.caption)
            .foregroundStyle(theme.textTertiary)
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissSelection()
        }
    }
    
    /// Action to start a new chat from empty state
    private func createNewChatAction() {
        // This triggers the input focus so user can start typing
        isInputFocused = true
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
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button {
                        viewModel.clearError()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .accessibilityLabel("Dismiss error")
                }
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.vertical, OneraSpacing.sm)
                .background(theme.secondaryBackground)
            }
            
            // Show hint if no model selected
            if viewModel.modelSelector.selectedModel == nil && !viewModel.modelSelector.isLoading {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(theme.info)
                    Text("Tap the model name above to select a model")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.vertical, OneraSpacing.sm)
                .background(theme.secondaryBackground)
            }
            
            MessageInputView(
                text: $viewModel.inputText,
                attachments: $viewModel.attachments,
                isSending: viewModel.isSending,
                isStreaming: viewModel.isStreaming,
                canSend: viewModel.canSend,
                onSend: {
                    let isNewChat = viewModel.messages.isEmpty
                    messageSentTrigger.toggle()
                    if isNewChat {
                        isNewChatSendAnimating = true
                        firstMessageAnimationComplete = false
                    }
                    Task { await viewModel.sendMessage() }
                },
                onStop: { viewModel.stopStreaming() },
                isRecording: viewModel.isRecording,
                onStartRecording: { handleStartRecording() },
                onStopRecording: { viewModel.stopRecording() },
                promptSummaries: promptSummaries,
                onFetchPromptContent: onFetchPromptContent,
                searchEnabled: $viewModel.searchEnabled,
                isSearching: viewModel.isSearching
            )
            .focused($isInputFocused)
        }
        .background(theme.background)
        .ignoresSafeArea()
    }
    
    // MARK: - Message Bubble Builder
    
    @ViewBuilder
    private func messageBubble(for message: Message) -> some View {
        MessageBubbleView(
            message: message,
            onEdit: message.isUser ? { newContent, regenerate in
                handleEdit(messageId: message.id, newContent: newContent, regenerate: regenerate)
            } : nil,
            onRegenerate: message.isAssistant && !message.isStreaming ? { modifier in
                handleRegenerate(messageId: message.id, modifier: modifier)
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
    
    private func handleRegenerate(messageId: String, modifier: String? = nil) {
        Task {
            await viewModel.regenerateMessage(messageId: messageId, modifier: modifier)
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
