//
//  KeyShares.swift
//  Onera
//
//  E2EE key share models
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import IOKit
#endif

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
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        #if os(iOS)
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
        let userAgent = "Onera iOS/\(appVersion) (\(device.model); iOS \(device.systemVersion))"
        #elseif os(macOS)
        let name = Host.current().localizedName ?? "Mac"
        let platform = "macOS"
        
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        var fingerprintComponents = [
            "Mac",
            "macOS",
            osVersionString
        ]
        // Add hardware UUID if available
        if let hardwareUUID = getHardwareUUID() {
            fingerprintComponents.append(hardwareUUID)
        }
        let fingerprint = fingerprintComponents.joined(separator: "|")
        let userAgent = "Onera macOS/\(appVersion) (Mac; macOS \(osVersionString))"
        #endif
        
        return DeviceInfo(
            deviceId: deviceId,
            deviceName: name,
            platform: platform,
            fingerprint: fingerprint,
            userAgent: userAgent
        )
    }
    
    #if os(macOS)
    private static func getHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0,
              let uuid = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String else {
            return nil
        }
        return uuid
    }
    #endif
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
