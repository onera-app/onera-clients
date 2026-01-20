//
//  CryptoService.swift
//  Onera
//
//  Implementation of cryptographic operations using libsodium
//  for full compatibility with the web client
//

import Foundation
import Sodium
import BIP39

final class CryptoService: ExtendedCryptoServiceProtocol, @unchecked Sendable {
    
    private let sodium = Sodium()
    
    // MARK: - Random Generation
    
    func generateRandomBytes(count: Int) throws -> Data {
        guard let bytes = sodium.randomBytes.buf(length: count) else {
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
    
    // MARK: - Key Derivation (BLAKE2b + KDF - matching web)
    
    /// Derives an encryption key using BLAKE2b + crypto_kdf (matching web's shareManager.ts)
    /// This is the core key derivation function used for device share encryption
    private func deriveShareEncryptionKey(
        identifier: String,
        context: String,
        salt: Data? = nil
    ) throws -> Data {
        let identifierBytes = [UInt8](identifier.utf8)
        
        // Use 8-byte context for KDF (padded or truncated as needed) - matches web
        let paddedContext = context.padding(toLength: 8, withPad: "\0", startingAt: 0)
        let kdfContext = String(paddedContext.prefix(8))
        
        // Derive master key material from identifier (and optional salt) using BLAKE2b
        let inputBytes: [UInt8]
        if let salt = salt {
            inputBytes = [UInt8](salt) + identifierBytes
        } else {
            inputBytes = identifierBytes
        }
        
        guard let masterKeyMaterial = sodium.genericHash.hash(
            message: inputBytes,
            outputLength: Configuration.Security.masterKeyLength
        ) else {
            throw CryptoError.keyDerivationFailed
        }
        
        // Use crypto_kdf to derive the final key with context separation
        guard let derivedKey = sodium.keyDerivation.derive(
            secretKey: masterKeyMaterial,
            index: 1,
            length: Configuration.Security.masterKeyLength,
            context: kdfContext
        ) else {
            throw CryptoError.keyDerivationFailed
        }
        
        return Data(derivedKey)
    }
    
    func deriveDeviceShareKey(
        deviceId: String,
        fingerprint: String,
        deviceSecret: Data
    ) throws -> Data {
        // Combine all entropy sources (matching web's deriveDeviceShareKey)
        var components = [deviceId]
        if !fingerprint.isEmpty {
            components.append(fingerprint)
        }
        
        // Convert deviceSecret to base64 string and add to components
        let deviceSecretString = deviceSecret.base64EncodedString()
        components.append(deviceSecretString)
        
        let identifier = components.joined(separator: ":")
        return try deriveShareEncryptionKey(
            identifier: identifier,
            context: Configuration.CryptoContext.deviceShareDerivation
        )
    }
    
    func deriveRecoveryKey(fromMnemonic mnemonic: String) throws -> Data {
        // Use BIP39 to convert mnemonic to entropy (matching web's recoveryKey.ts)
        let words = mnemonic
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        do {
            // Use the static toEntropy method to convert mnemonic words back to entropy
            let entropy = try Mnemonic.toEntropy(words)
            // The web uses the raw entropy bytes as the recovery key
            // For 24 words, entropy is 32 bytes (256 bits)
            return Data(entropy)
        } catch {
            throw CryptoError.mnemonicValidationFailed
        }
    }
    
    // MARK: - Password-Based Key Derivation (Argon2id - matching web)
    
    /// Derives a Key Encryption Key (KEK) from a password using Argon2id
    /// Matches web's derivePasswordKEK in passwordDerivation.ts
    func derivePasswordKEK(
        password: String,
        salt: Data,
        opsLimit: Int,
        memLimit: Int
    ) throws -> Data {
        let saltBytes = [UInt8](salt)
        
        // Derive KEK using Argon2id (matching web's crypto_pwhash)
        guard let kek = sodium.pwHash.hash(
            outputLength: Configuration.Security.masterKeyLength,
            passwd: password.bytes,
            salt: saltBytes,
            opsLimit: opsLimit,
            memLimit: memLimit
        ) else {
            throw CryptoError.passwordDerivationFailed
        }
        
        return Data(kek)
    }
    
    /// Encrypts master key with a password-derived KEK
    /// Matches web's encryptMasterKeyWithPassword in passwordDerivation.ts
    func encryptMasterKeyWithPassword(
        masterKey: Data,
        password: String
    ) throws -> PasswordEncryptedMasterKey {
        // Generate random salt (16 bytes, matching web)
        let salt = try generateRandomBytes(count: Configuration.Security.passwordSaltLength)
        
        // Use MODERATE params matching web's getDefaultArgon2idParams()
        let opsLimit = sodium.pwHash.OpsLimitModerate
        let memLimit = sodium.pwHash.MemLimitModerate
        
        // Derive KEK from password
        let kek = try derivePasswordKEK(
            password: password,
            salt: salt,
            opsLimit: opsLimit,
            memLimit: memLimit
        )
        
        // Encrypt master key with KEK using XSalsa20-Poly1305
        let (ciphertext, nonce) = try encrypt(plaintext: masterKey, key: kek)
        
        return PasswordEncryptedMasterKey(
            ciphertext: ciphertext.base64EncodedString(),
            nonce: nonce.base64EncodedString(),
            salt: salt.base64EncodedString(),
            opsLimit: opsLimit,
            memLimit: memLimit
        )
    }
    
    /// Decrypts master key with a password-derived KEK
    /// Matches web's decryptMasterKeyWithPassword in passwordDerivation.ts
    func decryptMasterKeyWithPassword(
        encrypted: PasswordEncryptedMasterKey,
        password: String
    ) throws -> Data {
        // Decode base64 values
        guard let salt = Data(base64Encoded: encrypted.salt),
              let ciphertext = Data(base64Encoded: encrypted.ciphertext),
              let nonce = Data(base64Encoded: encrypted.nonce) else {
            throw CryptoError.decryptionFailed
        }
        
        // Derive KEK from password using stored parameters
        let kek = try derivePasswordKEK(
            password: password,
            salt: salt,
            opsLimit: encrypted.opsLimit,
            memLimit: encrypted.memLimit
        )
        
        // Decrypt master key
        do {
            return try decrypt(ciphertext: ciphertext, nonce: nonce, key: kek)
        } catch {
            throw CryptoError.incorrectPassword
        }
    }
    
    // MARK: - Symmetric Encryption (XSalsa20-Poly1305 - matching web)
    
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data) {
        guard key.count == Configuration.Security.masterKeyLength else {
            throw CryptoError.invalidKeyLength(
                expected: Configuration.Security.masterKeyLength,
                actual: key.count
            )
        }
        
        // Generate nonce (24 bytes for XSalsa20-Poly1305)
        let nonce = sodium.secretBox.nonce()
        
        // Encrypt using XSalsa20-Poly1305 (matching web's secretBox)
        guard let ciphertext = sodium.secretBox.seal(
            message: [UInt8](plaintext),
            secretKey: [UInt8](key),
            nonce: nonce
        ) else {
            throw CryptoError.encryptionFailed
        }
        
        return (Data(ciphertext), Data(nonce))
    }
    
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data {
        guard key.count == Configuration.Security.masterKeyLength else {
            throw CryptoError.invalidKeyLength(
                expected: Configuration.Security.masterKeyLength,
                actual: key.count
            )
        }
        
        guard nonce.count == Configuration.Security.nonceLength else {
            throw CryptoError.decryptionFailed
        }
        
        // Decrypt using XSalsa20-Poly1305 (matching web's secretBox.open)
        guard let plaintext = sodium.secretBox.open(
            authenticatedCipherText: [UInt8](ciphertext),
            secretKey: [UInt8](key),
            nonce: [UInt8](nonce)
        ) else {
            throw CryptoError.decryptionFailed
        }
        
        return Data(plaintext)
    }
    
    // MARK: - String Encryption (for encrypting titles, etc.)
    
    func encryptString(_ string: String, key: Data) throws -> (ciphertext: String, nonce: String) {
        guard let data = string.data(using: .utf8) else {
            throw CryptoError.encryptionFailed
        }
        
        let (ciphertext, nonce) = try encrypt(plaintext: data, key: key)
        return (ciphertext.base64EncodedString(), nonce.base64EncodedString())
    }
    
    func decryptString(ciphertext: String, nonce: String, key: Data) throws -> String {
        guard let ciphertextData = Data(base64Encoded: ciphertext),
              let nonceData = Data(base64Encoded: nonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let plaintext = try decrypt(ciphertext: ciphertextData, nonce: nonceData, key: key)
        
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw CryptoError.decryptionFailed
        }
        
        return string
    }
    
    // MARK: - JSON Encryption (for encrypting chat messages, credentials, etc.)
    
    func encryptJSON<T: Encodable>(_ value: T, key: Data) throws -> (ciphertext: String, nonce: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(value)
        let (ciphertext, nonce) = try encrypt(plaintext: data, key: key)
        return (ciphertext.base64EncodedString(), nonce.base64EncodedString())
    }
    
    func decryptJSON<T: Decodable>(ciphertext: String, nonce: String, key: Data) throws -> T {
        guard let ciphertextData = Data(base64Encoded: ciphertext),
              let nonceData = Data(base64Encoded: nonce) else {
            throw CryptoError.decryptionFailed
        }
        
        let plaintext = try decrypt(ciphertext: ciphertextData, nonce: nonceData, key: key)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: plaintext)
    }
    
