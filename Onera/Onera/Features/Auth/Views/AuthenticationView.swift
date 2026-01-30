//
//  AuthenticationView.swift
//  Onera
//
//  OAuth sign in view - Apple and Google only
//  Animated welcome screen with bottom drawer
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    
    @Bindable var viewModel: AuthViewModel
    @Environment(\.theme) private var theme
    
    // Animation states
    @State private var titleText = ""
    @State private var showCircle = false
    @State private var showDrawer = false
    @State private var circleScale: CGFloat = 0
    
    private let fullTitle = "Let's collaborate"
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            // Background
            theme.background
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Animated header - positioned slightly above center
                headerView
                    .offset(y: showDrawer ? -60 : 0)
                    .animation(reduceMotion ? nil : OneraAnimation.springSmooth, value: showDrawer)
                
                Spacer()
                Spacer()
            }
            
            // Bottom drawer
            VStack {
                Spacer()
                
                if showDrawer {
                    bottomDrawer
                        .transition(.move(edge: .bottom))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityIdentifier("authenticationView")
        .onAppear {
            startAnimations()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        Task {
            await typewriterAnimation()
        }
    }
    
    @MainActor
    private func typewriterAnimation() async {
        // Respect Reduce Motion accessibility setting
        if reduceMotion {
            // Skip all animations - show final state immediately
            titleText = fullTitle
            showCircle = true
            circleScale = 1.0
            showDrawer = true
            return
        }
        
        // Small delay before starting
        try? await Task.sleep(for: .milliseconds(300))
        
        // Typewriter effect for title
        for character in fullTitle {
            titleText.append(character)
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Show circle with bounce
        withAnimation(OneraAnimation.springBouncy) {
            showCircle = true
            circleScale = 1.0
        }
        
        // Small delay then show drawer
        try? await Task.sleep(for: .milliseconds(400))
        
        withAnimation(OneraAnimation.springSmooth) {
            showDrawer = true
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: OneraSpacing.sm) {
            Text(titleText)
                .font(OneraTypography.displayLarge)
                .foregroundStyle(theme.textPrimary)
            
            // Animated circular icon
            if showCircle {
                Circle()
                    .fill(theme.textPrimary)
                    .frame(width: 24, height: 24)
                    .scaleEffect(circleScale)
            }
        }
        .padding(.horizontal, OneraSpacing.xxl)
        // Demo mode activation: press and hold header for 10 seconds
        .demoModeActivation()
    }
    
    /// Terms and Privacy links - HIG compliant with tappable links
    private var termsAndPrivacyView: some View {
        VStack(spacing: OneraSpacing.xxs) {
            Text("By continuing, you agree to our")
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textSecondary)
            
            HStack(spacing: OneraSpacing.xxs) {
                Link("Terms of Use", destination: URL(string: "https://onera.app/terms")!)
                    .font(OneraTypography.caption.weight(.medium))
                    .foregroundStyle(theme.accent)
                
                Text("and")
                    .font(OneraTypography.caption)
                    .foregroundStyle(theme.textSecondary)
                
                Link("Privacy Policy", destination: URL(string: "https://onera.app/privacy")!)
                    .font(OneraTypography.caption.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
        }
        .multilineTextAlignment(.center)
        .frame(minHeight: AccessibilitySize.minTouchTarget) // Ensure adequate touch target
    }
    
    // MARK: - Button Constants (Apple HIG compliant)
    
    /// Button height - 50pt per Apple HIG (minimum 44pt recommended)
    private let buttonHeight: CGFloat = 50
    
    /// Button corner radius - matches Apple's default rounded style
    private let buttonCornerRadius: CGFloat = 12
    
    private var bottomDrawer: some View {
        VStack(spacing: 0) {
            // Drawer content
            VStack(spacing: OneraSpacing.md) {
                // Continue with Apple - Native system button (Apple HIG compliant)
                SignInWithAppleButton(.continue) { request in
                    viewModel.configureAppleRequest(request)
                } onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignIn(result: result)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: buttonHeight)
                .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithApple")
                
                // Continue with Google - styled to match Apple button
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 8) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .font(.system(size: 19, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: buttonHeight)
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithGoogle")
            }
            .padding(.horizontal, OneraSpacing.xxl)
            .padding(.top, OneraSpacing.xxl)
            .padding(.bottom, OneraSpacing.lg)
            
            // Terms text with tappable links
            termsAndPrivacyView
                .padding(.horizontal, OneraSpacing.xxxl)
                .padding(.bottom, 34)
        }
        .background(
            RoundedRectangle(cornerRadius: OneraRadius.sheet)
                .fill(theme.secondaryBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay {
            if viewModel.isLoading {
                RoundedRectangle(cornerRadius: OneraRadius.sheet)
                    .fill(theme.textPrimary.opacity(0.3))
                    .ignoresSafeArea(edges: .bottom)
                ProgressView()
                    .tint(theme.textPrimary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    AuthenticationView(
        viewModel: AuthViewModel(
            authService: MockAuthService(),
            onSuccess: {}
        )
    )
}
#endif