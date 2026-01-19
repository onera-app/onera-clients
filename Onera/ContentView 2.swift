//
//  ContentView.swift
//  Onera
//
//  Root content view with state-based navigation
//

import SwiftUI

struct ContentView: View {
    @State private var coordinator = AppCoordinator()
    
    var body: some View {
        Group {
            switch coordinator.state {
            case .loading:
                loadingView
                
            case .authentication:
                AuthenticationView()
                    .onChange(of: AuthenticationManager.shared.isAuthenticated) { _, isAuthenticated in
                        if isAuthenticated {
                            Task {
                                await coordinator.onAuthenticationComplete()
                            }
                        }
                    }
                
            case .e2eeSetup:
                E2EESetupView {
                    coordinator.onE2EESetupComplete()
                }
                
            case .e2eeUnlock:
                RecoveryPhraseEntryView {
                    coordinator.onE2EEUnlockComplete()
                }
                
            case .main:
                MainView()
                    .onChange(of: AuthenticationManager.shared.isAuthenticated) { _, isAuthenticated in
                        if !isAuthenticated {
                            coordinator.onSignOut()
                        }
                    }
            }
        }
        .task {
            await coordinator.checkState()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
