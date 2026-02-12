//
//  MessageBubbleView.swift
//  Onera
//
//  Chat message bubble with markdown and reasoning support
//

import SwiftUI
import Highlightr
import Markdown
import Textual
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Renderer Selection

/// Which markdown renderer to use (for A/B testing)
enum MarkdownRenderer: String, CaseIterable {
    case custom = "Custom"
    case textual = "Textual"
}

struct MessageBubbleView: View {
    
    let message: Message
    /// Called when user saves edit (with regenerate: true to regenerate, false to just save)
    var onEdit: ((String, Bool) -> Void)?
    var onRegenerate: ((String?) -> Void)?
    var onSpeak: ((String) -> Void)?
    var onStopSpeaking: (() -> Void)?
    var isSpeaking: Bool = false
    
    // Branch navigation (response versioning)
    var branchInfo: (current: Int, total: Int)?
    var onPreviousBranch: (() -> Void)?
    var onNextBranch: (() -> Void)?
    
    @Environment(\.theme) private var theme
    @AppStorage("markdownRenderer") private var markdownRenderer: MarkdownRenderer = .custom
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showCopiedFeedback = false
    @State private var isRegenerating = false
    @State private var showTextSelection = false
    @FocusState private var isEditFocused: Bool
    
    /// Parse the message content for thinking tags
    private var parsedContent: ParsedMessageContent {
        ThinkingTagParser.parse(message.content)
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
                    
                    // Branch navigation — always visible (even during streaming)
                    // so users can switch back to older responses
                    if let branch = branchInfo, branch.total > 1 {
                        HStack(spacing: 0) {
                            if !message.isStreaming {
                                assistantActionButtons
                            }
                            branchNavigationView(current: branch.current, total: branch.total)
                            if message.isStreaming {
                                Spacer()
                            }
                        }
                    } else if !message.isStreaming {
                        // No branches — just show action buttons
                        HStack(spacing: 0) {
                            assistantActionButtons
                        }
                    }
                }
                .contextMenu {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = parsedContent.displayContent
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(parsedContent.displayContent, forType: .string)
                        #endif
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    #if os(iOS)
                    Button {
                        showTextSelection = true
                    } label: {
                        Label("Select Text", systemImage: "text.cursor")
                    }
                    #endif
                    
                    if onSpeak != nil || onStopSpeaking != nil {
                        Button {
                            doSpeak()
                        } label: {
                            Label(
                                isSpeaking ? "Stop Speaking" : "Read Aloud",
                                systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Renderer toggle for A/B testing
                    Menu {
                        ForEach(MarkdownRenderer.allCases, id: \.self) { renderer in
                            Button {
                                markdownRenderer = renderer
                            } label: {
                                if markdownRenderer == renderer {
                                    Label(renderer.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(renderer.rawValue)
                                }
                            }
                        }
                    } label: {
                        Label(
                            "Renderer: \(markdownRenderer.rawValue)",
                            systemImage: "paintbrush"
                        )
                    }
                }
                #if os(iOS)
                .sheet(isPresented: $showTextSelection) {
                    SelectableTextSheet(text: parsedContent.displayContent)
                }
                #endif
            }
        }
    }
    
    // MARK: - Branch Navigation View
    
    @State private var branchNavTrigger = false
    
    private func branchNavigationView(current: Int, total: Int) -> some View {
        let isDisabledByStreaming = message.isStreaming
        
        return HStack(spacing: OneraSpacing.xxs) {
            // Previous button
            Button {
                branchNavTrigger.toggle()
                onPreviousBranch?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.medium))
                    .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current <= 1 || isDisabledByStreaming)
            .opacity(current > 1 && !isDisabledByStreaming ? 1 : 0.3)
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
                branchNavTrigger.toggle()
                onNextBranch?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(current >= total || isDisabledByStreaming)
            .opacity(current < total && !isDisabledByStreaming ? 1 : 0.3)
            .accessibilityIdentifier("branchNext")
            .accessibilityLabel("Next response version")
            .accessibilityHint(current < total ? "Shows version \(current + 1) of \(total)" : "No next version available")
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.leading, OneraSpacing.sm)
        .sensoryFeedback(.impact(weight: .light), trigger: branchNavTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Response versions. Version \(current) of \(total)")
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
        HStack(spacing: OneraSpacing.xxs) {
            copyButton
            
            if onRegenerate != nil {
                regenerateButton
            }
            
            if onSpeak != nil || onStopSpeaking != nil {
                speakButton
            }
            
            Spacer()
        }
        .padding(.top, OneraSpacing.xs)
        .contentShape(Rectangle())
        .zIndex(1)
    }
    
