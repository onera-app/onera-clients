//
//  KeyShares.swift
//  Onera
//
//  E2EE key share models
//

import Foundation
import UIKit

// MARK: - Key Shares (Server Response)

struct KeyShares: Sendable {
    let authShare: Data
    let encryptedRecoveryShare: Data
    let recoveryShareNonce: Data
    let publicKey: Data
    let encryptedPrivateKey: Data
    let privateKeyNonce: Data
    let masterKeyRecovery: Data
    let masterKeyRecoveryNonce: Data
    let encryptedRecoveryKey: Data
    let recoveryKeyNonce: Data
}

// MARK: - Split Shares (Local)

struct SplitShares: Sendable {
    let deviceShare: Data
    let authShare: Data
    let recoveryShare: Data
}

// MARK: - Device Info

struct DeviceInfo: Sendable {
    let deviceId: String
    let deviceName: String
    let platform: String
    let fingerprint: String
    let userAgent: String
    
    static func current() throws -> DeviceInfo {
        let deviceId = try KeychainService().getOrCreateDeviceId()
        
        let device = UIDevice.current
        let name = device.name
        let platform = "iOS"
        
        var fingerprintComponents = [
            device.model,
            device.systemName,
            device.systemVersion
        ]
        if let vendorId = device.identifierForVendor?.uuidString {
            fingerprintComponents.append(vendorId)
        }
        let fingerprint = fingerprintComponents.joined(separator: "|")
        
        // User agent format: "Onera iOS/version (device model; iOS version)"
        let userAgent = "Onera iOS/\(Bundle.main.appVersion) (\(device.model); iOS \(device.systemVersion))"
        
        return DeviceInfo(
            deviceId: deviceId,
            deviceName: name,
            platform: platform,
            fingerprint: fingerprint,
            userAgent: userAgent
        )
    }
}

// MARK: - Encrypted Device Name

struct EncryptedDeviceName: Codable, Sendable {
    let encryptedDeviceName: String
    let deviceNameNonce: String
}

// MARK: - Password Encrypted Master Key

/// Encrypted master key with password derivation metadata (matching web's PasswordEncryptedMasterKey)
struct PasswordEncryptedMasterKey: Codable, Sendable {
    /// Base64-encoded ciphertext
    let ciphertext: String
    /// Base64-encoded nonce (24 bytes for XSalsa20-Poly1305)
    let nonce: String
    /// Base64-encoded salt used for Argon2id key derivation (16 bytes)
    let salt: String
    /// Argon2id operations limit used
    let opsLimit: Int
    /// Argon2id memory limit used
    let memLimit: Int
}

// MARK: - Encrypted Chat Data (Server Format)

struct EncryptedChatData: Sendable {
    let id: String
    let encryptedChatKey: Data
    let chatKeyNonce: Data
    let encryptedTitle: Data
    let titleNonce: Data
    let encryptedChat: Data
    let chatNonce: Data
    let createdAt: Date
    let updatedAt: Date
}
