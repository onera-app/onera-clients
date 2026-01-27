package chat.onera.mobile.data.security

import android.content.Context
import android.util.Log
import androidx.biometric.BiometricManager as AndroidBiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Result of a biometric authentication attempt.
 */
sealed class BiometricResult {
    data object Success : BiometricResult()
    data class Error(val errorCode: Int, val message: String) : BiometricResult()
    data object Cancelled : BiometricResult()
    data object NotAvailable : BiometricResult()
}

/**
 * Manager for handling biometric (passkey) authentication on Android.
 * Uses AndroidX BiometricPrompt for secure authentication.
 */
@Singleton
class BiometricManager @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "BiometricManager"
    }
    
    private val androidBiometricManager = AndroidBiometricManager.from(context)
    
    private val _isAuthenticating = MutableStateFlow(false)
    val isAuthenticating: StateFlow<Boolean> = _isAuthenticating.asStateFlow()
    
    // Channel for async result delivery
    private var resultChannel: Channel<BiometricResult>? = null
    
    /**
     * Check if biometric authentication is available on this device.
     */
    fun isBiometricAvailable(): Boolean {
        return when (androidBiometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
            AndroidBiometricManager.Authenticators.DEVICE_CREDENTIAL
        )) {
            AndroidBiometricManager.BIOMETRIC_SUCCESS -> true
            else -> false
        }
    }
    
    /**
     * Check if strong biometric (fingerprint/face) is available.
     */
    fun isStrongBiometricAvailable(): Boolean {
        return androidBiometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG
        ) == AndroidBiometricManager.BIOMETRIC_SUCCESS
    }
    
    /**
     * Get a human-readable status of biometric availability.
     */
    fun getBiometricStatus(): String {
        return when (androidBiometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
            AndroidBiometricManager.Authenticators.DEVICE_CREDENTIAL
        )) {
            AndroidBiometricManager.BIOMETRIC_SUCCESS -> "Available"
            AndroidBiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "No biometric hardware"
            AndroidBiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "Hardware unavailable"
            AndroidBiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "No biometrics enrolled"
            AndroidBiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "Security update required"
            else -> "Unknown status"
        }
    }
    
    /**
     * Authenticate using biometrics.
     * Must be called from a FragmentActivity context.
     * 
     * @param activity The FragmentActivity to show the prompt from
     * @param title Title of the biometric prompt
     * @param subtitle Subtitle/description of the prompt
     * @param negativeButtonText Text for the cancel/negative button
     * @return BiometricResult indicating success, error, or cancellation
     */
    suspend fun authenticate(
        activity: FragmentActivity,
        title: String = "Unlock Onera",
        subtitle: String = "Use your fingerprint or face to unlock",
        negativeButtonText: String = "Cancel"
    ): BiometricResult {
        if (!isBiometricAvailable()) {
            Log.w(TAG, "Biometric not available: ${getBiometricStatus()}")
            return BiometricResult.NotAvailable
        }
        
        _isAuthenticating.value = true
        resultChannel = Channel(Channel.RENDEZVOUS)
        
        val executor = ContextCompat.getMainExecutor(context)
        
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                Log.d(TAG, "Authentication error: $errorCode - $errString")
                _isAuthenticating.value = false
                
                val result = when (errorCode) {
                    BiometricPrompt.ERROR_USER_CANCELED,
                    BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                    BiometricPrompt.ERROR_CANCELED -> BiometricResult.Cancelled
                    else -> BiometricResult.Error(errorCode, errString.toString())
                }
                
                resultChannel?.trySend(result)
            }
            
            override fun onAuthenticationFailed() {
                Log.d(TAG, "Authentication failed (biometric not recognized)")
                // Don't send result - prompt will retry automatically
            }
            
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                Log.d(TAG, "Authentication succeeded")
                _isAuthenticating.value = false
                resultChannel?.trySend(BiometricResult.Success)
            }
        }
        
        val biometricPrompt = BiometricPrompt(activity, executor, callback)
        
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(
                AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
                AndroidBiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()
        
        try {
            biometricPrompt.authenticate(promptInfo)
            
            // Wait for result
            val result = resultChannel?.receive() ?: BiometricResult.Error(-1, "Unknown error")
            resultChannel?.close()
            resultChannel = null
            return result
        } catch (e: Exception) {
            Log.e(TAG, "Error showing biometric prompt", e)
            _isAuthenticating.value = false
            resultChannel?.close()
            resultChannel = null
            return BiometricResult.Error(-1, e.message ?: "Unknown error")
        }
    }
    
    /**
     * Cancel any ongoing authentication.
     */
    fun cancelAuthentication() {
        _isAuthenticating.value = false
        resultChannel?.trySend(BiometricResult.Cancelled)
        resultChannel?.close()
        resultChannel = null
    }
}