    private var copyButton: some View {
        Button(action: doCopy) {
            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(showCopiedFeedback ? theme.success : theme.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: showCopiedFeedback)
        .accessibilityIdentifier("copyButton")
        .accessibilityLabel(showCopiedFeedback ? "Copied to clipboard" : "Copy message")
        .accessibilityHint("Copies the message text to clipboard")
    }
    
    private func doCopy() {
        // Copy to clipboard
        #if os(iOS)
        UIPasteboard.general.string = parsedContent.displayContent
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parsedContent.displayContent, forType: .string)
        #endif
        
        // Show visual feedback
        withAnimation(OneraAnimation.springBouncy) {
            showCopiedFeedback = true
        }
        
        // Auto-dismiss after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(OneraAnimation.standard) {
                showCopiedFeedback = false
            }
        }
    }
    
    private var regenerateButton: some View {
        Menu {
            Button {
                doRegenerate(modifier: nil)
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            
            Divider()
            
            Button {
                doRegenerate(modifier: "Please provide more details and expand on your explanation.")
            } label: {
                Label("Add Details", systemImage: "doc.text")
            }
            
            Button {
                doRegenerate(modifier: "Please be more concise and brief in your response.")
            } label: {
                Label("More Concise", systemImage: "arrow.down.right.and.arrow.up.left")
            }
            
            Button {
                doRegenerate(modifier: "Please be more creative and think outside the box.")
            } label: {
                Label("Be Creative", systemImage: "sparkles")
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(isRegenerating ? theme.info : theme.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .contentShape(Rectangle())
                .rotationEffect(.degrees(isRegenerating ? 360 : 0))
                .animateRepeatingIfAllowed(OneraAnimation.rotate, isActive: isRegenerating)
        } primaryAction: {
            doRegenerate(modifier: nil)
        }
        .menuStyle(.borderlessButton)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRegenerating)
        .disabled(isRegenerating)
        .accessibilityIdentifier("regenerateButton")
        .accessibilityLabel(isRegenerating ? "Regenerating response" : "Regenerate response")
        .accessibilityHint("Tap to regenerate, hold for options")
    }
    
    private func doRegenerate(modifier: String? = nil) {
        // Show visual feedback
        withAnimation(OneraAnimation.springBouncy) {
            isRegenerating = true
        }
        
        // Call the regenerate callback with optional modifier
        onRegenerate?(modifier)
        
        // Reset after short delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(OneraAnimation.standard) {
                isRegenerating = false
            }
        }
    }
    
    private var speakButton: some View {
        Button(action: doSpeak) {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(isSpeaking ? theme.error : theme.textTertiary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isSpeaking)
        .accessibilityIdentifier("speakButton")
        .accessibilityLabel(isSpeaking ? "Stop speaking" : "Read aloud")
        .accessibilityHint(isSpeaking ? "Stops text-to-speech" : "Reads the message aloud")
    }
    
    private func doSpeak() {
        if isSpeaking {
            onStopSpeaking?()
        } else {
            onSpeak?(parsedContent.displayContent)
        }
    }
}

// MARK: - Markdown Content View (swift-markdown AST)

struct MarkdownContentView: View {
    @Environment(\.theme) private var theme
    @AppStorage("markdownRenderer") private var renderer: MarkdownRenderer = .custom
    let content: String
    let isStreaming: Bool
    
    private var document: Document {
        Document(parsing: content)
    }
    
    var body: some View {
        if content.isEmpty && isStreaming {
            streamingPlaceholder
        } else {
            switch renderer {
            case .custom:
                customRendererView
            case .textual:
                textualRendererView
            }
        }
    }
    
    // MARK: - Custom Renderer (swift-markdown AST)
    
