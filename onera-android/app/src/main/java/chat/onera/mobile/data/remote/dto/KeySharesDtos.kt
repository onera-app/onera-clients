package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for KeyShares API - matches iOS E2EEService.swift
 * Used for E2EE key management with Shamir secret sharing.
 */

// ===== Check Status =====

@Serializable
data class KeySharesCheckResponse(
    val hasShares: Boolean
)

// ===== Get Key Shares =====

@Serializable
data class KeySharesGetResponse(
    val authShare: String,
    val encryptedRecoveryShare: String,
    val recoveryShareNonce: String,
    val publicKey: String,
    val encryptedPrivateKey: String,
    val privateKeyNonce: String,
    val masterKeyRecovery: String,
    val masterKeyRecoveryNonce: String,
    val encryptedRecoveryKey: String,
    val recoveryKeyNonce: String
)

// ===== Create Key Shares =====

@Serializable
data class KeySharesCreateRequest(
    val authShare: String,
    val encryptedRecoveryShare: String,
    val recoveryShareNonce: String,
    val publicKey: String,
    val encryptedPrivateKey: String,
    val privateKeyNonce: String,
    val masterKeyRecovery: String,
    val masterKeyRecoveryNonce: String,
    val encryptedRecoveryKey: String,
    val recoveryKeyNonce: String
)

@Serializable
data class KeySharesCreateResponse(
    val success: Boolean
)

// ===== Update Auth Share =====

@Serializable
data class UpdateAuthShareRequest(
    val authShare: String
)

@Serializable
data class UpdateAuthShareResponse(
    val success: Boolean
)

// ===== Update Recovery Share =====

@Serializable
data class UpdateRecoveryShareRequest(
    val encryptedRecoveryShare: String,
    val recoveryShareNonce: String
)

@Serializable
data class UpdateRecoveryShareResponse(
    val success: Boolean
)

// ===== Password Encryption =====

@Serializable
data class PasswordEncryptionCheckResponse(
    val hasPassword: Boolean
)

@Serializable
data class PasswordEncryptionGetResponse(
    val encryptedMasterKey: String,
    val nonce: String,
    val salt: String,
    val opsLimit: Int,
    val memLimit: Int
)

@Serializable
data class PasswordEncryptionSetRequest(
    val encryptedMasterKey: String,
    val nonce: String,
    val salt: String,
    val opsLimit: Int,
    val memLimit: Int
)

@Serializable
data class PasswordEncryptionSetResponse(
    val success: Boolean
)

@Serializable
data class PasswordEncryptionRemoveResponse(
    val success: Boolean
)

// ===== Delete Key Shares =====

@Serializable
data class KeySharesDeleteResponse(
    val success: Boolean
)

// ===== Reset Encryption =====

@Serializable
data class ResetEncryptionRequest(
    val confirmPhrase: String
)

@Serializable
data class ResetEncryptionResponse(
    val success: Boolean
)
