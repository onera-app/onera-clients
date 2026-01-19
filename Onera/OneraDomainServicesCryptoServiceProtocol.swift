//
//  CryptoServiceProtocol.swift
//  Onera
//
//  Protocol for cryptographic operations
//

import Foundation

// MARK: - Crypto Service Protocol

protocol CryptoServiceProtocol: Sendable {
    
    // MARK: - Random Generation
    
    /// Generates cryptographically secure random bytes
    func generateRandomBytes(count: Int) throws -> Data
    
    /// Generates a 32-byte master key
    func generateMasterKey() throws -> Data
    
    /// Generates a 32-byte share
    func generateShare() throws -> Data
    
    // MARK: - XOR Operations
    
    /// XORs two Data objects of equal length
    func xor(_ a: Data, _ b: Data) throws -> Data
    
    /// Splits master key into 3 XOR shares
    func splitMasterKey(_ masterKey: Data) throws -> SplitShares
    
    /// Reconstructs master key from 3 shares
    func reconstructMasterKey(shares: SplitShares) throws -> Data
    
    // MARK: - Key Derivation
    
    /// Derives device share encryption key using BLAKE2b
    func deriveDeviceShareKey(
        deviceId: String,
        fingerprint: String,
        deviceSecret: Data
    ) throws -> Data
    
    /// Derives recovery key from BIP39 mnemonic
    func deriveRecoveryKey(fromMnemonic mnemonic: String) throws -> Data
    
    // MARK: - Symmetric Encryption (XSalsa20-Poly1305)
    
    /// Encrypts data using XSalsa20-Poly1305
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data)
    
    /// Decrypts data using XSalsa20-Poly1305
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data
    
    // MARK: - X25519 Key Pair
    
    /// Generates an X25519 key pair
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data)
    
    // MARK: - BIP39 Mnemonic
    
    /// Generates a 24-word BIP39 mnemonic
    func generateMnemonic() throws -> String
    
    /// Validates a BIP39 mnemonic
    func validateMnemonic(_ mnemonic: String) -> Bool
    
    // MARK: - Memory Security
    
    /// Securely zeros sensitive data
    func secureZero(_ data: inout Data)
}
