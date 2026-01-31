//
//  GlassEffect.swift
//  Onera
//
//  Reusable glass morphism effect component
//  Adapts to light and dark modes for native appearance
//
//  NOTE: Modifiers are prefixed with "onera" to avoid conflict with
//  iOS 26's native .glassEffect() API. On iOS 26+, the native API
//  will be used automatically for better performance and native feel.
//

import SwiftUI

/// Glass effect modifier that applies the liquid glass design pattern
/// Adapts automatically to light/dark mode for a native look
struct OneraGlassEffect<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    let shape: S
    let showBorder: Bool
    let showShadow: Bool
    
    init(shape: S, showBorder: Bool = true, showShadow: Bool = true) {
        self.shape = shape
        self.showBorder = showBorder
        self.showShadow = showShadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(backgroundMaterial)
            )
            .overlay(
                showBorder ? AnyView(borderOverlay) : AnyView(EmptyView())
            )
            .shadow(
                color: shadowColor,
                radius: showShadow ? shadowRadius : 0,
                x: 0,
                y: showShadow ? shadowY : 0
            )
    }
    
    // MARK: - Adaptive Properties
    
    /// Background material adapts to color scheme
    private var backgroundMaterial: some ShapeStyle {
        if colorScheme == .dark {
            // Dark mode: Ultra thin material for that glass look
            return AnyShapeStyle(.ultraThinMaterial)
        } else {
            // Light mode: Use theme's secondary background for a solid, native look
            return AnyShapeStyle(theme.secondaryBackground)
        }
    }
    
    /// Border overlay adapts to color scheme
    @ViewBuilder
    private var borderOverlay: some View {
        if colorScheme == .dark {
            // Dark mode: White gradient border for glass effect
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        } else {
            // Light mode: Subtle dark border for definition
            shape.strokeBorder(
                theme.border.opacity(0.5),
                lineWidth: 0.5
            )
        }
    }
    
    /// Shadow color adapts to color scheme
    private var shadowColor: Color {
        if colorScheme == .dark {
            return showShadow ? .black.opacity(0.2) : .clear
        } else {
            return showShadow ? .black.opacity(0.08) : .clear
        }
    }
    
    /// Shadow radius
    private var shadowRadius: CGFloat {
        colorScheme == .dark ? 8 : 4
    }
    
    /// Shadow Y offset
    private var shadowY: CGFloat {
        colorScheme == .dark ? 2 : 1
    }
}

// MARK: - iOS 26+ Native Glass Effect Wrapper

