//
//  FollowUpsView.swift
//  Onera
//
//  Displays follow-up suggestions as tappable pill buttons
//

import SwiftUI

struct FollowUpsView: View {
    
    let followUps: [String]
    let onSelect: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    @State private var appeared = false
    
    var body: some View {
        if !followUps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested follow-ups")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(Array(followUps.enumerated()), id: \.element) { index, followUp in
                        FollowUpPill(text: followUp) {
                            onSelect(followUp)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .scaleEffect(appeared ? 1 : 0.9)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06),
                            value: appeared
                        )
                    }
                }
            }
            .padding(.top, OneraSpacing.sm)
            .onAppear {
                appeared = true
            }
        }
    }
}

// MARK: - Follow Up Pill

private struct FollowUpPill: View {
    
    let text: String
    let action: () -> Void
    
    @State private var isHovered = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, OneraSpacing.md)
                .padding(.vertical, OneraSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: OneraRadius.xl)
                        .fill(isHovered ? theme.accent.opacity(0.15) : theme.secondaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneraRadius.xl)
                        .stroke(isHovered ? theme.accent.opacity(0.3) : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isHovered)
        .onHover { hovering in
            withAnimation(OneraAnimation.springQuick) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Follow-up suggestion: \(text)")
        .accessibilityHint("Double-tap to send this as your next message")
    }
}

// MARK: - Preview
// Note: FlowLayout is defined in DesignSystem/Components/FlowLayout.swift

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 20) {
        FollowUpsView(
            followUps: [
                "Tell me more about that",
                "What are the alternatives?",
                "Can you give me an example?",
                "How does this compare to other approaches?"
            ],
            onSelect: { print("Selected: \($0)") }
        )
        
        Divider()
        
        FollowUpsView(
            followUps: [
                "Explain in simpler terms",
                "Show me the code"
            ],
            onSelect: { print("Selected: \($0)") }
        )
    }
    .padding()
}
#endif
