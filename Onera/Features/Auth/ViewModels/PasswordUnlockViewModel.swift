//
//  PasswordUnlockViewModel.swift
//  Onera
//
//  Password-based E2EE unlock view model
//

import Foundation
import Observation

@MainActor
@Observable
final class PasswordUnlockViewModel {
    
    // MARK: - State
    
    var password = ""
    var showPassword = false
    
    private(set) var isUnlocking = false
    private(set) var error: String?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    var isValid: Bool {
        !password.isEmpty
    }
    
    var canUnlock: Bool {
        isValid && !isUnlocking
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    private let onComplete: () -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        e2eeService: E2EEServiceProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.authService = authService
        self.e2eeService = e2eeService
        self.onComplete = onComplete
    }
    
    // MARK: - Actions
    
    func unlock() async {
        guard canUnlock else { return }
        
        isUnlocking = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.unlockWithPassword(
                password: password,
                token: token
            )
            onComplete()
        } catch let cryptoError as CryptoError {
            switch cryptoError {
            case .incorrectPassword:
                self.error = "Incorrect password. Please try again."
            default:
                self.error = "Failed to unlock. Please try again."
            }
        } catch {
            self.error = "Failed to unlock. Please try again."
        }
        
        isUnlocking = false
    }
    
    func togglePasswordVisibility() {
        showPassword.toggle()
    }
    
    func clearError() {
        error = nil
    }
    
    func clearPassword() {
        password = ""
    }
}
