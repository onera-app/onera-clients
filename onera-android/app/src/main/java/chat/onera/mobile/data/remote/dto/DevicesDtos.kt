package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for Devices API - matches iOS E2EEService.swift
 * Used for device registration and management.
 */

// ===== Device List =====

@Serializable
data class DeviceResponse(
    val id: String,
    val userId: String,
    val deviceId: String,
    val encryptedDeviceName: String?,
    val deviceNameNonce: String?,
    val userAgent: String?,
    val lastSeen: Long,
    val createdAt: Long
)

// ===== Register Device =====

@Serializable
data class DeviceRegisterRequest(
    val deviceId: String,
    val encryptedDeviceName: String?,
    val deviceNameNonce: String?,
    val userAgent: String?
)

@Serializable
data class DeviceRegisterResponse(
    val deviceSecret: String
)

// ===== Get Device Secret =====

@Serializable
data class DeviceSecretRequest(
    val deviceId: String
)

@Serializable
data class DeviceSecretResponse(
    val deviceSecret: String
)

// ===== Update Last Seen =====

@Serializable
data class DeviceUpdateLastSeenRequest(
    val deviceId: String
)

@Serializable
data class DeviceUpdateLastSeenResponse(
    val success: Boolean
)

// ===== Revoke Device =====

@Serializable
data class DeviceRevokeRequest(
    val deviceId: String
)

@Serializable
data class DeviceRevokeResponse(
    val success: Boolean
)

// ===== Delete Device =====

@Serializable
data class DeviceDeleteRequest(
    val deviceId: String
)

@Serializable
data class DeviceDeleteResponse(
    val success: Boolean
)
