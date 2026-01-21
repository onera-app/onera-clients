//
//  KeychainService.swift
//  Onera
//
//  Implementation of keychain operations
//

import Foundation
import Security

final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    
    private let serviceName: String
    private let accessGroup: String?
    
    init(
        serviceName: String = Configuration.Keychain.serviceName,
        accessGroup: String? = nil
    ) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    // MARK: - Device ID
    
    func getOrCreateDeviceId() throws -> String {
        let key = Configuration.Keychain.Keys.deviceId
        
        if let existingData = try? get(forKey: key),
           let existingId = String(data: existingData, encoding: .utf8) {
            return existingId
        }
        
        let newId = UUID().uuidString
        guard let idData = newId.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        
        try save(idData, forKey: key)
        return newId
    }
    
    // MARK: - Device Share
    
    func saveDeviceShare(encryptedShare: Data, nonce: Data) throws {
        try save(encryptedShare, forKey: Configuration.Keychain.Keys.encryptedDeviceShare)
        try save(nonce, forKey: Configuration.Keychain.Keys.deviceShareNonce)
    }
    
    func getDeviceShare() throws -> (encryptedShare: Data, nonce: Data) {
        let encryptedShare = try get(forKey: Configuration.Keychain.Keys.encryptedDeviceShare)
        let nonce = try get(forKey: Configuration.Keychain.Keys.deviceShareNonce)
        return (encryptedShare, nonce)
    }
    
    func hasDeviceShare() -> Bool {
        (try? get(forKey: Configuration.Keychain.Keys.encryptedDeviceShare)) != nil
    }
    
    func removeDeviceShare() throws {
        try delete(forKey: Configuration.Keychain.Keys.encryptedDeviceShare)
        try delete(forKey: Configuration.Keychain.Keys.deviceShareNonce)
    }
    
    // MARK: - Passkey KEK
    
    func hasPasskeyKEK() -> Bool {
        (try? get(forKey: Configuration.Keychain.Keys.passkeyKEK)) != nil
    }
    
    func getPasskeyCredentialId() throws -> String? {
        guard let data = try? get(forKey: Configuration.Keychain.Keys.passkeyCredentialId) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Generic Operations
    
    func save(_ data: Data, forKey key: String) throws {
        // Delete existing first
        try? delete(forKey: key)
        
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    func get(forKey key: String) throws -> Data {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.readFailed(status: status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        return data
    }
    
    func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
    
    func clearAll() throws {
        let keys = [
            Configuration.Keychain.Keys.deviceId,
            Configuration.Keychain.Keys.encryptedDeviceShare,
            Configuration.Keychain.Keys.deviceShareNonce,
            Configuration.Keychain.Keys.passkeyKEK,
            Configuration.Keychain.Keys.passkeyCredentialId
        ]
        
        for key in keys {
            try? delete(forKey: key)
        }
    }
    
    // MARK: - Private Helpers
    
    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Mock Implementation

#if DEBUG
final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    
    private var storage: [String: Data] = [:]
    private var deviceId: String?
    
    var shouldFail = false
    
    func getOrCreateDeviceId() throws -> String {
        if shouldFail { throw KeychainError.readFailed(status: -1) }
        if let id = deviceId { return id }
        let newId = UUID().uuidString
        deviceId = newId
        return newId
    }
    
    func saveDeviceShare(encryptedShare: Data, nonce: Data) throws {
        if shouldFail { throw KeychainError.saveFailed(status: -1) }
        storage["encryptedDeviceShare"] = encryptedShare
        storage["deviceShareNonce"] = nonce
    }
    
    func getDeviceShare() throws -> (encryptedShare: Data, nonce: Data) {
        if shouldFail { throw KeychainError.readFailed(status: -1) }
        guard let share = storage["encryptedDeviceShare"],
              let nonce = storage["deviceShareNonce"] else {
            throw KeychainError.itemNotFound
        }
        return (share, nonce)
    }
    
    func hasDeviceShare() -> Bool {
        storage["encryptedDeviceShare"] != nil
    }
    
    func removeDeviceShare() throws {
        storage.removeValue(forKey: "encryptedDeviceShare")
        storage.removeValue(forKey: "deviceShareNonce")
    }
    
    func hasPasskeyKEK() -> Bool {
        storage[Configuration.Keychain.Keys.passkeyKEK] != nil
    }
    
    func getPasskeyCredentialId() throws -> String? {
        guard let data = storage[Configuration.Keychain.Keys.passkeyCredentialId] else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    func save(_ data: Data, forKey key: String) throws {
        if shouldFail { throw KeychainError.saveFailed(status: -1) }
        storage[key] = data
    }
    
    func get(forKey key: String) throws -> Data {
        if shouldFail { throw KeychainError.readFailed(status: -1) }
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }
    
    func clearAll() throws {
        storage.removeAll()
        deviceId = nil
    }
}
#endif
