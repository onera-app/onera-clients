//
//  MessageBubbleView.swift
//  Onera
//
//  Chat message bubble with markdown and reasoning support
//

import SwiftUI
import Highlightr
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Parsed message content with thinking blocks extracted
struct ParsedMessageContent {
    let displayContent: String
    let thinkingContent: String?
    let isThinking: Bool
}

struct MessageBubbleView: View {
    
    let message: Message
    /// Called when user saves edit (with regenerate: true to regenerate, false to just save)
    var onEdit: ((String, Bool) -> Void)?
    var onRegenerate: (() -> Void)?
    var onSpeak: ((String) -> Void)?
    var onStopSpeaking: (() -> Void)?
    var isSpeaking: Bool = false
    
    // Branch navigation (response versioning)
    var branchInfo: (current: Int, total: Int)?
    var onPreviousBranch: (() -> Void)?
    var onNextBranch: (() -> Void)?
    
    @Environment(\.theme) private var theme
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showCopiedFeedback = false
    @State private var isRegenerating = false
    @FocusState private var isEditFocused: Bool
    
    /// Parse the message content for thinking tags
    private var parsedContent: ParsedMessageContent {
        parseThinkingContent(message.content)
    }
    
    /// Combined reasoning from SDK events and parsed <think> tags
    private var combinedReasoning: String? {
        var parts: [String] = []
        if let sdkReasoning = message.reasoning, !sdkReasoning.isEmpty {
            parts.append(sdkReasoning)
        }
        if let parsedThinking = parsedContent.thinkingContent, !parsedThinking.isEmpty {
            parts.append(parsedThinking)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }
    
    /// Whether this message has any reasoning content
    private var hasAnyReasoning: Bool {
        combinedReasoning != nil && !(combinedReasoning?.isEmpty ?? true)
    }
    
    /// Whether the message is currently streaming reasoning (no main content yet)
    private var isStreamingReasoning: Bool {
        message.isStreaming && (message.hasReasoning || parsedContent.isThinking) && parsedContent.displayContent.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.isUser {
                userMessageView
            } else {
                // Assistant message - full width, no bubble (ChatGPT style)
                VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                    // Reasoning view (if available from SDK events or parsed from content)
                    if hasAnyReasoning {
                        ReasoningView(
                            reasoning: combinedReasoning ?? "",
                            isStreaming: isStreamingReasoning
                        )
                    }
                    
                    // Full width markdown content (with thinking tags removed)
                    MarkdownContentView(content: parsedContent.displayContent, isStreaming: message.isStreaming)
                    
                    if !message.attachments.isEmpty {
                        AttachmentsView(attachments: message.attachments)
                    }
                    
                    // Action buttons row (ChatGPT style)
                    if !message.isStreaming {
                        HStack(spacing: 0) {
                            assistantActionButtons
                            
                            // Branch navigation (if multiple versions exist)
                            if let branch = branchInfo, branch.total > 1 {
                                branchNavigationView(current: branch.current, total: branch.total)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Branch Navigation View
    
    private func branchNavigationView(current: Int, total: Int) -> some View {
        HStack(spacing: OneraSpacing.xxs) {
            // Previous button
            Button {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                onPreviousBranch?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current <= 1)
            .opacity(current > 1 ? 1 : 0.3)
            .accessibilityIdentifier("branchPrevious")
            .accessibilityLabel("Previous response version")
            .accessibilityHint(current > 1 ? "Shows version \(current - 1) of \(total)" : "No previous version available")
            
            // Count display
            Text("\(current)/\(total)")
                .font(OneraTypography.monoSmall.weight(.medium))
                .foregroundStyle(theme.textSecondary)
                .accessibilityIdentifier("branchCount")
                .accessibilityLabel("Response version \(current) of \(total)")
            
            // Next button
            Button {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                onNextBranch?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current >= total)
            .opacity(current < total ? 1 : 0.3)
            .accessibilityIdentifier("branchNext")
            .accessibilityLabel("Next response version")
            .accessibilityHint(current < total ? "Shows version \(current + 1) of \(total)" : "No next version available")
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.leading, OneraSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response versions. Version \(current) of \(total)")
    }
    
    // MARK: - Thinking Tag Parser
    
    /// Supported thinking tags
    private static let thinkingTags = ["think", "thinking", "reason", "reasoning"]
    
    /// Parse content and extract thinking blocks
    private func parseThinkingContent(_ content: String) -> ParsedMessageContent {
        guard !content.isEmpty else {
            return ParsedMessageContent(displayContent: "", thinkingContent: nil, isThinking: false)
        }
        
        var displayContent = content
        var thinkingBlocks: [String] = []
        var isThinking = false
        
        // Build regex pattern for complete blocks: <tag>content</tag>
        let tagsPattern = Self.thinkingTags.joined(separator: "|")
        let completeBlockPattern = "<(\(tagsPattern))>([\\s\\S]*?)</\\1>"
        
        // Find and extract complete thinking blocks
        if let regex = try? NSRegularExpression(pattern: completeBlockPattern, options: [.caseInsensitive]) {
            let nsContent = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
            
            // Process matches in reverse order to preserve indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let contentRange = match.range(at: 2)
                    let thinkingText = nsContent.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !thinkingText.isEmpty {
                        thinkingBlocks.insert(thinkingText, at: 0)
                    }
                    // Remove the block from display content
                    displayContent = (displayContent as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        
        // Check for incomplete (still streaming) thinking block: <tag>content (no closing tag)
        let openTagPattern = "<(\(tagsPattern))>([\\s\\S]*)$"
        if let regex = try? NSRegularExpression(pattern: openTagPattern, options: [.caseInsensitive]) {
            let nsDisplay = displayContent as NSString
            if let match = regex.firstMatch(in: displayContent, options: [], range: NSRange(location: 0, length: nsDisplay.length)) {
                if match.numberOfRanges >= 3 {
                    let contentRange = match.range(at: 2)
                    let thinkingText = nsDisplay.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !thinkingText.isEmpty {
                        thinkingBlocks.append(thinkingText)
                    }
                    // Remove the incomplete block from display content
                    displayContent = (displayContent as NSString).replacingCharacters(in: match.range, with: "")
                    isThinking = true
                }
            }
        }
        
        // Clean up display content
        displayContent = displayContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        let combinedThinking = thinkingBlocks.isEmpty ? nil : thinkingBlocks.joined(separator: "\n\n")
        
        return ParsedMessageContent(
            displayContent: displayContent,
            thinkingContent: combinedThinking,
            isThinking: isThinking
        )
    }
    
    // MARK: - User Message View
    
    @ViewBuilder
    private var userMessageView: some View {
        if isEditing {
            // Editing mode
            VStack(alignment: .trailing, spacing: OneraSpacing.sm) {
                HStack {
                    Spacer(minLength: 40)
                    
                    TextField("Edit message", text: $editText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, OneraSpacing.lg)
                        .padding(.vertical, OneraSpacing.md)
                        .background(theme.userBubble)
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.bubble))
                        .focused($isEditFocused)
                }
                
                HStack(spacing: OneraSpacing.md) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .foregroundStyle(theme.textSecondary)
                    
                    Button("Save") {
                        saveEdit(regenerate: false)
                    }
                    .foregroundStyle(theme.textPrimary)
                    
                    Button("Send") {
                        saveEdit(regenerate: true)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.info)
                }
                .font(OneraTypography.subheadline)
            }
        } else {
            // Normal display mode
            HStack(alignment: .top) {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: OneraSpacing.xxs) {
                    Text(message.content)
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, OneraSpacing.lg)
                        .padding(.vertical, OneraSpacing.md)
                        .background(theme.userBubble)
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.bubble))
                        .textSelection(.enabled)
                        .contextMenu {
                            Button {
                                #if os(iOS)
                                UIPasteboard.general.string = message.content
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                #elseif os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                                #endif
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if onEdit != nil {
                                Button {
                                    startEdit()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                        }
                    
                    // Edited indicator
                    if message.edited == true {
                        Text("Edited")
                            .font(OneraTypography.caption2)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.trailing, OneraSpacing.sm)
                    }
                }
            }
        }
    }
    
    // MARK: - Edit Actions
    
    private func startEdit() {
        editText = message.content
        isEditing = true
        isEditFocused = true
    }
    
    private func cancelEdit() {
        isEditing = false
        editText = ""
        isEditFocused = false
    }
    
    private func saveEdit(regenerate: Bool) {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != message.content {
            onEdit?(trimmed, regenerate)
        }
        isEditing = false
        editText = ""
        isEditFocused = false
    }
    
    // MARK: - Subviews
    
    private var assistantActionButtons: some View {
        HStack(spacing: OneraSpacing.sm) {
            // Copy button with feedback
            copyButton
            
            // Regenerate button
            if onRegenerate != nil {
                regenerateButton
            }
            
            // Read aloud button
            if onSpeak != nil || onStopSpeaking != nil {
                speakButton
            }
            
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.top, OneraSpacing.sm)
        .padding(.bottom, OneraSpacing.xxs)
        .contentShape(Rectangle())
        .zIndex(1)
    }
    
    private var copyButton: some View {
        Button(action: doCopy) {
            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(showCopiedFeedback ? theme.success : theme.textSecondary)
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .background(showCopiedFeedback ? theme.success.opacity(0.15) : theme.secondaryBackground)
                .clipShape(Circle())
                .animateBouncyWithReducedMotion(value: showCopiedFeedback)
        }
        .buttonStyle(ActionButtonStyle())
        .contentShape(Circle())
        .accessibilityIdentifier("copyButton")
        .accessibilityLabel(showCopiedFeedback ? "Copied to clipboard" : "Copy message")
        .accessibilityHint("Copies the message text to clipboard")
    }
    
    private func doCopy() {
        // Copy to clipboard
        #if os(iOS)
        UIPasteboard.general.string = parsedContent.displayContent
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parsedContent.displayContent, forType: .string)
        #endif
        
        // Show visual feedback
        withAnimation(OneraAnimation.springBouncy) {
            showCopiedFeedback = true
        }
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(OneraAnimation.standard) {
                showCopiedFeedback = false
            }
        }
    }
    
    private var regenerateButton: some View {
        Button(action: doRegenerate) {
            Image(systemName: "arrow.clockwise")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(isRegenerating ? theme.info : theme.textSecondary)
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .background(isRegenerating ? theme.info.opacity(0.15) : theme.secondaryBackground)
                .clipShape(Circle())
                .rotationEffect(.degrees(isRegenerating ? 360 : 0))
                .animateRepeatingIfAllowed(OneraAnimation.rotate, isActive: isRegenerating)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .disabled(isRegenerating)
        .accessibilityIdentifier("regenerateButton")
        .accessibilityLabel(isRegenerating ? "Regenerating response" : "Regenerate response")
        .accessibilityHint("Generates a new response from the assistant")
    }
    
    private func doRegenerate() {
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        // Show visual feedback
        withAnimation(OneraAnimation.springBouncy) {
            isRegenerating = true
        }
        
        // Call the regenerate callback
        onRegenerate?()
        
        // Reset after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(OneraAnimation.standard) {
                isRegenerating = false
            }
        }
    }
    
    private var speakButton: some View {
        Button(action: doSpeak) {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(isSpeaking ? theme.error : theme.textSecondary)
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .background(isSpeaking ? theme.error.opacity(0.15) : theme.secondaryBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityIdentifier("speakButton")
        .accessibilityLabel(isSpeaking ? "Stop speaking" : "Read aloud")
        .accessibilityHint(isSpeaking ? "Stops text-to-speech" : "Reads the message aloud")
    }
    
    private func doSpeak() {
        // Haptic feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        
        if isSpeaking {
            onStopSpeaking?()
        } else {
            onSpeak?(parsedContent.displayContent)
        }
    }
}

// MARK: - Markdown Content View with Code Block Detection

struct MarkdownContentView: View {
    @Environment(\.theme) private var theme
    let content: String
    let isStreaming: Bool
    
    var body: some View {
        if content.isEmpty && isStreaming {
            streamingPlaceholder
        } else {
            VStack(alignment: .leading, spacing: OneraSpacing.md) {
                // Parse and render content blocks
                ForEach(Array(parseContent().enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .text(let text):
                        NativeMarkdownText(text: text)
                    case .code(let code, let language):
                        CodeBlockView(code: code, language: language)
                    }
                }
                
                if isStreaming {
                    streamingCursor
                }
            }
        }
    }
    
    private var streamingPlaceholder: some View {
        HStack(spacing: OneraSpacing.xxs) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(theme.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.5)
            }
        }
        .padding(.vertical, OneraSpacing.xxs)
    }
    
    private var streamingCursor: some View {
        Rectangle()
            .fill(theme.textPrimary)
            .frame(width: 2, height: 16)
            .opacity(0.7)
            .modifier(BlinkingModifier())
    }
    
    // Parse markdown content into text and code blocks
    private func parseContent() -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(content)]
        }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        
        var lastEnd = 0
        
        for match in matches {
            // Text before code block
            if match.range.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let text = nsContent.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.text(text))
                }
            }
            
            // Code block
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language = languageRange.length > 0 ? nsContent.substring(with: languageRange) : nil
            let code = nsContent.substring(with: codeRange)
            
            blocks.append(.code(code, language))
            
            lastEnd = match.range.location + match.range.length
        }
        
        // Remaining text after last code block
        if lastEnd < nsContent.length {
            let text = nsContent.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.text(text))
            }
        }
        
        // If no blocks found, treat entire content as text
        if blocks.isEmpty {
            blocks.append(.text(content))
        }
        
        return blocks
    }
}

