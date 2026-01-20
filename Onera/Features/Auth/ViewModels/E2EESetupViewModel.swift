//
//  E2EESetupViewModel.swift
//  Onera
//
//  E2EE setup view model with optional password setup
//

import Foundation
import Observation

@MainActor
@Observable
final class E2EESetupViewModel {
    
    // MARK: - State
    
    enum SetupState: Equatable {
        case loading
        case showingPhrase(String)
        case confirmPhrase
        case unlockMethodOptions
        case settingPassword
        case error(String)
    }
    
    private(set) var state: SetupState = .loading
    var hasSavedPhrase = false
    var showConfirmation = false
    
    // Password setup state
    var password = ""
    var confirmPassword = ""
    var showPassword = false
    private(set) var isSettingUpPassword = false
    private(set) var passwordError: String?
    var showPasswordError: Bool {
        get { passwordError != nil }
        set { if !newValue { passwordError = nil } }
    }
    
    // Stored recovery phrase
    private var savedMnemonic: String?
    
    var canComplete: Bool {
        if case .showingPhrase = state {
            return hasSavedPhrase
        }
        return false
    }
    
    var recoveryPhrase: String? {
        if case .showingPhrase(let phrase) = state {
            return phrase
        }
        return savedMnemonic
    }
    
    var isPasswordValid: Bool {
        password.count >= 8 && password == confirmPassword
    }
    
    var canSetupPassword: Bool {
        isPasswordValid && !isSettingUpPassword
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
    
    func startSetup() async {
        state = .loading
        
        do {
            let token = try await authService.getToken()
            let mnemonic = try await e2eeService.setupNewUser(token: token)
            savedMnemonic = mnemonic
            state = .showingPhrase(mnemonic)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func confirmSaved() {
        showConfirmation = true
    }
    
    func proceedToUnlockMethod() {
        state = .unlockMethodOptions
    }
    
    func selectPasswordSetup() {
        state = .settingPassword
    }
    
    func backToOptions() {
        password = ""
        confirmPassword = ""
        passwordError = nil
        state = .unlockMethodOptions
    }
    
    func setupPassword() async {
        guard canSetupPassword else { return }
        
        isSettingUpPassword = true
        passwordError = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.setupPasswordEncryption(
                password: password,
                token: token
            )
            completeSetup()
        } catch {
            passwordError = "Failed to set up password. Please try again."
        }
        
        isSettingUpPassword = false
    }
    
    func skipPasswordSetup() {
        completeSetup()
    }
    
    func completeSetup() {
        onComplete()
    }
    
    func retry() async {
        await startSetup()
    }
    
    func togglePasswordVisibility() {
        showPassword.toggle()
    }
    
    func clearPasswordError() {
        passwordError = nil
    }
}
