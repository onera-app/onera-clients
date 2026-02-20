//
//  Typography.swift
//  Onera
//
//  Centralized typography system with Dynamic Type support
//

import SwiftUI

/// Onera Design System — Typography Tokens
///
/// All font styles used throughout the app should be referenced from here.
/// All styles support Dynamic Type for accessibility.
enum OneraTypography {
    
    // MARK: - Display Styles (Scalable)
    
    /// Large display text — Welcome screens, hero text
    static let displayLarge = Font.largeTitle.weight(.semibold)
    
    /// Medium display text — Section headers
    static let displayMedium = Font.title.weight(.semibold)
    
    // MARK: - Title Styles
    
    /// Title style — Navigation titles, modal headers
    static let title = Font.title
    
    /// Title 2 style — Card headers
    static let title2 = Font.title2
    
    /// Title 3 style — Subsection headers
    static let title3 = Font.title3
    
    // MARK: - Body Styles
    
    /// Headline — Bold body text for emphasis
    static let headline = Font.headline
    
    /// Subheadline — Secondary information
    static let subheadline = Font.subheadline
    
    /// Body — Primary reading text
    static let body = Font.body
    
    /// Callout — Slightly smaller body text (chat message content)
    static let callout = Font.callout
    
    /// Footnote — Small body text
    static let footnote = Font.footnote
    
    // MARK: - Caption Styles
    
    /// Caption — Labels, timestamps
    static let caption = Font.caption
    
    /// Caption 2 — Very small labels
    static let caption2 = Font.caption2
    
    // MARK: - Monospaced Styles
    
    /// Monospaced — Code blocks, technical content
    static let mono = Font.system(.callout, design: .monospaced)
    
    /// Monospaced small — Inline code, counts
    static let monoSmall = Font.system(.caption, design: .monospaced)
    
    /// Monospaced digit — Numbers that should align
    static let monoDigit = Font.caption.monospacedDigit()
    
    // MARK: - Semantic Styles (Scalable)
    
    /// Navigation bar title
    static let navTitle = Font.headline
    
    /// Button text
    static let button = Font.body.weight(.medium)
    
    /// Small button text
    static let buttonSmall = Font.caption.weight(.medium)
    
    /// Icon-sized text label
    static let iconLabel = Font.callout.weight(.medium)
    
    /// Large icon text
    static let iconLarge = Font.body.weight(.medium)
    
    /// Extra large icon text
    static let iconXLarge = Font.headline.weight(.medium)
}

// MARK: - Line Spacing Tokens

/// Consistent line spacing values for text blocks
enum OneraLineSpacing {
    /// 2pt — Tight line spacing (compact lists, captions)
    static let tight: CGFloat = 2
    
    /// 4pt — Standard line spacing (body text, paragraphs)
    static let standard: CGFloat = 4
    
    /// 6pt — Relaxed line spacing (reading-heavy content, markdown)
    static let relaxed: CGFloat = 6
}

// MARK: - Scaled Metrics for Custom Sizes

/// Use these @ScaledMetric properties in views that need specific pixel sizes
/// that still scale with Dynamic Type
struct ScaledTypographySizes {
    /// Large display icon size (base: 48pt, scales with .largeTitle)
    @ScaledMetric(relativeTo: .largeTitle) var displayIconLarge: CGFloat = 48
    
    /// Medium display icon size (base: 32pt, scales with .title)
    @ScaledMetric(relativeTo: .title) var displayIconMedium: CGFloat = 32
    
    /// Standard icon size (base: 24pt, scales with .body)
    @ScaledMetric(relativeTo: .body) var iconStandard: CGFloat = 24
    
    /// Small icon size (base: 16pt, scales with .caption)
    @ScaledMetric(relativeTo: .caption) var iconSmall: CGFloat = 16
    
    /// Avatar size (base: 40pt, scales with .body)
    @ScaledMetric(relativeTo: .body) var avatar: CGFloat = 40
    
    /// Large avatar size (base: 80pt, scales with .title)
    @ScaledMetric(relativeTo: .title) var avatarLarge: CGFloat = 80
    
    /// Touch target minimum (base: 44pt, scales with .body)
    @ScaledMetric(relativeTo: .body) var touchTarget: CGFloat = 44
    
    /// Button height (base: 50pt, scales with .body)
    @ScaledMetric(relativeTo: .body) var buttonHeight: CGFloat = 50
    
    /// Navigation bar button size (base: 44pt, scales with .body)
    @ScaledMetric(relativeTo: .body) var navButton: CGFloat = 44
    
    /// Chevron / disclosure indicator size (base: 10pt, scales with .caption2)
    @ScaledMetric(relativeTo: .caption2) var chevron: CGFloat = 10
    
    init() {}
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