enum ContentBlock {
    case text(String)
    case code(String, String?) // code, language
}

// MARK: - Native Markdown Text (Replaces Textual)

/// Native SwiftUI markdown text view using AttributedString
struct NativeMarkdownText: View {
    @Environment(\.theme) private var theme
    let text: String
    
    private var attributedText: AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            ))
            // Apply theme colors
            attributed.foregroundColor = theme.textPrimary
            return attributed
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(text)
        }
    }
    
    var body: some View {
        Text(attributedText)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Code Block View (Separate from Textual)

struct CodeBlockView: View {
    @Environment(\.theme) private var theme
    let code: String
    let language: String?
    
    @State private var copied = false
    @State private var highlightedCode: AttributedString?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language ?? "code")
                    .font(OneraTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                
                Spacer()
                
                // Copy button - native SwiftUI button, NOT inside Textual
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: OneraSpacing.xs) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(OneraTypography.buttonSmall)
                        Text(copied ? "Copied!" : "Copy code")
                            .font(OneraTypography.buttonSmall)
                    }
                    .foregroundStyle(copied ? theme.success : theme.textSecondary)
                    .padding(.horizontal, OneraSpacing.md)
                    .frame(minHeight: AccessibilitySize.minTouchTarget)
                    .background(copied ? theme.success.opacity(0.2) : theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.small))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("codeBlockCopyButton")
                .accessibilityLabel(copied ? "Code copied to clipboard" : "Copy code")
                .accessibilityHint("Copies the code block to clipboard")
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(theme.tertiaryBackground)
            
            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(OneraTypography.mono)
                        .textSelection(.enabled)
                        .padding(.vertical, OneraSpacing.md)
                        .padding(.horizontal, OneraSpacing.comfortable)
                } else {
                    Text(code)
                        .font(OneraTypography.mono)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .padding(.vertical, OneraSpacing.md)
                        .padding(.horizontal, OneraSpacing.comfortable)
                }
            }
            .background(theme.secondaryBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.standard, style: .continuous))
        .task {
            await highlightCode()
        }
        .onChange(of: colorScheme) { _, _ in
            Task {
                await highlightCode()
            }
        }
    }
    
    private func highlightCode() async {
        // Capture values before entering detached task to avoid MainActor isolation issues
        let codeText = code
        let lang = language
        let isDark = colorScheme == .dark
        
        let highlighted = await Task.detached(priority: .userInitiated) {
            SyntaxHighlighter.shared.highlight(code: codeText, language: lang, isDark: isDark)
        }.value
        
        await MainActor.run {
            self.highlightedCode = highlighted
        }
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = code
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        
        withAnimation(OneraAnimation.springBouncy) {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(OneraAnimation.standard) {
                copied = false
            }
        }
    }
}

