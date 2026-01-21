//
//  Configuration.swift
//  Onera
//
//  App configuration and constants
//

import Foundation

// MARK: - Environment

enum AppEnvironment: String {
    case development
    case staging
    case production
    
    static var current: AppEnvironment {
        #if DEBUG
        return .staging
        #else
        return .production
        #endif
    }
}

// MARK: - Configuration

enum Configuration {
    
    // MARK: - API Configuration
    
    static var apiBaseURL: URL {
        switch AppEnvironment.current {
        case .development:
            return URL(string: "http://localhost:3000")!
        case .staging:
            return URL(string: "https://api-stage.onera.app")!
        case .production:
            return URL(string: "https://api.onera.app")!
        }
    }
    
    static let trpcPath = "/trpc"
    
    // MARK: - Clerk Configuration
    
    static var clerkPublishableKey: String {
        switch AppEnvironment.current {
        case .development, .staging:
            return "REDACTED_CLERK_KEY"
        case .production:
            return "REDACTED_CLERK_KEY"
        }
    }
    
    // MARK: - Security Configuration
    
    enum Security: Sendable {
        nonisolated static let sessionTimeoutMinutes: TimeInterval = 30
        nonisolated static let backgroundLockTimeoutMinutes: TimeInterval = 5
        nonisolated static let masterKeyLength = 32
        nonisolated static let nonceLength = 24 // XSalsa20-Poly1305 nonce
        nonisolated static let shareCount = 3
        nonisolated static let passwordSaltLength = 16 // crypto_pwhash_SALTBYTES
    }
    
    // MARK: - BIP39 Configuration
    
    enum Mnemonic: Sendable {
        nonisolated static let wordCount = 24
        nonisolated static let entropyBytes = 32 // 256 bits for 24 words
    }
    
    // MARK: - Keychain Configuration
    
    enum Keychain: Sendable {
        nonisolated static let serviceName = "com.onera.keychain"
        
        enum Keys: Sendable {
            nonisolated static let deviceId = "deviceId"
            nonisolated static let encryptedDeviceShare = "encryptedDeviceShare"
            nonisolated static let deviceShareNonce = "deviceShareNonce"
            nonisolated static let passkeyKEK = "passkeyKEK"
            nonisolated static let passkeyCredentialId = "passkeyCredentialId"
        }
    }
    
    // MARK: - WebAuthn Configuration
    
    enum WebAuthn {
        static var rpID: String {
            switch AppEnvironment.current {
            case .development:
                return "localhost"
            case .staging:
                return "staging.onera.app"
            case .production:
                return "onera.app"
            }
        }
        
        static var rpName: String {
            return "Onera"
        }
    }
    
    // MARK: - Encryption Context Strings
    
    enum CryptoContext: Sendable {
        nonisolated static let deviceShareDerivation = "onera.deviceshare.v2"
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        static let enableBiometricUnlock = true
        static let enablePushNotifications = true
        static let enableAnalytics = AppEnvironment.current == .production
    }
}
