//
//  E2EESetupViewModel.swift
//  Onera
//
//  E2EE setup view model with optional password and passkey setup
//

import Foundation
import Observation
#if os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class E2EESetupViewModel {
    
    // MARK: - State
    
    /// Setup flow order (mirrors web app):
    /// 1. loading - Generate E2EE keys
    /// 2. settingPasskey / settingPassword - Set up primary unlock method
    /// 3. showingPhrase - Show recovery phrase as backup insurance
    /// 4. confirmPhrase - Confirm recovery phrase is saved
    enum SetupState: Equatable {
        case loading
        case unlockMethodOptions      // Choose passkey or password (if passkey not supported)
        case settingPasskey           // Create passkey (recommended)
        case settingPassword          // Set encryption password
        case showingPhrase(String)    // Show recovery phrase as backup
        case confirmPhrase            // Confirm phrase is saved
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
    
    /// Can show "Done" button when viewing recovery phrase and user has confirmed saving
    var canComplete: Bool {
        if case .showingPhrase = state {
            return hasSavedPhrase
        }
        if case .confirmPhrase = state {
            return true
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
            
            // Web app flow: Show passkey setup first (if supported), then recovery phrase
            if passkeySupported {
                state = .settingPasskey
            } else {
                state = .unlockMethodOptions
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func confirmSaved() {
        showConfirmation = true
    }
    
    /// Called after user confirms they've saved the recovery phrase
    /// (Recovery phrase is now shown AFTER passkey/password setup)
    func proceedAfterRecoveryPhrase() {
        // Complete the setup - user has saved their recovery phrase
        completeSetup()
    }
    
    /// Legacy method - redirects to new flow
    func proceedToUnlockMethod() {
        proceedAfterRecoveryPhrase()
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
            // After passkey setup, show recovery phrase as backup
            showRecoveryPhrase()
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
        #elseif os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
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
            // After password setup, show recovery phrase as backup
            showRecoveryPhrase()
        } catch {
            passwordError = "Failed to set up password. Please try again."
        }
        
        isSettingUpPassword = false
    }
    
    func skipPasswordSetup() {
        // If user skips unlock method, still show recovery phrase
        showRecoveryPhrase()
    }
    
    /// Shows the recovery phrase as backup insurance (after passkey/password setup)
    private func showRecoveryPhrase() {
        if let mnemonic = savedMnemonic {
            state = .showingPhrase(mnemonic)
        } else {
            // Fallback: complete setup if no mnemonic (shouldn't happen)
            completeSetup()
        }
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
