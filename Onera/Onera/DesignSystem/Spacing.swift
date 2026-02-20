//
//  Spacing.swift
//  Onera
//
//  Centralized spacing scale — strict 8pt grid
//

import SwiftUI

/// Onera Design System — Spacing Tokens
///
/// Built on a strict 8-point grid with 2pt and 4pt micro values.
/// All spacing in the app should reference these tokens.
///
/// Scale: 2 → 4 → 8 → 12 → 16 → 24 → 32 → 48 → 64
enum OneraSpacing {
    
    // MARK: - Base Scale (8pt grid)
    
    /// 2pt — Micro spacing: badge vertical padding, hairline gaps
    static let xxxs: CGFloat = 2
    
    /// 4pt — Minimal spacing: tight inline elements, icon badge offsets
    static let xxs: CGFloat = 4
    
    /// 8pt — Small spacing: inline elements, small gaps, icon-to-text tight
    static let xs: CGFloat = 8
    
    /// 12pt — Standard inner padding: list item gaps, compact card padding
    static let sm: CGFloat = 12
    
    /// 16pt — Standard section padding: page margins, card padding, button H padding
    static let md: CGFloat = 16
    
    /// 24pt — Section gaps: generous padding, section separators
    static let lg: CGFloat = 24
    
    /// 32pt — Large section gaps: major content separators
    static let xl: CGFloat = 32
    
    /// 48pt — Hero spacing: major section dividers, empty state spacing
    static let xxl: CGFloat = 48
    
    /// 64pt — Maximum breathing room: splash/onboarding hero areas
    static let xxxl: CGFloat = 64
    
    // MARK: - Semantic Spacing
    
    /// Standard horizontal page padding (16pt)
    static let pagePadding: CGFloat = md
    
    /// Standard vertical content padding (12pt)
    static let contentPadding: CGFloat = sm
    
    /// Padding inside cards/containers (16pt)
    static let cardPadding: CGFloat = md
    
    /// Gap between list items (4pt)
    static let listItemGap: CGFloat = xxs
    
    /// Gap between sections (24pt)
    static let sectionGap: CGFloat = lg
    
    /// Inset for grouped list rows (12pt)
    static let listRowInset: CGFloat = sm
    
    /// Icon to text spacing (8pt)
    static let iconTextGap: CGFloat = xs
    
    /// Button internal padding — horizontal (16pt)
    static let buttonPaddingH: CGFloat = md
    
    /// Button internal padding — vertical (12pt)
    static let buttonPaddingV: CGFloat = sm
    
    /// Gap between buttons in a group (12pt)
    static let buttonGap: CGFloat = sm
    
    // MARK: - Dynamic Spacing
    
    /// Message spacing based on chat density preference
    static func messageSpacing(for density: String) -> CGFloat {
        switch density {
        case "compact": return xs     // 8pt
        case "spacious": return lg    // 24pt
        default: return md            // 16pt (comfortable)
        }
    }
}

// MARK: - View Extension for Semantic Padding

extension View {
    /// Apply standard page padding (16pt horizontal)
    func pagePadding() -> some View {
        self.padding(.horizontal, OneraSpacing.pagePadding)
    }
    
    /// Apply standard card padding (16pt all sides)
    func cardPadding() -> some View {
        self.padding(OneraSpacing.cardPadding)
    }
    
    /// Apply standard content padding (12pt all sides)
    func contentPadding() -> some View {
        self.padding(OneraSpacing.contentPadding)
    }
}
