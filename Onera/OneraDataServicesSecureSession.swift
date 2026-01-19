//
//  SecureSession.swift
//  Onera
//
//  In-memory secure session for decrypted E2EE keys
//

import Foundation
import Observation
import UIKit

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
    private let timeoutInterval: TimeInterval
    private var lockTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        cryptoService: CryptoServiceProtocol,
        timeoutMinutes: TimeInterval = Configuration.Security.sessionTimeoutMinutes
    ) {
        self.cryptoService = cryptoService
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
    }
    
    func lock() {
        // Securely zero all keys before clearing
        securelyZeroKeys()
        
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
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackgrounding()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForegrounding()
        }
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
            Task { @MainActor in
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
    
    private func securelyZeroKeys() {
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
    }
    
    deinit {
        // Ensure keys are cleared
        securelyZeroKeys()
    }
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
    
    func recordActivity() {
        lastActivityDate = Date()
    }
}
#endif
