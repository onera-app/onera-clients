//
//  Configuration.swift
//  Onera
//
//  App configuration and constants
//
//  Environment variables are set via xcconfig files:
//  - Config/Production.xcconfig (for Production target)
//  - Config/Staging.xcconfig (for Staging target)
//
//  Values are read from Config.plist which uses $(VARIABLE) substitution
//  from the xcconfig build settings at compile time.
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

// MARK: - Config.plist Helper

private enum ConfigPlist {
    private static var config: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("⚠️ Warning: Config.plist not found or invalid. Using default values.")
            return nil
        }
        return plist
    }()
    
    static func string(forKey key: String) -> String? {
        config?[key] as? String
    }
    
    static func string(forKey key: String, default defaultValue: String) -> String {
        string(forKey: key) ?? defaultValue
    }
}

// MARK: - Configuration

enum Configuration {
    
    // MARK: - API Configuration
    
    static var apiBaseURL: URL {
        let urlString = ConfigPlist.string(forKey: "API_BASE_URL", default: "https://api.onera.chat")
        guard let url = URL(string: urlString) else {
            fatalError("Invalid API_BASE_URL in Config.plist: \(urlString)")
        }
        return url
    }
    
    static var trpcPath: String {
        ConfigPlist.string(forKey: "TRPC_PATH", default: "/trpc")
    }
    
    // MARK: - Clerk Configuration
    
    static var clerkPublishableKey: String {
        ConfigPlist.string(forKey: "CLERK_PUBLISHABLE_KEY", default: "REDACTED_CLERK_KEY")
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
        nonisolated static var serviceName: String {
            ConfigPlist.string(forKey: "KEYCHAIN_SERVICE_NAME", default: "chat.onera.keychain")
        }
        
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
            ConfigPlist.string(forKey: "WEBAUTHN_RP_ID", default: "onera.chat")
        }
        
        static var rpName: String {
            ConfigPlist.string(forKey: "WEBAUTHN_RP_NAME", default: "Onera")
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
