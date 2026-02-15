package chat.onera.mobile.presentation.features.settings.security

import android.app.Activity
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.DevicesProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.remote.trpc.WebAuthnProcedures
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import javax.inject.Inject

// ── State ───────────────────────────────────────────────────────────────

data class SecuritySettingsState(
    val isLoading: Boolean = true,
    val isEncryptionActive: Boolean = false,
    val isSessionUnlocked: Boolean = false,

    // Change password
    val currentPassword: String = "",
    val newPassword: String = "",
    val confirmPassword: String = "",
    val isChangingPassword: Boolean = false,

    // Passkeys
    val passkeys: List<PasskeyItem> = emptyList(),
    val isLoadingPasskeys: Boolean = false,
    val isAddingPasskey: Boolean = false,

    // Devices
    val devices: List<DeviceItem> = emptyList(),
    val isLoadingDevices: Boolean = false,
    val currentDeviceId: String? = null,

    // Dialogs
    val deletePasskeyTarget: PasskeyItem? = null,
    val revokeDeviceTarget: DeviceItem? = null,
    val showLockConfirmation: Boolean = false,

    val error: String? = null
) : UiState

data class PasskeyItem(
    val id: String,
    val credentialId: String,
    val name: String?,
    val lastUsed: Long?,
    val createdAt: Long
)

data class DeviceItem(
    val id: String,
    val deviceId: String,
    val name: String?,
    val userAgent: String?,
    val lastSeen: Long,
    val createdAt: Long,
    val isCurrent: Boolean = false
)

// ── Intent ──────────────────────────────────────────────────────────────

sealed interface SecuritySettingsIntent : UiIntent {
    data object LoadData : SecuritySettingsIntent

    // Change password
    data class UpdateCurrentPassword(val value: String) : SecuritySettingsIntent
    data class UpdateNewPassword(val value: String) : SecuritySettingsIntent
    data class UpdateConfirmPassword(val value: String) : SecuritySettingsIntent
    data object SubmitPasswordChange : SecuritySettingsIntent

    // Passkeys
    data class AddPasskey(val activity: Activity) : SecuritySettingsIntent
    data class ConfirmDeletePasskey(val passkey: PasskeyItem) : SecuritySettingsIntent
    data object DismissDeletePasskey : SecuritySettingsIntent
    data object DeletePasskey : SecuritySettingsIntent

    // Devices
    data class ConfirmRevokeDevice(val device: DeviceItem) : SecuritySettingsIntent
    data object DismissRevokeDevice : SecuritySettingsIntent
    data object RevokeDevice : SecuritySettingsIntent

    // Session lock
    data object ShowLockConfirmation : SecuritySettingsIntent
    data object DismissLockConfirmation : SecuritySettingsIntent
    data object LockSession : SecuritySettingsIntent

    data object DismissError : SecuritySettingsIntent
}

// ── Effect ──────────────────────────────────────────────────────────────

sealed interface SecuritySettingsEffect : UiEffect {
    data class ShowToast(val message: String) : SecuritySettingsEffect
    data object NavigateToUnlock : SecuritySettingsEffect
    data object PasswordChanged : SecuritySettingsEffect
}

// ── ViewModel ───────────────────────────────────────────────────────────