// MARK: - Syntax Highlighter

/// Thread-safe syntax highlighter - explicitly nonisolated since it uses NSLock for thread safety
final class SyntaxHighlighter: @unchecked Sendable {
    nonisolated(unsafe) static let shared = SyntaxHighlighter()
    
    /// Using nonisolated(unsafe) since access is protected by lock
    private nonisolated(unsafe) let highlightr: Highlightr?
    private let lock = NSLock()
    
    private init() {
        highlightr = Highlightr()
    }
    
    nonisolated func highlight(code: String, language: String?, isDark: Bool) -> AttributedString? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let highlightr else { return nil }
        
        // Set theme based on color scheme
        let theme = isDark ? "atom-one-dark" : "atom-one-light"
        highlightr.setTheme(to: theme)
        
        // Highlight the code
        let lang = language ?? "plaintext"
        guard let highlighted = highlightr.highlight(code, as: lang) else {
            return nil
        }
        
        // Convert NSAttributedString to AttributedString
        do {
            #if os(iOS)
            return try AttributedString(highlighted, including: \.uiKit)
            #elseif os(macOS)
            return try AttributedString(highlighted, including: \.appKit)
            #endif
        } catch {
            return nil
        }
    }
}

// MARK: - Action Button Style (Visual Feedback on Press + Hover)

