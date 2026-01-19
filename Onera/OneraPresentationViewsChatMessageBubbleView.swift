//
//  MessageBubbleView.swift
//  Onera
//
//  Chat message bubble with markdown support
//

import SwiftUI

struct MessageBubbleView: View {
    
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 48)
            } else {
                avatarView
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                bubbleContent
                
                if !message.attachments.isEmpty {
                    AttachmentsView(attachments: message.attachments)
                }
                
                timestampView
            }
            
            if message.isAssistant {
                Spacer(minLength: 48)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var avatarView: some View {
        Circle()
            .fill(.tint.opacity(0.1))
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
    }
    
    private var bubbleContent: some View {
        Group {
            if message.isAssistant {
                MarkdownTextView(content: message.content, isStreaming: message.isStreaming)
            } else {
                Text(message.content)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.isUser {
                Color.accentColor
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }
    
    private var timestampView: some View {
        Text(message.createdAt, style: .time)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    
    let content: String
    let isStreaming: Bool
    
    var body: some View {
        Group {
            if content.isEmpty && isStreaming {
                streamingPlaceholder
            } else {
                Text(attributedContent)
                    .textSelection(.enabled)
            }
        }
    }
    
    private var streamingPlaceholder: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.5)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var attributedContent: AttributedString {
        do {
            var attributed = try AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            
            // Style code spans
            for run in attributed.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    attributed[run.range].font = .system(.body, design: .monospaced)
                    attributed[run.range].backgroundColor = Color(.tertiarySystemBackground)
                }
            }
            
            return attributed
        } catch {
            return AttributedString(content)
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

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(message: .mockUserMessage)
        MessageBubbleView(message: .mockAssistantMessage)
        MessageBubbleView(message: .mockStreamingMessage)
    }
    .padding()
}
