//
//  E2EEUnlockViewModel.swift
//  Onera
//
//  E2EE unlock/recovery view model with passkey support
//

import Foundation
import Observation

@MainActor
@Observable
final class E2EEUnlockViewModel {
    
    // MARK: - State
    
    var words: [String] = Array(repeating: "", count: Configuration.Mnemonic.wordCount)
    var pastedPhrase = ""
    var showPasteField = false
    
    private(set) var isUnlocking = false
    private(set) var error: String?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    // Passkey state
    private(set) var isUnlockingWithPasskey = false
    private(set) var hasServerPasskey = false
    private(set) var isCheckingPasskey = true
    
    var currentPhrase: String {
        if showPasteField && !pastedPhrase.isEmpty {
            return pastedPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return words
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    var isValid: Bool {
        let wordCount = currentPhrase.split(separator: " ").count
        return wordCount == Configuration.Mnemonic.wordCount
    }
    
    var canUnlock: Bool {
        isValid && !isUnlocking
    }
    
    /// Check if passkey is supported on this device
    var passkeySupported: Bool {
        e2eeService.isPasskeySupported()
    }
    
    /// Check if this device has a passkey set up locally
    var hasLocalPasskey: Bool {
        e2eeService.hasLocalPasskey()
    }
    
    /// Show passkey option if supported and user has passkey registered on server
    /// Cross-device passkeys (synced via iCloud Keychain) don't require local storage
    var canUsePasskey: Bool {
        passkeySupported && hasServerPasskey
    }
    
    // MARK: - Dependencies
    
    /// Exposed for view to create related ViewModels (e.g., PasswordUnlockViewModel)
    let authService: AuthServiceProtocol
    let e2eeService: E2EEServiceProtocol
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
    
    // MARK: - Passkey Actions
    
    /// Check if user has passkeys on server and attempt auto-unlock
    func checkAndAutoUnlockWithPasskey() async {
        isCheckingPasskey = true
        
        do {
            let token = try await authService.getToken()
            hasServerPasskey = try await e2eeService.hasPasskeys(token: token)
            
            // If user has passkey on server, auto-trigger unlock
            // Cross-device passkeys (synced via iCloud Keychain) will be available
            if hasServerPasskey && passkeySupported {
                await unlockWithPasskey()
            }
        } catch {
            // Failed to check passkey status - continue to show unlock options
            hasServerPasskey = false
        }
        
        isCheckingPasskey = false
    }
    
    /// Unlock using passkey (Face ID / Touch ID)
    func unlockWithPasskey() async {
        guard !isUnlockingWithPasskey else { return }
        
        isUnlockingWithPasskey = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.unlockWithPasskey(token: token)
            onComplete()
        } catch let passkeyError as PasskeyError {
            if case .cancelled = passkeyError {
                // User cancelled - don't show error
                isUnlockingWithPasskey = false
                return
            }
            self.error = passkeyError.localizedDescription
        } catch {
            self.error = "Failed to unlock with passkey. Please try another method."
        }
        
        isUnlockingWithPasskey = false
    }
    
    // MARK: - Recovery Phrase Actions
    
    func unlock() async {
        guard canUnlock else { return }
        
        isUnlocking = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.unlockWithRecoveryPhrase(
                mnemonic: currentPhrase,
                token: token
            )
            onComplete()
        } catch {
            self.error = "Invalid recovery phrase. Please check and try again."
        }
        
        isUnlocking = false
    }
    
    func parsePhrase(_ text: String) {
        let parsed = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        for (index, word) in parsed.prefix(Configuration.Mnemonic.wordCount).enumerated() {
            words[index] = word
        }
    }
    
    func toggleInputMode() {
        showPasteField.toggle()
    }
    
    func clearError() {
        error = nil
    }
}