struct ActionButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : (isHovered ? 1.05 : 1.0))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : (isHovered ? 0.05 : 0))
            .animation(OneraAnimation.quick, value: configuration.isPressed)
            .animation(OneraAnimation.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// For backward compatibility
typealias ResponsiveButtonStyle = ActionButtonStyle

// MARK: - Blinking Cursor Modifier

struct BlinkingModifier: ViewModifier {
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(OneraAnimation.blink) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Attachments View

struct AttachmentsView: View {
    
    let attachments: [Attachment]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OneraSpacing.sm) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnailView(attachment: attachment)
                }
            }
        }
    }
}

struct AttachmentThumbnailView: View {
    
    let attachment: Attachment
    
    var body: some View {
        Group {
            switch attachment.type {
            case .image:
                #if os(iOS)
                if let uiImage = UIImage(data: attachment.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.medium))
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: attachment.data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.medium))
                }
                #endif
                
            case .file:
                HStack {
                    Image(systemName: "doc.fill")
                    Text(attachment.fileName ?? "File")
                        .lineLimit(1)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: OneraRadius.medium))
            }
        }
    }
}

// MARK: - Reasoning View

/// Reasoning/thinking display with bottom drawer sheet (ChatGPT style)
struct ReasoningView: View {
    @Environment(\.theme) private var theme
    let reasoning: String
    let isStreaming: Bool
    