    private var customRendererView: some View {
        VStack(alignment: .leading, spacing: OneraSpacing.xl) {
            ForEach(Array(document.children.enumerated()), id: \.offset) { index, child in
                MarkdownBlockView(block: child)
                    .modifier(StreamingBlockFadeIn(
                        isStreaming: isStreaming,
                        blockIndex: index,
                        totalBlocks: document.childCount
                    ))
            }
            if isStreaming {
                streamingCursor
            }
        }
    }
    
    // MARK: - Textual Renderer (gonzalezreal/textual)
    
    private var textualRendererView: some View {
        VStack(alignment: .leading, spacing: 0) {
            StructuredText(markdown: content)
                .font(OneraTypography.body)
                .foregroundStyle(theme.textPrimary)
                .textual.textSelection(.enabled)
                .textual.structuredTextStyle(.gitHub)
            if isStreaming {
                streamingCursor
            }
        }
    }
    
    private var streamingPlaceholder: some View {
        PhaseAnimator([false, true]) { phase in
            HStack(spacing: OneraSpacing.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(theme.textSecondary)
                        .frame(width: 5, height: 5)
                        .opacity(phase ? 0.8 : 0.3)
                        .scaleEffect(phase ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6).delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
        }
        .padding(.vertical, OneraSpacing.xs)
        .transition(.opacity.animation(OneraAnimation.springQuick))
    }
    
    private var streamingCursor: some View {
        Rectangle()
            .fill(theme.textPrimary)
            .frame(width: 2, height: 16)
            .opacity(0.7)
            .modifier(BlinkingModifier())
    }
}

// MARK: - Pulsing Dot Animation

struct PulsingDot: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.0 : 0.5))
            .opacity(reduceMotion ? 0.6 : (isAnimating ? 0.8 : 0.3))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                if !reduceMotion { isAnimating = true }
            }
    }
}

// MARK: - Streaming Block Fade In (v0-style staggered animation)

/// Fades in new markdown blocks as they appear during streaming.
/// Only the last few blocks animate — earlier blocks are already visible.
struct StreamingBlockFadeIn: ViewModifier {
    let isStreaming: Bool
    let blockIndex: Int
    let totalBlocks: Int
    
    @State private var opacity: Double = 0
    
    /// Only animate blocks near the end of the content (the "new" ones)
    private var shouldAnimate: Bool {
        isStreaming && blockIndex >= totalBlocks - 2
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(shouldAnimate ? opacity : 1)
            .onAppear {
                if shouldAnimate {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        opacity = 1
                    }
                } else {
                    opacity = 1
                }
            }
            .onChange(of: totalBlocks) { _, _ in
                // When new blocks arrive, this block is no longer "last" — snap to full opacity
                if !shouldAnimate {
                    opacity = 1
                }
            }
    }
}

// MARK: - Block Renderer

/// Renders a single Markdown AST block node as a SwiftUI view.
struct MarkdownBlockView: View {
    @Environment(\.theme) private var theme
    let block: any Markup
    
    var body: some View {
        renderBlock(block)
    }
    
