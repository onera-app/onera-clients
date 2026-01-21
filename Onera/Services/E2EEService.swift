//
//  E2EEService.swift
//  Onera
//
//  E2EE key management implementation
//

import Foundation

final class E2EEService: E2EEServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let cryptoService: CryptoServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let secureSession: SecureSessionProtocol
    private lazy var passkeyService: PasskeyServiceProtocol = PasskeyService(
        networkService: networkService,
        cryptoService: cryptoService,
        keychainService: keychainService
    )
    
    // MARK: - Initialization
    
    init(
        cryptoService: CryptoServiceProtocol,
        keychainService: KeychainServiceProtocol,
        networkService: NetworkServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.cryptoService = cryptoService
        self.keychainService = keychainService
        self.networkService = networkService
        self.secureSession = secureSession
    }
    
    /// For testing: allows injecting a mock passkey service
    func setPasskeyService(_ service: PasskeyServiceProtocol) {
        // This would require making passkeyService non-lazy and var
        // For production, the lazy initialization is fine
    }
    
    // MARK: - Setup Status
    
    func checkSetupStatus(token: String) async throws -> Bool {
        // Query (GET) to check if user has key shares
        let response: KeySharesCheckResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.check,
            token: token
        )
        return response.hasShares
    }
    
    // MARK: - New User Setup
    
    func setupNewUser(token: String) async throws -> String {
        // 1. Get device info and register
        let deviceInfo = try DeviceInfo.current()
        
        let deviceResponse: DeviceRegisterResponse = try await networkService.call(
            procedure: APIEndpoint.Devices.register,
            input: DeviceRegisterRequest(
                deviceId: deviceInfo.deviceId,
                deviceName: deviceInfo.deviceName,
                platform: deviceInfo.platform
            ),
            token: token
        )
        
        guard let deviceSecret = Data(base64Encoded: deviceResponse.deviceSecret) else {
            throw E2EEError.deviceRegistrationFailed
        }
        
        // 2. Generate cryptographic material
        var masterKey = try cryptoService.generateMasterKey()
        let keyPair = try cryptoService.generateX25519KeyPair()
        let mnemonic = try cryptoService.generateMnemonic()
        var recoveryKey = try cryptoService.deriveRecoveryKey(fromMnemonic: mnemonic)
        
        // 3. Split master key into shares
        let shares = try cryptoService.splitMasterKey(masterKey)
        
        // 4. Encrypt device share for keychain
        let deviceShareKey = try cryptoService.deriveDeviceShareKey(
            deviceId: deviceInfo.deviceId,
            fingerprint: deviceInfo.fingerprint,
            deviceSecret: deviceSecret
        )
        
        let (encryptedDeviceShare, deviceShareNonce) = try cryptoService.encrypt(
            plaintext: shares.deviceShare,
            key: deviceShareKey
        )
        
        // 5. Encrypt other shares for server
        let (encryptedRecoveryShare, recoveryShareNonce) = try cryptoService.encrypt(
            plaintext: shares.recoveryShare,
            key: recoveryKey
        )
        
        let (encryptedPrivateKey, privateKeyNonce) = try cryptoService.encrypt(
            plaintext: keyPair.privateKey,
            key: masterKey
        )
        
        let (masterKeyRecovery, masterKeyRecoveryNonce) = try cryptoService.encrypt(
            plaintext: masterKey,
            key: recoveryKey
        )
        
        let (encryptedRecoveryKey, recoveryKeyNonce) = try cryptoService.encrypt(
            plaintext: recoveryKey,
            key: masterKey
        )
        
        // 6. Save device share to keychain
        try keychainService.saveDeviceShare(
            encryptedShare: encryptedDeviceShare,
            nonce: deviceShareNonce
        )
        
        // 7. Save shares to server
        let createRequest = KeySharesCreateRequest(
            authShare: shares.authShare.base64EncodedString(),
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
        
        let _: KeySharesCreateResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.create,
            input: createRequest,
            token: token
        )
        
        // 8. Unlock secure session
        await MainActor.run {
            secureSession.unlock(
                masterKey: masterKey,
                privateKey: keyPair.privateKey,
                publicKey: keyPair.publicKey,
                recoveryKey: recoveryKey
            )
        }
        
        // 9. Cleanup sensitive data
        var deviceShare = shares.deviceShare
        var authShare = shares.authShare
        var recoveryShare = shares.recoveryShare
        
        cryptoService.secureZero(&masterKey)
        cryptoService.secureZero(&recoveryKey)
        cryptoService.secureZero(&deviceShare)
        cryptoService.secureZero(&authShare)
        cryptoService.secureZero(&recoveryShare)
        
        return mnemonic
    }
    
    // MARK: - Unlock (Same Device)
    
    func unlockWithDeviceShare(token: String) async throws {
        guard keychainService.hasDeviceShare() else {
            throw E2EEError.deviceShareNotFound
        }
        
        // 1. Get device info
        let deviceInfo = try DeviceInfo.current()
        
        // 2. Get device secret from server (query with input)
        let secretResponse: DeviceSecretResponse = try await networkService.query(
            procedure: APIEndpoint.Devices.getSecret,
            input: DeviceSecretRequest(deviceId: deviceInfo.deviceId),
            token: token
        )
        
        guard let deviceSecret = Data(base64Encoded: secretResponse.deviceSecret) else {
            throw E2EEError.deviceRegistrationFailed
        }
        
        // 3. Derive device share encryption key
        let deviceShareKey = try cryptoService.deriveDeviceShareKey(
            deviceId: deviceInfo.deviceId,
            fingerprint: deviceInfo.fingerprint,
            deviceSecret: deviceSecret
        )
        
        // 4. Decrypt device share
        let (encryptedDeviceShare, deviceShareNonce) = try keychainService.getDeviceShare()
        var deviceShare = try cryptoService.decrypt(
            ciphertext: encryptedDeviceShare,
            nonce: deviceShareNonce,
            key: deviceShareKey
        )
        
        // 5. Get key shares from server
        let keyShares: KeySharesGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.get,
            token: token
        )
        
        // For same-device unlock, we need cached recovery key or need recovery phrase
        // This path assumes we have the recovery key cached
        throw E2EEError.recoveryRequired
    }
    
    // MARK: - Unlock (Recovery)
    
    func unlockWithRecoveryPhrase(mnemonic: String, token: String) async throws {
        guard cryptoService.validateMnemonic(mnemonic) else {
            throw CryptoError.mnemonicValidationFailed
        }
        
        // 1. Derive recovery key
        var recoveryKey = try cryptoService.deriveRecoveryKey(fromMnemonic: mnemonic)
        
        // 2. Get key shares from server
        let keyShares: KeySharesGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.get,
            token: token
        )
        
        // 3. Decrypt master key using recovery key
        guard let masterKeyRecovery = Data(base64Encoded: keyShares.masterKeyRecovery),
              let masterKeyRecoveryNonce = Data(base64Encoded: keyShares.masterKeyRecoveryNonce) else {
            throw E2EEError.keySharesFetchFailed
        }
        
        var masterKey = try cryptoService.decrypt(
            ciphertext: masterKeyRecovery,
            nonce: masterKeyRecoveryNonce,
            key: recoveryKey
        )
        
        // 4. Decrypt private key
        guard let encryptedPrivateKey = Data(base64Encoded: keyShares.encryptedPrivateKey),
              let privateKeyNonce = Data(base64Encoded: keyShares.privateKeyNonce),
              let publicKey = Data(base64Encoded: keyShares.publicKey) else {
            throw E2EEError.keySharesFetchFailed
        }
        
        let privateKey = try cryptoService.decrypt(
            ciphertext: encryptedPrivateKey,
            nonce: privateKeyNonce,
            key: masterKey
        )
        
        // 5. Set up new device share if needed
        if !keychainService.hasDeviceShare() {
            try await setupNewDeviceShare(masterKey: masterKey, token: token)
        }
        
        // 6. Unlock session
        await MainActor.run {
            secureSession.unlock(
                masterKey: masterKey,
                privateKey: privateKey,
                publicKey: publicKey,
                recoveryKey: recoveryKey
            )
        }
        
        // 7. Cleanup
        cryptoService.secureZero(&masterKey)
        cryptoService.secureZero(&recoveryKey)
    }
    
    // MARK: - Password-Based Unlock
    
    func hasPasswordEncryption(token: String) async throws -> Bool {
        let response: PasswordEncryptionCheckResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.hasPasswordEncryption,
            token: token
        )
        return response.hasPassword
    }
    
    func setupPasswordEncryption(password: String, token: String) async throws {
        // Get master key from session
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        // Encrypt master key with password
        let encrypted = try cryptoService.encryptMasterKeyWithPassword(
            masterKey: masterKey,
            password: password
        )
        
        // Store encrypted master key on server
        let request = PasswordEncryptionSetRequest(
            encryptedMasterKey: encrypted.ciphertext,
            nonce: encrypted.nonce,
            salt: encrypted.salt,
            opsLimit: encrypted.opsLimit,
            memLimit: encrypted.memLimit
        )
        
        let _: PasswordEncryptionSetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.setPasswordEncryption,
            input: request,
            token: token
        )
    }
    
    func unlockWithPassword(password: String, token: String) async throws {
        // 1. Fetch encrypted master key from server
        let encryptedData: PasswordEncryptionGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.getPasswordEncryption,
            token: token
        )
        
        // 2. Reconstruct encrypted data structure
        let encrypted = PasswordEncryptedMasterKey(
            ciphertext: encryptedData.encryptedMasterKey,
            nonce: encryptedData.nonce,
            salt: encryptedData.salt,
            opsLimit: encryptedData.opsLimit,
            memLimit: encryptedData.memLimit
        )
        
        // 3. Decrypt master key with password
        var masterKey = try cryptoService.decryptMasterKeyWithPassword(
            encrypted: encrypted,
            password: password
        )
        
        // 4. Get key shares from server to get public/private keys
        let keyShares: KeySharesGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.get,
            token: token
        )
        
        // 5. Decrypt private key with master key
        guard let encryptedPrivateKey = Data(base64Encoded: keyShares.encryptedPrivateKey),
              let privateKeyNonce = Data(base64Encoded: keyShares.privateKeyNonce),
              let publicKey = Data(base64Encoded: keyShares.publicKey) else {
            throw E2EEError.keySharesFetchFailed
        }
        
        let privateKey = try cryptoService.decrypt(
            ciphertext: encryptedPrivateKey,
            nonce: privateKeyNonce,
            key: masterKey
        )
        
        // 6. Set up new device share if needed
        if !keychainService.hasDeviceShare() {
            try await setupNewDeviceShare(masterKey: masterKey, token: token)
        }
        
        // 7. Unlock session
        await MainActor.run {
            secureSession.unlock(
                masterKey: masterKey,
                privateKey: privateKey,
                publicKey: publicKey,
                recoveryKey: nil
            )
        }
        
        // 8. Update device last seen
        let deviceInfo = try DeviceInfo.current()
        try? await networkService.call(
            procedure: APIEndpoint.Devices.updateLastSeen,
            input: DeviceUpdateLastSeenRequest(deviceId: deviceInfo.deviceId),
            token: token
        ) as DeviceUpdateLastSeenResponse
        
        // 9. Cleanup
        cryptoService.secureZero(&masterKey)
    }
    
    func removePasswordEncryption(token: String) async throws {
        guard await secureSession.isUnlocked else {
            throw E2EEError.sessionLocked
        }
        
        let _: PasswordEncryptionRemoveResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.removePasswordEncryption,
            token: token
        )
    }
    
    // MARK: - Passkey-Based Unlock
    
    func isPasskeySupported() -> Bool {
        return passkeyService.isPasskeySupported()
    }
    
    func hasPasskeys(token: String) async throws -> Bool {
        return try await passkeyService.hasPasskeys(token: token)
    }
    
    func hasLocalPasskey() -> Bool {
        return passkeyService.hasLocalPasskeyKEK()
    }
    
    func registerPasskey(name: String?, token: String) async throws {
        // Requires unlocked session to get master key
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        // Register passkey with master key encryption
        _ = try await passkeyService.registerPasskey(
            masterKey: masterKey,
            name: name,
            token: token
        )
    }
    
    func unlockWithPasskey(token: String) async throws {
        // 1. Authenticate with passkey and get decrypted master key
        var masterKey = try await passkeyService.authenticateWithPasskey(token: token)
        
        // 2. Get key shares from server to get public/private keys
        let keyShares: KeySharesGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.get,
            token: token
        )
        
        // 3. Decrypt private key with master key
        guard let encryptedPrivateKey = Data(base64Encoded: keyShares.encryptedPrivateKey),
              let privateKeyNonce = Data(base64Encoded: keyShares.privateKeyNonce),
              let publicKey = Data(base64Encoded: keyShares.publicKey) else {
            throw E2EEError.keySharesFetchFailed
        }
        
        let privateKey = try cryptoService.decrypt(
            ciphertext: encryptedPrivateKey,
            nonce: privateKeyNonce,
            key: masterKey
        )
        
        // 4. Set up new device share if needed
        if !keychainService.hasDeviceShare() {
            try await setupNewDeviceShare(masterKey: masterKey, token: token)
        }
        
        // 5. Unlock session
        await MainActor.run {
            secureSession.unlock(
                masterKey: masterKey,
                privateKey: privateKey,
                publicKey: publicKey,
                recoveryKey: nil
            )
        }
        
        // 6. Update device last seen
        let deviceInfo = try DeviceInfo.current()
        try? await networkService.call(
            procedure: APIEndpoint.Devices.updateLastSeen,
            input: DeviceUpdateLastSeenRequest(deviceId: deviceInfo.deviceId),
            token: token
        ) as DeviceUpdateLastSeenResponse
        
        // 7. Cleanup
        cryptoService.secureZero(&masterKey)
    }
    
    // MARK: - Recovery Phrase
    
    func getRecoveryPhrase(token: String) async throws -> String {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let keyShares: KeySharesGetResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.get,
            token: token
        )
        
        guard let encryptedRecoveryKey = Data(base64Encoded: keyShares.encryptedRecoveryKey),
              let recoveryKeyNonce = Data(base64Encoded: keyShares.recoveryKeyNonce) else {
            throw E2EEError.keySharesFetchFailed
        }
        
        let recoveryKey = try cryptoService.decrypt(
            ciphertext: encryptedRecoveryKey,
            nonce: recoveryKeyNonce,
            key: masterKey
        )
        
        // TODO: Convert recovery key back to mnemonic
        // return BIP39.entropyToMnemonic([UInt8](recoveryKey))
        
        throw CryptoError.mnemonicGenerationFailed
    }
    
    // MARK: - Private Helpers
    
    private func setupNewDeviceShare(masterKey: Data, token: String) async throws {
        let deviceInfo = try DeviceInfo.current()
        
        // Register device
        let deviceResponse: DeviceRegisterResponse = try await networkService.call(
            procedure: APIEndpoint.Devices.register,
            input: DeviceRegisterRequest(
                deviceId: deviceInfo.deviceId,
                deviceName: deviceInfo.deviceName,
                platform: deviceInfo.platform
            ),
            token: token
        )
        
        guard let deviceSecret = Data(base64Encoded: deviceResponse.deviceSecret) else {
            throw E2EEError.deviceRegistrationFailed
        }
        
        // Generate new shares (we'll update server with new auth share)
        let shares = try cryptoService.splitMasterKey(masterKey)
        
        // Encrypt device share
        let deviceShareKey = try cryptoService.deriveDeviceShareKey(
            deviceId: deviceInfo.deviceId,
            fingerprint: deviceInfo.fingerprint,
            deviceSecret: deviceSecret
        )
        
        let (encryptedDeviceShare, nonce) = try cryptoService.encrypt(
            plaintext: shares.deviceShare,
            key: deviceShareKey
        )
        
        // Save to keychain
        try keychainService.saveDeviceShare(encryptedShare: encryptedDeviceShare, nonce: nonce)
        
        // Note: Full implementation would also update server with new auth share
    }
}

