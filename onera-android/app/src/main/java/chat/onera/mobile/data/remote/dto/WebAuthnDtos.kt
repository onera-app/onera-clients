package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * DTOs for WebAuthn (Passkeys) API - matches iOS PasskeyService.swift
 * Used for passkey registration and authentication.
 */

// ===== Has Passkeys =====

@Serializable
data class WebAuthnHasPasskeysResponse(
    val hasPasskeys: Boolean
)

// ===== List Passkeys =====

@Serializable
data class WebAuthnCredentialResponse(
    val id: String,
    val credentialId: String,
    val publicKey: String,
    val name: String?,
    val lastUsed: Long?,
    val createdAt: Long
)

// ===== Registration Options =====

@Serializable
data class WebAuthnRegistrationOptionsRequest(
    val name: String? = null
)

@Serializable
data class WebAuthnRegistrationOptionsResponse(
    val options: WebAuthnCreationOptions,
    val prfSalt: String
)

@Serializable
data class WebAuthnCreationOptions(
    val challenge: String,
    val rp: WebAuthnRelyingParty,
    val user: WebAuthnUser,
    val pubKeyCredParams: List<WebAuthnPubKeyCredParam>,
    val timeout: Long? = null,
    val attestation: String? = null,
    val authenticatorSelection: WebAuthnAuthenticatorSelection? = null
)

@Serializable
data class WebAuthnRelyingParty(
    val id: String,
    val name: String
)

@Serializable
data class WebAuthnUser(
    val id: String,
    val name: String,
    val displayName: String
)

@Serializable
data class WebAuthnPubKeyCredParam(
    val type: String,
    val alg: Int
)

@Serializable
data class WebAuthnAuthenticatorSelection(
    val authenticatorAttachment: String? = null,
    val residentKey: String? = null,
    val requireResidentKey: Boolean? = null,
    val userVerification: String? = null
)

// ===== Verify Registration =====

@Serializable
data class WebAuthnVerifyRegistrationRequest(
    val response: WebAuthnRegistrationResponse,
    val prfSalt: String,
    val encryptedMasterKey: String,
    val masterKeyNonce: String,
    val name: String? = null
)

@Serializable
data class WebAuthnRegistrationResponse(
    val id: String,
    val rawId: String,
    val type: String,
    val response: WebAuthnAttestationResponse,
    val clientExtensionResults: WebAuthnClientExtensionResults? = null
)

@Serializable
data class WebAuthnAttestationResponse(
    val clientDataJSON: String,
    val attestationObject: String
)

@Serializable
data class WebAuthnClientExtensionResults(
    val prf: WebAuthnPRFExtensionResult? = null
)

@Serializable
data class WebAuthnPRFExtensionResult(
    val enabled: Boolean? = null
)

@Serializable
data class WebAuthnVerifyRegistrationResponse(
    val verified: Boolean,
    val credentialId: String? = null
)

// ===== Authentication Options =====

@Serializable
data class WebAuthnAuthOptionsResponse(
    val options: WebAuthnRequestOptions,
    val prfSalts: Map<String, String> = emptyMap() // Map of credentialId to prfSalt
)

@Serializable
data class WebAuthnRequestOptions(
    val challenge: String,
    val timeout: Long? = null,
    val rpId: String? = null,
    val allowCredentials: List<WebAuthnAllowCredential>? = null,
    val userVerification: String? = null
)

@Serializable
data class WebAuthnAllowCredential(
    val id: String,
    val type: String,
    val transports: List<String>? = null
)

// ===== Verify Authentication =====

@Serializable
data class WebAuthnVerifyAuthRequest(
    val response: WebAuthnAuthenticationResponse
)

@Serializable
data class WebAuthnAuthenticationResponse(
    val id: String,
    val rawId: String,
    val type: String,
    val response: WebAuthnAssertionResponse,
    val clientExtensionResults: JsonObject? = null
)

@Serializable
data class WebAuthnAssertionResponse(
    val clientDataJSON: String,
    val authenticatorData: String,
    val signature: String,
    val userHandle: String? = null
)

@Serializable
data class WebAuthnVerifyAuthResponse(
    val verified: Boolean,
    val encryptedMasterKey: String,
    val masterKeyNonce: String,
    val prfSalt: String? = null
)

// ===== Rename Passkey =====

@Serializable
data class WebAuthnRenameRequest(
    val credentialId: String,
    val name: String
)

@Serializable
data class WebAuthnRenameResponse(
    val success: Boolean
)

// ===== Delete Passkey =====

@Serializable
data class WebAuthnDeleteRequest(
    val credentialId: String
)

@Serializable
data class WebAuthnDeleteResponse(
    val success: Boolean
)
