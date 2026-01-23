//
//  AuthenticationView.swift
//  Onera
//
//  OAuth sign in view - Apple and Google only
//  Native iOS design with animated welcome
//

import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    
    @Bindable var viewModel: AuthViewModel
    
    // Animation states
    @State private var titleText = ""
    @State private var showButtons = false
    
    private let fullTitle = "Let's collaborate"
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Animated header
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .opacity(showButtons ? 1 : 0)
                    .scaleEffect(showButtons ? 1 : 0.5)
                
                Text(titleText)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Sign in buttons
            if showButtons {
                VStack(spacing: 12) {
                    // Sign in with Apple - Native
                    SignInWithAppleButton(.continue) { request in
                        viewModel.configureAppleRequest(request)
                    } onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result: result)
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("signInWithApple")
                    
                    // Sign in with Google
                    Button {
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image("google")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text("Continue with Google")
                                .font(.body.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .foregroundStyle(.primary)
                    .disabled(viewModel.isLoading)
                    .accessibilityIdentifier("signInWithGoogle")
                    
                    // Terms text
                    Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
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
        
        // Show buttons with animation
        try? await Task.sleep(for: .milliseconds(200))
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showButtons = true
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
