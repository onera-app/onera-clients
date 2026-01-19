//
//  SecureSession.swift
//  Onera
//
//  In-memory secure session for decrypted E2EE keys
//

import Foundation
import Combine

/// Holds decrypted keys in memory only - never persisted
/// Auto-locks after configurable timeout
@MainActor
final class SecureSession: ObservableObject {
    static let shared = SecureSession()
    
    // MARK: - Published State
    
    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var lastActivityDate: Date = Date()
    
    // MARK: - Sensitive Data (Memory Only)
    
    private var _masterKey: Data?
    private var _privateKey: Data?
    private var _publicKey: Data?
    private var _recoveryKey: Data?
    
    // MARK: - Session Management
    
    private var lockTimer: Timer?
    private let timeoutInterval: TimeInterval
    
    private init(timeoutMinutes: TimeInterval = Configuration.sessionTimeoutMinutes) {
        self.timeoutInterval = timeoutMinutes * 60
        setupActivityMonitoring()
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
        recordActivity()
        return _recoveryKey
    }
    
    // MARK: - Session Lifecycle
    
    /// Unlocks the session with decrypted keys
    func unlock(
        masterKey: Data,
        privateKey: Data,
        publicKey: Data,
        recoveryKey: Data? = nil
    ) {
        _masterKey = masterKey
        _privateKey = privateKey
        _publicKey = publicKey
        _recoveryKey = recoveryKey
        
        isUnlocked = true
        recordActivity()
        startLockTimer()
    }
    
    /// Locks the session and securely clears all keys
    func lock() {
        // Securely zero all keys before clearing
        if var key = _masterKey {
            CryptoManager.shared.secureZero(&key)
        }
        if var key = _privateKey {
            CryptoManager.shared.secureZero(&key)
        }
        if var key = _publicKey {
            CryptoManager.shared.secureZero(&key)
        }
        if var key = _recoveryKey {
            CryptoManager.shared.secureZero(&key)
        }
        
        _masterKey = nil
        _privateKey = nil
        _publicKey = nil
        _recoveryKey = nil
        
        isUnlocked = false
        stopLockTimer()
    }
    
    // MARK: - Activity Tracking
    
    func recordActivity() {
        lastActivityDate = Date()
        resetLockTimer()
    }
    
    private func setupActivityMonitoring() {
        // Monitor app going to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Start aggressive timer when backgrounded
            self?.startBackgroundLockTimer()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkSessionTimeout()
        }
    }
    
    // MARK: - Timer Management
    
    private func startLockTimer() {
        stopLockTimer()
        lockTimer = Timer.scheduledTimer(
            withTimeInterval: timeoutInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }
    
    private func startBackgroundLockTimer() {
        // Lock more aggressively in background (5 minutes)
        stopLockTimer()
        lockTimer = Timer.scheduledTimer(
            withTimeInterval: 5 * 60,
            repeats: false
        ) { [weak self] _ in
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
    
    deinit {
        // Ensure keys are cleared if session is deallocated
        lock()
    }
}

// MARK: - Session State

extension SecureSession {
    enum State {
        case locked
        case unlocked
        case needsRecoveryPhrase
    }
    
    var state: State {
        if isUnlocked {
            return .unlocked
        }
        return .locked
    }
}
