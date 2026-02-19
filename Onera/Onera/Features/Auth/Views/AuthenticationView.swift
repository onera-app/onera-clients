//
//  AuthenticationView.swift
//  Onera
//
//  OAuth sign in view - Apple and Google only
//  Onera-branded login with gradient background and dark bottom card
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    
    @Bindable var viewModel: AuthViewModel
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Animation states
    @State private var showBranding = false
    @State private var showCard = false
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private let iPadMaxWidth: CGFloat = 600
    
    var body: some View {
        ZStack {
            // Gradient background (matches Onera onboarding style)
            theme.onboardingGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Centered branding
                if showBranding {
                    brandingView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Spacer()
                
                // Bottom dark card with sign-in buttons
                if showCard {
                    bottomCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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
    
    // MARK: - Branding
    
    private var brandingView: some View {
        VStack(spacing: OneraSpacing.md) {
            Text("onera")
                .font(.system(size: 52, weight: .bold, design: .default))
                .foregroundStyle(theme.onboardingTextPrimary)
            
            Text("Private AI chat, built differently.")
                .font(.title3)
                .foregroundStyle(theme.onboardingTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
        .padding(.horizontal, OneraSpacing.xxxl)
        // Demo mode activation: press and hold branding for 10 seconds
        .demoModeActivation()
    }
    
    // MARK: - Bottom Card
    
    private var bottomCard: some View {
        VStack(spacing: OneraSpacing.lg) {
            signInButtons
            termsAndPrivacyView
        }
        .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
        .padding(.horizontal, OneraSpacing.xxl)
        .padding(.top, OneraSpacing.xxxl)
        .padding(.bottom, OneraSpacing.xxxl)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: OneraRadius.pill,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: OneraRadius.pill
            )
            .fill(theme.onboardingSheetBackground)
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Sign In Buttons
    
    private var signInButtons: some View {
        VStack(spacing: OneraSpacing.md) {
            // Continue with Apple - uses Captions primary style (white pill)
            Button {
                // Trigger native Apple Sign In via the hidden SignInWithAppleButton
            } label: {
                HStack(spacing: OneraSpacing.md) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Continue with Apple")
                }
            }
            .buttonStyle(CaptionsPrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("signInWithApple")
            .overlay {
                // Hidden native SignInWithAppleButton for actual auth
                SignInWithAppleButton(.continue) { request in
                    viewModel.configureAppleRequest(request)
                } onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignIn(result: result)
                    }
                }
                .blendMode(.overlay)
                .opacity(0.02) // Nearly invisible but tappable
                .allowsHitTesting(true)
            }
            
            // Continue with Google - dark pill style
            Button {
                Task { await viewModel.signInWithGoogle() }
            } label: {
                HStack(spacing: OneraSpacing.md) {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                }
            }
            .buttonStyle(CaptionsDarkButtonStyle())
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("signInWithGoogle")
        }
        .overlay {
            if viewModel.isLoading {
                RoundedRectangle(cornerRadius: CaptionsRadius.medium)
                    .fill(.black.opacity(0.3))
                ProgressView()
                    .tint(.white)
            }
        }
    }
    
    // MARK: - Terms & Privacy
    
    private var termsAndPrivacyView: some View {
        VStack(spacing: OneraSpacing.xxs) {
            Text("By continuing, you agree to our")
                .font(OneraTypography.caption)
                .foregroundStyle(theme.onboardingTextSecondary)
            
            HStack(spacing: OneraSpacing.xxs) {
                Link("Terms of Use", destination: URL(string: "https://onera.app/terms")!)
                    .font(OneraTypography.caption.weight(.medium))
                    .foregroundStyle(theme.onboardingTextPrimary)
                
                Text("and")
                    .font(OneraTypography.caption)
                    .foregroundStyle(theme.onboardingTextSecondary)
                
                Link("Privacy Policy", destination: URL(string: "https://onera.app/privacy")!)
                    .font(OneraTypography.caption.weight(.medium))
                    .foregroundStyle(theme.onboardingTextPrimary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(minHeight: AccessibilitySize.minTouchTarget)
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        if reduceMotion {
            showBranding = true
            showCard = true
            return
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showBranding = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            showCard = true
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