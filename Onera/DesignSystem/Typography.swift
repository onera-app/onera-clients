//
//  Typography.swift
//  Onera
//
//  Centralized typography system
//

import SwiftUI

/// Onera Design System - Typography Tokens
/// All font styles used throughout the app should be referenced from here
enum OneraTypography {
    
    // MARK: - Display Styles
    
    /// Large display text (32pt, semibold) - Welcome screens, hero text
    static let displayLarge = Font.system(size: 32, weight: .semibold)
    
    /// Medium display text (24pt, semibold) - Section headers
    static let displayMedium = Font.system(size: 24, weight: .semibold)
    
    // MARK: - Title Styles
    
    /// Title style - Navigation titles, modal headers
    static let title = Font.title
    
    /// Title 2 style - Card headers
    static let title2 = Font.title2
    
    /// Title 3 style - Subsection headers
    static let title3 = Font.title3
    
    // MARK: - Body Styles
    
    /// Headline - Bold body text for emphasis
    static let headline = Font.headline
    
    /// Subheadline - Secondary information
    static let subheadline = Font.subheadline
    
    /// Body - Primary reading text
    static let body = Font.body
    
    /// Callout - Slightly smaller body text
    static let callout = Font.callout
    
    /// Footnote - Small body text
    static let footnote = Font.footnote
    
    // MARK: - Caption Styles
    
    /// Caption - Labels, timestamps
    static let caption = Font.caption
    
    /// Caption 2 - Very small labels
    static let caption2 = Font.caption2
    
    // MARK: - Monospaced Styles
    
    /// Monospaced - Code blocks, technical content
    static let mono = Font.system(.callout, design: .monospaced)
    
    /// Monospaced small - Inline code, counts
    static let monoSmall = Font.system(.caption, design: .monospaced)
    
    /// Monospaced digit - Numbers that should align
    static let monoDigit = Font.caption.monospacedDigit()
    
    // MARK: - Custom Sizes
    
    /// Navigation bar model name (17pt, semibold)
    static let navTitle = Font.system(size: 17, weight: .semibold)
    
    /// Button text (17pt, medium)
    static let button = Font.system(size: 17, weight: .medium)
    
    /// Small button text (12pt, medium)
    static let buttonSmall = Font.system(size: 12, weight: .medium)
    
    /// Icon-sized text (16pt, medium)
    static let iconLabel = Font.system(size: 16, weight: .medium)
    
    /// Large icon text (18pt, medium)
    static let iconLarge = Font.system(size: 18, weight: .medium)
    
    /// Extra large icon text (20pt, medium)
    static let iconXLarge = Font.system(size: 20, weight: .medium)
}

// MARK: - Font Weight Helpers

extension Font {
    /// Apply semibold weight
    func semibold() -> Font {
        self.weight(.semibold)
    }
    
    /// Apply medium weight
    func medium() -> Font {
        self.weight(.medium)
    }
    
    /// Apply bold weight
    func bold() -> Font {
        self.weight(.bold)
    }
}
