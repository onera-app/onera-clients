//
//  CryptoService.swift
//  Onera
//
//  Implementation of cryptographic operations
//
//  IMPORTANT: Add Sodium SPM package: https://github.com/jedisct1/swift-sodium
//

import Foundation
import CryptoKit
// import Sodium  // Uncomment after adding package

final class CryptoService: CryptoServiceProtocol, @unchecked Sendable {
    
    // private let sodium = Sodium()  // Uncomment after adding package
    
    // MARK: - Random Generation
    
    func generateRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        
        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed
        }
        
        return Data(bytes)
    }
    
    func generateMasterKey() throws -> Data {
        try generateRandomBytes(count: Configuration.Security.masterKeyLength)
    }
    
    func generateShare() throws -> Data {
        try generateRandomBytes(count: Configuration.Security.masterKeyLength)
    }
    
    // MARK: - XOR Operations
    
    func xor(_ a: Data, _ b: Data) throws -> Data {
        guard a.count == b.count else {
            throw CryptoError.xorOperationFailed
        }
        
        var result = [UInt8](repeating: 0, count: a.count)
        let aBytes = [UInt8](a)
        let bBytes = [UInt8](b)
        
        for i in 0..<a.count {
            result[i] = aBytes[i] ^ bBytes[i]
        }
        
        return Data(result)
    }
    
    func splitMasterKey(_ masterKey: Data) throws -> SplitShares {
        guard masterKey.count == Configuration.Security.masterKeyLength else {
            throw CryptoError.invalidKeyLength(
                expected: Configuration.Security.masterKeyLength,
                actual: masterKey.count
            )
        }
        
        let deviceShare = try generateShare()
        let authShare = try generateShare()
        
        // recoveryShare = masterKey XOR deviceShare XOR authShare
        let intermediate = try xor(masterKey, deviceShare)
        let recoveryShare = try xor(intermediate, authShare)
        
        return SplitShares(
            deviceShare: deviceShare,
            authShare: authShare,
            recoveryShare: recoveryShare
        )
    }
    
    func reconstructMasterKey(shares: SplitShares) throws -> Data {
        let keyLength = Configuration.Security.masterKeyLength
        
        guard shares.deviceShare.count == keyLength,
              shares.authShare.count == keyLength,
              shares.recoveryShare.count == keyLength else {
            throw CryptoError.invalidKeyLength(expected: keyLength, actual: 0)
        }
        
        // masterKey = deviceShare XOR authShare XOR recoveryShare
        let intermediate = try xor(shares.deviceShare, shares.authShare)
        return try xor(intermediate, shares.recoveryShare)
    }
    
    // MARK: - Key Derivation
    
    func deriveDeviceShareKey(
        deviceId: String,
        fingerprint: String,
        deviceSecret: Data
    ) throws -> Data {
        // TODO: Replace with Sodium's crypto_generichash (BLAKE2b)
        // For production compatibility with web client
        
        /*
        let input = [UInt8](deviceId.utf8) + [UInt8](fingerprint.utf8) + [UInt8](deviceSecret)
        let context = Configuration.CryptoContext.deviceShareDerivation
        
        guard let hash = sodium.genericHash.hash(
            message: input,
            key: [UInt8](context.utf8),
            outputLength: 32
        ) else {
            throw CryptoError.keyDerivationFailed
        }
        return Data(hash)
        */
        
        // Temporary: Using HKDF with SHA256
        guard let deviceIdData = deviceId.data(using: .utf8),
              let fingerprintData = fingerprint.data(using: .utf8),
              let contextData = Configuration.CryptoContext.deviceShareDerivation.data(using: .utf8) else {
            throw CryptoError.keyDerivationFailed
        }
        
        var inputData = Data()
        inputData.append(deviceIdData)
        inputData.append(fingerprintData)
        inputData.append(deviceSecret)
        
        let inputKey = SymmetricKey(data: inputData)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: contextData,
            outputByteCount: Configuration.Security.masterKeyLength
        )
        
        return derivedKey.withUnsafeBytes { Data($0) }
    }
    
    func deriveRecoveryKey(fromMnemonic mnemonic: String) throws -> Data {
        // TODO: Use proper BIP39 library for mnemonic → entropy → key
        // The mnemonic should be converted to entropy, then to seed
        
        /*
        guard let entropy = BIP39.mnemonicToEntropy(mnemonic) else {
            throw CryptoError.mnemonicValidationFailed
        }
        return Data(entropy)
        */
        
        // Temporary: Hash the mnemonic
        guard let mnemonicData = mnemonic.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8) else {
            throw CryptoError.mnemonicValidationFailed
        }
        
        let hash = SHA256.hash(data: mnemonicData)
        return Data(hash)
    }
    
    // MARK: - Symmetric Encryption
    
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data) {
        guard key.count == Configuration.Security.masterKeyLength else {
            throw CryptoError.invalidKeyLength(
                expected: Configuration.Security.masterKeyLength,
                actual: key.count
            )
        }
        
        // TODO: Replace with Sodium's secretbox (XSalsa20-Poly1305)
        /*
        guard let nonce = sodium.secretBox.nonce(),
              let ciphertext = sodium.secretBox.seal(
                message: [UInt8](plaintext),
                secretKey: [UInt8](key),
                nonce: nonce
              ) else {
            throw CryptoError.encryptionFailed
        }
        return (Data(ciphertext), Data(nonce))
        */
        
        // Using CryptoKit's ChaChaPoly (12-byte nonce)
        let nonce = try generateRandomBytes(count: 12)
        let symmetricKey = SymmetricKey(data: key)
        
        do {
            let nonceValue = try ChaChaPoly.Nonce(data: nonce)
            let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey, nonce: nonceValue)
            // Combine ciphertext and tag
            var combined = Data(sealedBox.ciphertext)
            combined.append(contentsOf: sealedBox.tag)
            return (combined, nonce)
        } catch {
            throw CryptoError.encryptionFailed
        }
    }
    
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data {
        guard key.count == Configuration.Security.masterKeyLength else {
            throw CryptoError.invalidKeyLength(
                expected: Configuration.Security.masterKeyLength,
                actual: key.count
            )
        }
        
        // TODO: Replace with Sodium's secretbox_open
        /*
        guard let plaintext = sodium.secretBox.open(
            authenticatedCipherText: [UInt8](ciphertext),
            secretKey: [UInt8](key),
            nonce: [UInt8](nonce)
        ) else {
            throw CryptoError.decryptionFailed
        }
        return Data(plaintext)
        */
        
        let symmetricKey = SymmetricKey(data: key)
        let tagSize = 16
        
        guard ciphertext.count >= tagSize else {
            throw CryptoError.decryptionFailed
        }
        
        let actualCiphertext = ciphertext.prefix(ciphertext.count - tagSize)
        let tag = ciphertext.suffix(tagSize)
        
        do {
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
    
    // MARK: - X25519 Key Pair
    
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data) {
        // TODO: Replace with Sodium's box keypair for web compatibility
        /*
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keypairGenerationFailed
        }
        return (Data(keyPair.publicKey), Data(keyPair.secretKey))
        */
        
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return (privateKey.publicKey.rawRepresentation, privateKey.rawRepresentation)
    }
    
    // MARK: - BIP39 Mnemonic
    
    func generateMnemonic() throws -> String {
        // TODO: Use proper BIP39 library
        /*
        let entropy = try generateRandomBytes(count: Configuration.Mnemonic.entropyBytes)
        guard let mnemonic = BIP39.entropyToMnemonic([UInt8](entropy)) else {
            throw CryptoError.mnemonicGenerationFailed
        }
        return mnemonic
        */
        
        // Placeholder - MUST be replaced
        throw CryptoError.mnemonicGenerationFailed
    }
    
    func validateMnemonic(_ mnemonic: String) -> Bool {
        let words = mnemonic.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
        
        guard words.count == Configuration.Mnemonic.wordCount else {
            return false
        }
        
        // TODO: Validate against BIP39 wordlist and checksum
        // return BIP39.validateMnemonic(mnemonic)
        
        return true
    }
    
    // MARK: - Memory Security
    
    func secureZero(_ data: inout Data) {
        data.secureZero()
    }
}

