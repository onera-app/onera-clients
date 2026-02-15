//
//  WebAuthnModels.swift
//  Onera
//
//  WebAuthn API request/response models for passkey operations
//

import Foundation

// MARK: - Registration Options

struct WebAuthnRegistrationOptionsRequest: Codable {
    let name: String?
}

struct WebAuthnRegistrationOptionsResponse: Codable {
    let options: WebAuthnCreationOptions
    let prfSalt: String
    let name: String?
}

struct WebAuthnCreationOptions: Codable {
    let challenge: String
    let rp: WebAuthnRelyingParty
    let user: WebAuthnUser
    let pubKeyCredParams: [WebAuthnPubKeyCredParam]
    let timeout: Int?
    let excludeCredentials: [WebAuthnCredentialDescriptor]?
    let authenticatorSelection: WebAuthnAuthenticatorSelection?
    let attestation: String?
}

struct WebAuthnRelyingParty: Codable {
    let id: String
    let name: String
}

struct WebAuthnUser: Codable {
    let id: String
    let name: String
    let displayName: String
}

struct WebAuthnPubKeyCredParam: Codable {
    let type: String
    let alg: Int
}

struct WebAuthnAuthenticatorSelection: Codable {
    let authenticatorAttachment: String?
    let residentKey: String?
    let requireResidentKey: Bool?
    let userVerification: String?
}

// MARK: - Registration Response

struct WebAuthnRegistrationResponse: Codable {
    let id: String
    let rawId: String
    let type: String
    let response: WebAuthnAttestationResponse
    let clientExtensionResults: WebAuthnClientExtensionResults?
    let authenticatorAttachment: String?
    
    init(id: String, rawId: String, type: String, response: WebAuthnAttestationResponse, clientExtensionResults: WebAuthnClientExtensionResults?, authenticatorAttachment: String? = nil) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
        self.clientExtensionResults = clientExtensionResults
        self.authenticatorAttachment = authenticatorAttachment
    }
}

struct WebAuthnAttestationResponse: Codable {
    let clientDataJSON: String
    let attestationObject: String
    let transports: [String]?
    let publicKeyAlgorithm: Int?
    let publicKey: String?
    let authenticatorData: String?
    
    init(clientDataJSON: String, attestationObject: String, transports: [String]? = nil, publicKeyAlgorithm: Int? = nil, publicKey: String? = nil, authenticatorData: String? = nil) {
        self.clientDataJSON = clientDataJSON
        self.attestationObject = attestationObject
        self.transports = transports
        self.publicKeyAlgorithm = publicKeyAlgorithm
        self.publicKey = publicKey
        self.authenticatorData = authenticatorData
    }
}

struct WebAuthnClientExtensionResults: Codable {
    let prf: WebAuthnPRFExtensionResult?
}

struct WebAuthnPRFExtensionResult: Codable {
    let enabled: Bool?
    let results: WebAuthnPRFResults?
    
    init(enabled: Bool? = nil, results: WebAuthnPRFResults? = nil) {
        self.enabled = enabled
        self.results = results
    }
}

struct WebAuthnPRFResults: Codable {
    let first: String?
    let second: String?
}

// MARK: - Verify Registration

struct WebAuthnVerifyRegistrationRequest: Codable {
    let response: WebAuthnRegistrationResponse
    let prfSalt: String
    let encryptedMasterKey: String
    let masterKeyNonce: String
    let name: String?
}

struct WebAuthnVerifyRegistrationResponse: Codable {
    let success: Bool
    let verified: Bool
}

// MARK: - Authentication Options

struct WebAuthnAuthOptionsResponse: Codable {
    let options: WebAuthnRequestOptions
    let prfSalts: [String: String]?
}

struct WebAuthnRequestOptions: Codable {
    let challenge: String
    let timeout: Int?
    let rpId: String?
    let allowCredentials: [WebAuthnCredentialDescriptor]?
    let userVerification: String?
}

struct WebAuthnCredentialDescriptor: Codable {
    let id: String
    let type: String
    let transports: [String]?
}

// MARK: - Authentication Response

struct WebAuthnAuthenticationResponse: Codable {
    let id: String
    let rawId: String
    let type: String
    let response: WebAuthnAssertionResponse
    let clientExtensionResults: [String: String]?
    let authenticatorAttachment: String?
    
    init(id: String, rawId: String, type: String, response: WebAuthnAssertionResponse, clientExtensionResults: [String: String]? = nil, authenticatorAttachment: String? = nil) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
        self.clientExtensionResults = clientExtensionResults
        self.authenticatorAttachment = authenticatorAttachment
    }
}

struct WebAuthnAssertionResponse: Codable {
    let clientDataJSON: String
    let authenticatorData: String
    let signature: String
    let userHandle: String?
}

// MARK: - Verify Authentication

struct WebAuthnVerifyAuthRequest: Codable {
    let response: WebAuthnAuthenticationResponse
}

struct WebAuthnVerifyAuthResponse: Codable {
    let success: Bool
    let verified: Bool
    let encryptedMasterKey: String
    let masterKeyNonce: String
    let prfSalt: String?
}

// MARK: - Has Passkeys

struct WebAuthnHasPasskeysResponse: Codable {
    let hasPasskeys: Bool
}

// MARK: - List Passkeys

struct WebAuthnPasskey: Codable, Identifiable {
    let id: String
    let credentialId: String
    let encryptedName: String?
    let nameNonce: String?
    let credentialDeviceType: String?
    let credentialBackedUp: Bool?
    let lastUsedAt: Date?
    let createdAt: Date
    let deviceType: String?
    
    /// Client-side decrypted name (set after decryption, not from server)
    var displayName: String {
        // If we have encrypted name data, we'd decrypt here with master key
        // For now, fall back to a readable default
        "Passkey"
    }
}

// MARK: - Rename Passkey

struct WebAuthnRenameRequest: Codable {
    let credentialId: String
    let encryptedName: String
    let nameNonce: String
}

struct WebAuthnRenameResponse: Codable {
    let success: Bool
}

// MARK: - Delete Passkey

struct WebAuthnDeleteRequest: Codable {
    let credentialId: String
}

struct WebAuthnDeleteResponse: Codable {
    let success: Bool
}
