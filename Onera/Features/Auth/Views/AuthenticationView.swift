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
    }
    
    private var bottomDrawer: some View {
        VStack(spacing: 0) {
            // Drawer content
            VStack(spacing: OneraSpacing.md) {
                // Continue with Apple - Native Button
                SignInWithAppleButton(.continue) { request in
                    viewModel.configureAppleRequest(request)
                } onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignIn(result: result)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: OneraRadius.pill))
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithApple")
                
                // Continue with Google
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: OneraSpacing.md) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Continue with Google")
                            .font(OneraTypography.button)
                    }
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(theme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: OneraRadius.pill)
                            .stroke(theme.textPrimary.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithGoogle")
            }
            .padding(.horizontal, OneraSpacing.xxl)
            .padding(.top, OneraSpacing.xxl)
            .padding(.bottom, OneraSpacing.lg)
            
            // Terms text
            Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
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

#Preview {
    AuthenticationView(
        viewModel: AuthViewModel(
            authService: MockAuthService(),
            onSuccess: {}
        )
    )
}