    @State private var showDrawer = false
    @State private var startTime: Date?
    @State private var duration: Int = 0
    
    var body: some View {
        // Trigger button - tapping opens bottom drawer
        Button {
            if !isStreaming {
                showDrawer = true
            }
        } label: {
            HStack(spacing: OneraSpacing.xs) {
                // Brain icon with pulse animation when streaming
                Image(systemName: "brain")
                    .font(OneraTypography.buttonSmall)
                    .foregroundStyle(isStreaming ? theme.reasoning : theme.textSecondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isStreaming)
                
                // Label - "Thinking" when streaming, duration when complete
                if isStreaming {
                    Text("Thinking")
                        .font(OneraTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                    
                    // Streaming dots indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(theme.reasoning)
                                .frame(width: 4, height: 4)
                                .opacity(0.7)
                                .modifier(PulsingDotModifier(delay: Double(index) * 0.15))
                        }
                    }
                } else if duration > 0 {
                    Text(formatDurationShort(duration))
                        .font(OneraTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("Reasoning")
                        .font(OneraTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                
                // Chevron (pointing right to indicate tap to expand)
                if !isStreaming {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, OneraSpacing.compact)
            .padding(.vertical, OneraSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.small)
                    .fill(theme.secondaryBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
        .accessibilityIdentifier("reasoningButton")
        .accessibilityLabel(isStreaming ? "AI is thinking" : "View reasoning")
        .accessibilityHint(isStreaming ? "Thinking in progress" : "Opens the reasoning details drawer")
        .accessibilityValue(duration > 0 ? Text("Thought for \(duration) seconds") : Text(""))
        .sheet(isPresented: $showDrawer) {
            ThinkingDrawerView(
                reasoning: reasoning,
                duration: duration
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if isStreaming {
                startTime = Date()
            }
        }
        .onChange(of: isStreaming) { wasStreaming, nowStreaming in
            if wasStreaming && !nowStreaming {
                // Streaming just ended
                if let start = startTime {
                    duration = Int(Date().timeIntervalSince(start))
                }
            } else if nowStreaming && !wasStreaming {
                // Streaming just started
                startTime = Date()
            }
        }
    }
    
    private func formatDurationShort(_ seconds: Int) -> String {
        if seconds < 60 {
            return "Thought for \(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "Thought for \(minutes)m"
            }
            return "Thought for \(minutes)m \(remainingSeconds)s"
        }
    }
}

// MARK: - Thinking Drawer View

/// Bottom drawer sheet showing thinking/reasoning content (ChatGPT style)
struct ThinkingDrawerView: View {
    @Environment(\.theme) private var theme
    let reasoning: String
    let duration: Int
    
    @Environment(\.dismiss) private var dismiss
    
    /// Parse reasoning into bullet points
    private var thinkingSteps: [String] {
        // Split by common delimiters - newlines, numbered lists, etc.
        let lines = reasoning.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // If we have very few lines, try to split by sentences
        if lines.count <= 2 {
            let sentences = reasoning.components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if sentences.count > lines.count {
                return sentences
            }
        }
        
        return lines
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OneraSpacing.lg) {
                    // Thinking steps as bullet points
                    ForEach(Array(thinkingSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: OneraSpacing.md) {
                            // Yellow bullet point
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            
                            Text(step)
                                .font(OneraTypography.body)
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, OneraSpacing.xl)
                .padding(.vertical, OneraSpacing.lg)
            }
            .navigationTitle(formatDurationTitle(duration))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.textSecondary)
                            .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
                    }
                    .accessibilityIdentifier("dismissReasoningDrawer")
                    .accessibilityLabel("Close")
                    .accessibilityHint("Closes the reasoning drawer")
                }
            }
        }
    }
    
    private func formatDurationTitle(_ seconds: Int) -> String {
        if seconds < 1 {
            return "Thought for less than a second"
        } else if seconds == 1 {
            return "Thought for 1s"
        } else if seconds < 60 {
            return "Thought for \(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "Thought for \(minutes)m"
            }
            return "Thought for \(minutes)m \(remainingSeconds)s"
        }
    }
}

/// Pulsing animation for streaming dots
private struct PulsingDotModifier: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1 : 0.5)
            .animation(
                .easeInOut(duration: 0.4)
                .repeatForever()
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: .mockUserMessage,
            onEdit: { content, regenerate in print("Edit: \(content), regenerate: \(regenerate)") }
        )
        MessageBubbleView(
            message: .mockAssistantMessage,
            onRegenerate: { print("Regenerate") },
            onSpeak: { print("Speak: \($0)") },
            onStopSpeaking: { print("Stop speaking") }
        )
        MessageBubbleView(message: .mockStreamingMessage)
    }
    .padding()
}
#endif