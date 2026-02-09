//
//  PasskeyService.swift
//  Onera
//
//  Implementation of passkey (WebAuthn) operations using iOS AuthenticationServices
//
//  Security Model (PRF-based, cross-platform compatible):
//  - Uses WebAuthn PRF extension (iOS 17+) for cross-platform key derivation
//  - PRF output + salt → HKDF → KEK (Key Encryption Key)
//  - KEK encrypts/decrypts the master key
//  - Same passkey works on iOS, macOS, and web
//
//  Flow:
//  1. Registration: User creates passkey → PRF output → encrypt master key → store on server
//  2. Authentication: User signs with passkey → PRF output → decrypt master key → unlock
//

import Foundation
import AuthenticationServices
import LocalAuthentication
import CryptoKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - HKDF Constants (must match web implementation)

private let HKDF_INFO = "onera-webauthn-prf-kek-v1"
private let KEK_BYTES = 32

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
        // PRF requires iOS 18+
        guard #available(iOS 18.0, macOS 15.0, *) else {
            return false
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // Also check for device passcode as fallback
        let hasPasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        
        return canEvaluate || hasPasscode
    }
    
    // MARK: - Registration
    
    @available(iOS 18.0, macOS 15.0, *)
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String {
        guard isPasskeySupported() else {
            throw PasskeyError.notSupported
        }
        
        // Step 1: Get registration options from server (includes prfSalt)
        let optionsResponse: WebAuthnRegistrationOptionsResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.generateRegistrationOptions,
            input: WebAuthnRegistrationOptionsRequest(name: name),
            token: token
        )
        
        print("[PasskeyService] Registration options received, prfSalt: \(optionsResponse.prfSalt.prefix(20))...")
        
        // Step 2: Create passkey credential with PRF extension
        let (credential, prfOutput) = try await createPlatformCredentialWithPRF(
            options: optionsResponse.options,
            prfSalt: optionsResponse.prfSalt
        )
        
        guard let registrationCredential = credential.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyError.registrationFailed("Invalid credential type")
        }
        
        // Step 3: Derive KEK from PRF output using HKDF (matches web implementation)
        let kek = try derivePRFKEK(prfOutput: prfOutput, salt: optionsResponse.prfSalt)
        print("[PasskeyService] KEK derived from PRF output")
        
        // Step 4: Encrypt master key with PRF-derived KEK
        let (encryptedMasterKey, nonce) = try cryptoService.encrypt(plaintext: masterKey, key: kek)
        
        // Step 5: Build registration response for server (using base64url encoding per WebAuthn spec)
        let credentialId = base64URLEncode(registrationCredential.credentialID)
        let clientDataJSON = base64URLEncode(registrationCredential.rawClientDataJSON)
        let attestationObject = registrationCredential.rawAttestationObject.map { base64URLEncode($0) } ?? ""
        
        let registrationResponse = WebAuthnRegistrationResponse(
            id: credentialId,
            rawId: credentialId,
            type: "public-key",
            response: WebAuthnAttestationResponse(
                clientDataJSON: clientDataJSON,
                attestationObject: attestationObject
            ),
            clientExtensionResults: WebAuthnClientExtensionResults(
                prf: WebAuthnPRFExtensionResult(enabled: true)
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
        
        print("[PasskeyService] Registration verified with server")
        
        // Secure cleanup
        var mutableKEK = kek
        cryptoService.secureZero(&mutableKEK)
        
        return credentialId
    }
    
    // MARK: - Authentication
    
    @available(iOS 18.0, macOS 15.0, *)
    func authenticateWithPasskey(token: String) async throws -> Data {
        guard isPasskeySupported() else {
            throw PasskeyError.notSupported
        }
        
        // Step 1: Get authentication options from server (includes prfSalts per credential)
        let optionsResponse: WebAuthnAuthOptionsResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.generateAuthenticationOptions,
            input: EmptyInput(),
            token: token
        )
        
        print("[PasskeyService] Auth options received, prfSalts count: \(optionsResponse.prfSalts?.count ?? 0)")
        
        // Step 2: Authenticate with passkey and get PRF output
        let (credential, prfOutput, _) = try await authenticateWithPlatformCredentialAndPRF(
            options: optionsResponse.options,
            prfSalts: optionsResponse.prfSalts ?? [:]
        )
        
        guard let assertionCredential = credential.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.authenticationFailed("Invalid credential type")
        }
        
        // Step 3: Build authentication response for server (using base64url encoding per WebAuthn spec)
        let credentialId = base64URLEncode(assertionCredential.credentialID)
        let clientDataJSON = base64URLEncode(assertionCredential.rawClientDataJSON)
        let authenticatorData = base64URLEncode(assertionCredential.rawAuthenticatorData)
        let signature = base64URLEncode(assertionCredential.signature)
        let userHandle = assertionCredential.userID.map { base64URLEncode($0) }
        
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
        
        // Step 4: Verify authentication with server and get encrypted master key
        let verifyRequest = WebAuthnVerifyAuthRequest(response: authResponse)
        let verifyResponse: WebAuthnVerifyAuthResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.verifyAuthentication,
            input: verifyRequest,
            token: token
        )
        
        print("[PasskeyService] Auth verified, decrypting master key...")
        
        // Step 5: Derive KEK from PRF output using the credential's salt
        guard let prfSalt = verifyResponse.prfSalt else {
            throw PasskeyError.invalidResponse
        }
        
        let kek = try derivePRFKEK(prfOutput: prfOutput, salt: prfSalt)
        
        // Step 6: Decrypt master key with PRF-derived KEK
        guard let encryptedMasterKey = Data(base64Encoded: verifyResponse.encryptedMasterKey),
              let masterKeyNonce = Data(base64Encoded: verifyResponse.masterKeyNonce) else {
            throw PasskeyError.invalidResponse
        }
        
        let masterKey = try cryptoService.decrypt(
            ciphertext: encryptedMasterKey,
            nonce: masterKeyNonce,
            key: kek
        )
        
        print("[PasskeyService] Master key decrypted successfully")
        
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
    
    func listPasskeys(token: String) async throws -> [WebAuthnPasskey] {
        let response: WebAuthnListResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.list,
            token: token
        )
        return response.passkeys
    }
    
    func renamePasskey(credentialId: String, name: String, token: String) async throws {
        let input = WebAuthnRenameRequest(credentialId: credentialId, name: name)
        let _: WebAuthnRenameResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.rename,
            input: input,
            token: token
        )
    }
    
    func deletePasskey(credentialId: String, token: String) async throws {
        let input = WebAuthnDeleteRequest(credentialId: credentialId)
        let _: WebAuthnDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.WebAuthn.delete,
            input: input,
            token: token
        )
    }
    
    func hasLocalPasskeyKEK() -> Bool {
        // With PRF, we no longer store local KEK
        // Return true if PRF is supported (passkeys can work)
        return isPasskeySupported()
    }
    
    func removeLocalPasskeyKEK() throws {
        // No-op with PRF - there's no local KEK to remove
        // KEK is derived from PRF output each time
    }
    
    // MARK: - Private Methods - PRF Key Derivation
    
    /// Derive KEK from PRF output using HKDF-SHA256 (matches web implementation)
    private func derivePRFKEK(prfOutput: Data, salt: String) throws -> Data {
        guard let saltData = Data(base64Encoded: salt) else {
            throw PasskeyError.invalidResponse
        }
        
        let infoData = Data(HKDF_INFO.utf8)
        
        // Use CryptoKit HKDF-SHA256
        let symmetricKey = SymmetricKey(data: prfOutput)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: symmetricKey,
            salt: saltData,
            info: infoData,
            outputByteCount: KEK_BYTES
        )
        
        // Convert SymmetricKey to Data
        return derivedKey.withUnsafeBytes { Data($0) }
    }
    
    // MARK: - Private Methods - Credential Creation with PRF
    
    @available(iOS 18.0, macOS 15.0, *)
    @MainActor
    private func createPlatformCredentialWithPRF(
        options: WebAuthnCreationOptions,
        prfSalt: String
    ) async throws -> (ASAuthorization, Data) {
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
        
        // Configure PRF extension
        guard let saltData = Data(base64Encoded: prfSalt) else {
            throw PasskeyError.invalidResponse
        }
        
        // Set up PRF input for registration using Swift static factory methods
        let inputValues = ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues.saltInput1(saltData)
        request.prf = ASAuthorizationPublicKeyCredentialPRFRegistrationInput.inputValues(inputValues)
        
        print("[PasskeyService] PRF registration input configured")
        
        let authorization = try await performAuthorization(requests: [request])
        
        // Extract PRF output from registration result
        guard let registrationCredential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            throw PasskeyError.registrationFailed("Invalid credential type")
        }
        
        // Get PRF output from registration result
        guard let prfResult = registrationCredential.prf else {
            print("[PasskeyService] PRF extension not available on credential")
            throw PasskeyError.prfNotSupported
        }
        
        // Check if PRF is supported and we got output
        guard prfResult.isSupported, let prfOutputKey = prfResult.first else {
            print("[PasskeyService] PRF extension not supported by this authenticator")
            throw PasskeyError.prfNotSupported
        }
        
        // Convert SymmetricKey to Data
        let prfOutput = prfOutputKey.withUnsafeBytes { Data($0) }
        print("[PasskeyService] PRF output received: \(prfOutput.count) bytes")
        
        return (authorization, prfOutput)
    }
    
    @available(iOS 18.0, macOS 15.0, *)
    @MainActor
    private func authenticateWithPlatformCredentialAndPRF(
        options: WebAuthnRequestOptions,
        prfSalts: [String: String]
    ) async throws -> (ASAuthorization, Data, String) {
        let rpId = Configuration.WebAuthn.rpID
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: rpId)
        
        // Convert challenge from base64url to Data
        let challengeData = try base64URLDecode(options.challenge)
        
        // Build allowed credentials list and PRF inputs
        var allowedCredentials: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
        var prfInputsByCredential: [Data: Data] = [:] // credentialID -> saltData
        
        if let allowCreds = options.allowCredentials {
            for cred in allowCreds {
                let credentialId = try base64URLDecode(cred.id)
                allowedCredentials.append(ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialId))
                
                // Map PRF salt for this credential
                if let salt = prfSalts[cred.id], let saltData = Data(base64Encoded: salt) {
                    prfInputsByCredential[credentialId] = saltData
                }
            }
        }
        
        let request = provider.createCredentialAssertionRequest(challenge: challengeData)
        if !allowedCredentials.isEmpty {
            request.allowedCredentials = allowedCredentials
        }
        
        // Configure PRF extension for assertion
        // For assertion, we provide salt inputs per credential since each credential has its own prfSalt
        if !prfInputsByCredential.isEmpty {
            // Build per-credential inputs as dictionary [credentialID: inputValues] using Swift static factory methods
            var perCredentialDict: [Data: ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues] = [:]
            
            for (credentialID, saltData) in prfInputsByCredential {
                let inputValues = ASAuthorizationPublicKeyCredentialPRFAssertionInput.InputValues.saltInput1(saltData)
                perCredentialDict[credentialID] = inputValues
            }
            
            // Create PRF input with per-credential values
            request.prf = ASAuthorizationPublicKeyCredentialPRFAssertionInput.perCredentialInputValues(perCredentialDict)
            
            print("[PasskeyService] PRF assertion input configured for \(prfInputsByCredential.count) credentials")
        }
        
        let authorization = try await performAuthorization(requests: [request])
        
        // Extract PRF output from assertion result
        guard let assertionCredential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyError.authenticationFailed("Invalid credential type")
        }
        
        // Get PRF output from assertion result
        guard let prfResult = assertionCredential.prf else {
            print("[PasskeyService] PRF extension not available in assertion")
            throw PasskeyError.prfNotSupported
        }
        
        // For assertion, 'first' is non-optional when prf is present
        let prfOutputKey = prfResult.first
        
        // Convert SymmetricKey to Data
        let prfOutput = prfOutputKey.withUnsafeBytes { Data($0) }
        
        let usedCredentialId = assertionCredential.credentialID.base64EncodedString()
        print("[PasskeyService] PRF output received for credential: \(usedCredentialId.prefix(20))...")
        
        return (authorization, prfOutput, usedCredentialId)
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
    
    /// Encode Data to base64url (WebAuthn standard encoding)
    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
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
        #if os(iOS)
        // Get the key window from active scene
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback: return first window
            return UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first }
                .first ?? UIWindow()
        }
        return window
        #elseif os(macOS)
        // On macOS, return the key window or first window
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #endif
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
    var mockMasterKey = Data(repeating: 0xAB, count: 32)
    
    func isPasskeySupported() -> Bool {
        isSupported
    }
    
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String {
        if shouldFail { throw PasskeyError.registrationFailed("Mock error") }
        hasPasskey = true
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
    
    func listPasskeys(token: String) async throws -> [WebAuthnPasskey] {
        if shouldFail { throw PasskeyError.serverError("Mock error") }
        return hasPasskey ? [WebAuthnPasskey(id: "1", credentialId: "mock-cred", name: "Mock Passkey", credentialDeviceType: "multiDevice", credentialBackedUp: true, lastUsedAt: nil, createdAt: Date(), deviceType: "platform")] : []
    }
    
    func renamePasskey(credentialId: String, name: String, token: String) async throws {
        if shouldFail { throw PasskeyError.serverError("Mock error") }
    }
    
    func deletePasskey(credentialId: String, token: String) async throws {
        if shouldFail { throw PasskeyError.serverError("Mock error") }
        hasPasskey = false
    }
    
    func hasLocalPasskeyKEK() -> Bool {
        // With PRF, always return true if supported
        return isSupported
    }
    
    func removeLocalPasskeyKEK() throws {
        // No-op with PRF
    }
}
#endif
