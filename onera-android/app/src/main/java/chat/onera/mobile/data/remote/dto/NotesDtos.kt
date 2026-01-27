package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for encrypted Notes API - matches iOS NoteRepository.swift
 * Notes are encrypted client-side using E2EE with the master key.
 */

// ===== Note List Request =====

@Serializable
data class NoteListRequest(
    val folderId: String? = null,
    val archived: Boolean = false
)

// ===== Encrypted Note Summary (from server list) =====

@Serializable
data class EncryptedNoteSummary(
    val id: String,
    val userId: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val folderId: String?,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Get Note Request =====

@Serializable
data class NoteGetRequest(
    val noteId: String
)

// ===== Encrypted Note Response (full note with content) =====

@Serializable
data class EncryptedNoteResponse(
    val id: String,
    val userId: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedContent: String,
    val contentNonce: String,
    val folderId: String?,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Create Note Request =====

@Serializable
data class NoteCreateRequest(
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedContent: String,
    val contentNonce: String,
    val folderId: String? = null
)

@Serializable
data class NoteCreateResponse(
    val id: String
)

// ===== Update Note Request =====

@Serializable
data class NoteUpdateRequest(
    val noteId: String,
    val encryptedTitle: String? = null,
    val titleNonce: String? = null,
    val encryptedContent: String? = null,
    val contentNonce: String? = null,
    val folderId: String? = null,
    val pinned: Boolean? = null,
    val archived: Boolean? = null
)

@Serializable
data class NoteUpdateResponse(
    val id: String
)

// ===== Delete Note Request =====

@Serializable
data class NoteDeleteRequest(
    val noteId: String
)

@Serializable
data class NoteDeleteResponse(
    val success: Boolean
)
