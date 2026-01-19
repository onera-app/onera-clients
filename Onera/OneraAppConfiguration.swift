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
            return "REDACTED_CLERK_TEST_KEY"
        case .production:
            return "pk_live_YOUR_PRODUCTION_KEY"
        }
    }
    
    // MARK: - Security Configuration
    
    enum Security {
        static let sessionTimeoutMinutes: TimeInterval = 30
        static let backgroundLockTimeoutMinutes: TimeInterval = 5
        static let masterKeyLength = 32
        static let nonceLength = 24 // XSalsa20-Poly1305 nonce
        static let shareCount = 3
    }
    
    // MARK: - BIP39 Configuration
    
    enum Mnemonic {
        static let wordCount = 24
        static let entropyBytes = 32 // 256 bits for 24 words
    }
    
    // MARK: - Keychain Configuration
    
    enum Keychain {
        static let serviceName = "com.onera.keychain"
        
        enum Keys {
            static let deviceId = "deviceId"
            static let encryptedDeviceShare = "encryptedDeviceShare"
            static let deviceShareNonce = "deviceShareNonce"
        }
    }
    
    // MARK: - Encryption Context Strings
    
    enum CryptoContext {
        static let deviceShareDerivation = "onera.deviceshare.v2"
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        static let enableBiometricUnlock = true
        static let enablePushNotifications = true
        static let enableAnalytics = AppEnvironment.current == .production
    }
}
