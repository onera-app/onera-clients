//
//  AppCoordinator.swift
//  Onera
//
//  Coordinates app-level navigation and state transitions
//

import SwiftUI
import Observation

// MARK: - App State

enum AppState: Equatable {
    case launching
    case unauthenticated
    case authenticatedNeedsOnboarding      // New user: show educational onboarding
    case authenticatedNeedsE2EESetup       // After onboarding: set up E2EE keys
    case authenticatedNeedsE2EEUnlock      // Returning user: unlock E2EE
    case authenticatedNeedsAddApiKey       // After E2EE setup: prompt to add API key
    case authenticated
}

// MARK: - App Coordinator

@MainActor
@Observable
final class AppCoordinator {
    
    // MARK: - Published State
    
    private(set) var state: AppState = .launching
    private(set) var isLoading = false
    private(set) var error: AppError?
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    // MARK: - Initialization
    
    init(dependencies: DependencyContaining = DependencyContainer.shared) {
        self.authService = dependencies.authService
        self.e2eeService = dependencies.e2eeService
        self.secureSession = dependencies.secureSession
    }
    
    // MARK: - State Management
    
    func determineInitialState() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check authentication status
            guard authService.isAuthenticated else {
                transition(to: .unauthenticated)
                return
            }
            
            let token = try await authService.getToken()
            
            // Check E2EE setup status
            let hasE2EEKeys = try await e2eeService.checkSetupStatus(token: token)
            
            guard hasE2EEKeys else {
                // New user - show educational onboarding first
                transition(to: .authenticatedNeedsOnboarding)
                return
            }
            
            // Attempt to unlock session
            if await secureSession.isUnlocked {
                transition(to: .authenticated)
                return
            }
            
            // 1. First try to restore session with biometrics (Face ID / Touch ID)
            if await secureSession.tryRestoreSession() {
                transition(to: .authenticated)
                return
            }
            
            // 2. Try automatic unlock with device share (same device)
            do {
                try await e2eeService.unlockWithDeviceShare(token: token)
                transition(to: .authenticated)
            } catch {
                // Need manual recovery with password/recovery phrase
                transition(to: .authenticatedNeedsE2EEUnlock)
            }
            
        } catch let networkError as NetworkError {
            // Check if it's an unauthorized error
            if case .unauthorized = networkError {
                // Token is invalid or expired - sign out and start fresh
                await authService.signOut()
                transition(to: .unauthenticated)
            } else {
                self.error = AppError.from(networkError)
                transition(to: .unauthenticated)
            }
        } catch {
            self.error = AppError.from(error)
            transition(to: .unauthenticated)
        }
    }
    
    // MARK: - State Transitions
    
    func handleAuthenticationSuccess() async {
        // Wait for Clerk session to be fully established
        // This helps with OAuth redirects where the session may not be immediately available
        for _ in 1...3 {
            if authService.isAuthenticated {
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        
        await determineInitialState()
    }
    
    /// Called when user completes the educational onboarding flow
    func handleOnboardingComplete() {
        transition(to: .authenticatedNeedsE2EESetup)
    }
    
    /// Called when user completes E2EE key setup (new user)
    /// Proceeds to API key prompt
    func handleE2EESetupComplete() {
        transition(to: .authenticatedNeedsAddApiKey)
    }
    
    /// Called when returning user unlocks their E2EE
    func handleE2EEUnlockComplete() {
        transition(to: .authenticated)
    }
    
    /// Called when user adds an API key or skips
    func handleAddApiKeyComplete() {
        transition(to: .authenticated)
    }
    
    func handleSignOut() async {
        await authService.signOut()
        await secureSession.lock()
        transition(to: .unauthenticated)
    }
    
    func handleSessionLock() {
        transition(to: .authenticatedNeedsE2EEUnlock)
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Helpers
    
    private func transition(to newState: AppState) {
        guard state != newState else { return }
        state = newState
    }
}

// MARK: - App Error

enum AppError: LocalizedError, Equatable {
    case network(message: String)
    case authentication(message: String)
    case encryption(message: String)
    case unknown(message: String)
    
    var errorDescription: String? {
        switch self {
        case .network(let message): return message
        case .authentication(let message): return message
        case .encryption(let message): return message
        case .unknown(let message): return message
        }
    }
    
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        if let authError = error as? AuthError {
            return .authentication(message: authError.localizedDescription)
        }
        if let cryptoError = error as? CryptoError {
            return .encryption(message: cryptoError.localizedDescription)
        }
        if let networkError = error as? NetworkError {
            return .network(message: networkError.localizedDescription)
        }
        return .unknown(message: error.localizedDescription)
    }
}
