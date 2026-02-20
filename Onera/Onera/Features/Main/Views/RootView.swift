//
//  RootView.swift
//  Onera
//
//  Root view that handles app state transitions
//

import SwiftUI

struct RootView: View {
    
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dependencies) private var dependencies
    
    // State for AddCredentialView sheet from API key prompt
    @State private var selectedProvider: LLMProvider?
    @State private var showAddCredential = false
    
    var body: some View {
        Group {
            switch coordinator.state {
            case .launching:
                LaunchView()
                
            case .unauthenticated:
                AuthenticationView(
                    viewModel: AuthViewModel(
                        authService: dependencies.authService,
                        onSuccess: { await coordinator.handleAuthenticationSuccess() }
                    )
                )
                
            case .authenticatedNeedsOnboarding:
                OnboardingView(
                    onComplete: { coordinator.handleOnboardingComplete() }
                )
                
            case .authenticatedNeedsE2EESetup:
                E2EESetupView(
                    viewModel: E2EESetupViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EESetupComplete() }
                    ),
                    onSignOut: { Task { await coordinator.handleSignOut() } }
                )
                
            case .authenticatedNeedsE2EEUnlock:
                E2EEUnlockView(
                    viewModel: E2EEUnlockViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EEUnlockComplete() }
                    ),
                    onComplete: { coordinator.handleE2EEUnlockComplete() },
                    onSignOut: { Task { await coordinator.handleSignOut() } }
                )
                
            case .authenticatedNeedsAddApiKey:
                AddApiKeyPromptView(
                    onSelectProvider: { provider in
                        selectedProvider = provider
                        showAddCredential = true
                    },
                    onSkip: { coordinator.handleAddApiKeyComplete() }
                )
                .sheet(isPresented: $showAddCredential) {
                    if let provider = selectedProvider {
                        AddCredentialView(
                            viewModel: makeCredentialsViewModel(),
                            selectedProvider: provider,
                            onSave: {
                                showAddCredential = false
                                coordinator.handleAddApiKeyComplete()
                            },
                            onCancel: {
                                showAddCredential = false
                            }
                        )
                    }
                }
                
            case .authenticated:
                AdaptiveMainView(
                    onSignOut: { await coordinator.handleSignOut() }
                )
            }
        }
        .task {
            // Wait for the auth service to be ready before determining state.
            // Supabase restores persisted sessions from Keychain on init and fires
            // the initial authStateChanges event, which sets isReady = true.
            let authService = dependencies.authService
            var attempts = 0
            while !authService.isReady && attempts < 20 {
                try? await Task.sleep(for: .milliseconds(100))
                attempts += 1
            }
            
            if authService.isReady {
                print("[RootView] Auth service ready, determining initial state")
            } else {
                print("[RootView] WARNING: Auth service not ready after timeout, proceeding anyway")
            }
            
            await coordinator.determineInitialState()
        }
        .alert(
            "Error",
            isPresented: .init(
                get: { coordinator.error != nil },
                set: { if !$0 { coordinator.clearError() } }
            )
        ) {
            Button("OK") {
                coordinator.clearError()
            }
        } message: {
            if let error = coordinator.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func makeCredentialsViewModel() -> CredentialsViewModel {
        CredentialsViewModel(
            credentialService: dependencies.credentialService,
            networkService: dependencies.networkService,
            cryptoService: dependencies.cryptoService,
            extendedCryptoService: dependencies.extendedCryptoService,
            secureSession: dependencies.secureSession,
            authService: dependencies.authService
        )
    }
    
}

// MARK: - Launch View

struct LaunchView: View {
    @State private var isAnimating = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: OneraSpacing.lg) {
            Spacer()
            Spacer()
            
            // App icon with subtle pulse animation
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 0.8 : 0.4)
                
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: OneraRadius.xxl)
                        .fill(theme.background)
                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                    
                    // Lock + chat bubble icon representing secure chat
                    OneraIcon.shield.solidImage
                        .font(.title.weight(.medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 80, height: 80)
            }
            
            VStack(spacing: OneraSpacing.xs) {
                Text("Onera")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Preparing your secure session...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Subtle loading indicator at bottom
            ProgressView()
                .tint(.secondary)
                .padding(.bottom, OneraSpacing.xxxl)
        }
        .accessibilityIdentifier("launchView")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RootView(coordinator: AppCoordinator())
}
