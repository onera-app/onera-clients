//
//  Configuration.swift
//  Onera
//
//  App configuration and constants
//

import Foundation

enum Configuration {
    // MARK: - API Configuration
    static let apiBaseURL = URL(string: "https://api.your-backend.com")!
    static let trpcPath = "/trpc"
    
    // MARK: - Clerk Configuration
    static let clerkPublishableKey = "pk_test_YOUR_CLERK_KEY"
    
    // MARK: - Security Configuration
    static let sessionTimeoutMinutes: TimeInterval = 30
    static let masterKeyLength = 32
    static let nonceLength = 24 // XSalsa20-Poly1305 nonce
    static let shareCount = 3
    
    // MARK: - BIP39 Configuration
    static let mnemonicWordCount = 24
    
    // MARK: - Keychain Configuration
    enum KeychainKeys {
        static let deviceId = "com.onera.deviceId"
        static let encryptedDeviceShare = "com.onera.encryptedDeviceShare"
        static let deviceShareNonce = "com.onera.deviceShareNonce"
    }
    
    // MARK: - Encryption Context Strings
    enum CryptoContext {
        static let deviceShareDerivation = "onera.deviceshare.v2"
    }
}
