//
//  Animations.swift
//  Onera
//
//  Centralized animation presets
//

import SwiftUI

/// Onera Design System - Animation Tokens
/// Consistent animation presets used throughout the app
enum OneraAnimation {
    
    // MARK: - Duration Constants
    
    /// Quick duration (0.15s) - micro interactions
    static let durationQuick: Double = 0.15
    
    /// Fast duration (0.2s) - button presses, toggles
    static let durationFast: Double = 0.2
    
    /// Standard duration (0.3s) - general transitions
    static let durationStandard: Double = 0.3
    
    /// Slow duration (0.4s) - complex animations
    static let durationSlow: Double = 0.4
    
    // MARK: - Easing Animations
    
    /// Quick ease-in-out (0.15s) - micro interactions
    static let quick = Animation.easeInOut(duration: durationQuick)
    
    /// Fast ease-in-out (0.2s) - button presses, toggles
    static let fast = Animation.easeInOut(duration: durationFast)
    
    /// Standard ease-in-out (0.3s) - general transitions
    static let standard = Animation.easeInOut(duration: durationStandard)
    
    /// Slow ease-out (0.4s) - content appearing
    static let slow = Animation.easeOut(duration: durationSlow)
    
    // MARK: - Spring Animations
    
    /// Bouncy spring - playful interactions (response: 0.3, damping: 0.7)
    static let springBouncy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Smooth spring - natural motion (response: 0.5, damping: 0.8)
    static let springSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    /// Quick spring - fast responsive (response: 0.3, damping: 0.8)
    static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    /// Gentle spring - subtle motion (response: 0.6, damping: 0.85)
    static let springGentle = Animation.spring(response: 0.6, dampingFraction: 0.85)
    
    // MARK: - Semantic Animations
    
    /// Button press feedback
    static let buttonPress = quick
    
    /// Modal/sheet presentation
    static let sheetPresent = springSmooth
    
    /// Dropdown menu open/close
    static let dropdown = springQuick
    
    /// Content fade in
    static let fadeIn = standard
    
    /// Rotation animation (loading spinners)
    static let rotate = Animation.linear(duration: 1).repeatForever(autoreverses: false)
    
    /// Pulsing animation (recording indicator)
    static let pulse = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    
    /// Blinking animation (cursor)
    static let blink = Animation.easeInOut(duration: 0.5).repeatForever()
}

// MARK: - Transition Helpers

extension AnyTransition {
    /// Slide up with fade
    static var slideUpFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
    
    /// Slide from leading with fade
    static var slideLeadingFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .opacity
        )
    }
    
    /// Scale with fade
    static var scaleFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }
}

// MARK: - View Extension for Animations

extension View {
    /// Apply standard animation
    func animateStandard<V: Equatable>(value: V) -> some View {
        animation(OneraAnimation.standard, value: value)
    }
    
    /// Apply spring animation
    func animateSpring<V: Equatable>(value: V) -> some View {
        animation(OneraAnimation.springSmooth, value: value)
    }
    
    /// Apply bouncy spring animation
    func animateBouncy<V: Equatable>(value: V) -> some View {
        animation(OneraAnimation.springBouncy, value: value)
    }
}