@HiltViewModel
class SecuritySettingsViewModel @Inject constructor(
    private val e2eeRepository: E2EERepository,
    private val trpcClient: TRPCClient
) : BaseViewModel<SecuritySettingsState, SecuritySettingsIntent, SecuritySettingsEffect>(
    SecuritySettingsState()
) {

    init {
        loadData()
    }

    override fun handleIntent(intent: SecuritySettingsIntent) {
        when (intent) {
            is SecuritySettingsIntent.LoadData -> loadData()

            is SecuritySettingsIntent.UpdateCurrentPassword ->
                updateState { copy(currentPassword = intent.value) }
            is SecuritySettingsIntent.UpdateNewPassword ->
                updateState { copy(newPassword = intent.value) }
            is SecuritySettingsIntent.UpdateConfirmPassword ->
                updateState { copy(confirmPassword = intent.value) }
            is SecuritySettingsIntent.SubmitPasswordChange -> changePassword()

            is SecuritySettingsIntent.AddPasskey -> addPasskey(intent.activity)
            is SecuritySettingsIntent.ConfirmDeletePasskey ->
                updateState { copy(deletePasskeyTarget = intent.passkey) }
            is SecuritySettingsIntent.DismissDeletePasskey ->
                updateState { copy(deletePasskeyTarget = null) }
            is SecuritySettingsIntent.DeletePasskey -> deletePasskey()

            is SecuritySettingsIntent.ConfirmRevokeDevice ->
                updateState { copy(revokeDeviceTarget = intent.device) }
            is SecuritySettingsIntent.DismissRevokeDevice ->
                updateState { copy(revokeDeviceTarget = null) }
            is SecuritySettingsIntent.RevokeDevice -> revokeDevice()

            is SecuritySettingsIntent.ShowLockConfirmation ->
                updateState { copy(showLockConfirmation = true) }
            is SecuritySettingsIntent.DismissLockConfirmation ->
                updateState { copy(showLockConfirmation = false) }
            is SecuritySettingsIntent.LockSession -> lockSession()

            is SecuritySettingsIntent.DismissError ->
                updateState { copy(error = null) }
        }
    }

    private fun loadData() {
        updateState { copy(isLoading = true) }
        viewModelScope.launch {
            try {
                val hasKeys = e2eeRepository.hasEncryptionKeys()
                val isUnlocked = e2eeRepository.isSessionUnlocked()
                updateState {
                    copy(
                        isEncryptionActive = hasKeys,
                        isSessionUnlocked = isUnlocked,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                updateState { copy(isLoading = false, error = e.message) }
            }
        }
        loadPasskeys()
        loadDevices()
    }

    private fun loadPasskeys() {
        updateState { copy(isLoadingPasskeys = true) }
        viewModelScope.launch {
            try {
                val result = trpcClient.query<Unit, List<WebAuthnCredentialResponse>>(
                    WebAuthnProcedures.LIST,
                    Unit
                )
                result.onSuccess { credentials ->
                    updateState {
                        copy(
                            passkeys = credentials.map { cred ->
                                PasskeyItem(
                                    id = cred.id,
                                    credentialId = cred.credentialId,
                                    name = cred.name,
                                    lastUsed = cred.lastUsed,
                                    createdAt = cred.createdAt
                                )
                            },
                            isLoadingPasskeys = false
                        )
                    }
                }.onFailure { e ->
                    updateState { copy(isLoadingPasskeys = false) }
                }
            } catch (e: Exception) {
                updateState { copy(isLoadingPasskeys = false) }
            }
        }
    }

    private fun loadDevices() {
        updateState { copy(isLoadingDevices = true) }
        viewModelScope.launch {
            try {
                val result = trpcClient.query<Unit, List<DeviceResponse>>(
                    DevicesProcedures.LIST,
                    Unit
                )
                result.onSuccess { deviceList ->
                    updateState {
                        copy(
                            devices = deviceList.map { device ->
                                DeviceItem(
                                    id = device.id,
                                    deviceId = device.deviceId,
                                    name = device.encryptedDeviceName,
                                    userAgent = device.userAgent,
                                    lastSeen = device.lastSeen,
                                    createdAt = device.createdAt,
                                    isCurrent = device.deviceId == currentDeviceId
                                )
                            },
                            isLoadingDevices = false
                        )
                    }
                }.onFailure { e ->
                    updateState { copy(isLoadingDevices = false) }
                }
            } catch (e: Exception) {
                updateState { copy(isLoadingDevices = false) }
            }
        }
    }

    private fun changePassword() {
        val state = currentState
        if (state.newPassword.isBlank()) {
            updateState { copy(error = "New password cannot be empty") }
            return
        }
        if (state.newPassword != state.confirmPassword) {
            updateState { copy(error = "Passwords do not match") }
            return
        }
        if (state.newPassword.length < 8) {
            updateState { copy(error = "Password must be at least 8 characters") }
            return
        }
        if (state.isChangingPassword) return

        updateState { copy(isChangingPassword = true) }
        viewModelScope.launch {
            try {
                // Verify current password if one exists
                val hasPassword = e2eeRepository.hasPasswordEncryption()
                if (hasPassword && state.currentPassword.isBlank()) {
                    updateState {
                        copy(isChangingPassword = false, error = "Current password is required")
                    }
                    return@launch
                }

                // Set up new password encryption
                e2eeRepository.setupPasswordEncryption(state.newPassword)

                updateState {
                    copy(
                        isChangingPassword = false,
                        currentPassword = "",
                        newPassword = "",
                        confirmPassword = ""
                    )
                }
                sendEffect(SecuritySettingsEffect.PasswordChanged)
                sendEffect(SecuritySettingsEffect.ShowToast("Password updated successfully"))
            } catch (e: Exception) {
                updateState {
                    copy(isChangingPassword = false, error = e.message ?: "Failed to change password")
                }
            }
        }
    }

    private fun addPasskey(activity: Activity) {
        if (currentState.isAddingPasskey) return
        updateState { copy(isAddingPasskey = true) }

        viewModelScope.launch {
            try {
                e2eeRepository.registerPasskey(null, activity)
                updateState { copy(isAddingPasskey = false) }
                sendEffect(SecuritySettingsEffect.ShowToast("Passkey added successfully"))
                loadPasskeys()
            } catch (e: Exception) {
                updateState {
                    copy(isAddingPasskey = false, error = e.message ?: "Failed to add passkey")
                }
            }
        }
    }

    private fun deletePasskey() {
        val target = currentState.deletePasskeyTarget ?: return
        updateState { copy(deletePasskeyTarget = null) }

        viewModelScope.launch {
            try {
                val result = trpcClient.mutation<WebAuthnDeleteRequest, WebAuthnDeleteResponse>(
                    WebAuthnProcedures.DELETE,
                    WebAuthnDeleteRequest(credentialId = target.credentialId)
                )
                result.onSuccess {
                    sendEffect(SecuritySettingsEffect.ShowToast("Passkey deleted"))
                    loadPasskeys()
                }.onFailure { e ->
                    updateState { copy(error = e.message ?: "Failed to delete passkey") }
                }
            } catch (e: Exception) {
                updateState { copy(error = e.message ?: "Failed to delete passkey") }
            }
        }
    }

    private fun revokeDevice() {
        val target = currentState.revokeDeviceTarget ?: return
        updateState { copy(revokeDeviceTarget = null) }

        viewModelScope.launch {
            try {
                val result = trpcClient.mutation<DeviceRevokeRequest, DeviceRevokeResponse>(
                    DevicesProcedures.REVOKE,
                    DeviceRevokeRequest(deviceId = target.deviceId)
                )
                result.onSuccess {
                    sendEffect(SecuritySettingsEffect.ShowToast("Device revoked"))
                    loadDevices()
                }.onFailure { e ->
                    updateState { copy(error = e.message ?: "Failed to revoke device") }
                }
            } catch (e: Exception) {
                updateState { copy(error = e.message ?: "Failed to revoke device") }
            }
        }
    }

    private fun lockSession() {
        updateState { copy(showLockConfirmation = false) }
        e2eeRepository.lockSession()
        sendEffect(SecuritySettingsEffect.NavigateToUnlock)
    }
}
