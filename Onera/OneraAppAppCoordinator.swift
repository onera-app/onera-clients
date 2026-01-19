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
    case authenticatedNeedsE2EESetup
    case authenticatedNeedsE2EEUnlock
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
                transition(to: .authenticatedNeedsE2EESetup)
                return
            }
            
            // Attempt to unlock session
            if await secureSession.isUnlocked {
                transition(to: .authenticated)
                return
            }
            
            // Try automatic unlock (same device with stored share)
            do {
                try await e2eeService.unlockWithDeviceShare(token: token)
                transition(to: .authenticated)
            } catch {
                // Need manual recovery
                transition(to: .authenticatedNeedsE2EEUnlock)
            }
            
        } catch {
            self.error = AppError.from(error)
            transition(to: .unauthenticated)
        }
    }
    
    // MARK: - State Transitions
    
    func handleAuthenticationSuccess() async {
        await determineInitialState()
    }
    
    func handleE2EESetupComplete() {
        transition(to: .authenticated)
    }
    
    func handleE2EEUnlockComplete() {
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
