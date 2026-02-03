//
//  SecureSession.swift
//  Onera
//
//  Secure session management with Keychain persistence and biometric protection
//

import Foundation
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import LocalAuthentication
import Security

@MainActor
@Observable
final class SecureSession: SecureSessionProtocol {
    
    // MARK: - State
    
    private(set) var isUnlocked = false
    private(set) var lastActivityDate = Date()
    
    // MARK: - Sensitive Data (Memory Only)
    
    private var _masterKey: Data?
    private var _privateKey: Data?
    private var _publicKey: Data?
    private var _recoveryKey: Data?
    
    // MARK: - Configuration
    
    private let cryptoService: CryptoServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let timeoutInterval: TimeInterval
    private var lockTimer: Timer?
    
    // Keychain keys for session data
    private enum SessionKeys {
        static let sessionBundle = "sessionBundle" // Single item for all session data
    }
    
    // MARK: - Initialization
    
    init(
        cryptoService: CryptoServiceProtocol,
        keychainService: KeychainServiceProtocol,
        timeoutMinutes: TimeInterval = Configuration.Security.sessionTimeoutMinutes
    ) {
        self.cryptoService = cryptoService
        self.keychainService = keychainService
        self.timeoutInterval = timeoutMinutes * 60
        
        setupNotifications()
    }
    
    // MARK: - Key Access
    
    var masterKey: Data? {
        guard isUnlocked else { return nil }
        recordActivity()
        return _masterKey
    }
    
    var privateKey: Data? {
        guard isUnlocked else { return nil }
        recordActivity()
        return _privateKey
    }
    
    var publicKey: Data? {
        guard isUnlocked else { return nil }
        recordActivity()
        return _publicKey
    }
    
    var recoveryKey: Data? {
        guard isUnlocked else { return nil }
        return _recoveryKey
    }
    
    // MARK: - Lifecycle
    
    func unlock(
        masterKey: Data,
        privateKey: Data,
        publicKey: Data,
        recoveryKey: Data?
    ) {
        _masterKey = masterKey
        _privateKey = privateKey
        _publicKey = publicKey
        _recoveryKey = recoveryKey
        
        isUnlocked = true
        recordActivity()
        startLockTimer()
        
        // Persist session with biometric protection if enabled
        if Configuration.Features.enableBiometricUnlock {
            Task {
                await persistSession()
            }
        }
    }
    
    func lock() {
        // Securely zero all keys before clearing
        if var key = _masterKey {
            cryptoService.secureZero(&key)
        }
        if var key = _privateKey {
            cryptoService.secureZero(&key)
        }
        if var key = _publicKey {
            cryptoService.secureZero(&key)
        }
        if var key = _recoveryKey {
            cryptoService.secureZero(&key)
        }
        
        _masterKey = nil
        _privateKey = nil
        _publicKey = nil
        _recoveryKey = nil
        
        isUnlocked = false
        stopLockTimer()
    }
    
    func recordActivity() {
        lastActivityDate = Date()
        resetLockTimer()
    }
    
    // MARK: - Session Persistence (Biometric)
    
    /// Attempts to restore session using biometric authentication
    /// Returns true if restoration was successful
    /// Note: FaceID prompt is triggered automatically by Keychain access (via SecAccessControl),
    /// so we don't need to call LAContext.evaluatePolicy explicitly.
    @discardableResult
    func tryRestoreSession() async -> Bool {
        guard Configuration.Features.enableBiometricUnlock else { return false }
        guard hasStoredSession() else { return false }
        
        // Check if biometrics are available (but don't prompt yet)
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        // The Keychain item itself is protected by biometrics (SecAccessControl),
        // so accessing it will automatically trigger a single FaceID prompt.
        // We don't need to explicitly call evaluatePolicy here.
        do {
            return try await restorePersistedSession(context: context)
        } catch {
            print("Session restore failed: \(error)")
            return false
        }
    }
    
    /// Clears persisted session data
    func clearPersistedSession() {
        try? keychainService.delete(forKey: SessionKeys.sessionBundle)
        // Clean up old format keys (migration)
        try? keychainService.delete(forKey: "encryptedSession")
        try? keychainService.delete(forKey: "sessionNonce")
        try? keychainService.delete(forKey: "sessionEncryptionKey")
    }
    
    /// Checks if there's a stored session that can be restored
    func hasStoredSession() -> Bool {
        (try? keychainService.get(forKey: SessionKeys.sessionBundle)) != nil
    }
    
    // MARK: - Private Session Persistence
    
