//
//  KeychainManager.swift
//  Onera
//
//  Secure keychain operations for E2EE key storage
//

import Foundation
import Security

final class KeychainManager: Sendable {
    static let shared = KeychainManager()
    
    private let accessControl: SecAccessControl? = {
        SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [],
            nil
        )
    }()
    
    private init() {}
    
    // MARK: - Device ID Management
    
    /// Gets or creates a persistent device ID
    func getOrCreateDeviceId() throws -> String {
        if let existingId = try? getData(forKey: Configuration.KeychainKeys.deviceId),
           let idString = String(data: existingId, encoding: .utf8) {
            return idString
        }
        
        let newId = UUID().uuidString
        guard let idData = newId.data(using: .utf8) else {
            throw CryptoError.keychainOperationFailed
        }
        
        try save(data: idData, forKey: Configuration.KeychainKeys.deviceId)
        return newId
    }
    
    // MARK: - Device Share Management
    
    /// Saves encrypted device share to keychain
    func saveEncryptedDeviceShare(_ encryptedShare: Data, nonce: Data) throws {
        try save(data: encryptedShare, forKey: Configuration.KeychainKeys.encryptedDeviceShare)
        try save(data: nonce, forKey: Configuration.KeychainKeys.deviceShareNonce)
    }
    
    /// Retrieves encrypted device share and nonce
    func getEncryptedDeviceShare() throws -> (encryptedShare: Data, nonce: Data) {
        let encryptedShare = try getData(forKey: Configuration.KeychainKeys.encryptedDeviceShare)
        let nonce = try getData(forKey: Configuration.KeychainKeys.deviceShareNonce)
        return (encryptedShare, nonce)
    }
    
    /// Checks if device share exists
    func hasDeviceShare() -> Bool {
        (try? getData(forKey: Configuration.KeychainKeys.encryptedDeviceShare)) != nil
    }
    
    /// Removes device share (for logout/device reset)
    func removeDeviceShare() throws {
        try delete(forKey: Configuration.KeychainKeys.encryptedDeviceShare)
        try delete(forKey: Configuration.KeychainKeys.deviceShareNonce)
    }
    
    // MARK: - Generic Keychain Operations
    
    func save(data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(forKey: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw CryptoError.keychainOperationFailed
        }
    }
    
    func getData(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw CryptoError.keychainOperationFailed
        }
        
        return data
    }
    
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CryptoError.keychainOperationFailed
        }
    }
    
    /// Clears all Onera-related keychain items (for complete logout)
    func clearAll() {
        try? delete(forKey: Configuration.KeychainKeys.deviceId)
        try? delete(forKey: Configuration.KeychainKeys.encryptedDeviceShare)
        try? delete(forKey: Configuration.KeychainKeys.deviceShareNonce)
    }
}
