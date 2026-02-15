package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for encrypted Prompts API - matches iOS PromptRepository.swift
 * Prompts are encrypted client-side using E2EE with the master key.
 */

// ===== Encrypted Prompt Response (from server list and get) =====

@Serializable
data class EncryptedPromptResponse(
    val id: String,
    val userId: String,
    val encryptedName: String,
    val nameNonce: String,
    val encryptedDescription: String? = null,
    val descriptionNonce: String? = null,
    val encryptedContent: String,
    val contentNonce: String,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Get Prompt Request =====

@Serializable
data class PromptGetRequest(
    val promptId: String
)

// ===== Create Prompt Request =====

@Serializable
data class PromptCreateRequest(
    val encryptedName: String,
    val nameNonce: String,
    val encryptedDescription: String? = null,
    val descriptionNonce: String? = null,
    val encryptedContent: String,
    val contentNonce: String
)

@Serializable
data class PromptCreateResponse(
    val id: String
)

// ===== Update Prompt Request =====

@Serializable
data class PromptUpdateRequest(
    val promptId: String,
    val encryptedName: String? = null,
    val nameNonce: String? = null,
    val encryptedDescription: String? = null,
    val descriptionNonce: String? = null,
    val encryptedContent: String? = null,
    val contentNonce: String? = null
)

@Serializable
data class PromptUpdateResponse(
    val id: String
)

// ===== Delete Prompt Request =====

@Serializable
data class PromptDeleteRequest(
    val promptId: String
)

@Serializable
data class PromptDeleteResponse(
    val success: Boolean
)
