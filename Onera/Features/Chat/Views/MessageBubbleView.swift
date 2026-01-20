//
//  MessageBubbleView.swift
//  Onera
//
//  Chat message bubble with markdown and reasoning support
//

import SwiftUI
import Textual
import Highlightr

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
    
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showCopiedFeedback = false
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
                VStack(alignment: .leading, spacing: 8) {
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
        HStack(spacing: 4) {
            // Previous button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onPreviousBranch?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current <= 1)
            .opacity(current > 1 ? 1 : 0.3)
            .accessibilityIdentifier("branchPrevious")
            
            // Count display
            Text("\(current)/\(total)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("branchCount")
            
            // Next button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onNextBranch?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current >= total)
            .opacity(current < total ? 1 : 0.3)
            .accessibilityIdentifier("branchNext")
        }
        .foregroundStyle(Color(.systemGray))
        .padding(.leading, 8)
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
            VStack(alignment: .trailing, spacing: 8) {
                HStack {
                    Spacer(minLength: 40)
                    
                    TextField("Edit message", text: $editText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($isEditFocused)
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .foregroundStyle(.secondary)
                    
                    Button("Save") {
                        saveEdit(regenerate: false)
                    }
                    .foregroundStyle(.primary)
                    
                    Button("Send") {
                        saveEdit(regenerate: true)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                }
                .font(.subheadline)
            }
        } else {
            // Normal display mode
            HStack(alignment: .top) {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .textSelection(.enabled)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.content
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
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
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
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
        HStack(spacing: 16) {
            // Copy button with feedback
            Button {
                UIPasteboard.general.string = parsedContent.displayContent
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Show "Copied" feedback
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedFeedback = true
                }
                
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopiedFeedback = false
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(showCopiedFeedback ? .green : Color(.systemGray))
                    
                    if showCopiedFeedback {
                        Text("Copied")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.2), value: showCopiedFeedback)
            }
            .buttonStyle(.plain)
            .disabled(showCopiedFeedback)
            .accessibilityIdentifier("copyButton")
            
            // Regenerate button
            if let regenerate = onRegenerate {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    regenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("regenerateButton")
            }
            
            // Read aloud button
            if onSpeak != nil || onStopSpeaking != nil {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    if isSpeaking {
                        onStopSpeaking?()
                    } else {
                        onSpeak?(parsedContent.displayContent)
                    }
                } label: {
                    Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundStyle(isSpeaking ? .red : Color(.systemGray))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("speakButton")
            }
            
            Spacer()
        }
        .foregroundStyle(Color(.systemGray))
        .padding(.top, 8)
    }
}

// MARK: - Markdown Content View with Code Block Detection

struct MarkdownContentView: View {
    let content: String
    let isStreaming: Bool
    
    var body: some View {
        if content.isEmpty && isStreaming {
            streamingPlaceholder
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Parse and render content blocks
                ForEach(Array(parseContent().enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .text(let text):
                        StructuredText(markdown: text)
                            .textual.textSelection(.enabled)
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
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.5)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var streamingCursor: some View {
        Rectangle()
            .fill(.primary)
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

// MARK: - Code Block View (Separate from Textual)

struct CodeBlockView: View {
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Copy button - native SwiftUI button, NOT inside Textual
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                        Text(copied ? "Copied!" : "Copy code")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(copied ? .green : Color(.secondaryLabel))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(copied ? Color.green.opacity(0.2) : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                } else {
                    Text(code)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                }
            }
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        let highlighted = await Task.detached(priority: .userInitiated) {
            SyntaxHighlighter.shared.highlight(code: code, language: language, isDark: colorScheme == .dark)
        }.value
        
        await MainActor.run {
            self.highlightedCode = highlighted
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = code
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                copied = false
            }
        }
    }
}

// MARK: - Syntax Highlighter

final class SyntaxHighlighter: @unchecked Sendable {
    static let shared = SyntaxHighlighter()
    
    private let highlightr: Highlightr?
    private let lock = NSLock()
    
    private init() {
        highlightr = Highlightr()
    }
    
    func highlight(code: String, language: String?, isDark: Bool) -> AttributedString? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let highlightr = highlightr else { return nil }
        
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
            return try AttributedString(highlighted, including: \.uiKit)
        } catch {
            return nil
        }
    }
}

// MARK: - Blinking Cursor Modifier

struct BlinkingModifier: ViewModifier {
    @State private var isVisible = true
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
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
            HStack(spacing: 8) {
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
                if let uiImage = UIImage(data: attachment.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
            case .file:
                HStack {
                    Image(systemName: "doc.fill")
                    Text(attachment.fileName ?? "File")
                        .lineLimit(1)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Reasoning View

/// Reasoning/thinking display with bottom drawer sheet (ChatGPT style)
struct ReasoningView: View {
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
            HStack(spacing: 6) {
                // Brain icon with pulse animation when streaming
                Image(systemName: "brain")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isStreaming ? .purple : .secondary)
                    .symbolEffect(.pulse, options: .repeating, isActive: isStreaming)
                
                // Label - "Thinking" when streaming, duration when complete
                if isStreaming {
                    Text("Thinking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Streaming dots indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 4, height: 4)
                                .opacity(0.7)
                                .modifier(PulsingDotModifier(delay: Double(index) * 0.15))
                        }
                    }
                } else if duration > 0 {
                    Text(formatDurationShort(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Reasoning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Chevron (pointing right to indicate tap to expand)
                if !isStreaming {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
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
                VStack(alignment: .leading, spacing: 16) {
                    // Thinking steps as bullet points
                    ForEach(Array(thinkingSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            // Yellow bullet point
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            
                            Text(step)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(formatDurationTitle(duration))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
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
