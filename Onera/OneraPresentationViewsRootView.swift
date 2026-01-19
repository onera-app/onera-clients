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
                
            case .authenticatedNeedsE2EESetup:
                E2EESetupView(
                    viewModel: E2EESetupViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EESetupComplete() }
                    )
                )
                
            case .authenticatedNeedsE2EEUnlock:
                E2EEUnlockView(
                    viewModel: E2EEUnlockViewModel(
                        authService: dependencies.authService,
                        e2eeService: dependencies.e2eeService,
                        onComplete: { coordinator.handleE2EEUnlockComplete() }
                    )
                )
                
            case .authenticated:
                MainView(
                    onSignOut: { await coordinator.handleSignOut() }
                )
            }
        }
        .task {
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
}

// MARK: - Launch View

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView(coordinator: AppCoordinator())
}