    @ViewBuilder
    private func renderBlock(_ node: any Markup) -> some View {
        switch node {
        case let heading as Heading:
            Text(InlineRenderer.render(heading, theme: theme))
                .font(headingFont(for: heading.level))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, OneraSpacing.xs)
            
        case let paragraph as Paragraph:
            Text(InlineRenderer.render(paragraph, theme: theme))
                .font(OneraTypography.callout)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(5)
            
        case let list as UnorderedList:
            VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                ForEach(Array(list.listItems.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: OneraSpacing.sm) {
                        Text("•")
                            .font(OneraTypography.callout)
                            .foregroundStyle(theme.textSecondary)
                        VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                            ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                                renderListChild(child)
                            }
                        }
                    }
                }
            }
            
        case let list as OrderedList:
            VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                ForEach(Array(list.listItems.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: OneraSpacing.sm) {
                        Text("\(Int(list.startIndex) + idx).")
                            .font(OneraTypography.callout)
                            .foregroundStyle(theme.textSecondary)
                            .frame(minWidth: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                            ForEach(Array(item.children.enumerated()), id: \.offset) { _, child in
                                renderListChild(child)
                            }
                        }
                    }
                }
            }
            
        case let quote as BlockQuote:
            HStack(alignment: .top, spacing: OneraSpacing.sm) {
                Rectangle()
                    .fill(theme.textSecondary.opacity(0.5))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.small))
                VStack(alignment: .leading, spacing: OneraSpacing.xs) {
                    ForEach(Array(quote.children.enumerated()), id: \.offset) { _, child in
                        MarkdownBlockView(block: child)
                    }
                }
            }
            .padding(.vertical, OneraSpacing.xs)
            
        case let codeBlock as CodeBlock:
            CodeBlockView(
                code: codeBlock.code.hasSuffix("\n")
                    ? String(codeBlock.code.dropLast())
                    : codeBlock.code,
                language: codeBlock.language
            )
            
        case let table as Markdown.Table:
            MarkdownTableView(table: table)
            
        case is ThematicBreak:
            Divider().padding(.vertical, OneraSpacing.xs)
            
        default:
            // HTMLBlock or other unsupported nodes – render as plain text
            // Use plainText where available; avoid format() which crashes on table sub-nodes
            Text(InlineRenderer.extractPlainText(from: node))
                .font(OneraTypography.callout)
                .foregroundStyle(theme.textPrimary)
        }
    }
    
    @ViewBuilder
    private func renderListChild(_ child: any Markup) -> some View {
        if let p = child as? Paragraph {
            Text(InlineRenderer.render(p, theme: theme))
                .font(OneraTypography.callout)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else if child is UnorderedList || child is OrderedList {
            MarkdownBlockView(block: child)
                .padding(.leading, OneraSpacing.md)
        } else {
            MarkdownBlockView(block: child)
        }
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return OneraTypography.title2.weight(.semibold)
        case 2: return OneraTypography.title3.weight(.semibold)
        case 3: return OneraTypography.headline.weight(.medium)
        default: return OneraTypography.subheadline.weight(.medium)
        }
    }
}

// MARK: - Inline Renderer (Markup → AttributedString)

/// Walks Markdown AST nodes and builds a styled AttributedString from inline content.
/// Recursively descends into block containers (e.g. Paragraph inside Table.Cell) to find inline nodes.
enum InlineRenderer {
    static func render(_ container: any Markup, theme: any ThemeColors) -> AttributedString {
        var result = AttributedString()
        collectInlines(from: container, into: &result, theme: theme)
        if result.characters.isEmpty {
            // Safe plain text fallback – avoid format() which crashes on Table.Cell nodes
            // Use plainText if available (InlineMarkup, InlineContainer, Table.Cell, Heading, Paragraph)
            let plain: String
            if let ptc = container as? any PlainTextConvertibleMarkup {
                plain = ptc.plainText
            } else {
                // Last resort: collect text by walking children manually
                plain = extractPlainText(from: container)
            }
            let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                var fallback = AttributedString(trimmed)
                fallback.foregroundColor = theme.textPrimary
                return fallback
            }
        }
        return result
    }
    
    /// Recursively extract plain text from any Markup node without using format().
    static func extractPlainText(from node: any Markup) -> String {
        if let ptc = node as? any PlainTextConvertibleMarkup {
            return ptc.plainText
        }
        return node.children.map { extractPlainText(from: $0) }.joined()
    }
    
    /// Recursively walk children – render InlineMarkup directly, descend into block containers.
    private static func collectInlines(from node: any Markup, into result: inout AttributedString, theme: any ThemeColors) {
        for child in node.children {
            if let inline = child as? any InlineMarkup {
                result.append(renderInline(inline, theme: theme))
            } else {
                // Block child (e.g. Paragraph inside a ListItem or Table.Cell) – recurse
                collectInlines(from: child, into: &result, theme: theme)
            }
        }
    }
    
    private static func renderInline(_ node: any InlineMarkup, theme: any ThemeColors) -> AttributedString {
        switch node {
        case let text as Markdown.Text:
            var s = AttributedString(text.string)
            s.foregroundColor = theme.textPrimary
            return s
            
        case let strong as Strong:
            var s = inlineChildren(of: strong, theme: theme)
            s.font = OneraTypography.callout.weight(.semibold)
            return s
            
        case let em as Emphasis:
            var s = inlineChildren(of: em, theme: theme)
            s.font = OneraTypography.callout.italic()
            return s
            
        case let code as InlineCode:
            var s = AttributedString(code.code)
            s.font = .system(.callout, design: .monospaced)
            s.backgroundColor = theme.secondaryBackground
            s.foregroundColor = theme.textPrimary
            return s
            
        case let link as Markdown.Link:
            var s = inlineChildren(of: link, theme: theme)
            if let dest = link.destination { s.link = URL(string: dest) }
            s.foregroundColor = theme.accent
            s.underlineStyle = .single
            return s
            
        case let strike as Strikethrough:
            var s = inlineChildren(of: strike, theme: theme)
            s.strikethroughStyle = .single
            return s
            
        case is SoftBreak:
            return AttributedString(" ")
            
        case is LineBreak:
            return AttributedString("\n")
            
        case let img as Markdown.Image:
            var s = AttributedString(img.title ?? img.source ?? "image")
            s.foregroundColor = theme.accent
            return s
            
        default:
            // Safe plain-text extraction for unknown inline types
            var s = AttributedString(node.plainText)
            s.foregroundColor = theme.textPrimary
            return s
        }
    }
    
    private static func inlineChildren(of node: any Markup, theme: any ThemeColors) -> AttributedString {
        var result = AttributedString()
        for child in node.children {
            if let inline = child as? any InlineMarkup {
                result.append(renderInline(inline, theme: theme))
            }
        }
        return result
    }
}