// MARK: - API Request/Response Models

struct KeySharesCheckResponse: Codable {
    let hasShares: Bool
}

struct KeySharesGetResponse: Codable {
    let authShare: String
    let encryptedRecoveryShare: String
    let recoveryShareNonce: String
    let publicKey: String
    let encryptedPrivateKey: String
    let privateKeyNonce: String
    let masterKeyRecovery: String
    let masterKeyRecoveryNonce: String
    let encryptedRecoveryKey: String
    let recoveryKeyNonce: String
}

struct KeySharesCreateRequest: Codable {
    let authShare: String
    let encryptedRecoveryShare: String
    let recoveryShareNonce: String
    let publicKey: String
    let encryptedPrivateKey: String
    let privateKeyNonce: String
    let masterKeyRecovery: String
    let masterKeyRecoveryNonce: String
    let encryptedRecoveryKey: String
    let recoveryKeyNonce: String
}

struct KeySharesCreateResponse: Codable {
    let success: Bool
}

struct DeviceRegisterRequest: Codable {
    let deviceId: String
    let deviceName: String
    let platform: String
}

struct DeviceRegisterResponse: Codable {
    let deviceSecret: String
}

struct DeviceSecretRequest: Codable {
    let deviceId: String
}

struct DeviceSecretResponse: Codable {
    let deviceSecret: String
}

