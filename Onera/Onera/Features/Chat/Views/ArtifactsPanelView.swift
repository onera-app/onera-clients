//
//  ArtifactsPanelView.swift
//  Onera
//
//  Panel/sheet for displaying code/text artifacts from chat
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Code Artifact Model

struct CodeArtifact: Identifiable, Equatable {
    let id: String
    let title: String
    let content: String
    let language: String?
    let messageId: String
    
    init(id: String = UUID().uuidString, title: String, content: String, language: String? = nil, messageId: String) {
        self.id = id
        self.title = title
        self.content = content
        self.language = language
        self.messageId = messageId
    }
}

// MARK: - Artifact Extraction

enum ArtifactExtractor {
    /// Extract code blocks from assistant messages as artifacts
    static func extractArtifacts(from messages: [Message]) -> [CodeArtifact] {
        var artifacts: [CodeArtifact] = []
        let codeBlockPattern = "```(\\w*)\\n([\\s\\S]*?)```"
        
        for message in messages where message.role == .assistant {
            guard let regex = try? NSRegularExpression(pattern: codeBlockPattern) else { continue }
            let nsContent = message.content as NSString
            let matches = regex.matches(in: message.content, range: NSRange(location: 0, length: nsContent.length))
            
            for (index, match) in matches.enumerated() {
                guard match.numberOfRanges >= 3 else { continue }
                
                let langRange = match.range(at: 1)
                let codeRange = match.range(at: 2)
                
                let language = langRange.length > 0 ? nsContent.substring(with: langRange) : nil
                let code = nsContent.substring(with: codeRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !code.isEmpty else { continue }
                
                // Generate a title from language or first line
                let title: String
                if let lang = language, !lang.isEmpty {
                    title = "\(lang.capitalized) snippet \(index + 1)"
                } else {
                    let firstLine = code.components(separatedBy: .newlines).first ?? "Code"
                    title = String(firstLine.prefix(40))
                }
                
                artifacts.append(CodeArtifact(
                    title: title,
                    content: code,
                    language: language,
                    messageId: message.id
                ))
            }
        }
        
        return artifacts
    }
}

// MARK: - macOS Artifacts Panel

#if os(macOS)

struct ArtifactsPanelView: View {
    let artifacts: [CodeArtifact]
    @Binding var activeArtifactId: String?
    let onClose: () -> Void
    
    @Environment(\.theme) private var theme
    @State private var showCopied = false
    
    private var activeArtifact: CodeArtifact? {
        if let id = activeArtifactId {
            return artifacts.first(where: { $0.id == id })
        }
        return artifacts.last
    }
    
