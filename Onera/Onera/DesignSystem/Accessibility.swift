//
//  Accessibility.swift
//  Onera
//
//  Centralized accessibility helpers and modifiers
//  Ensures VoiceOver support, Dynamic Type, and proper touch targets
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Touch Target Constants

/// Minimum touch target size per Apple HIG (44x44 points)
enum AccessibilitySize {
    /// Minimum touch target size (44pt)
    static let minTouchTarget: CGFloat = 44
    
    /// Comfortable touch target size (48pt)
    static let comfortableTouchTarget: CGFloat = 48
    
    /// Large touch target size (56pt)
    static let largeTouchTarget: CGFloat = 56
}

// MARK: - Accessibility Modifier

/// A view modifier that adds comprehensive accessibility support
struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let isButton: Bool
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        isButton: Bool = false
    ) {
        self.label = label
        self.hint = hint
        self.traits = isButton ? traits.union(.isButton) : traits
        self.isButton = isButton
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

// MARK: - Touch Target Modifier

/// Ensures a view meets the minimum touch target size
struct TouchTargetModifier: ViewModifier {
    let minSize: CGFloat
    
    init(minSize: CGFloat = AccessibilitySize.minTouchTarget) {
        self.minSize = minSize
    }
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

// MARK: - Icon Button Modifier

/// Combines accessibility label with proper touch target for icon-only buttons
struct IconButtonModifier: ViewModifier {
    let label: String
    let hint: String?
    let size: CGFloat
    
    init(
        label: String,
        hint: String? = nil,
        size: CGFloat = AccessibilitySize.minTouchTarget
    ) {
        self.label = label
        self.hint = hint
        self.size = size
    }
    
    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Combined Element Modifier

/// Combines child elements into a single accessibility element
struct CombinedAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    
    init(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) {
        self.label = label
        self.hint = hint
        self.traits = traits
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

// MARK: - View Extensions

extension View {
    // MARK: - Basic Accessibility
    
    /// Add accessibility label and optional hint
    func accessible(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(AccessibilityModifier(label: label, hint: hint, traits: traits))
    }
    
    /// Add accessibility for a button
    func accessibleButton(
        label: String,
        hint: String? = nil
    ) -> some View {
        modifier(AccessibilityModifier(label: label, hint: hint, isButton: true))
    }
    
    // MARK: - Touch Targets
    
    /// Ensure minimum 44x44pt touch target
    func touchTarget(_ size: CGFloat = AccessibilitySize.minTouchTarget) -> some View {
        modifier(TouchTargetModifier(minSize: size))
    }
    
    /// Configure as an icon button with proper accessibility and touch target
    func iconButton(
        label: String,
        hint: String? = nil,
        size: CGFloat = AccessibilitySize.minTouchTarget
    ) -> some View {
        modifier(IconButtonModifier(label: label, hint: hint, size: size))
    }
    
    // MARK: - Combined Elements
    
    /// Combine children into single accessibility element
    func accessibilityCombined(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        modifier(CombinedAccessibilityModifier(label: label, hint: hint, traits: traits))
    }
    
    /// Hide from accessibility (for decorative elements)
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }
    
    // MARK: - State-Based Labels
    
    /// Accessibility label that changes based on a boolean state
    func accessibilityLabel(
        when condition: Bool,
        trueLabel: String,
        falseLabel: String
    ) -> some View {
        self.accessibilityLabel(condition ? trueLabel : falseLabel)
    }
    
    /// Accessibility for toggle buttons (e.g., show/hide password)
    func accessibilityToggle(
        isOn: Bool,
        onLabel: String,
        offLabel: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(isOn ? onLabel : offLabel)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(isOn ? "On" : "Off")
    }
    
    // MARK: - Selection State
    
    /// Add selection state for list items
    func accessibilitySelectable(
        label: String,
        isSelected: Bool,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Scaled Sizes for Views

/// Commonly used scaled sizes for accessibility
/// Use these in views that need specific pixel sizes that scale with Dynamic Type
struct ScaledAccessibilitySizes {
    /// Touch target minimum (44pt base)
    @ScaledMetric(relativeTo: .body) var touchTarget: CGFloat = 44
    
    /// Icon size for buttons (24pt base)
    @ScaledMetric(relativeTo: .body) var buttonIcon: CGFloat = 24
    
    /// Small icon size (16pt base)
    @ScaledMetric(relativeTo: .caption) var smallIcon: CGFloat = 16
    
    /// Large icon size (32pt base)
    @ScaledMetric(relativeTo: .title) var largeIcon: CGFloat = 32
    
    /// Hero icon size (48pt base)
    @ScaledMetric(relativeTo: .largeTitle) var heroIcon: CGFloat = 48
    
    /// Extra large hero icon (64pt base)
    @ScaledMetric(relativeTo: .largeTitle) var extraLargeIcon: CGFloat = 64
    
    /// Avatar small (32pt base)
    @ScaledMetric(relativeTo: .body) var avatarSmall: CGFloat = 32
    
    /// Avatar medium (40pt base)
    @ScaledMetric(relativeTo: .body) var avatarMedium: CGFloat = 40
    
    /// Avatar large (80pt base)
    @ScaledMetric(relativeTo: .title) var avatarLarge: CGFloat = 80
    
    init() {}
}

// MARK: - Accessibility Announcements

/// Helper for posting accessibility announcements
enum AccessibilityAnnouncement {
    /// Announce a message to VoiceOver users
    static func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: message])
        #endif
    }
    
    /// Announce screen change
    static func screenChanged(focus: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .screenChanged, argument: focus)
        #elseif os(macOS)
        // macOS doesn't have direct equivalent, use window change
        if let element = focus {
            NSAccessibility.post(element: element, notification: .focusedWindowChanged)
        }
        #endif
    }
    
    /// Announce layout change
    static func layoutChanged(focus: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .layoutChanged, argument: focus)
        #elseif os(macOS)
        // macOS handles layout changes automatically
        if let element = focus {
            NSAccessibility.post(element: element, notification: .layoutChanged)
        }
        #endif
    }
}

// MARK: - Preview

#Preview("Accessibility Examples") {
    VStack(spacing: 20) {
        // Icon button with proper touch target
        Button { } label: {
            Image(systemName: "plus")
                .font(.system(size: 20))
        }
        .iconButton(label: "Add new item", hint: "Creates a new conversation")
        .oneraGlassCircle()
        
        // Toggle button
        Button { } label: {
            Image(systemName: "eye.fill")
                .font(.system(size: 16))
        }
        .touchTarget()
        .accessibilityToggle(
            isOn: true,
            onLabel: "Hide password",
            offLabel: "Show password"
        )
        
        // Combined row
        HStack {
            Image(systemName: "folder.fill")
            Text("Documents")
            Spacer()
            Text("5 items")
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityCombined(
            label: "Documents folder, 5 items",
            traits: .isButton
        )
        
        // Decorative element
        Circle()
            .fill(.blue.opacity(0.2))
            .frame(width: 100, height: 100)
            .accessibilityDecorative()
    }
    .padding()
}
