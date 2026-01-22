//
//  Radius.swift
//  Onera
//
//  Centralized corner radius tokens
//

import SwiftUI

/// Onera Design System - Corner Radius Tokens
/// Consistent corner radius values used throughout the app
enum OneraRadius {
    
    // MARK: - Base Scale
    
    /// 4pt - Minimal rounding (inline badges)
    static let xs: CGFloat = 4
    
    /// 6pt - Small rounding (code blocks, small buttons)
    static let small: CGFloat = 6
    
    /// 8pt - Standard rounding (thumbnails, small cards)
    static let standard: CGFloat = 8
    
    /// 10pt - Medium-small rounding (option buttons)
    static let mediumSmall: CGFloat = 10
    
    /// 12pt - Medium rounding (cards, inputs, list items)
    static let medium: CGFloat = 12
    
    /// 16pt - Large rounding (modals, sheets)
    static let large: CGFloat = 16
    
    /// 20pt - Extra large rounding (user bubbles, containers)
    static let xlarge: CGFloat = 20
    
    /// 24pt - Drawer/sheet rounding
    static let sheet: CGFloat = 24
    
    /// 28pt - Pill buttons (login buttons, capsules)
    static let pill: CGFloat = 28
    
    // MARK: - Semantic Radius
    
    /// Input field corner radius
    static let input: CGFloat = 12
    
    /// Button corner radius
    static let button: CGFloat = 12
    
    /// Card corner radius
    static let card: CGFloat = 12
    
    /// Modal/sheet corner radius
    static let modal: CGFloat = 24
    
    /// Message bubble corner radius
    static let bubble: CGFloat = 20
    
    /// Thumbnail corner radius
    static let thumbnail: CGFloat = 8
}

// MARK: - Shape Helpers

extension RoundedRectangle {
    /// Standard card shape
    static var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.card, style: .continuous)
    }
    
    /// Input field shape
    static var input: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.input, style: .continuous)
    }
    
    /// Button shape
    static var button: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.button, style: .continuous)
    }
    
    /// Modal/sheet shape
    static var modal: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.modal, style: .continuous)
    }
    
    /// Message bubble shape
    static var bubble: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.bubble, style: .continuous)
    }
}