    private func persistSession() async {
        guard let masterKey = _masterKey,
              let privateKey = _privateKey,
              let publicKey = _publicKey else {
            return
        }
        
        do {
            // Create session data structure with all keys
            let sessionData = SessionData(
                masterKey: masterKey.base64EncodedString(),
                privateKey: privateKey.base64EncodedString(),
                publicKey: publicKey.base64EncodedString(),
                recoveryKey: _recoveryKey?.base64EncodedString(),
                createdAt: Date()
            )
            
            // Encode to JSON - store directly without additional encryption
            // The Keychain item itself is protected by biometrics
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(sessionData)
            
            // Store as single bundle with biometric protection
            // This ensures Face ID is only asked ONCE
            try saveBiometricProtected(jsonData, forKey: SessionKeys.sessionBundle)
        } catch {
            print("Failed to persist session: \(error)")
        }
    }
    
    private func restorePersistedSession(context: LAContext) async throws -> Bool {
        // Retrieve session bundle using the provided LAContext
        // This ensures only ONE FaceID prompt is shown (via SecAccessControl)
        let jsonData = try getBiometricProtected(forKey: SessionKeys.sessionBundle, context: context)
        
        // Decode session data
        let decoder = JSONDecoder()
        let sessionData = try decoder.decode(SessionData.self, from: jsonData)
        
        // Check if session is still valid (e.g., not too old)
        let sessionAge = Date().timeIntervalSince(sessionData.createdAt)
        let maxSessionAge: TimeInterval = 24 * 60 * 60 // 24 hours
        
        guard sessionAge < maxSessionAge else {
            clearPersistedSession()
            return false
        }
        
        // Restore keys
        guard let masterKey = Data(base64Encoded: sessionData.masterKey),
              let privateKey = Data(base64Encoded: sessionData.privateKey),
              let publicKey = Data(base64Encoded: sessionData.publicKey) else {
            clearPersistedSession()
            return false
        }
        
        let recoveryKey = sessionData.recoveryKey.flatMap { Data(base64Encoded: $0) }
        
        // Unlock session
        unlock(
            masterKey: masterKey,
            privateKey: privateKey,
            publicKey: publicKey,
            recoveryKey: recoveryKey
        )
        
        return true
    }
    
    /// Retrieves biometric-protected data using provided LAContext
    /// The context allows reusing a single biometric authentication
    private func getBiometricProtected(forKey key: String, context: LAContext) throws -> Data {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Configuration.Keychain.serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            // Fall back to regular keychain access if biometric access fails
            return try keychainService.get(forKey: key)
        }
        
        return data
    }
    
    private func saveBiometricProtected(_ data: Data, forKey key: String) throws {
        // Delete existing first
        try? keychainService.delete(forKey: key)
        
        // Create access control with biometric requirement
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw KeychainError.accessControlFailed
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Configuration.Keychain.serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            // Fall back to regular save if biometric not available
            try keychainService.save(data, forKey: key)
            return
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleBackgrounding()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleForegrounding()
            }
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleBackgrounding()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handleForegrounding()
            }
        }
        #endif
    }
    
    private func handleBackgrounding() {
        // Use more aggressive timeout when backgrounded
        startLockTimer(interval: Configuration.Security.backgroundLockTimeoutMinutes * 60)
    }
    
    private func handleForegrounding() {
        checkSessionTimeout()
    }
    
    private func startLockTimer(interval: TimeInterval? = nil) {
        stopLockTimer()
        
        let timeout = interval ?? timeoutInterval
        lockTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }
    
    private func resetLockTimer() {
        if isUnlocked {
            startLockTimer()
        }
    }
    
    private func stopLockTimer() {
        lockTimer?.invalidate()
        lockTimer = nil
    }
    
    private func checkSessionTimeout() {
        guard isUnlocked else { return }
        
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        if elapsed >= timeoutInterval {
            lock()
        } else {
            resetLockTimer()
        }
    }
    
    deinit {
        // Note: In deinit we can't call MainActor-isolated methods,
        // but the memory will be reclaimed anyway when the object is deallocated.
        // For extra security during lock(), we zero the keys there.
    }
}

// MARK: - Session Data Model

private struct SessionData: Codable {
    let masterKey: String
    let privateKey: String
    let publicKey: String
    let recoveryKey: String?
    let createdAt: Date
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockSecureSession: SecureSessionProtocol {
    
    var isUnlocked = false
    var lastActivityDate = Date()
    
    var masterKey: Data?
    var privateKey: Data?
    var publicKey: Data?
    
    // For testing biometric restore
    var shouldRestoreSucceed = false
    
    func unlock(masterKey: Data, privateKey: Data, publicKey: Data, recoveryKey: Data?) {
        self.masterKey = masterKey
        self.privateKey = privateKey
        self.publicKey = publicKey
        isUnlocked = true
    }
    
    func lock() {
        masterKey = nil
        privateKey = nil
        publicKey = nil
        isUnlocked = false
    }
    
    func tryRestoreSession() async -> Bool {
        if shouldRestoreSucceed {
            isUnlocked = true
            return true
        }
        return false
    }
    
    func clearPersistedSession() {
        // No-op for mock
    }
    
    func recordActivity() {
        lastActivityDate = Date()
    }
}
#endif
