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
    
    /// Initialize with explicit dependencies (for testing)
    init(dependencies: DependencyContaining) {
        self.authService = dependencies.authService
        self.e2eeService = dependencies.e2eeService
        self.secureSession = dependencies.secureSession
    }
    
    /// Convenience initializer using shared container
    convenience init() {
        self.init(dependencies: DependencyContainer.shared)
    }
    
    // MARK: - State Management
    
    func determineInitialState() async {
        isLoading = true
        defer { isLoading = false }
        
        // Check for demo mode - simplified flow
        if DemoModeManager.shared.isActive {
            await determineInitialStateForDemoMode()
            return
        }
        
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
            
            // Attempt to unlock session - but ONLY if master key is valid
            if secureSession.isUnlocked, secureSession.masterKey != nil {
                print("[AppCoordinator] Session already unlocked, master key size: \(secureSession.masterKey?.count ?? 0)")
                // Verify the key actually works by checking if we can use it
                if await verifyMasterKeyWorks(token: token) {
                    transition(to: .authenticated)
                    return
                } else {
                    print("[AppCoordinator] Stored session has invalid master key, locking and trying other methods...")
                    secureSession.lock()
                }
            }
            
            // 1. First try to restore session with biometrics (Face ID / Touch ID)
            print("[AppCoordinator] Attempting biometric session restore...")
            if await secureSession.tryRestoreSession(), secureSession.masterKey != nil {
                print("[AppCoordinator] Biometric restore succeeded, master key size: \(secureSession.masterKey?.count ?? 0)")
                // Verify the restored key actually works
                if await verifyMasterKeyWorks(token: token) {
                    transition(to: .authenticated)
                    return
                } else {
                    print("[AppCoordinator] Biometric-restored key is stale/invalid, clearing and trying other methods...")
                    secureSession.lock()
                    secureSession.clearPersistedSession()
                }
            }
            print("[AppCoordinator] Biometric restore failed or key invalid, trying device share...")
            
            // 2. Try automatic unlock with device share (same device)
            do {
                try await e2eeService.unlockWithDeviceShare(token: token)
                print("[AppCoordinator] Device share unlock succeeded")
                transition(to: .authenticated)
                return
            } catch {
                print("[AppCoordinator] Device share unlock failed: \(error)")
            }
            
            // 3. Try passkey unlock (if user has passkeys set up)
            print("[AppCoordinator] Checking for passkey unlock...")
            do {
                let hasPasskeys = try await e2eeService.hasPasskeys(token: token)
                if hasPasskeys {
                    print("[AppCoordinator] User has passkeys, attempting passkey unlock...")
                    try await e2eeService.unlockWithPasskey(token: token)
                    print("[AppCoordinator] Passkey unlock succeeded")
                    transition(to: .authenticated)
                    return
                } else {
                    print("[AppCoordinator] No passkeys found for user")
                }
            } catch {
                print("[AppCoordinator] Passkey unlock failed: \(error)")
            }
            
            // 4. Need manual recovery with password/recovery phrase
            print("[AppCoordinator] Showing E2EE unlock screen for manual recovery")
            transition(to: .authenticatedNeedsE2EEUnlock)
            
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
    
    /// Simplified state determination for demo mode
    private func determineInitialStateForDemoMode() async {
        print("[DemoMode] Determining initial state for demo mode")
        
        // In demo mode, check if authenticated and go straight to main app
        if authService.isAuthenticated {
            print("[DemoMode] Already authenticated, transitioning to authenticated state")
            transition(to: .authenticated)
        } else {
            print("[DemoMode] Not authenticated, showing login screen")
            transition(to: .unauthenticated)
        }
    }
    
    // MARK: - State Transitions
    
    func handleAuthenticationSuccess() async {
        // Demo mode: Skip token verification and go straight to authenticated
        if DemoModeManager.shared.isActive {
            print("[DemoMode] Authentication success - transitioning to authenticated state")
            transition(to: .authenticated)
            return
        }
        
        // Wait for Clerk session to be fully established AND able to issue tokens
        // This helps with OAuth redirects where the session may not be immediately available
        var tokenReady = false
        
        for attempt in 1...5 {
            if authService.isAuthenticated {
                // Also verify we can actually get a token
                do {
                    _ = try await authService.getToken()
                    tokenReady = true
                    print("[AppCoordinator] Token ready after \(attempt) attempt(s)")
                    break
                } catch {
                    print("[AppCoordinator] Token not ready yet (attempt \(attempt)): \(error)")
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        
        if !tokenReady {
            print("[AppCoordinator] WARNING: Could not obtain token after auth success")
        }
        
        await determineInitialState()
    }
    
    /// Verifies that the current master key can actually decrypt data
    /// This catches stale keys from biometric restore that no longer match the server-side encryption
    private func verifyMasterKeyWorks(token: String) async -> Bool {
        do {
            // Try to verify by checking if we can use the key for any operation
            // The e2eeService.checkSetupStatus already uses the server, so we trust that
            // A better check would be to try decrypting a known piece of data
            
            // For now, we'll verify by attempting a simple key derivation test
            // If the master key is valid, basic crypto operations should work
            guard let masterKey = secureSession.masterKey, masterKey.count == 32 else {
                print("[AppCoordinator] Master key missing or wrong size")
                return false
            }
            
            // Try to get the auth share from server and verify it matches
            // This is the most reliable way to check if the key is correct
            let isValid = try await e2eeService.verifyMasterKey(token: token)
            print("[AppCoordinator] Master key verification result: \(isValid)")
            return isValid
        } catch {
            print("[AppCoordinator] Master key verification failed: \(error)")
            return false
        }
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
        secureSession.lock()
        
        // Deactivate demo mode on sign out
        if DemoModeManager.shared.isActive {
            DemoModeManager.shared.deactivate()
            print("[DemoMode] Demo mode deactivated on sign out")
        }
        
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
