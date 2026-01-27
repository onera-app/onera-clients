package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTOs for encrypted Credentials API - matches iOS CredentialService.swift
 * Credentials are encrypted client-side using E2EE.
 */

// ===== Encrypted Credential from Server =====

@Serializable
data class EncryptedCredentialResponse(
    val id: String,
    val userId: String,
    val encryptedData: String,
    val iv: String,
    val encryptedName: String?,
    val nameNonce: String?,
    val encryptedProvider: String?,
    val providerNonce: String?,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Credential Data (decrypted JSON structure) =====
// Web uses snake_case: api_key, base_url, org_id

@Serializable
data class CredentialData(
    @SerialName("api_key")
    val apiKey: String,
    @SerialName("base_url")
    val baseUrl: String? = null,
    @SerialName("org_id")
    val orgId: String? = null,
    val config: Map<String, String>? = null
)

// ===== Create Encrypted Credential =====

@Serializable
data class CreateEncryptedCredentialRequest(
    val encryptedData: String,
    val iv: String,
    val encryptedName: String,
    val nameNonce: String,
    val encryptedProvider: String,
    val providerNonce: String
)

@Serializable
data class CreateCredentialResponse(
    val id: String
)

// ===== Update Encrypted Credential =====

@Serializable
data class UpdateEncryptedCredentialRequest(
    val credentialId: String,
    val encryptedData: String? = null,
    val iv: String? = null,
    val encryptedName: String? = null,
    val nameNonce: String? = null
)

@Serializable
data class UpdateCredentialResponse(
    val id: String
)

// ===== Remove Credential =====

@Serializable
data class RemoveCredentialRequest(
    val credentialId: String
)

@Serializable
data class RemoveCredentialResponse(
    val success: Boolean
)
