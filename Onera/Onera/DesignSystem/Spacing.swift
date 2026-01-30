//
//  Spacing.swift
//  Onera
//
//  Centralized spacing scale
//

import SwiftUI

/// Onera Design System - Spacing Tokens
/// Consistent spacing values used throughout the app
enum OneraSpacing {
    
    // MARK: - Base Scale
    
    /// 4pt - Minimal spacing, tight layouts
    static let xxs: CGFloat = 4
    
    /// 6pt - Very small gaps
    static let xs: CGFloat = 6
    
    /// 8pt - Small spacing, inline elements
    static let sm: CGFloat = 8
    
    /// 10pt - Compact padding
    static let compact: CGFloat = 10
    
    /// 12pt - Medium spacing, standard gaps
    static let md: CGFloat = 12
    
    /// 14pt - Comfortable padding
    static let comfortable: CGFloat = 14
    
    /// 16pt - Large spacing, section padding
    static let lg: CGFloat = 16
    
    /// 20pt - Extra large spacing
    static let xl: CGFloat = 20
    
    /// 24pt - Section separators
    static let xxl: CGFloat = 24
    
    /// 32pt - Large section gaps
    static let xxxl: CGFloat = 32
    
    /// 40pt - Maximum spacing
    static let max: CGFloat = 40
    
    // MARK: - Semantic Spacing
    
    /// Standard horizontal page padding
    static let pagePadding: CGFloat = 16
    
    /// Standard vertical content padding
    static let contentPadding: CGFloat = 12
    
    /// Padding inside cards/containers
    static let cardPadding: CGFloat = 16
    
    /// Gap between list items
    static let listItemGap: CGFloat = 4
    
    /// Gap between sections
    static let sectionGap: CGFloat = 24
    
    /// Inset for grouped list rows
    static let listRowInset: CGFloat = 12
    
    /// Icon to text spacing
    static let iconTextGap: CGFloat = 12
    
    /// Button internal padding (horizontal)
    static let buttonPaddingH: CGFloat = 16
    
    /// Button internal padding (vertical)
    static let buttonPaddingV: CGFloat = 12
}

// MARK: - View Extension for Semantic Padding

extension View {
    /// Apply standard page padding
    func pagePadding() -> some View {
        self.padding(.horizontal, OneraSpacing.pagePadding)
    }
    
    /// Apply standard card padding
    func cardPadding() -> some View {
        self.padding(OneraSpacing.cardPadding)
    }
    
    /// Apply standard content padding
    func contentPadding() -> some View {
        self.padding(OneraSpacing.contentPadding)
    }
}
