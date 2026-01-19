//
//  E2EEManager.swift
//  Onera
//
//  End-to-End Encryption key management and operations
//

import Foundation

/// Manages E2EE key lifecycle and encryption operations
@MainActor
@Observable
final class E2EEManager {
    static let shared = E2EEManager()
    
    // MARK: - State
    
    private(set) var isSetup = false
    private(set) var needsRecoveryPhrase = false
    private(set) var isLoading = false
    private(set) var error: CryptoError?
    
    private let crypto = CryptoManager.shared
    private let keychain = KeychainManager.shared
    private let api = APIClient.shared
    
    private init() {}
    
    // MARK: - Setup Check
    
    /// Checks if user has E2EE keys set up
    func checkSetup(token: String) async throws -> Bool {
        let response = try await api.checkKeyShares(token: token)
        isSetup = response.hasKeyShares
        return isSetup
    }
    
    // MARK: - New User Setup (Sign-Up Flow)
    
    /// Sets up E2EE for a new user
    /// Returns the recovery mnemonic that MUST be shown to the user
    func setupNewUser(token: String) async throws -> String {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // 1. Register device and get device secret
            let deviceId = try keychain.getOrCreateDeviceId()
            let fingerprint = try crypto.createDeviceFingerprint()
            
            let deviceResponse = try await api.registerDevice(
                request: DeviceRegisterRequest(
                    deviceId: deviceId,
                    deviceName: getDeviceName(),
                    platform: "iOS"
                ),
                token: token
            )
            
            let deviceSecret = Data(base64Encoded: deviceResponse.deviceSecret)!
            
            // 2. Generate keys
            var masterKey = try crypto.generateMasterKey()
            let keyPair = try crypto.generateX25519KeyPair()
            var recoveryKey = try crypto.generateRandomBytes(count: 32)
            
            // 3. Generate recovery mnemonic
            // TODO: Convert recoveryKey to BIP39 mnemonic
            let mnemonic = try crypto.generateRecoveryMnemonic()
            
            // For now, derive recovery key from mnemonic (in production, mnemonic IS the key source)
            recoveryKey = try crypto.deriveRecoveryKey(fromMnemonic: mnemonic)
            
            // 4. Split master key into 3 shares
            let shares = try crypto.splitMasterKey(masterKey)
            var deviceShare = shares.deviceShare
            let authShare = shares.authShare
            var recoveryShare = shares.recoveryShare
            
            // 5. Encrypt device share for keychain storage
            let deviceShareKey = try crypto.deriveDeviceShareKey(
                deviceId: deviceId,
                fingerprint: fingerprint,
                deviceSecret: deviceSecret
            )
            
            let (encryptedDeviceShare, deviceShareNonce) = try crypto.encrypt(
                plaintext: deviceShare,
                key: deviceShareKey
            )
            
            // 6. Encrypt recovery share with recovery key
            let (encryptedRecoveryShare, recoveryShareNonce) = try crypto.encrypt(
                plaintext: recoveryShare,
                key: recoveryKey
            )
            
            // 7. Encrypt private key with master key
            let (encryptedPrivateKey, privateKeyNonce) = try crypto.encrypt(
                plaintext: keyPair.privateKey,
                key: masterKey
            )
            
            // 8. Encrypt master key with recovery key (for mnemonic unlock)
            let (masterKeyRecovery, masterKeyRecoveryNonce) = try crypto.encrypt(
                plaintext: masterKey,
                key: recoveryKey
            )
            
            // 9. Encrypt recovery key with master key (for viewing phrase later)
            let (encryptedRecoveryKey, recoveryKeyNonce) = try crypto.encrypt(
                plaintext: recoveryKey,
                key: masterKey
            )
            
            // 10. Store device share in keychain
            try keychain.saveEncryptedDeviceShare(encryptedDeviceShare, nonce: deviceShareNonce)
            
            // 11. Store shares on server
            let createRequest = KeySharesCreateRequest(
                authShare: authShare.base64EncodedString(),
                encryptedRecoveryShare: encryptedRecoveryShare.base64EncodedString(),
                recoveryShareNonce: recoveryShareNonce.base64EncodedString(),
                publicKey: keyPair.publicKey.base64EncodedString(),
                encryptedPrivateKey: encryptedPrivateKey.base64EncodedString(),
                privateKeyNonce: privateKeyNonce.base64EncodedString(),
                masterKeyRecovery: masterKeyRecovery.base64EncodedString(),
                masterKeyRecoveryNonce: masterKeyRecoveryNonce.base64EncodedString(),
                encryptedRecoveryKey: encryptedRecoveryKey.base64EncodedString(),
                recoveryKeyNonce: recoveryKeyNonce.base64EncodedString()
            )
            
            _ = try await api.createKeyShares(request: createRequest, token: token)
            
            // 12. Unlock secure session
            await SecureSession.shared.unlock(
                masterKey: masterKey,
                privateKey: keyPair.privateKey,
                publicKey: keyPair.publicKey,
                recoveryKey: recoveryKey
            )
            
            // 13. Secure cleanup
            crypto.secureZero(&masterKey)
            crypto.secureZero(&deviceShare)
            crypto.secureZero(&recoveryShare)
            crypto.secureZero(&recoveryKey)
            
            isSetup = true
            
            return mnemonic
            
        } catch let cryptoError as CryptoError {
            self.error = cryptoError
            throw cryptoError
        } catch {
            self.error = .keyGenerationFailed
            throw CryptoError.keyGenerationFailed
        }
    }
    
    // MARK: - Returning User (Same Device)
    
    /// Unlocks E2EE for a returning user on the same device
    func unlockSameDevice(token: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        guard keychain.hasDeviceShare() else {
            needsRecoveryPhrase = true
            throw CryptoError.decryptionFailed
        }
        
        do {
            // 1. Get device ID and fingerprint
            let deviceId = try keychain.getOrCreateDeviceId()
            let fingerprint = try crypto.createDeviceFingerprint()
            
            // 2. Get device secret from server
            let secretResponse = try await api.getDeviceSecret(deviceId: deviceId, token: token)
            let deviceSecret = Data(base64Encoded: secretResponse.deviceSecret)!
            
            // 3. Derive device share encryption key
            let deviceShareKey = try crypto.deriveDeviceShareKey(
                deviceId: deviceId,
                fingerprint: fingerprint,
                deviceSecret: deviceSecret
            )
            
            // 4. Decrypt device share from keychain
            let (encryptedDeviceShare, deviceShareNonce) = try keychain.getEncryptedDeviceShare()
            var deviceShare = try crypto.decrypt(
                ciphertext: encryptedDeviceShare,
                nonce: deviceShareNonce,
                key: deviceShareKey
            )
            
            // 5. Get key shares from server
            let keyShares = try await api.getKeyShares(token: token)
            
            let authShare = Data(base64Encoded: keyShares.authShare)!
            let encryptedRecoveryShare = Data(base64Encoded: keyShares.encryptedRecoveryShare)!
            let recoveryShareNonce = Data(base64Encoded: keyShares.recoveryShareNonce)!
            
            // 6. We need recovery key to decrypt recovery share
            // Check if we have it cached, otherwise need mnemonic
            if let cachedRecoveryKey = await SecureSession.shared.recoveryKey {
                // Have cached recovery key
                var recoveryShare = try crypto.decrypt(
                    ciphertext: encryptedRecoveryShare,
                    nonce: recoveryShareNonce,
                    key: cachedRecoveryKey
                )
                
                // 7. Reconstruct master key
                var masterKey = try crypto.reconstructMasterKey(
                    deviceShare: deviceShare,
                    authShare: authShare,
                    recoveryShare: recoveryShare
                )
                
                // 8. Decrypt private key
                let encryptedPrivateKey = Data(base64Encoded: keyShares.encryptedPrivateKey)!
                let privateKeyNonce = Data(base64Encoded: keyShares.privateKeyNonce)!
                let privateKey = try crypto.decrypt(
                    ciphertext: encryptedPrivateKey,
                    nonce: privateKeyNonce,
                    key: masterKey
                )
                
                let publicKey = Data(base64Encoded: keyShares.publicKey)!
                
                // 9. Unlock session
                await SecureSession.shared.unlock(
                    masterKey: masterKey,
                    privateKey: privateKey,
                    publicKey: publicKey,
                    recoveryKey: cachedRecoveryKey
                )
                
                // Cleanup
                crypto.secureZero(&deviceShare)
                crypto.secureZero(&recoveryShare)
                crypto.secureZero(&masterKey)
                
            } else {
                // Need recovery phrase to continue
                needsRecoveryPhrase = true
                crypto.secureZero(&deviceShare)
                throw CryptoError.decryptionFailed
            }
            
        } catch let cryptoError as CryptoError {
            self.error = cryptoError
            throw cryptoError
        } catch {
            self.error = .decryptionFailed
            throw CryptoError.decryptionFailed
        }
    }
    
    // MARK: - Returning User (New Device / Recovery)
    
    /// Unlocks E2EE using recovery mnemonic
    func unlockWithRecoveryPhrase(mnemonic: String, token: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        guard crypto.validateMnemonic(mnemonic) else {
            self.error = .mnemonicValidationFailed
            throw CryptoError.mnemonicValidationFailed
        }
        
        do {
            // 1. Derive recovery key from mnemonic
            var recoveryKey = try crypto.deriveRecoveryKey(fromMnemonic: mnemonic)
            
            // 2. Get key shares from server
            let keyShares = try await api.getKeyShares(token: token)
            
            // 3. Decrypt master key using recovery key
            let masterKeyRecovery = Data(base64Encoded: keyShares.masterKeyRecovery)!
            let masterKeyRecoveryNonce = Data(base64Encoded: keyShares.masterKeyRecoveryNonce)!
            
            var masterKey = try crypto.decrypt(
                ciphertext: masterKeyRecovery,
                nonce: masterKeyRecoveryNonce,
                key: recoveryKey
            )
            
            // 4. Decrypt private key with master key
            let encryptedPrivateKey = Data(base64Encoded: keyShares.encryptedPrivateKey)!
            let privateKeyNonce = Data(base64Encoded: keyShares.privateKeyNonce)!
            let privateKey = try crypto.decrypt(
                ciphertext: encryptedPrivateKey,
                nonce: privateKeyNonce,
                key: masterKey
            )
            
            let publicKey = Data(base64Encoded: keyShares.publicKey)!
            
            // 5. If this is a new device, set up device share
            if !keychain.hasDeviceShare() {
                try await setupNewDeviceShare(
                    masterKey: masterKey,
                    authShare: Data(base64Encoded: keyShares.authShare)!,
                    token: token
                )
            }
            
            // 6. Unlock session
            await SecureSession.shared.unlock(
                masterKey: masterKey,
                privateKey: privateKey,
                publicKey: publicKey,
                recoveryKey: recoveryKey
            )
            
            needsRecoveryPhrase = false
            
            // Cleanup
            crypto.secureZero(&recoveryKey)
            crypto.secureZero(&masterKey)
            
        } catch let cryptoError as CryptoError {
            self.error = cryptoError
            throw cryptoError
        } catch {
            self.error = .decryptionFailed
            throw CryptoError.decryptionFailed
        }
    }
    
    /// Sets up device share for a new device during recovery
    private func setupNewDeviceShare(masterKey: Data, authShare: Data, token: String) async throws {
        // 1. Register new device
        let deviceId = try keychain.getOrCreateDeviceId()
        let fingerprint = try crypto.createDeviceFingerprint()
        
        let deviceResponse = try await api.registerDevice(
            request: DeviceRegisterRequest(
                deviceId: deviceId,
                deviceName: getDeviceName(),
                platform: "iOS"
            ),
            token: token
        )
        
        let deviceSecret = Data(base64Encoded: deviceResponse.deviceSecret)!
        
        // 2. Generate new device share
        // We need to compute: deviceShare = masterKey XOR authShare XOR recoveryShare
        // But we can also just generate a random new device share and update server
        // For simplicity, generate new splits
        
        let shares = try crypto.splitMasterKey(masterKey)
        
        // 3. Encrypt and store new device share
        let deviceShareKey = try crypto.deriveDeviceShareKey(
            deviceId: deviceId,
            fingerprint: fingerprint,
            deviceSecret: deviceSecret
        )
        
        let (encryptedDeviceShare, nonce) = try crypto.encrypt(
            plaintext: shares.deviceShare,
            key: deviceShareKey
        )
        
        try keychain.saveEncryptedDeviceShare(encryptedDeviceShare, nonce: nonce)
        
        // Note: In a full implementation, you'd also need to update the server with
        // the new authShare and encryptedRecoveryShare to match the new splits
    }
    
    // MARK: - View Recovery Phrase
    
    /// Decrypts and returns the recovery phrase (requires active session)
    func getRecoveryPhrase() async throws -> String {
        guard await SecureSession.shared.isUnlocked,
              let masterKey = await SecureSession.shared.masterKey else {
            throw CryptoError.decryptionFailed
        }
        
        let token = try await AuthenticationManager.shared.getToken()
        let keyShares = try await api.getKeyShares(token: token)
        
        // Decrypt recovery key using master key
        let encryptedRecoveryKey = Data(base64Encoded: keyShares.encryptedRecoveryKey)!
        let recoveryKeyNonce = Data(base64Encoded: keyShares.recoveryKeyNonce)!
        
        let recoveryKey = try crypto.decrypt(
            ciphertext: encryptedRecoveryKey,
            nonce: recoveryKeyNonce,
            key: masterKey
        )
        
        // TODO: Convert recovery key back to mnemonic
        // return BIP39.toMnemonic(entropy: recoveryKey)
        
        fatalError("Recovery key to mnemonic conversion not implemented")
    }
    
    // MARK: - Helpers
    
    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }
}
