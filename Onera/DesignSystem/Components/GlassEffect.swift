//
//  GlassEffect.swift
//  Onera
//
//  Reusable glass morphism effect component
//  Adapts to light and dark modes for native appearance
//

import SwiftUI

/// Glass effect modifier that applies the liquid glass design pattern
/// Adapts automatically to light/dark mode for a native look
struct GlassEffect<S: InsettableShape>: ViewModifier {
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

// MARK: - Convenience Modifiers

extension View {
    /// Apply glass effect with a capsule shape (default for buttons)
    func glassEffect(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(GlassEffect(shape: Capsule(), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a circle shape (for icon buttons)
    func glassCircle(showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(GlassEffect(shape: Circle(), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a rounded rectangle shape
    func glassRounded(_ cornerRadius: CGFloat = OneraRadius.medium, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(GlassEffect(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), showBorder: showBorder, showShadow: showShadow))
    }
    
    /// Apply glass effect with a custom shape
    func glass<S: InsettableShape>(shape: S, showBorder: Bool = true, showShadow: Bool = true) -> some View {
        modifier(GlassEffect(shape: shape, showBorder: showBorder, showShadow: showShadow))
    }
}

// MARK: - Glass Button Style

/// A button style that applies the glass effect automatically
/// Adapts to light/dark mode
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
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
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(OneraAnimation.quick, value: configuration.isPressed)
    }
}

/// A capsule button style with glass effect
/// Adapts to light/dark mode
struct GlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
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
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(OneraAnimation.quick, value: configuration.isPressed)
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
        .glassEffect()
        
        // Circle glass effect
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .glassCircle()
        
        // Rounded glass effect
        Text("Rounded Glass")
            .padding()
            .glassRounded(16)
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
        .glassEffect()
        
        // Circle glass effect
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
            .glassCircle()
        
        // Rounded glass effect
        Text("Rounded Glass")
            .padding()
            .glassRounded(16)
    }
    .padding()
    .background(Color(red: 0.984, green: 0.976, blue: 0.965)) // Claude light bg
    .preferredColorScheme(.light)
}
