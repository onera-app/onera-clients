//
//  CryptoManager.swift
//  Onera
//
//  E2EE cryptographic operations using libsodium
//
//  IMPORTANT: Add Sodium via SPM: https://github.com/jedisct1/swift-sodium
//

import Foundation
import CryptoKit
// import Sodium  // Uncomment after adding Sodium package

/// Manages all cryptographic operations for E2EE
/// Uses libsodium for compatibility with web client
final class CryptoManager {
    static let shared = CryptoManager()
    
    // private let sodium = Sodium()  // Uncomment after adding Sodium
    
    private init() {}
    
    // MARK: - Random Generation
    
    /// Generates cryptographically secure random bytes
    func generateRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        
        guard status == errSecSuccess else {
            throw CryptoError.keyGenerationFailed
        }
        
        return Data(bytes)
    }
    
    /// Generates a 32-byte master key
    func generateMasterKey() throws -> Data {
        try generateRandomBytes(count: Configuration.masterKeyLength)
    }
    
    /// Generates a 32-byte share
    func generateShare() throws -> Data {
        try generateRandomBytes(count: Configuration.masterKeyLength)
    }
    
    // MARK: - XOR Operations for Key Sharding
    
    /// XORs two Data objects of equal length
    func xor(_ a: Data, _ b: Data) throws -> Data {
        guard a.count == b.count else {
            throw CryptoError.shareXOROperationFailed
        }
        
        var result = [UInt8](repeating: 0, count: a.count)
        let aBytes = [UInt8](a)
        let bBytes = [UInt8](b)
        
        for i in 0..<a.count {
            result[i] = aBytes[i] ^ bBytes[i]
        }
        
        return Data(result)
    }
    
    /// Splits master key into 3 XOR shares
    /// masterKey = deviceShare XOR authShare XOR recoveryShare
    func splitMasterKey(_ masterKey: Data) throws -> (deviceShare: Data, authShare: Data, recoveryShare: Data) {
        guard masterKey.count == Configuration.masterKeyLength else {
            throw CryptoError.invalidKeyLength
        }
        
        let deviceShare = try generateShare()
        let authShare = try generateShare()
        
        // recoveryShare = masterKey XOR deviceShare XOR authShare
        let intermediate = try xor(masterKey, deviceShare)
        let recoveryShare = try xor(intermediate, authShare)
        
        return (deviceShare, authShare, recoveryShare)
    }
    
    /// Reconstructs master key from 3 shares
    func reconstructMasterKey(deviceShare: Data, authShare: Data, recoveryShare: Data) throws -> Data {
        guard deviceShare.count == Configuration.masterKeyLength,
              authShare.count == Configuration.masterKeyLength,
              recoveryShare.count == Configuration.masterKeyLength else {
            throw CryptoError.invalidKeyLength
        }
        
        // masterKey = deviceShare XOR authShare XOR recoveryShare
        let intermediate = try xor(deviceShare, authShare)
        let masterKey = try xor(intermediate, recoveryShare)
        
        return masterKey
    }
    
    // MARK: - Key Derivation
    
    /// Derives device share encryption key using BLAKE2b
    /// Key = BLAKE2b-256(deviceId + fingerprint + deviceSecret, context: "onera.deviceshare.v2")
    func deriveDeviceShareKey(deviceId: String, fingerprint: String, deviceSecret: Data) throws -> Data {
        // TODO: Replace with Sodium's crypto_generichash (BLAKE2b) after adding package
        // For now, using SHA256 as placeholder - MUST be replaced for production
        
        var inputData = Data()
        if let deviceIdData = deviceId.data(using: .utf8),
           let fingerprintData = fingerprint.data(using: .utf8),
           let contextData = Configuration.CryptoContext.deviceShareDerivation.data(using: .utf8) {
            inputData.append(deviceIdData)
            inputData.append(fingerprintData)
            inputData.append(deviceSecret)
            inputData.append(contextData)
        } else {
            throw CryptoError.keyDerivationFailed
        }
        
        // IMPORTANT: Replace with BLAKE2b for production
        // let key = sodium.genericHash.hash(message: [UInt8](inputData), outputLength: 32)
        
        let hash = SHA256.hash(data: inputData)
        return Data(hash)
    }
    
    /// Derives recovery key from BIP39 mnemonic
    func deriveRecoveryKey(fromMnemonic mnemonic: String) throws -> Data {
        // TODO: Use proper BIP39 library for mnemonic → entropy → key derivation
        // For now, using SHA256 of mnemonic words as placeholder
        
        guard let mnemonicData = mnemonic.data(using: .utf8) else {
            throw CryptoError.mnemonicValidationFailed
        }
        
        let hash = SHA256.hash(data: mnemonicData)
        return Data(hash)
    }
    
    // MARK: - Device Fingerprint
    
    /// Creates a device fingerprint for key derivation
    func createDeviceFingerprint() throws -> String {
        var components: [String] = []
        
        #if os(iOS)
        import UIKit
        let device = UIDevice.current
        components.append(device.model)
        components.append(device.systemName)
        components.append(device.systemVersion)
        if let identifierForVendor = device.identifierForVendor {
            components.append(identifierForVendor.uuidString)
        }
        #elseif os(macOS)
        import IOKit
        // Get hardware UUID on macOS
        if let uuid = getMacHardwareUUID() {
            components.append(uuid)
        }
        components.append(ProcessInfo.processInfo.operatingSystemVersionString)
        #endif
        
        guard !components.isEmpty else {
            throw CryptoError.deviceFingerprintFailed
        }
        
        return components.joined(separator: "|")
    }
    
    #if os(macOS)
    private func getMacHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0,
              let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
                platformExpert,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault,
                0
              )?.takeUnretainedValue() as? String else {
            return nil
        }
        
        return serialNumberAsCFString
    }
    #endif
    
    // MARK: - Symmetric Encryption (XSalsa20-Poly1305)
    
    /// Encrypts data using XSalsa20-Poly1305 (crypto_secretbox)
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data) {
        guard key.count == Configuration.masterKeyLength else {
            throw CryptoError.invalidKeyLength
        }
        
        // TODO: Replace with Sodium's secretbox after adding package
        // let nonce = sodium.secretBox.nonce()
        // guard let ciphertext = sodium.secretBox.seal(message: [UInt8](plaintext), secretKey: [UInt8](key), nonce: nonce) else {
        //     throw CryptoError.encryptionFailed
        // }
        // return (Data(ciphertext), Data(nonce))
        
        // Placeholder using CryptoKit's ChaChaPoly (similar but not identical)
        // MUST be replaced with libsodium for web client compatibility
        let nonce = try generateRandomBytes(count: 12) // ChaChaPoly uses 12-byte nonce
        let symmetricKey = SymmetricKey(data: key)
        
        do {
            let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey, nonce: ChaChaPoly.Nonce(data: nonce))
            return (sealedBox.ciphertext + sealedBox.tag, nonce)
        } catch {
            throw CryptoError.encryptionFailed
        }
    }
    
    /// Decrypts data using XSalsa20-Poly1305 (crypto_secretbox_open)
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data {
        guard key.count == Configuration.masterKeyLength else {
            throw CryptoError.invalidKeyLength
        }
        
        // TODO: Replace with Sodium's secretbox_open after adding package
        // guard let plaintext = sodium.secretBox.open(authenticatedCipherText: [UInt8](ciphertext), secretKey: [UInt8](key), nonce: [UInt8](nonce)) else {
        //     throw CryptoError.decryptionFailed
        // }
        // return Data(plaintext)
        
        // Placeholder using CryptoKit's ChaChaPoly
        let symmetricKey = SymmetricKey(data: key)
        
        do {
            // ChaChaPoly tag is last 16 bytes
            let tagSize = 16
            guard ciphertext.count >= tagSize else {
                throw CryptoError.decryptionFailed
            }
            
            let actualCiphertext = ciphertext.prefix(ciphertext.count - tagSize)
            let tag = ciphertext.suffix(tagSize)
            
            let sealedBox = try ChaChaPoly.SealedBox(
                nonce: ChaChaPoly.Nonce(data: nonce),
                ciphertext: actualCiphertext,
                tag: tag
            )
            
            return try ChaChaPoly.open(sealedBox, using: symmetricKey)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
    
    // MARK: - X25519 Key Pair Generation
    
    /// Generates an X25519 key pair for asymmetric encryption
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data) {
        // TODO: Replace with Sodium's box keypair for compatibility
        // let keyPair = sodium.box.keyPair()!
        // return (Data(keyPair.publicKey), Data(keyPair.secretKey))
        
        // Using CryptoKit's Curve25519
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return (publicKey.rawRepresentation, privateKey.rawRepresentation)
    }
    
    // MARK: - Memory Security
    
    /// Securely zeroes out sensitive data
    /// Call this when done with keys/secrets
    func secureZero(_ data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                memset_s(baseAddress, ptr.count, 0, ptr.count)
            }
        }
    }
}

// MARK: - BIP39 Mnemonic Support

extension CryptoManager {
    /// Generates a 24-word BIP39 mnemonic recovery phrase
    /// TODO: Implement using a proper BIP39 library (e.g., WalletCore or swift-bip39)
    func generateRecoveryMnemonic() throws -> String {
        // This is a placeholder - use a proper BIP39 library
        // The entropy should be 256 bits for 24 words
        
        let entropy = try generateRandomBytes(count: 32) // 256 bits
        
        // TODO: Convert entropy to mnemonic using BIP39 wordlist
        // return BIP39.generateMnemonic(entropy: entropy)
        
        // Placeholder: Return a fake mnemonic for development
        // MUST be replaced with actual BIP39 implementation
        fatalError("BIP39 mnemonic generation not yet implemented. Add a BIP39 library.")
    }
    
    /// Validates a BIP39 mnemonic phrase
    func validateMnemonic(_ mnemonic: String) -> Bool {
        let words = mnemonic.lowercased().split(separator: " ")
        
        // Check word count
        guard words.count == Configuration.mnemonicWordCount else {
            return false
        }
        
        // TODO: Validate against BIP39 wordlist and checksum
        // return BIP39.validateMnemonic(mnemonic)
        
        return true // Placeholder
    }
}
