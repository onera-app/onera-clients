//
//  E2EEServiceProtocol.swift
//  Onera
//
//  Protocol for E2EE key management
//

import Foundation

// MARK: - E2EE Service Protocol

protocol E2EEServiceProtocol: Sendable {
    
    // MARK: - Setup Status
    
    /// Checks if user has E2EE keys set up
    func checkSetupStatus(token: String) async throws -> Bool
    
    // MARK: - New User Setup
    
    /// Sets up E2EE for a new user
    /// Returns the recovery mnemonic that MUST be shown to user
    func setupNewUser(token: String) async throws -> String
    
    // MARK: - Unlock (Same Device)
    
    /// Attempts to unlock using stored device share
    func unlockWithDeviceShare(token: String) async throws
    
    // MARK: - Unlock (Recovery)
    
    /// Unlocks using recovery mnemonic
    func unlockWithRecoveryPhrase(mnemonic: String, token: String) async throws
    
    // MARK: - Password-Based Unlock
    
    /// Checks if user has password encryption set up
    func hasPasswordEncryption(token: String) async throws -> Bool
    
    /// Sets up password-based encryption for the master key
    func setupPasswordEncryption(password: String, token: String) async throws
    
    /// Unlocks using password
    func unlockWithPassword(password: String, token: String) async throws
    
    /// Removes password encryption (requires unlocked session)
    func removePasswordEncryption(token: String) async throws
    
    // MARK: - Passkey-Based Unlock
    
    /// Checks if passkey is supported on this device
    func isPasskeySupported() -> Bool
    
    /// Checks if user has any passkeys registered on server
    func hasPasskeys(token: String) async throws -> Bool
    
    /// Checks if this device has a passkey set up locally
    func hasLocalPasskey() -> Bool
    
    /// Registers a new passkey for the current session
    /// Requires session to be unlocked (master key available)
    func registerPasskey(name: String?, token: String) async throws
    
    /// Unlocks using passkey (Face ID / Touch ID)
    func unlockWithPasskey(token: String) async throws
    
    // MARK: - Recovery Phrase
    
    /// Gets the decrypted recovery phrase (requires unlocked session)
    func getRecoveryPhrase(token: String) async throws -> String
    
    // MARK: - Verification
    
    /// Verifies that the current master key in session is valid by checking against server
    /// Returns true if the key can successfully decrypt server-side data
    func verifyMasterKey(token: String) async throws -> Bool
}

// MARK: - Secure Session Protocol

@MainActor
protocol SecureSessionProtocol: Sendable {
    
    // MARK: - State
    
    var isUnlocked: Bool { get }
    var lastActivityDate: Date { get }
    
    // MARK: - Key Access
    
    var masterKey: Data? { get }
    var privateKey: Data? { get }
    var publicKey: Data? { get }
    
    // MARK: - Lifecycle
    
    /// Unlocks the session with decrypted keys
    func unlock(
        masterKey: Data,
        privateKey: Data,
        publicKey: Data,
        recoveryKey: Data?
    )
    
    /// Locks the session and clears all keys
    func lock()
    
    /// Attempts to restore session using biometric authentication
    /// Returns true if restoration was successful
    @discardableResult
    func tryRestoreSession() async -> Bool
    
    /// Clears any persisted session data (biometric keychain)
    func clearPersistedSession()
    
    /// Records user activity to reset timeout
    func recordActivity()
}
