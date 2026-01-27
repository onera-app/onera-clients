package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for encrypted Folders API - matches iOS FolderRepository.swift
 * Folder names are encrypted client-side using E2EE with the master key.
 */

// ===== Encrypted Folder Response =====

@Serializable
data class EncryptedFolderResponse(
    val id: String,
    val userId: String,
    val encryptedName: String?,
    val nameNonce: String?,
    val parentId: String?,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Get Folder Request =====

@Serializable
data class FolderGetRequest(
    val folderId: String
)

// ===== Create Folder Request =====

@Serializable
data class FolderCreateRequest(
    val encryptedName: String,
    val nameNonce: String,
    val parentId: String? = null
)

@Serializable
data class FolderCreateResponse(
    val id: String,
    val userId: String,
    val encryptedName: String?,
    val nameNonce: String?,
    val parentId: String?,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Update Folder Request =====

@Serializable
data class FolderUpdateRequest(
    val folderId: String,
    val encryptedName: String? = null,
    val nameNonce: String? = null,
    val parentId: String? = null
)

@Serializable
data class FolderUpdateResponse(
    val id: String,
    val userId: String,
    val encryptedName: String?,
    val nameNonce: String?,
    val parentId: String?,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Delete Folder Request =====

@Serializable
data class FolderDeleteRequest(
    val folderId: String
)

@Serializable
data class FolderDeleteResponse(
    val success: Boolean
)
