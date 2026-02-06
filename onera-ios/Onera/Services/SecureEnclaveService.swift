//
//  SecureEnclaveService.swift
//  Onera
//
//  Implementation of Secure Enclave operations using CryptoKit and Security framework
//  with hardware-backed keys when available, software fallback otherwise
//

import Foundation
import Security
import CryptoKit
import os.log

/// Implementation of Secure Enclave operations with hardware-backed key generation
/// when available, falling back to software Keychain for unsupported devices.
final class SecureEnclaveService: SecureEnclaveServiceProtocol, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "chat.onera", category: "SecureEnclave")
    
    // MARK: - Hardware Support Detection
    
    /// Indicates whether the current device supports hardware-backed keys
    var isHardwareBacked: Bool {
        // Check if Secure Enclave is available by attempting to create an access control
        guard let _ = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        ) else {
            return false
        }
        
        // Additional check: Try to query for Secure Enclave availability
        // This is more reliable than just checking access control creation
        return isSecureEnclaveAvailable()
    }
    
    // MARK: - Key Generation
    
    /// Generates a cryptographic key pair using the most secure method available
    func generateKeyPair() throws -> (publicKey: Data, privateKey: SecKey) {
        if isHardwareBacked {
            logger.info("Generating P-256 key pair in Secure Enclave")
            return try generateSecureEnclaveKeyPair()
        } else {
            logger.warning("Secure Enclave not available, falling back to software X25519 keys")
            return try generateSoftwareKeyPair()
        }
    }
    
    // MARK: - Signing
    
    /// Signs data using a private key
    func sign(data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        
        // Use ECDSA with SHA-256 for P-256 keys, or appropriate algorithm for X25519
        let algorithm: SecKeyAlgorithm = isHardwareBacked ? 
            .ecdsaSignatureMessageX962SHA256 : 
            .ecdsaSignatureMessageX962SHA256
        
        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            data as CFData,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Signing failed: \(String(describing: error))")
            }
            throw SecureEnclaveError.signingFailed
        }
        
        return signature as Data
    }
    
    // MARK: - Key Agreement
    
    /// Performs Elliptic Curve Diffie-Hellman key agreement
    func performKeyAgreement(privateKey: SecKey, publicKey: Data) throws -> Data {
        // Convert public key data to SecKey
        let remotePublicKey = try createPublicKey(from: publicKey)
        
        var error: Unmanaged<CFError>?
        
        // Perform ECDH key agreement
        guard let sharedSecret = SecKeyCopyKeyExchangeResult(
            privateKey,
            .ecdhKeyExchangeStandard,
            remotePublicKey,
            [:] as CFDictionary,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Key agreement failed: \(String(describing: error))")
            }
            throw SecureEnclaveError.keyAgreementFailed
        }
        
        return sharedSecret as Data
    }
    
    // MARK: - Private Implementation
    
    /// Checks if Secure Enclave is available on the current device
    private func isSecureEnclaveAvailable() -> Bool {
        // Try to create a temporary key in Secure Enclave to test availability
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false,
                kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    .privateKeyUsage,
                    nil
                ) as Any
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let _ = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return false
        }
        
        return true
    }
    
    /// Generates a P-256 key pair in Secure Enclave
    private func generateSecureEnclaveKeyPair() throws -> (publicKey: Data, privateKey: SecKey) {
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        ) else {
            throw SecureEnclaveError.keyGenerationFailed
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256, // P-256
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false, // Don't store permanently
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Secure Enclave key generation failed: \(String(describing: error))")
            }
            throw SecureEnclaveError.keyGenerationFailed
        }
        
        // Extract public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.keyGenerationFailed
        }
        
        // Convert public key to data
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Failed to extract public key data: \(String(describing: error))")
            }
            throw SecureEnclaveError.keyGenerationFailed
        }
        
        return (publicKeyData as Data, privateKey)
    }
    
    /// Generates an X25519 key pair in software Keychain as fallback
    private func generateSoftwareKeyPair() throws -> (publicKey: Data, privateKey: SecKey) {
        // Generate X25519 key pair using CryptoKit
        let privateKeyData = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyData = privateKeyData.publicKey
        
        // Convert CryptoKit private key to SecKey for consistent interface
        let privateKey = try createPrivateKey(from: privateKeyData.rawRepresentation)
        
        return (publicKeyData.rawRepresentation, privateKey)
    }
    
    /// Creates a SecKey from private key data
    private func createPrivateKey(from data: Data) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: data.count * 8,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(
            data as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Failed to create private key: \(String(describing: error))")
            }
            throw SecureEnclaveError.invalidPrivateKey
        }
        
        return privateKey
    }
    
    /// Creates a SecKey from public key data
    private func createPublicKey(from data: Data) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: data.count * 8,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(
            data as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                logger.error("Failed to create public key: \(String(describing: error))")
            }
            throw SecureEnclaveError.invalidPublicKey
        }
        
        return publicKey
    }
}

// MARK: - Mock Implementation

#if DEBUG
final class MockSecureEnclaveService: SecureEnclaveServiceProtocol, @unchecked Sendable {
    
    var isHardwareBacked: Bool = true
    var shouldFail = false
    
    func generateKeyPair() throws -> (publicKey: Data, privateKey: SecKey) {
        if shouldFail {
            throw SecureEnclaveError.keyGenerationFailed
        }
        
        // Generate a mock key pair using CryptoKit for testing
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        // Create a mock SecKey (this won't work for actual crypto operations in tests)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        
        let mockSecKey = SecKeyCreateWithData(
            privateKey.rawRepresentation as CFData,
            attributes as CFDictionary,
            nil
        )!
        
        return (publicKey.rawRepresentation, mockSecKey)
    }
    
    func sign(data: Data, with privateKey: SecKey) throws -> Data {
        if shouldFail {
            throw SecureEnclaveError.signingFailed
        }
        // Return mock signature
        return Data(repeating: 0xAB, count: 64)
    }
    
    func performKeyAgreement(privateKey: SecKey, publicKey: Data) throws -> Data {
        if shouldFail {
            throw SecureEnclaveError.keyAgreementFailed
        }
        // Return mock shared secret
        return Data(repeating: 0xCD, count: 32)
    }
}
#endif