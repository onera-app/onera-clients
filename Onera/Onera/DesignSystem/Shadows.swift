//
//  Shadows.swift
//  Onera
//
//  Centralized shadow/elevation tokens
//

import SwiftUI

/// Onera Design System — Shadow Tokens
///
/// Four distinct elevation levels with clear visual differentiation.
/// Each level has unique opacity, radius, and offset values.
enum OneraShadow {
    
    /// Shadow elevation levels
    enum Level {
        /// Extra-subtle lift for cards in light mode (opacity: 0.06, radius: 2)
        case xs
        
        /// Standard elevation for cards and surfaces (opacity: 0.08, radius: 4)
        case sm
        
        /// Medium elevation for dropdowns and popovers (opacity: 0.10, radius: 8)
        case md
        
        /// High elevation for modals and floating panels (opacity: 0.14, radius: 16)
        case lg
    }
    
    /// Get shadow parameters for a given elevation level
    static func parameters(for level: Level) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch level {
        case .xs:
            return (.black.opacity(0.06), 2, 0, 1)
        case .sm:
            return (.black.opacity(0.08), 4, 0, 2)
        case .md:
            return (.black.opacity(0.10), 8, 0, 4)
        case .lg:
            return (.black.opacity(0.14), 16, 0, 8)
        }
    }
    
    // MARK: - Backward Compatibility
    
    /// Legacy shadow style type (maps to new Level)
    enum Style {
        case subtle
        case medium
        case elevated
        case glass
    }
    
    /// Legacy API — use `parameters(for level:)` instead
    static func parameters(for style: Style) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch style {
        case .subtle:   return parameters(for: .xs)
        case .medium:   return parameters(for: .sm)
        case .elevated: return parameters(for: .md)
        case .glass:    return parameters(for: .md)
        }
    }
}

// MARK: - Shadow View Modifier

struct ShadowModifier: ViewModifier {
    let level: OneraShadow.Level
    
    func body(content: Content) -> some View {
        let params = OneraShadow.parameters(for: level)
        return content.shadow(
            color: params.color,
            radius: params.radius,
            x: params.x,
            y: params.y
        )
    }
}

struct LegacyShadowModifier: ViewModifier {
    let style: OneraShadow.Style
    
    func body(content: Content) -> some View {
        let params = OneraShadow.parameters(for: style)
        return content.shadow(
            color: params.color,
            radius: params.radius,
            x: params.x,
            y: params.y
        )
    }
}

// MARK: - View Extension

extension View {
    /// Apply shadow at a specific elevation level
    func elevation(_ level: OneraShadow.Level) -> some View {
        modifier(ShadowModifier(level: level))
    }
    
    /// Apply a standard shadow style (legacy API)
    func shadow(_ style: OneraShadow.Style) -> some View {
        modifier(LegacyShadowModifier(style: style))
    }
    
    /// Apply subtle shadow (cards, surfaces)
    func subtleShadow() -> some View {
        elevation(.xs)
    }
    
    /// Apply elevated shadow (floating elements)
    func elevatedShadow() -> some View {
        elevation(.md)
    }
    
    /// Apply glass effect shadow
    func glassShadow() -> some View {
        elevation(.md)
    }
}
