package chat.onera.mobile.data.security

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.DevicesProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Device Manager - matches iOS E2EEService device registration.
 * Handles device registration, secrets, and management for E2EE.
 */
@Singleton
class DeviceManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager
) {
    companion object {
        private const val TAG = "DeviceManager"
        private const val PREFS_NAME = "device_prefs"
        private const val PREF_DEVICE_ID = "device_id"
        private const val PREF_DEVICE_SECRET = "device_secret"
    }
    
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // ===== Device Info =====
    
    /**
     * Get or generate a unique device ID.
     */
    fun getDeviceId(): String {
        var deviceId = prefs.getString(PREF_DEVICE_ID, null)
        if (deviceId == null) {
            // Try to use Android ID first, fall back to random UUID
            deviceId = try {
                Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                    ?: UUID.randomUUID().toString()
            } catch (e: Exception) {
                UUID.randomUUID().toString()
            }
            prefs.edit().putString(PREF_DEVICE_ID, deviceId).apply()
        }
        return deviceId
    }
    
    /**
     * Get device name (model name).
     */
    fun getDeviceName(): String {
        val manufacturer = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        val model = Build.MODEL
        return if (model.startsWith(manufacturer, ignoreCase = true)) {
            model
        } else {
            "$manufacturer $model"
        }
    }
    
    /**
     * Get user agent string.
     */
    fun getUserAgent(): String {
        return "Onera-Android/${getAppVersion()} (${Build.MODEL}; Android ${Build.VERSION.RELEASE})"
    }
    
    /**
     * Get a device fingerprint based on device characteristics.
     */
    fun getDeviceFingerprint(): String {
        val components = listOf(
            Build.MANUFACTURER,
            Build.MODEL,
            Build.BRAND,
            Build.DEVICE,
            Build.HARDWARE
        ).joinToString("|")
        
        val hash = encryptionManager.sha256(components.toByteArray())
        return android.util.Base64.encodeToString(hash, android.util.Base64.NO_WRAP)
    }
    
    private fun getAppVersion(): String {
        return try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0"
        } catch (e: Exception) {
            "1.0"
        }
    }
    
    // ===== Device Registration =====
    
    /**
     * Register this device with the server.
     * 
     * @param masterKey The master encryption key for encrypting device name
     * @return The device secret from the server
     */
    suspend fun registerDevice(masterKey: ByteArray): ByteArray {
        Log.d(TAG, "Registering device...")
        
        val deviceId = getDeviceId()
        val deviceName = getDeviceName()
        val userAgent = getUserAgent()
        
        // Encrypt device name with master key
        val (encryptedDeviceName, deviceNameNonce) = encryptionManager.encryptForServer(
            deviceName, 
            masterKey
        )
        
        val request = DeviceRegisterRequest(
            deviceId = deviceId,
            encryptedDeviceName = encryptedDeviceName,
            deviceNameNonce = deviceNameNonce,
            userAgent = userAgent
        )
        
        val result = trpcClient.mutation<DeviceRegisterRequest, DeviceRegisterResponse>(
            DevicesProcedures.REGISTER,
            request
        )
        
        val response = result.getOrThrow()
        
        val deviceSecret = android.util.Base64.decode(
            response.deviceSecret, 
            android.util.Base64.NO_WRAP
        )
        
        // Store device secret securely
        saveDeviceSecret(response.deviceSecret)
        
        Log.d(TAG, "Device registered successfully")
        return deviceSecret
    }
    
    /**
     * Get the device secret from server (for returning devices).
     */
    suspend fun getDeviceSecret(): ByteArray {
        // First check if we have it cached
        val cached = prefs.getString(PREF_DEVICE_SECRET, null)
        if (cached != null) {
            return android.util.Base64.decode(cached, android.util.Base64.NO_WRAP)
        }
        
        // Fetch from server
        Log.d(TAG, "Fetching device secret from server...")
        
        val request = DeviceSecretRequest(deviceId = getDeviceId())
        val result = trpcClient.query<DeviceSecretRequest, DeviceSecretResponse>(
            DevicesProcedures.GET_SECRET,
            request
        )
        
        val response = result.getOrThrow()
        
        // Cache it
        saveDeviceSecret(response.deviceSecret)
        
        return android.util.Base64.decode(response.deviceSecret, android.util.Base64.NO_WRAP)
    }
    
    /**
     * Derive the device share encryption key.
     * This matches iOS's deriveDeviceShareKey.
     */
    fun deriveDeviceShareKey(deviceSecret: ByteArray): ByteArray {
        val deviceId = getDeviceId()
        val fingerprint = getDeviceFingerprint()
        
        // Combine device ID, fingerprint, and secret
        val combined = (deviceId + fingerprint).toByteArray() + deviceSecret
        
        // Derive key using SHA-256 (simplified - iOS uses HKDF)
        return encryptionManager.sha256(combined)
    }
    
    // ===== Device Management =====
    
    /**
     * Update the device's last seen timestamp on server.
     */
    suspend fun updateLastSeen() {
        Log.d(TAG, "Updating last seen...")
        
        try {
            val request = DeviceUpdateLastSeenRequest(deviceId = getDeviceId())
            val result = trpcClient.mutation<DeviceUpdateLastSeenRequest, DeviceUpdateLastSeenResponse>(
                DevicesProcedures.UPDATE_LAST_SEEN,
                request
            )
            
            result.onSuccess {
                Log.d(TAG, "Last seen updated")
            }.onFailure { e ->
                Log.w(TAG, "Failed to update last seen", e)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error updating last seen", e)
        }
    }
    
    /**
     * Get list of all devices for this user.
     */
    suspend fun getDevices(masterKey: ByteArray): List<Device> {
        Log.d(TAG, "Fetching devices...")
        
        val result = trpcClient.query<Unit, List<DeviceResponse>>(
            DevicesProcedures.LIST,
            Unit
        )
        
        return result.fold(
            onSuccess = { devices ->
                devices.map { device ->
                    val name = if (device.encryptedDeviceName != null && device.deviceNameNonce != null) {
                        try {
                            encryptionManager.decryptFromServer(
                                device.encryptedDeviceName,
                                device.deviceNameNonce,
                                masterKey
                            )
                        } catch (e: Exception) {
                            "Encrypted Device"
                        }
                    } else {
                        "Unknown Device"
                    }
                    
                    Device(
                        id = device.id,
                        deviceId = device.deviceId,
                        name = name,
                        userAgent = device.userAgent,
                        lastSeen = device.lastSeen,
                        createdAt = device.createdAt,
                        isCurrentDevice = device.deviceId == getDeviceId()
                    )
                }
            },
            onFailure = { e ->
                Log.e(TAG, "Failed to fetch devices", e)
                emptyList()
            }
        )
    }
    
    /**
     * Revoke another device.
     */
    suspend fun revokeDevice(deviceId: String) {
        Log.d(TAG, "Revoking device $deviceId...")
        
        val request = DeviceRevokeRequest(deviceId = deviceId)
        val result = trpcClient.mutation<DeviceRevokeRequest, DeviceRevokeResponse>(
            DevicesProcedures.REVOKE,
            request
        )
        
        result.onSuccess {
            Log.d(TAG, "Device revoked: $deviceId")
        }.onFailure { e ->
            Log.e(TAG, "Failed to revoke device", e)
            throw e
        }
    }
    
    /**
     * Delete a device.
     */
    suspend fun deleteDevice(deviceId: String) {
        Log.d(TAG, "Deleting device $deviceId...")
        
        val request = DeviceDeleteRequest(deviceId = deviceId)
        val result = trpcClient.mutation<DeviceDeleteRequest, DeviceDeleteResponse>(
            DevicesProcedures.DELETE,
            request
        )
        
        result.onSuccess {
            Log.d(TAG, "Device deleted: $deviceId")
        }.onFailure { e ->
            Log.e(TAG, "Failed to delete device", e)
            throw e
        }
    }
    
    /**
     * Clear local device data (for logout/account deletion).
     */
    fun clearDeviceData() {
        prefs.edit().clear().apply()
        Log.d(TAG, "Device data cleared")
    }
    
    // ===== Private Helpers =====
    
    private fun saveDeviceSecret(secret: String) {
        // In production, use EncryptedSharedPreferences
        prefs.edit().putString(PREF_DEVICE_SECRET, secret).apply()
    }
    
    fun hasDeviceSecret(): Boolean {
        return prefs.getString(PREF_DEVICE_SECRET, null) != null
    }
}

/**
 * Domain model for a registered device.
 */
data class Device(
    val id: String,
    val deviceId: String,
    val name: String,
    val userAgent: String?,
    val lastSeen: Long,
    val createdAt: Long,
    val isCurrentDevice: Boolean
)
