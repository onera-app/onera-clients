//
//  KeyShares.swift
//  Onera
//
//  E2EE key share models
//

import Foundation

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
    
    static func current() throws -> DeviceInfo {
        let deviceId = try KeychainService().getOrCreateDeviceId()
        
        #if os(iOS)
        import UIKit
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
        #else
        let name = Host.current().localizedName ?? "Mac"
        let platform = "macOS"
        let fingerprint = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        
        return DeviceInfo(
            deviceId: deviceId,
            deviceName: name,
            platform: platform,
            fingerprint: fingerprint
        )
    }
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
