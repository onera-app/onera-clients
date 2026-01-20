//
//  PasswordSetupViewModel.swift
//  Onera
//
//  Password setup view model for E2EE encryption password
//

import Foundation
import Observation

@MainActor
@Observable
final class PasswordSetupViewModel {
    
    // MARK: - State
    
    var password = ""
    var confirmPassword = ""
    var showPassword = false
    
    private(set) var isSettingUp = false
    private(set) var error: String?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    var isValid: Bool {
        password.count >= 8 && password == confirmPassword
    }
    
    var canSetup: Bool {
        isValid && !isSettingUp
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword || confirmPassword.isEmpty
    }
    
    var passwordLengthValid: Bool {
        password.count >= 8 || password.isEmpty
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    private let onComplete: () -> Void
    private let onSkip: () -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        e2eeService: E2EEServiceProtocol,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.authService = authService
        self.e2eeService = e2eeService
        self.onComplete = onComplete
        self.onSkip = onSkip
    }
    
    // MARK: - Actions
    
    func setupPassword() async {
        guard canSetup else { return }
        
        isSettingUp = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.setupPasswordEncryption(
                password: password,
                token: token
            )
            onComplete()
        } catch {
            self.error = "Failed to set up password. Please try again."
        }
        
        isSettingUp = false
    }
    
    func skip() {
        onSkip()
    }
    
    func togglePasswordVisibility() {
        showPassword.toggle()
    }
    
    func clearError() {
        error = nil
    }
    
    func clearPasswords() {
        password = ""
        confirmPassword = ""
    }
}