    private var activeIndex: Int {
        guard let active = activeArtifact else { return 0 }
        return artifacts.firstIndex(where: { $0.id == active.id }) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeArtifact?.title ?? "Artifacts")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let lang = activeArtifact?.language, !lang.isEmpty {
                        Text(lang)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if artifacts.count > 1 {
                    HStack(spacing: OneraSpacing.xxs) {
                        Button {
                            navigateToPrevious()
                        } label: {
                            OneraIcon.back.image
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .disabled(activeIndex <= 0)
                        .accessibilityLabel("Previous artifact")
                        
                        Text("\(activeIndex + 1)/\(artifacts.count)")
                            .font(.caption)
                            .monospacedDigit()
                        
                        Button {
                            navigateToNext()
                        } label: {
                            OneraIcon.chevronRight.image
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .disabled(activeIndex >= artifacts.count - 1)
                        .accessibilityLabel("Next artifact")
                    }
                    .foregroundStyle(.secondary)
                }
                
                Button {
                    onClose()
                } label: {
                    OneraIcon.close.image
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close panel")
                .accessibilityLabel("Close artifacts panel")
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Action bar
            HStack(spacing: OneraSpacing.xs) {
                Button {
                    copyToClipboard()
                } label: {
                    Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    saveToFile()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.xs)
            
            Divider()
            
            // Code content
            if let artifact = activeArtifact {
                ScrollView {
                    Text(artifact.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(OneraSpacing.md)
                }
            } else {
                VStack {
                    Spacer()
                    Text("No artifacts")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .background(theme.background)
    }
    
    // MARK: - Navigation
    
    private func navigateToPrevious() {
        let idx = max(0, activeIndex - 1)
        activeArtifactId = artifacts[idx].id
    }
    
    private func navigateToNext() {
        let idx = min(artifacts.count - 1, activeIndex + 1)
        activeArtifactId = artifacts[idx].id
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        guard let content = activeArtifact?.content else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
    
    private func saveToFile() {
        guard let artifact = activeArtifact else { return }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = artifactFileName(artifact)
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            try? artifact.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func artifactFileName(_ artifact: CodeArtifact) -> String {
        let ext: String
        switch artifact.language?.lowercased() {
        case "swift": ext = "swift"
        case "python", "py": ext = "py"
        case "javascript", "js": ext = "js"
        case "typescript", "ts": ext = "ts"
        case "html": ext = "html"
        case "css": ext = "css"
        case "json": ext = "json"
        case "kotlin", "kt": ext = "kt"
        case "java": ext = "java"
        case "rust", "rs": ext = "rs"
        case "go": ext = "go"
        case "ruby", "rb": ext = "rb"
        case "sql": ext = "sql"
        case "shell", "bash", "sh": ext = "sh"
        default: ext = "txt"
        }
        return "artifact.\(ext)"
    }
}

// MARK: - Artifact List (for sidebar-style)

struct ArtifactListView: View {
    let artifacts: [CodeArtifact]
    @Binding var activeArtifactId: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OneraSpacing.xs) {
                ForEach(artifacts) { artifact in
                    Button {
                        activeArtifactId = artifact.id
                    } label: {
                        HStack(spacing: OneraSpacing.xxs) {
                            OneraIcon.code.image
                                .font(.caption2)
                            Text(artifact.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, OneraSpacing.sm)
                        .padding(.vertical, OneraSpacing.xxs)
                        .background(activeArtifactId == artifact.id ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#endif

// MARK: - iOS Artifacts Sheet

#if os(iOS)

struct iOSArtifactsSheet: View {
    let artifacts: [CodeArtifact]
    @Binding var activeArtifactId: String?
    let onClose: () -> Void
    
    @Environment(\.theme) private var theme
    @State private var showCopied = false
    
    private var activeArtifact: CodeArtifact? {
        if let id = activeArtifactId {
            return artifacts.first(where: { $0.id == id })
        }
        return artifacts.last
    }
    
    private var activeIndex: Int {
        guard let active = activeArtifact else { return 0 }
        return artifacts.firstIndex(where: { $0.id == active.id }) ?? 0
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Artifact tabs if multiple
                if artifacts.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OneraSpacing.xs) {
                            ForEach(artifacts) { artifact in
                                Button {
                                    activeArtifactId = artifact.id
                                } label: {
                                    HStack(spacing: OneraSpacing.xxs) {
                                        OneraIcon.code.image
                                            .font(.caption2)
                                        Text(artifact.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, OneraSpacing.sm)
                                    .padding(.vertical, OneraSpacing.xs)
                                    .background(activeArtifactId == artifact.id ? Color.accentColor.opacity(0.15) : theme.secondaryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, OneraSpacing.sm)
                    }
                    
                    Divider()
                }
                
                // Action bar
                HStack(spacing: OneraSpacing.sm) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        shareArtifact()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    if let lang = activeArtifact?.language, !lang.isEmpty {
                        Text(lang)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, OneraSpacing.sm)
                
                Divider()
                
                // Code content
                if let artifact = activeArtifact {
                    ScrollView {
                        Text(artifact.content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    ContentUnavailableView("No Artifacts", systemImage: "chevron.left.forwardslash.chevron.right", description: Text("Code blocks from the conversation will appear here"))
                }
            }
            .navigationTitle(activeArtifact?.title ?? "Artifacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyToClipboard() {
        guard let content = activeArtifact?.content else { return }
        UIPasteboard.general.string = content
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
    
    private func shareArtifact() {
        guard let content = activeArtifact?.content else { return }
        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.keyWindow?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = root.view
                popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            }
            root.present(activityVC, animated: true)
        }
    }
}

#endif
