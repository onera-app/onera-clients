//
//  PasskeyService.swift
//  Onera
//
//  Implementation of passkey (WebAuthn) operations using iOS AuthenticationServices
//
//  Security Model:
//  - iOS doesn't support WebAuthn PRF extension
//  - We generate a device-bound KEK (Key Encryption Key) stored in keychain with biometric protection
//  - The passkey authenticates the user, then keychain releases the KEK for master key decryption
//  - Server stores encrypted master key per credential (same as web)
//

import Foundation
import AuthenticationServices
import LocalAuthentication
import Security

final class PasskeyService: NSObject, PasskeyServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let keychainService: KeychainServiceProtocol
    
    // MARK: - State
    
    private var authorizationContinuation: CheckedContinuation<ASAuthorization, Error>?
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.keychainService = keychainService
        super.init()
    }
    
    // MARK: - Support Check
    
    func isPasskeySupported() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // Also check for device passcode as fallback
        let hasPasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        
        return canEvaluate || hasPasscode
    }
    
    // MARK: - Registration
    
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String {
        guard isPasskeySupported() else {
            throw PasskeyError.notSupported
        }
        
        // Step 1: Get registration options from server
        let optionsResponse: WebAuthnRegistrationOptionsResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.generateRegistrationOptions,
            input: WebAuthnRegistrationOptionsRequest(name: name),
            token: token
        )
        
        // Step 2: Create passkey credential using AuthenticationServices
        let credential = try await createPlatformCredential(options: optionsResponse.options)
        
        guard let registrationCredential = credential.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyError.registrationFailed("Invalid credential type")
        }
        
        // Step 3: Generate device-bound KEK for encrypting master key
        // This replaces the WebAuthn PRF extension used on web
        let kek = try generateKEK()
        
        // Step 4: Encrypt master key with KEK
        let (encryptedMasterKey, nonce) = try cryptoService.encrypt(plaintext: masterKey, key: kek)
        
        // Step 5: Build registration response for server
        let credentialId = registrationCredential.credentialID.base64EncodedString()
        let clientDataJSON = registrationCredential.rawClientDataJSON.base64EncodedString()
        let attestationObject = registrationCredential.rawAttestationObject?.base64EncodedString() ?? ""
        
        let registrationResponse = WebAuthnRegistrationResponse(
            id: credentialId,
            rawId: credentialId,
            type: "public-key",
            response: WebAuthnAttestationResponse(
                clientDataJSON: clientDataJSON,
                attestationObject: attestationObject
            ),
            clientExtensionResults: WebAuthnClientExtensionResults(
                prf: WebAuthnPRFExtensionResult(enabled: true) // Simulate PRF enabled for server compatibility
            )
        )
        
        // Step 6: Verify registration with server
        let verifyRequest = WebAuthnVerifyRegistrationRequest(
            response: registrationResponse,
            prfSalt: optionsResponse.prfSalt,
            encryptedMasterKey: encryptedMasterKey.base64EncodedString(),
            masterKeyNonce: nonce.base64EncodedString(),
            name: name
        )
        
        let _: WebAuthnVerifyRegistrationResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.verifyRegistration,
            input: verifyRequest,
            token: token
        )
        
        // Step 7: Save KEK to keychain with biometric protection
        try saveKEKToKeychain(kek, credentialId: credentialId)
        
        // Secure cleanup
        var mutableKEK = kek
        cryptoService.secureZero(&mutableKEK)
        
        return credentialId
    }
    
    // MARK: - Authentication
    
    func authenticateWithPasskey(token: String) async throws -> Data {
        guard isPasskeySupported() else {
            throw PasskeyError.notSupported
        }
        
        // Step 1: Get authentication options from server (mutation/POST, not query/GET)
        let optionsResponse: WebAuthnAuthOptionsResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.generateAuthenticationOptions,
            input: EmptyInput(),
            token: token
        )
        
        // Step 2: Authenticate with passkey
        let credential = try await authenticateWithPlatformCredential(options: optionsResponse.options)
        
        guard let assertionCredential = credential.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.authenticationFailed("Invalid credential type")
        }
        
        // Step 3: Retrieve KEK from keychain (requires biometric)
        let kek = try getKEKFromKeychain()
        
        // Step 4: Build authentication response for server
        let credentialId = assertionCredential.credentialID.base64EncodedString()
        let clientDataJSON = assertionCredential.rawClientDataJSON.base64EncodedString()
        let authenticatorData = assertionCredential.rawAuthenticatorData.base64EncodedString()
        let signature = assertionCredential.signature.base64EncodedString()
        let userHandle = assertionCredential.userID?.base64EncodedString()
        
        let authResponse = WebAuthnAuthenticationResponse(
            id: credentialId,
            rawId: credentialId,
            type: "public-key",
            response: WebAuthnAssertionResponse(
                clientDataJSON: clientDataJSON,
                authenticatorData: authenticatorData,
                signature: signature,
                userHandle: userHandle
            ),
            clientExtensionResults: [:]
        )
        
        // Step 5: Verify authentication with server and get encrypted master key
        let verifyRequest = WebAuthnVerifyAuthRequest(response: authResponse)
        let verifyResponse: WebAuthnVerifyAuthResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.verifyAuthentication,
            input: verifyRequest,
            token: token
        )
        
        // Step 6: Decrypt master key with KEK
        guard let encryptedMasterKey = Data(base64Encoded: verifyResponse.encryptedMasterKey),
              let masterKeyNonce = Data(base64Encoded: verifyResponse.masterKeyNonce) else {
            throw PasskeyError.invalidResponse
        }
        
        let masterKey = try cryptoService.decrypt(
            ciphertext: encryptedMasterKey,
            nonce: masterKeyNonce,
            key: kek
        )
        
        // Secure cleanup
        var mutableKEK = kek
        cryptoService.secureZero(&mutableKEK)
        
        return masterKey
    }
    
    // MARK: - Passkey Management
    
    func hasPasskeys(token: String) async throws -> Bool {
        let response: WebAuthnHasPasskeysResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.hasPasskeys,
            token: token
        )
        return response.hasPasskeys
    }
    
    func hasLocalPasskeyKEK() -> Bool {
        do {
            _ = try keychainService.get(forKey: Configuration.Keychain.Keys.passkeyKEK)
            return true
        } catch {
            return false
        }
    }
    
    func removeLocalPasskeyKEK() throws {
        try keychainService.delete(forKey: Configuration.Keychain.Keys.passkeyKEK)
        try? keychainService.delete(forKey: Configuration.Keychain.Keys.passkeyCredentialId)
    }
    
    // MARK: - Private Methods - Credential Creation
    
    @MainActor
    private func createPlatformCredential(options: WebAuthnCreationOptions) async throws -> ASAuthorization {
        let rpId = Configuration.WebAuthn.rpID
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        // Convert challenge from base64url to Data
        let challengeData = try base64URLDecode(options.challenge)
        
        // Convert user ID to Data
        let userIdData = try base64URLDecode(options.user.id)
        
        let request = provider.createCredentialRegistrationRequest(
            challenge: challengeData,
            name: options.user.name,
            userID: userIdData
        )
        
        return try await performAuthorization(requests: [request])
    }
    
    @MainActor
    private func authenticateWithPlatformCredential(options: WebAuthnRequestOptions) async throws -> ASAuthorization {
        let rpId = Configuration.WebAuthn.rpID
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        // Convert challenge from base64url to Data
        let challengeData = try base64URLDecode(options.challenge)
        
        // Build allowed credentials list if provided
        let allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor]
        if let allowCreds = options.allowCredentials {
            allowedCredentials = try allowCreds.map { cred in
                let credentialId = try base64URLDecode(cred.id)
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialId)
            }
        } else {
            allowedCredentials = []
        }
        
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        if !allowedCredentials.isEmpty {
            request.allowedCredentials = allowedCredentials
        }
        
        return try await performAuthorization(requests: [request])
    }
    
    @MainActor
    private func performAuthorization(requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            
            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    // MARK: - Private Methods - KEK Management
    
    private func generateKEK() throws -> Data {
        // Generate 32-byte random KEK
        return try cryptoService.generateRandomBytes(count: Configuration.Security.masterKeyLength)
    }
    
    private func saveKEKToKeychain(_ kek: Data, credentialId: String) throws {
        // Build query with biometric access control
        let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            nil
        )
        
        // Delete existing KEK first
        try? keychainService.delete(forKey: Configuration.Keychain.Keys.passkeyKEK)
        try? keychainService.delete(forKey: Configuration.Keychain.Keys.passkeyCredentialId)
        
        // Save KEK with biometric protection
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Configuration.Keychain.serviceName,
            kSecAttrAccount as String: Configuration.Keychain.Keys.passkeyKEK,
            kSecValueData as String: kek
        ]
        
        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PasskeyError.kekGenerationFailed
        }
        
        // Save credential ID for reference
        if let credentialIdData = credentialId.data(using: .utf8) {
            try keychainService.save(credentialIdData, forKey: Configuration.Keychain.Keys.passkeyCredentialId)
        }
    }
    
    private func getKEKFromKeychain() throws -> Data {
        let context = LAContext()
        context.localizedReason = "Unlock your encrypted data"
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Configuration.Keychain.serviceName,
            kSecAttrAccount as String: Configuration.Keychain.Keys.passkeyKEK,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let kekData = result as? Data else {
                throw PasskeyError.kekRetrievalFailed
            }
            return kekData
            
        case errSecItemNotFound:
            throw PasskeyError.kekNotFound
            
        case errSecUserCanceled, errSecAuthFailed:
            throw PasskeyError.cancelled
            
        default:
            throw PasskeyError.kekRetrievalFailed
        }
    }
    
    // MARK: - Private Methods - Base64URL
    
    private func base64URLDecode(_ string: String) throws -> Data {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)
        
        guard let data = Data(base64Encoded: base64) else {
            throw PasskeyError.invalidResponse
        }
        
        return data
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeyService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        authorizationContinuation?.resume(returning: authorization)
        authorizationContinuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authError = error as NSError
        
        if authError.domain == ASAuthorizationError.errorDomain {
            switch authError.code {
            case ASAuthorizationError.canceled.rawValue:
                authorizationContinuation?.resume(throwing: PasskeyError.cancelled)
            case ASAuthorizationError.failed.rawValue:
                authorizationContinuation?.resume(throwing: PasskeyError.authenticationFailed(error.localizedDescription))
            case ASAuthorizationError.notHandled.rawValue:
                authorizationContinuation?.resume(throwing: PasskeyError.authenticationFailed("Request not handled"))
            case ASAuthorizationError.invalidResponse.rawValue:
                authorizationContinuation?.resume(throwing: PasskeyError.invalidResponse)
            default:
                authorizationContinuation?.resume(throwing: PasskeyError.authenticationFailed(error.localizedDescription))
            }
        } else {
            authorizationContinuation?.resume(throwing: PasskeyError.authenticationFailed(error.localizedDescription))
        }
        
        authorizationContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window from active scene
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback: return first window
            return UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first }
                .first ?? UIWindow()
        }
        return window
    }
}

// MARK: - Empty Input for Mutations

/// Empty input struct for mutations that don't require input but use POST method
private struct EmptyInput: Encodable {}

// MARK: - Mock Implementation

#if DEBUG
final class MockPasskeyService: PasskeyServiceProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var isSupported = true
    var hasPasskey = false
    var hasLocalKEK = false
    var mockMasterKey = Data(repeating: 0xAB, count: 32)
    
    func isPasskeySupported() -> Bool {
        isSupported
    }
    
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String {
        if shouldFail { throw PasskeyError.registrationFailed("Mock error") }
        hasPasskey = true
        hasLocalKEK = true
        return "mock-credential-id"
    }
    
    func authenticateWithPasskey(token: String) async throws -> Data {
        if shouldFail { throw PasskeyError.authenticationFailed("Mock error") }
        if !hasPasskey { throw PasskeyError.kekNotFound }
        return mockMasterKey
    }
    
    func hasPasskeys(token: String) async throws -> Bool {
        if shouldFail { throw PasskeyError.serverError("Mock error") }
        return hasPasskey
    }
    
    func hasLocalPasskeyKEK() -> Bool {
        hasLocalKEK
    }
    
    func removeLocalPasskeyKEK() throws {
        hasLocalKEK = false
    }
}
#endif