/// Wrapper that uses native iOS 26 glassEffect when available
@available(iOS 26.0, *)
struct NativeGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect()
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Apply Onera glass effect with a capsule shape (default for buttons)
    /// On iOS 26+, automatically uses native .glassEffect() for better performance
    @ViewBuilder
    func oneraGlass(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.modifier(OneraGlassEffect(shape: Capsule(), showBorder: showBorder, showShadow: showShadow))
        }
    }
    
    /// Apply Onera glass effect with a circle shape (for icon buttons)
    /// On iOS 26+, automatically uses native .glassEffect() with circle shape
    @ViewBuilder
    func oneraGlassCircle(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.modifier(OneraGlassEffect(shape: Circle(), showBorder: showBorder, showShadow: showShadow))
        }
    }
    
    /// Apply Onera glass effect with a rounded rectangle shape
    /// On iOS 26+, automatically uses native .glassEffect() with rounded rect
    @ViewBuilder
    func oneraGlassRounded(_ cornerRadius: CGFloat = OneraRadius.medium, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.modifier(OneraGlassEffect(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), showBorder: showBorder, showShadow: showShadow))
        }
    }
    
    /// Apply Onera glass effect with a custom shape (iOS 17-25 only)
    /// For iOS 26+, use native .glassEffect() directly with your shape
    func oneraGlass<S: InsettableShape>(shape: S, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(OneraGlassEffect(shape: shape, showBorder: showBorder, showShadow: showShadow))
    }
    
    // MARK: - Legacy Aliases (Deprecated)
    // These maintain backwards compatibility but will show deprecation warnings
    
    /// Apply glass effect with a capsule shape
    /// - Note: Renamed to `oneraGlass()` to avoid conflict with iOS 26 native API
    @available(*, deprecated, renamed: "oneraGlass", message: "Use oneraGlass() to avoid iOS 26 API conflict")
    func glassEffect(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(OneraGlassEffect(shape: Capsule(), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a circle shape
    /// - Note: Renamed to `oneraGlassCircle()` to avoid conflict with iOS 26 native API
    @available(*, deprecated, renamed: "oneraGlassCircle", message: "Use oneraGlassCircle() to avoid iOS 26 API conflict")
    func glassCircle(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(OneraGlassEffect(shape: Circle(), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a rounded rectangle shape
    /// - Note: Renamed to `oneraGlassRounded()` to avoid conflict with iOS 26 native API
    @available(*, deprecated, renamed: "oneraGlassRounded", message: "Use oneraGlassRounded() to avoid iOS 26 API conflict")
    func glassRounded(_ cornerRadius: CGFloat = OneraRadius.medium, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(OneraGlassEffect(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a custom shape
    /// - Note: Renamed to `oneraGlass(shape:)` to avoid conflict with iOS 26 native API
    @available(*, deprecated, renamed: "oneraGlass(shape:showBorder:showShadow:)", message: "Use oneraGlass(shape:) to avoid iOS 26 API conflict")
    func glass<S: InsettableShape>(shape: S, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(OneraGlassEffect(shape: shape, showBorder: showBorder, showShadow: showShadow))
    }
}

// MARK: - Glass Button Styles

/// A button style that applies the glass effect automatically
/// Adapts to light/dark mode and respects Reduce Motion accessibility setting
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @ViewBuilder
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.secondaryBackground))
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        colorScheme == .dark
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            : AnyShapeStyle(theme.border.opacity(0.5)),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.2) : .black.opacity(0.08),
                radius: colorScheme == .dark ? 8 : 4,
                x: 0,
                y: colorScheme == .dark ? 2 : 1
            )
            // Scale effect respects Reduce Motion - disabled when enabled
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.95 : 1.0))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : OneraAnimation.quick, value: configuration.isPressed)
    }
}

/// A capsule button style with glass effect
/// Adapts to light/dark mode and respects Reduce Motion accessibility setting
struct GlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @ViewBuilder
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.secondaryBackground))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        colorScheme == .dark
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            : AnyShapeStyle(theme.border.opacity(0.5)),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.2) : .black.opacity(0.08),
                radius: colorScheme == .dark ? 8 : 4,
                x: 0,
                y: colorScheme == .dark ? 2 : 1
            )
            // Scale effect respects Reduce Motion - disabled when enabled
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.95 : 1.0))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(reduceMotion ? nil : OneraAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - iOS 26+ Native Glass Button Styles

/// Button style that uses iOS 26 native .glass style when available
/// Falls back to custom GlassButtonStyle on earlier versions
struct AdaptiveGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .buttonStyle(.glass)
        } else {
            GlassButtonStyle().makeBody(configuration: configuration)
        }
    }
}

/// Button style that uses iOS 26 native .glassProminent style when available
/// Falls back to custom styling on earlier versions
struct AdaptiveGlassProminentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .buttonStyle(.glassProminent)
        } else {
            // Fallback: Solid prominent style
            configuration.label
                .background(
                    Capsule()
                        .fill(theme.accent)
                )
                .foregroundStyle(.white)
                .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.95 : 1.0))
                .opacity(configuration.isPressed ? 0.8 : 1.0)
                .animation(reduceMotion ? nil : OneraAnimation.quick, value: configuration.isPressed)
        }
    }
}

// MARK: - Preview

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        // Capsule glass effect
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
            Text("Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .oneraGlass()
        
        // Circle glass effect
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .oneraGlassCircle()
        
        // Rounded glass effect
        Text("Rounded Glass")
            .padding()
            .oneraGlassRounded(16)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    VStack(spacing: 20) {
        // Capsule glass effect
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
            Text("Search")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .oneraGlass()
        
        // Circle glass effect
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .oneraGlassCircle()
        
        // Rounded glass effect
        Text("Rounded Glass")
            .padding()
            .oneraGlassRounded(16)
    }
    .padding()
    .background(Color(red: 0.984, green: 0.976, blue: 0.965)) // Claude light bg
    .preferredColorScheme(.light)
}
