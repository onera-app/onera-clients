package chat.onera.mobile.presentation.features.e2ee

import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.security.BiometricManager
import chat.onera.mobile.data.security.BiometricResult
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for E2EE Unlock screen
 * Handles unlock flow for returning users
 */
@HiltViewModel
class E2EEUnlockViewModel @Inject constructor(
    private val e2eeRepository: E2EERepository,
    private val biometricManager: BiometricManager
) : BaseViewModel<E2EEUnlockState, E2EEUnlockIntent, E2EEUnlockEffect>(E2EEUnlockState()) {

    // Activity reference for biometric prompts
    private var activity: FragmentActivity? = null

    init {
        checkUnlockMethods()
    }
    
    /**
     * Set the activity for biometric prompts. Must be called from the screen.
     */
    fun setActivity(activity: FragmentActivity?) {
        this.activity = activity
    }

    override fun handleIntent(intent: E2EEUnlockIntent) {
        when (intent) {
            is E2EEUnlockIntent.CheckUnlockMethods -> checkUnlockMethods()
            is E2EEUnlockIntent.UnlockWithPasskey -> unlockWithPasskey()
            is E2EEUnlockIntent.UnlockWithPassword -> unlockWithPassword()
            is E2EEUnlockIntent.UnlockWithRecoveryPhrase -> unlockWithRecoveryPhrase()
            is E2EEUnlockIntent.UpdatePassword -> updatePassword(intent.password)
            is E2EEUnlockIntent.TogglePasswordVisibility -> togglePasswordVisibility()
            is E2EEUnlockIntent.UpdateRecoveryWord -> updateRecoveryWord(intent.index, intent.word)
            is E2EEUnlockIntent.UpdatePastedPhrase -> updatePastedPhrase(intent.phrase)
            is E2EEUnlockIntent.ToggleInputMode -> toggleInputMode()
            is E2EEUnlockIntent.GoBack -> sendEffect(E2EEUnlockEffect.NavigateBack)
            is E2EEUnlockIntent.ClearError -> updateState { copy(error = null) }
            // Reset encryption
            is E2EEUnlockIntent.ShowResetEncryption -> showResetEncryption()
            is E2EEUnlockIntent.UpdateResetConfirmInput -> updateResetConfirmInput(intent.input)
            is E2EEUnlockIntent.ConfirmResetEncryption -> confirmResetEncryption()
            is E2EEUnlockIntent.CancelResetEncryption -> cancelResetEncryption()
        }
    }

    private fun checkUnlockMethods() {
        viewModelScope.launch {
            updateState { copy(isCheckingMethods = true, error = null) }
            try {
                // Check local passkey KEK first (for biometric unlock)
                val hasLocalPasskey = e2eeRepository.hasLocalPasskey()
                
                // Also check server for registered passkeys (for display purposes)
                val hasServerPasskeys = e2eeRepository.hasServerPasskeys()
                
                // User can use passkey if they have local KEK
                val canUsePasskey = hasLocalPasskey
                
                // Show passkey option if they have server passkeys (even without local KEK)
                // This helps users understand they can register a passkey on this device
                val showPasskeyOption = hasLocalPasskey || hasServerPasskeys
                
                val hasPassword = e2eeRepository.hasPasswordEncryption()
                val hasMultipleOptions = listOf(showPasskeyOption, hasPassword, true).count { it } > 1
                
                updateState { 
                    copy(
                        isCheckingMethods = false,
                        hasPasskey = showPasskeyOption,
                        hasLocalPasskey = hasLocalPasskey,
                        hasPassword = hasPassword,
                        hasMultipleOptions = hasMultipleOptions
                    )
                }
                
                // Auto-unlock with passkey if local KEK is available
                if (hasLocalPasskey) {
                    unlockWithPasskey()
                }
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isCheckingMethods = false,
                        error = e.message ?: "Failed to check unlock methods"
                    ) 
                }
            }
        }
    }

    private fun unlockWithPasskey() {
        val currentActivity = activity
        if (currentActivity == null) {
            updateState { copy(error = "Unable to show passkey prompt") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isUnlocking = true, error = null) }
            
            try {
                // Use the new PRF-based passkey authentication
                // This shows the passkey selector and handles both:
                // 1. Synced passkeys from web (using PRF extension)
                // 2. Local passkeys (using KEK fallback)
                e2eeRepository.unlockWithPasskeyAuth(currentActivity)
                updateState { copy(isUnlocking = false) }
                sendEffect(E2EEUnlockEffect.UnlockComplete)
            } catch (e: androidx.credentials.exceptions.GetCredentialCancellationException) {
                // User cancelled the passkey selection
                updateState { copy(isUnlocking = false) }
            } catch (e: androidx.credentials.exceptions.NoCredentialException) {
                // No matching passkey found
                updateState { 
                    copy(
                        isUnlocking = false,
                        error = "No passkey found. Try another unlock method."
                    ) 
                }
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isUnlocking = false,
                        error = e.message ?: "Failed to unlock with passkey"
                    ) 
                }
            }
        }
    }

    private fun unlockWithPassword() {
        val password = currentState.password
        if (password.isBlank()) {
            updateState { copy(error = "Please enter your password") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isUnlocking = true, error = null) }
            try {
                e2eeRepository.unlockWithPassword(password)
                updateState { copy(isUnlocking = false) }
                sendEffect(E2EEUnlockEffect.UnlockComplete)
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isUnlocking = false,
                        error = e.message ?: "Incorrect password"
                    ) 
                }
            }
        }
    }

    private fun unlockWithRecoveryPhrase() {
        val phrase = if (currentState.showPasteField) {
            currentState.pastedPhrase.trim().split("\\s+".toRegex())
        } else {
            currentState.recoveryWords
        }
        
        if (phrase.size != 24 || phrase.any { it.isBlank() }) {
            updateState { copy(error = "Please enter all 24 words") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isUnlocking = true, error = null) }
            try {
                e2eeRepository.unlockWithRecoveryPhrase(phrase.joinToString(" "))
                updateState { copy(isUnlocking = false) }
                sendEffect(E2EEUnlockEffect.UnlockComplete)
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isUnlocking = false,
                        error = e.message ?: "Invalid recovery phrase"
                    ) 
                }
            }
        }
    }

    private fun updatePassword(password: String) {
        updateState { copy(password = password, error = null) }
    }

    private fun togglePasswordVisibility() {
        updateState { copy(showPassword = !showPassword) }
    }

    private fun updateRecoveryWord(index: Int, word: String) {
        val updatedWords = currentState.recoveryWords.toMutableList()
        if (index in updatedWords.indices) {
            updatedWords[index] = word.lowercase().trim()
            updateState { copy(recoveryWords = updatedWords, error = null) }
        }
    }

    private fun updatePastedPhrase(phrase: String) {
        updateState { copy(pastedPhrase = phrase, error = null) }
        
        // Parse pasted phrase into individual words
        val words = phrase.trim().split("\\s+".toRegex())
        if (words.size == 24) {
            val updatedWords = words.map { it.lowercase().trim() }
            updateState { copy(recoveryWords = updatedWords) }
        }
    }

    private fun toggleInputMode() {
        updateState { copy(showPasteField = !showPasteField, error = null) }
    }
    
    // ===== Reset Encryption =====
    
    private fun showResetEncryption() {
        updateState { 
            copy(
                resetConfirmInput = "",
                resetError = null
            )
        }
    }
    
    private fun updateResetConfirmInput(input: String) {
        updateState { 
            copy(
                resetConfirmInput = input,
                resetError = null
            )
        }
    }
    
    private fun confirmResetEncryption() {
        val confirmInput = currentState.resetConfirmInput
        
        if (confirmInput != "RESET MY ENCRYPTION") {
            updateState { copy(resetError = "Please type exactly: RESET MY ENCRYPTION") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isResetting = true, resetError = null) }
            try {
                e2eeRepository.resetEncryption(confirmInput)
                updateState { copy(isResetting = false) }
                sendEffect(E2EEUnlockEffect.ResetComplete)
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isResetting = false,
                        resetError = e.message ?: "Failed to reset encryption"
                    )
                }
            }
        }
    }
    
    private fun cancelResetEncryption() {
        updateState { 
            copy(
                resetConfirmInput = "",
                resetError = null
            )
        }
    }
}