struct DeviceUpdateLastSeenRequest: Codable {
    let deviceId: String
}

struct DeviceUpdateLastSeenResponse: Codable {
    let success: Bool
}

// MARK: - Password Encryption API Models

struct PasswordEncryptionCheckResponse: Codable {
    let hasPassword: Bool
}

struct PasswordEncryptionGetResponse: Codable {
    let encryptedMasterKey: String
    let nonce: String
    let salt: String
    let opsLimit: Int
    let memLimit: Int
}

struct PasswordEncryptionSetRequest: Codable {
    let encryptedMasterKey: String
    let nonce: String
    let salt: String
    let opsLimit: Int
    let memLimit: Int
}

struct PasswordEncryptionSetResponse: Codable {
    let success: Bool
}

struct PasswordEncryptionRemoveResponse: Codable {
    let success: Bool
}

// MARK: - Mock Implementation

#if DEBUG
final class MockE2EEService: E2EEServiceProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var hasKeys = false
    var hasPassword = false
    var hasPasskey = false
    var passkeySupported = true
    var mockMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    
    func checkSetupStatus(token: String) async throws -> Bool {
        if shouldFail { throw E2EEError.keySharesFetchFailed }
        return hasKeys
    }
    
    func setupNewUser(token: String) async throws -> String {
        if shouldFail { throw E2EEError.setupFailed(underlying: CryptoError.randomGenerationFailed) }
        hasKeys = true
        return mockMnemonic
    }
    
    func unlockWithDeviceShare(token: String) async throws {
        if shouldFail { throw E2EEError.unlockFailed }
    }
    
    func unlockWithRecoveryPhrase(mnemonic: String, token: String) async throws {
        if shouldFail { throw E2EEError.unlockFailed }
    }
    
    func hasPasswordEncryption(token: String) async throws -> Bool {
        if shouldFail { throw E2EEError.keySharesFetchFailed }
        return hasPassword
    }
    
    func setupPasswordEncryption(password: String, token: String) async throws {
        if shouldFail { throw E2EEError.passwordSetupFailed }
        hasPassword = true
    }
    
    func unlockWithPassword(password: String, token: String) async throws {
        if shouldFail { throw E2EEError.unlockFailed }
    }
    
    func removePasswordEncryption(token: String) async throws {
        if shouldFail { throw E2EEError.sessionLocked }
        hasPassword = false
    }
    
    func isPasskeySupported() -> Bool {
        passkeySupported
    }
    
    func hasPasskeys(token: String) async throws -> Bool {
        if shouldFail { throw E2EEError.keySharesFetchFailed }
        return hasPasskey
    }
    
    func hasLocalPasskey() -> Bool {
        hasPasskey
    }
    
    func registerPasskey(name: String?, token: String) async throws {
        if shouldFail { throw E2EEError.passkeyRegistrationFailed }
        hasPasskey = true
    }
    
    func unlockWithPasskey(token: String) async throws {
        if shouldFail { throw E2EEError.unlockFailed }
        if !hasPasskey { throw E2EEError.passkeyNotFound }
    }
    
    func getRecoveryPhrase(token: String) async throws -> String {
        if shouldFail { throw E2EEError.sessionLocked }
        return mockMnemonic
    }
}
#endif
