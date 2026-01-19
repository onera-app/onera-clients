//
//  AppCoordinator.swift
//  Onera
//
//  Coordinates app state and navigation flow
//

import SwiftUI

@MainActor
@Observable
final class AppCoordinator {
    enum AppState {
        case loading
        case authentication
        case e2eeSetup
        case e2eeUnlock
        case main
    }
    
    private(set) var state: AppState = .loading
    
    private let authManager = AuthenticationManager.shared
    private let e2eeManager = E2EEManager.shared
    private let secureSession = SecureSession.shared
    
    func checkState() async {
        // Check authentication
        guard authManager.isAuthenticated else {
            state = .authentication
            return
        }
        
        do {
            let token = try await authManager.getToken()
            
            // Check E2EE setup
            let hasKeys = try await e2eeManager.checkSetup(token: token)
            
            if !hasKeys {
                state = .e2eeSetup
                return
            }
            
            // Check if session is unlocked
            if secureSession.isUnlocked {
                state = .main
                return
            }
            
            // Try to unlock with device share
            do {
                try await e2eeManager.unlockSameDevice(token: token)
                state = .main
            } catch {
                // Need recovery phrase
                state = .e2eeUnlock
            }
            
        } catch {
            state = .authentication
        }
    }
    
    func onAuthenticationComplete() async {
        await checkState()
    }
    
    func onE2EESetupComplete() {
        state = .main
    }
    
    func onE2EEUnlockComplete() {
        state = .main
    }
    
    func onSignOut() {
        state = .authentication
    }
}
