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
            Color(.systemBackground)
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showCircle = true
            circleScale = 1.0
        }
        
        // Small delay then show drawer
        try? await Task.sleep(for: .milliseconds(400))
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showDrawer = true
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 8) {
            Text(titleText)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.primary)
            
            // Animated circular icon
            if showCircle {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 24, height: 24)
                    .scaleEffect(circleScale)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var bottomDrawer: some View {
        VStack(spacing: 0) {
            // Drawer content
            VStack(spacing: 12) {
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
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithApple")
                
                // Continue with Google
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("signInWithGoogle")
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Terms text
            Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 34)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay {
            if viewModel.isLoading {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(0.3))
                    .ignoresSafeArea(edges: .bottom)
                ProgressView()
                    .tint(.primary)
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
