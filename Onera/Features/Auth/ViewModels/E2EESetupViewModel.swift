//
//  E2EESetupViewModel.swift
//  Onera
//
//  E2EE setup view model with optional password and passkey setup
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class E2EESetupViewModel {
    
    // MARK: - State
    
    enum SetupState: Equatable {
        case loading
        case showingPhrase(String)
        case confirmPhrase
        case unlockMethodOptions
        case settingPasskey
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
    
    // Passkey setup state
    private(set) var isSettingUpPasskey = false
    private(set) var passkeyError: String?
    var showPasskeyError: Bool {
        get { passkeyError != nil }
        set { if !newValue { passkeyError = nil } }
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
    
    /// Check if passkey is supported on this device
    var passkeySupported: Bool {
        e2eeService.isPasskeySupported()
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
        // If passkey is supported, go directly to passkey setup
        if passkeySupported {
            state = .settingPasskey
        } else {
            state = .unlockMethodOptions
        }
    }
    
    // MARK: - Passkey Setup
    
    func selectPasskeySetup() {
        state = .settingPasskey
    }
    
    func setupPasskey() async {
        guard !isSettingUpPasskey else { return }
        
        isSettingUpPasskey = true
        passkeyError = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.registerPasskey(
                name: getDeviceName(),
                token: token
            )
            completeSetup()
        } catch let error as PasskeyError {
            if case .cancelled = error {
                // User cancelled, don't show error
                isSettingUpPasskey = false
                return
            }
            passkeyError = error.localizedDescription
        } catch {
            passkeyError = "Failed to set up passkey. Please try again."
        }
        
        isSettingUpPasskey = false
    }
    
    private func getDeviceName() -> String {
        #if targetEnvironment(simulator)
        return "iPhone Simulator"
        #else
        return UIDevice.current.name
        #endif
    }
    
    // MARK: - Password Setup
    
    func selectPasswordSetup() {
        state = .settingPassword
    }
    
    func backToOptions() {
        password = ""
        confirmPassword = ""
        passwordError = nil
        passkeyError = nil
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
    
    func clearPasskeyError() {
        passkeyError = nil
    }
}
