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
    
    // MARK: - Setup Status
    
    func checkSetupStatus(token: String) async throws -> Bool {
        let response: KeySharesCheckResponse = try await networkService.call(
            procedure: APIEndpoint.KeyShares.check,
            token: token
        )
        return response.hasKeyShares
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
        
        // 2. Get device secret from server
        let secretResponse: DeviceSecretResponse = try await networkService.call(
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

struct KeySharesCheckResponse: Decodable, Sendable {
    let hasKeyShares: Bool
}

struct KeySharesGetResponse: Decodable, Sendable {
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

struct KeySharesCreateRequest: Encodable, Sendable {
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

struct KeySharesCreateResponse: Decodable, Sendable {
    let success: Bool
}

struct DeviceRegisterRequest: Encodable, Sendable {
    let deviceId: String
    let deviceName: String
    let platform: String
}

struct DeviceRegisterResponse: Decodable, Sendable {
    let deviceSecret: String
}

struct DeviceSecretRequest: Encodable, Sendable {
    let deviceId: String
}

struct DeviceSecretResponse: Decodable, Sendable {
    let deviceSecret: String
}

// MARK: - Mock Implementation

#if DEBUG
final class MockE2EEService: E2EEServiceProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var hasKeys = false
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
    
    func getRecoveryPhrase(token: String) async throws -> String {
        if shouldFail { throw E2EEError.sessionLocked }
        return mockMnemonic
    }
}
#endif