// MARK: - Table View

struct MarkdownTableView: View {
    @Environment(\.theme) private var theme
    let table: Markdown.Table
    
    private var columnCount: Int {
        Array(table.head.cells).count
    }
    
    private var alignments: [Markdown.Table.ColumnAlignment?] {
        table.columnAlignments
    }
    
    var body: some View {
        let bodyRows = Array(table.body.rows)
        
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(Array(table.head.cells.enumerated()), id: \.offset) { col, cell in
                        Text(InlineRenderer.render(cell, theme: theme))
                            .font(OneraTypography.footnote.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: gridAlignment(for: col)
                            )
                            .padding(.horizontal, OneraSpacing.md)
                            .padding(.vertical, OneraSpacing.compact)
                    }
                }
                .background(theme.secondaryBackground.opacity(0.8))
                
                // Separator under header
                Divider()
                    .gridCellUnsizedAxes(.horizontal)
                
                // Body rows
                ForEach(Array(bodyRows.enumerated()), id: \.offset) { rowIdx, row in
                    GridRow {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { col, cell in
                            Text(InlineRenderer.render(cell, theme: theme))
                                .font(OneraTypography.footnote)
                                .foregroundStyle(theme.textPrimary)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: gridAlignment(for: col)
                                )
                                .padding(.horizontal, OneraSpacing.md)
                                .padding(.vertical, OneraSpacing.sm)
                                .textSelection(.enabled)
                        }
                    }
                    .background(
                        rowIdx % 2 == 0
                            ? Color.clear
                            : theme.secondaryBackground.opacity(0.35)
                    )
                    
                    // Row separator (except after last row)
                    if rowIdx < bodyRows.count - 1 {
                        Divider()
                            .opacity(0.4)
                            .gridCellUnsizedAxes(.horizontal)
                    }
                }
            }
            .frame(minWidth: CGFloat(columnCount) * 100)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: OneraRadius.medium)
                    .stroke(theme.border.opacity(0.6), lineWidth: 0.5)
            )
        }
    }
    
    private func gridAlignment(for col: Int) -> Alignment {
        guard col < alignments.count, let a = alignments[col] else { return .leading }
        switch a {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    @Environment(\.theme) private var theme
    let code: String
    let language: String?
    
    @State private var copied = false
    @State private var highlightedCode: AttributedString?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact header — language label + icon-only copy button
            HStack(spacing: OneraSpacing.xs) {
                Text(language ?? "code")
                    .font(OneraTypography.caption2)
                    .foregroundStyle(theme.textSecondary)
                
                Spacer()
                
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(OneraTypography.buttonSmall)
                            .contentTransition(.symbolEffect(.replace))
                        Text(copied ? "Copied!" : "Copy")
                            .font(OneraTypography.buttonSmall)
                            .contentTransition(.interpolate)
                    }
                    .foregroundStyle(copied ? theme.success : theme.textSecondary)
                    .padding(.horizontal, OneraSpacing.sm)
                    .padding(.vertical, OneraSpacing.xxs)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: copied)
                .accessibilityIdentifier("codeBlockCopyButton")
                .accessibilityLabel(copied ? "Code copied to clipboard" : "Copy code")
                .accessibilityHint("Copies the code block to clipboard")
            }
            .padding(.horizontal, OneraSpacing.compact)
            .padding(.vertical, OneraSpacing.xs)
            .background(theme.tertiaryBackground)
            
            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: false) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, OneraSpacing.sm)
                        .padding(.horizontal, OneraSpacing.compact)
                } else {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .padding(.vertical, OneraSpacing.sm)
                        .padding(.horizontal, OneraSpacing.compact)
                }
            }
            .background(theme.secondaryBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.mediumSmall, style: .continuous))
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
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        
        withAnimation(OneraAnimation.springBouncy) {
            copied = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(OneraAnimation.standard) {
                copied = false
            }
        }
    }
}

