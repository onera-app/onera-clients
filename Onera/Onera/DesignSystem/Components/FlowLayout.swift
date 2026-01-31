//
//  FlowLayout.swift
//  Onera
//
//  A flexible flow layout that wraps content to multiple lines
//

import SwiftUI

/// A layout that arranges views horizontally and wraps to the next line when needed
struct FlowLayout: Layout {
    
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            let x: CGFloat
            switch alignment {
            case .leading:
                x = bounds.minX + frame.origin.x
            case .center:
                x = bounds.midX - result.size.width / 2 + frame.origin.x
            case .trailing:
                x = bounds.maxX - result.size.width + frame.origin.x
            default:
                x = bounds.minX + frame.origin.x
            }
            
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        let totalWidth = frames.reduce(0) { max($0, $1.maxX) }
        let totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), frames)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Flow Layout") {
    VStack(alignment: .leading, spacing: 20) {
        Text("Tags Example")
            .font(.headline)
        
        FlowLayout(spacing: 8) {
            ForEach(["Swift", "SwiftUI", "iOS", "macOS", "watchOS", "tvOS", "visionOS", "Xcode", "UIKit", "AppKit"], id: \.self) { tag in
                Text(tag)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: 300)
    }
    .padding()
}
#endif
