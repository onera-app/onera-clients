//
//  Radius.swift
//  Onera
//
//  Centralized corner radius tokens
//

import SwiftUI

/// Onera Design System — Corner Radius Tokens
///
/// Scale: 4 → 6 → 8 → 12 → 16 → 20 → pill
/// Uses `.continuous` style throughout for the native Apple look.
enum OneraRadius {
    
    // MARK: - Base Scale
    
    /// 4pt — Minimal rounding: inline badges, code inline
    static let xs: CGFloat = 4
    
    /// 6pt — Small rounding: small buttons, chips, code blocks
    static let sm: CGFloat = 6
    
    /// 8pt — Standard rounding: thumbnails, small cards
    static let md: CGFloat = 8
    
    /// 12pt — Medium rounding: cards, inputs, list items, buttons
    static let lg: CGFloat = 12
    
    /// 16pt — Large rounding: modals, sheets, containers
    static let xl: CGFloat = 16
    
    /// 20pt — Extra large: message bubbles, large containers
    static let xxl: CGFloat = 20
    
    /// Full pill / capsule
    static let pill: CGFloat = 9999
    
    // MARK: - Semantic Aliases
    
    /// Input field corner radius (12pt)
    static let input: CGFloat = lg
    
    /// Button corner radius (12pt)
    static let button: CGFloat = lg
    
    /// Card corner radius (12pt)
    static let card: CGFloat = lg
    
    /// Modal / sheet corner radius (16pt)
    static let modal: CGFloat = xl
    
    /// Message bubble corner radius (20pt)
    static let bubble: CGFloat = xxl
    
    /// Thumbnail corner radius (8pt)
    static let thumbnail: CGFloat = md
}

// MARK: - Shape Helpers

extension RoundedRectangle {
    /// Standard card shape (12pt continuous)
    static var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.card, style: .continuous)
    }
    
    /// Input field shape (12pt continuous)
    static var input: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.input, style: .continuous)
    }
    
    /// Button shape (12pt continuous)
    static var button: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.button, style: .continuous)
    }
    
    /// Modal / sheet shape (16pt continuous)
    static var modal: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.modal, style: .continuous)
    }
    
    /// Message bubble shape (20pt continuous)
    static var bubble: RoundedRectangle {
        RoundedRectangle(cornerRadius: OneraRadius.bubble, style: .continuous)
    }
}
