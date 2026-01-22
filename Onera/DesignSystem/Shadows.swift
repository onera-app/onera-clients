//
//  Shadows.swift
//  Onera
//
//  Centralized shadow styles
//

import SwiftUI

/// Onera Design System - Shadow Tokens
/// Consistent shadow styles used throughout the app
enum OneraShadow {
    
    /// Shadow style presets
    enum Style {
        /// Subtle shadow for cards and surfaces (opacity: 0.08, radius: 6)
        case subtle
        
        /// Medium shadow for elevated elements (opacity: 0.1, radius: 6)
        case medium
        
        /// Elevated shadow for floating elements (opacity: 0.1, radius: 8)
        case elevated
        
        /// Glass effect shadow (opacity: 0.1, radius: 8)
        case glass
    }
    
    /// Get shadow parameters for a given style
    static func parameters(for style: Style) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch style {
        case .subtle:
            return (.black.opacity(0.08), 6, 0, 2)
        case .medium:
            return (.black.opacity(0.1), 6, 0, 2)
        case .elevated:
            return (.black.opacity(0.1), 8, 0, 2)
        case .glass:
            return (.black.opacity(0.1), 8, 0, 2)
        }
    }
}

// MARK: - Shadow View Modifier

struct ShadowModifier: ViewModifier {
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
    /// Apply a standard shadow style
    func shadow(_ style: OneraShadow.Style) -> some View {
        modifier(ShadowModifier(style: style))
    }
    
    /// Apply subtle shadow (cards, surfaces)
    func subtleShadow() -> some View {
        shadow(.subtle)
    }
    
    /// Apply elevated shadow (floating elements)
    func elevatedShadow() -> some View {
        shadow(.elevated)
    }
    
    /// Apply glass effect shadow
    func glassShadow() -> some View {
        shadow(.glass)
    }
}
