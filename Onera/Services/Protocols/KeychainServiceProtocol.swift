//
//  KeychainServiceProtocol.swift
//  Onera
//
//  Protocol for secure keychain operations
//

import Foundation

// MARK: - Keychain Service Protocol

protocol KeychainServiceProtocol: Sendable {
    
    // MARK: - Device ID
    
    /// Gets existing device ID or creates a new one
    func getOrCreateDeviceId() throws -> String
    
    // MARK: - Device Share
    
    /// Saves encrypted device share to keychain
    func saveDeviceShare(encryptedShare: Data, nonce: Data) throws
    
    /// Retrieves encrypted device share and nonce
    func getDeviceShare() throws -> (encryptedShare: Data, nonce: Data)
    
    /// Checks if device share exists
    func hasDeviceShare() -> Bool
    
    /// Removes device share
    func removeDeviceShare() throws
    
    // MARK: - Generic Operations
    
    /// Saves data to keychain
    func save(_ data: Data, forKey key: String) throws
    
    /// Retrieves data from keychain
    func get(forKey key: String) throws -> Data
    
    /// Deletes item from keychain
    func delete(forKey key: String) throws
    
    /// Clears all app keychain items
    func clearAll() throws
}