// MARK: - Syntax Highlighter

/// Thread-safe syntax highlighter - explicitly nonisolated since it uses NSLock for thread safety
final class SyntaxHighlighter: @unchecked Sendable {
    nonisolated static let shared = SyntaxHighlighter()
    
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 0.7 : (isVisible ? 1 : 0))
            .onAppear {
                if !reduceMotion {
                    withAnimation(OneraAnimation.blink) {
                        isVisible.toggle()
                    }
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
                        .font(.caption2.weight(.semibold))
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
                            .font(.title2)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isAnimating ? 1.3 : 0.8))
            .opacity(reduceMotion ? 0.7 : (isAnimating ? 1 : 0.5))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.4)
                    .repeatForever()
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                if !reduceMotion { isAnimating = true }
            }
    }
}

// MARK: - Selectable Text Sheet (iOS)

#if os(iOS)
/// A sheet that presents message text in a native UITextView for free-form text selection.
/// This gives the full iOS text selection experience with drag handles, copy, share, etc.
struct SelectableTextSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            SelectableTextViewRepresentable(text: text)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .navigationTitle("Select Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// UITextView wrapper that renders markdown as attributed text with native text selection handles.
/// Parses the markdown content so bold, italic, code, links, and headings are styled properly.
private struct SelectableTextViewRepresentable: UIViewRepresentable {
    let text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.dataDetectorTypes = [.link, .phoneNumber]
        textView.alwaysBounceVertical = true
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Attempt markdown → NSAttributedString via the system parser
        if let markdownAttr = try? NSAttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            // Re-style with Dynamic Type body font and label color
            let mutable = NSMutableAttributedString(attributedString: markdownAttr)
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
            mutable.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
            // Preserve bold/italic from the markdown parse by re-enumerating
            markdownAttr.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                guard let font = value as? UIFont else { return }
                let traits = font.fontDescriptor.symbolicTraits
                var descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
                if traits.contains(.traitBold) || traits.contains(.traitItalic) {
                    var newTraits: UIFontDescriptor.SymbolicTraits = []
                    if traits.contains(.traitBold) { newTraits.insert(.traitBold) }
                    if traits.contains(.traitItalic) { newTraits.insert(.traitItalic) }
                    if let boldItalicDescriptor = descriptor.withSymbolicTraits(newTraits) {
                        descriptor = boldItalicDescriptor
                    }
                    mutable.addAttribute(.font, value: UIFont(descriptor: descriptor, size: 0), range: range)
                }
                // Monospace (inline code)
                if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
                    let monoFont = UIFont.monospacedSystemFont(
                        ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize * 0.9,
                        weight: .regular
                    )
                    mutable.addAttribute(.font, value: monoFont, range: range)
                    mutable.addAttribute(.backgroundColor, value: UIColor.secondarySystemBackground, range: range)
                }
            }
            textView.attributedText = mutable
        } else {
            // Fallback to plain text
            textView.font = .preferredFont(forTextStyle: .body)
            textView.textColor = .label
            textView.text = text
        }
    }
}
#endif

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: .mockUserMessage,
            onEdit: { content, regenerate in print("Edit: \(content), regenerate: \(regenerate)") }
        )
        MessageBubbleView(
            message: .mockAssistantMessage,
            onRegenerate: { _ in print("Regenerate") },
            onSpeak: { print("Speak: \($0)") },
            onStopSpeaking: { print("Stop speaking") }
        )
        MessageBubbleView(message: .mockStreamingMessage)
    }
    .padding()
}
#endif
