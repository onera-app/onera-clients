//
//  CitationsView.swift
//  Onera
//
//  Displays source citations from AI responses
//

import SwiftUI

// MARK: - Citation Model

struct Citation: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let url: URL?
    let snippet: String?
    let sourceType: SourceType
    
    enum SourceType: String, Codable, Sendable {
        case web
        case document
        case note
        case unknown
        
        var iconName: String {
            switch self {
            case .web: return "globe"
            case .document: return "doc.text"
            case .note: return "note.text"
            case .unknown: return "link"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        url: URL? = nil,
        snippet: String? = nil,
        sourceType: SourceType = .unknown
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.sourceType = sourceType
    }
}

// MARK: - Citations View

struct CitationsView: View {
    
    let citations: [Citation]
    
    @State private var expandedCitationId: String?
    
    var body: some View {
        if !citations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sources")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 6) {
                    ForEach(citations) { citation in
                        CitationCard(
                            citation: citation,
                            isExpanded: expandedCitationId == citation.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedCitationId == citation.id {
                                        expandedCitationId = nil
                                    } else {
                                        expandedCitationId = citation.id
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Citation Card

private struct CitationCard: View {
    
    let citation: Citation
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    // Source type icon
                    Image(systemName: citation.sourceType.iconName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    // Title
                    Text(citation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    // Snippet
                    if let snippet = citation.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .padding(.horizontal, 12)
                    }
                    
                    // URL link
                    if let url = citation.url {
                        Button {
                            openURL(url)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                Text(url.host ?? url.absoluteString)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Inline Citation Marker

/// A small numbered badge for inline citations in text
struct InlineCitationMarker: View {
    
    let number: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("[\(number)]")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.blue)
                .baselineOffset(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Citation \(number)")
        .accessibilityHint("Double-tap to view source")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 20) {
        CitationsView(citations: [
            Citation(
                title: "SwiftUI Documentation - Apple Developer",
                url: URL(string: "https://developer.apple.com/documentation/swiftui"),
                snippet: "SwiftUI helps you build great-looking apps across all Apple platforms with the power of Swift.",
                sourceType: .web
            ),
            Citation(
                title: "Human Interface Guidelines",
                url: URL(string: "https://developer.apple.com/design/human-interface-guidelines"),
                snippet: "Get in-depth information and UI resources for designing great apps that integrate seamlessly with Apple platforms.",
                sourceType: .document
            ),
            Citation(
                title: "Meeting Notes - iOS Architecture Discussion",
                snippet: "We discussed the new modular architecture approach using SPM...",
                sourceType: .note
            )
        ])
        
        Divider()
        
        HStack {
            Text("This is referenced in the documentation")
            InlineCitationMarker(number: 1) {
                print("Tapped citation 1")
            }
            Text("and confirmed by recent findings")
            InlineCitationMarker(number: 2) {
                print("Tapped citation 2")
            }
        }
        .font(.body)
    }
    .padding()
}
#endif