    // MARK: - X25519 Key Pair
    
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data) {
        guard let keyPair = sodium.box.keyPair() else {
            throw CryptoError.keypairGenerationFailed
        }
        return (Data(keyPair.publicKey), Data(keyPair.secretKey))
    }
    
    // MARK: - BIP39 Mnemonic
    
    func generateMnemonic() throws -> String {
        // Generate 32 bytes (256 bits) of entropy for 24 words
        let entropy = try generateRandomBytes(count: Configuration.Mnemonic.entropyBytes)
        
        // Convert entropy to mnemonic using BIP39
        do {
            // Use static toMnemonic to convert entropy bytes to words
            let words = try Mnemonic.toMnemonic([UInt8](entropy))
            return words.joined(separator: " ")
        } catch {
            throw CryptoError.mnemonicGenerationFailed
        }
    }
    
    func validateMnemonic(_ mnemonic: String) -> Bool {
        let words = mnemonic
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        guard words.count == Configuration.Mnemonic.wordCount else {
            return false
        }
        
        // Validate using BIP39 library's static isValid method (checks wordlist and checksum)
        return Mnemonic.isValid(phrase: words)
    }
    
    // MARK: - Memory Security
    
    func secureZero(_ data: inout Data) {
        data.resetBytes(in: 0..<data.count)
    }
    
    // MARK: - Constant-Time Comparison
    
    func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        return sodium.utils.equals([UInt8](a), [UInt8](b))
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
    
    func derivePasswordKEK(password: String, salt: Data, opsLimit: Int, memLimit: Int) throws -> Data {
        try generateRandomBytes(count: 32)
    }
    
    func encryptMasterKeyWithPassword(masterKey: Data, password: String) throws -> PasswordEncryptedMasterKey {
        PasswordEncryptedMasterKey(
            ciphertext: masterKey.base64EncodedString(),
            nonce: Data(repeating: 0, count: 24).base64EncodedString(),
            salt: Data(repeating: 0, count: 16).base64EncodedString(),
            opsLimit: 3,
            memLimit: 268435456
        )
    }
    
    func decryptMasterKeyWithPassword(encrypted: PasswordEncryptedMasterKey, password: String) throws -> Data {
        guard let data = Data(base64Encoded: encrypted.ciphertext) else {
            throw CryptoError.decryptionFailed
        }
        return data
    }
    
    func encrypt(plaintext: Data, key: Data) throws -> (ciphertext: Data, nonce: Data) {
        (plaintext, Data(repeating: 0, count: 24))
    }
    
    func decrypt(ciphertext: Data, nonce: Data, key: Data) throws -> Data {
        ciphertext
    }
    
    func generateX25519KeyPair() throws -> (publicKey: Data, privateKey: Data) {
        (try generateRandomBytes(count: 32), try generateRandomBytes(count: 32))
    }
    
    func generateMnemonic() throws -> String {
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
    }
    
    func validateMnemonic(_ mnemonic: String) -> Bool {
        true
    }
    
    func secureZero(_ data: inout Data) {
        data = Data()
    }
}
#endif
