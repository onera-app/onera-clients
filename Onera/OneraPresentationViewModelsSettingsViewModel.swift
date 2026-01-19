//
//  SettingsViewModel.swift
//  Onera
//
//  Settings view model
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    
    // MARK: - State
    
    private(set) var user: User?
    private(set) var isSessionUnlocked = false
    private(set) var isLoadingRecoveryPhrase = false
    private(set) var recoveryPhrase: String?
    private(set) var error: Error?
    
    var showSignOutConfirmation = false
    var showRecoveryPhrase = false
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    private let secureSession: SecureSessionProtocol
    private let onSignOut: () async -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        e2eeService: E2EEServiceProtocol,
        secureSession: SecureSessionProtocol,
        onSignOut: @escaping () async -> Void
    ) {
        self.authService = authService
        self.e2eeService = e2eeService
        self.secureSession = secureSession
        self.onSignOut = onSignOut
    }
    
    // MARK: - Actions
    
    func loadSettings() {
        user = authService.currentUser
        isSessionUnlocked = secureSession.isUnlocked
    }
    
    func loadRecoveryPhrase() async {
        isLoadingRecoveryPhrase = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            recoveryPhrase = try await e2eeService.getRecoveryPhrase(token: token)
        } catch {
            self.error = error
        }
        
        isLoadingRecoveryPhrase = false
    }
    
    func lockSession() async {
        await secureSession.lock()
        isSessionUnlocked = false
    }
    
    func signOut() async {
        await onSignOut()
    }
    
    func clearRecoveryPhrase() {
        recoveryPhrase = nil
    }
}
