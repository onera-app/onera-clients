//
//  MessageBubble.swift
//  Onera
//
//  Chat message bubble with markdown support
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 48)
            } else {
                // Assistant avatar
                Circle()
                    .fill(.tint.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                Group {
                    if message.role == .assistant {
                        MarkdownText(message.content)
                    } else {
                        Text(message.content)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Attachments
                if !message.attachments.isEmpty {
                    AttachmentsView(attachments: message.attachments)
                }
                
                // Timestamp
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            Color.accentColor
        } else {
            Color(.secondarySystemBackground)
        }
    }
}

struct AttachmentsView: View {
    let attachments: [Attachment]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(attachment: attachment)
                }
            }
        }
    }
}

struct AttachmentThumbnail: View {
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
                    Text("File")
                        .lineLimit(1)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Markdown Text

struct MarkdownText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(attributedString)
            .textSelection(.enabled)
    }
    
    private var attributedString: AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            
            // Style code spans
            for run in attributed.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attributed[run.range].font = .system(.body, design: .monospaced)
                    attributed[run.range].backgroundColor = Color(.tertiarySystemBackground)
                }
            }
            
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String?
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let language = language {
                    Text(language)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = code
                    isCopied = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Label(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        MessageBubble(message: Message(
            role: .user,
            content: "Hello! Can you help me with Swift?"
        ))
        
        MessageBubble(message: Message(
            role: .assistant,
            content: "Of course! I'd be happy to help with Swift. What would you like to know?\n\nHere's a quick example:\n\n```swift\nlet greeting = \"Hello, World!\"\nprint(greeting)\n```"
        ))
    }
    .padding()
}