// MARK: - Mock Implementation

#if DEBUG
final class MockCryptoService: CryptoServiceProtocol, @unchecked Sendable {
    
    var shouldFail = false
    
    func generateRandomBytes(count: Int) throws -> Data {
        if shouldFail { throw CryptoError.randomGenerationFailed }
        return Data(repeating: 0xAB, count: count)
    }
    
    func generateMasterKey() throws -> Data {
        try generateRandomBytes(count: 32)
    }
    
    func generateShare() throws -> Data {
        try generateRandomBytes(count: 32)
    }
    
    func xor(_ a: Data, _ b: Data) throws -> Data {
        guard a.count == b.count else { throw CryptoError.xorOperationFailed }
        return Data(zip(a, b).map { $0 ^ $1 })
    }
    
    func splitMasterKey(_ masterKey: Data) throws -> SplitShares {
        SplitShares(
            deviceShare: try generateShare(),
            authShare: try generateShare(),
            recoveryShare: try generateShare()
        )
    }
    
    func reconstructMasterKey(shares: SplitShares) throws -> Data {
        try generateMasterKey()
    }
    
    func deriveDeviceShareKey(deviceId: String, fingerprint: String, deviceSecret: Data) throws -> Data {
        try generateRandomBytes(count: 32)
    }
    
    func deriveRecoveryKey(fromMnemonic mnemonic: String) throws -> Data {
        try generateRandomBytes(count: 32)
    }
    
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data) {
        (plaintext, Data(repeating: 0, count: 12))
    }
    
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data {
        ciphertext
    }
    
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data) {
        (try generateRandomBytes(count: 32), try generateRandomBytes(count: 32))
    }
    
    func generateMnemonic() throws -> String {
        "abandon " + String(repeating: "word ", count: 22) + "about"
    }
    
    func validateMnemonic(_ mnemonic: String) -> Bool {
        true
    }
    
    func secureZero(_ data: inout Data) {
        data = Data()
    }
}
#endif
