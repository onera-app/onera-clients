//
//  GlassEffect.swift
//  Onera
//
//  Reusable glass morphism effect component
//

import SwiftUI

/// Glass effect modifier that applies the liquid glass design pattern
/// Used throughout the app for buttons, inputs, and floating elements
struct GlassEffect<S: InsettableShape>: ViewModifier {
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
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                showBorder ?
                AnyView(
                    shape
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                : AnyView(EmptyView())
            )
            .shadow(color: showShadow ? .black.opacity(0.1) : .clear, radius: showShadow ? 8 : 0, x: 0, y: showShadow ? 2 : 0)
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
struct GlassButtonStyle: ButtonStyle {
    
    @ViewBuilder
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(OneraAnimation.quick, value: configuration.isPressed)
    }
}

/// A capsule button style with glass effect
struct GlassCapsuleButtonStyle: ButtonStyle {
    
    @ViewBuilder
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(OneraAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
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
    .background(Color.gray.opacity(0.2))
}
