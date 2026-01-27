package chat.onera.mobile.presentation.features.e2ee

import android.app.Activity
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.security.PasskeyManager
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * E2EE Setup ViewModel - matches web flow order:
 * 1. Intro
 * 2. Generate Keys
 * 3. Setup Passkey (if supported) OR Setup Password
 * 4. Show Recovery Phrase (AFTER unlock method is set up)
 * 5. Verify Recovery Phrase
 * 6. Complete
 */
@HiltViewModel
class E2EESetupViewModel @Inject constructor(
    private val e2eeRepository: E2EERepository,
    private val passkeyManager: PasskeyManager
) : BaseViewModel<E2EESetupState, E2EESetupIntent, E2EESetupEffect>(E2EESetupState()) {

    // Activity reference for passkey registration
    private var activity: Activity? = null
    
    init {
        // Check if passkey is supported on this device
        updateState { copy(isPasskeySupported = passkeyManager.isPasskeySupported()) }
    }
    
    /**
     * Set the activity for passkey registration. Must be called from the screen.
     */
    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun handleIntent(intent: E2EESetupIntent) {
        when (intent) {
            is E2EESetupIntent.StartSetup -> startSetup()
            is E2EESetupIntent.GenerateKeys -> generateKeys()
            is E2EESetupIntent.PhraseConfirmed -> phraseConfirmed()
            is E2EESetupIntent.VerifyWord -> verifyWord(intent.index, intent.word)
            is E2EESetupIntent.SubmitVerification -> submitVerification()
            // Passkey
            is E2EESetupIntent.RegisterPasskey -> registerPasskey()
            is E2EESetupIntent.SkipPasskey -> skipPasskeyUsePassword()
            // Password
            is E2EESetupIntent.UpdateSetupPassword -> updatePassword(intent.password)
            is E2EESetupIntent.UpdateConfirmPassword -> updateConfirmPassword(intent.password)
            is E2EESetupIntent.ToggleSetupPasswordVisibility -> togglePasswordVisibility()
            is E2EESetupIntent.SetupPassword -> setupPassword()
            // Complete
            is E2EESetupIntent.CompleteSetup -> completeSetup()
            is E2EESetupIntent.GoBack -> goBack()
            is E2EESetupIntent.ClearError -> updateState { copy(error = null) }
        }
    }

    private fun startSetup() {
        updateState { copy(step = E2EESetupStep.GENERATING_KEYS) }
        generateKeys()
    }

    private fun generateKeys() {
        viewModelScope.launch {
            updateState { copy(isLoading = true, error = null) }
            try {
                // Use the new setupNewUser which generates keys AND syncs to server
                val recoveryPhrase = e2eeRepository.setupNewUser()
                val words = recoveryPhrase.trim().split("\\s+".toRegex())
                
                // After generating keys, go to passkey setup (if supported) or password setup
                val nextStep = if (currentState.isPasskeySupported) {
                    E2EESetupStep.SETUP_PASSKEY
                } else {
                    E2EESetupStep.SETUP_PASSWORD
                }
                
                updateState { 
                    copy(
                        isLoading = false,
                        recoveryPhrase = words,
                        step = nextStep
                    )
                }
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isLoading = false, 
                        error = e.message ?: "Failed to generate keys",
                        step = E2EESetupStep.INTRO
                    ) 
                }
            }
        }
    }

    // ===== Passkey Setup =====
    
    private fun registerPasskey() {
        val currentActivity = activity
        if (currentActivity == null) {
            updateState { copy(error = "Unable to register passkey") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isRegisteringPasskey = true, error = null) }
            try {
                e2eeRepository.registerPasskey("Android Device", currentActivity)
                updateState { 
                    copy(
                        isRegisteringPasskey = false,
                        passkeyRegistered = true,
                        // After passkey registered, show recovery phrase
                        step = E2EESetupStep.SHOW_RECOVERY_PHRASE
                    )
                }
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isRegisteringPasskey = false,
                        error = e.message ?: "Failed to register passkey"
                    )
                }
            }
        }
    }
    
    private fun skipPasskeyUsePassword() {
        // User doesn't want passkey - must set up password instead
        // Can't skip BOTH unlock methods
        updateState { copy(step = E2EESetupStep.SETUP_PASSWORD) }
    }
    
    // ===== Password Setup =====
    
    private fun updatePassword(password: String) {
        updateState { copy(password = password, error = null) }
    }
    
    private fun updateConfirmPassword(password: String) {
        updateState { copy(confirmPassword = password, error = null) }
    }
    
    private fun togglePasswordVisibility() {
        updateState { copy(showPassword = !showPassword) }
    }
    
    private fun setupPassword() {
        val password = currentState.password
        val confirmPassword = currentState.confirmPassword
        
        // Validate
        if (password.length < 8) {
            updateState { copy(error = "Password must be at least 8 characters") }
            return
        }
        
        if (password != confirmPassword) {
            updateState { copy(error = "Passwords do not match") }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isSettingUpPassword = true, error = null) }
            try {
                e2eeRepository.setupPasswordEncryption(password)
                updateState { 
                    copy(
                        isSettingUpPassword = false,
                        passwordSetUp = true,
                        // Clear password from state for security
                        password = "",
                        confirmPassword = "",
                        // After password set up, show recovery phrase
                        step = E2EESetupStep.SHOW_RECOVERY_PHRASE
                    )
                }
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isSettingUpPassword = false,
                        error = e.message ?: "Failed to set up password"
                    )
                }
            }
        }
    }

    // ===== Recovery Phrase =====

    private fun phraseConfirmed() {
        // Select 3 random words for verification
        val phrase = currentState.recoveryPhrase
        if (phrase.size < 12) return
        
        val indices = (0 until phrase.size).shuffled().take(3).sorted()
        val verificationWords = indices.map { IndexedWord(it, phrase[it]) }
        
        updateState { 
            copy(
                step = E2EESetupStep.VERIFY_RECOVERY_PHRASE,
                verificationWords = verificationWords,
                userInputWords = emptyMap()
            )
        }
    }

    private fun verifyWord(index: Int, word: String) {
        updateState { 
            copy(userInputWords = userInputWords + (index to word.lowercase().trim()))
        }
    }

    private fun submitVerification() {
        val isValid = currentState.verificationWords.all { indexed ->
            currentState.userInputWords[indexed.index]?.equals(indexed.word, ignoreCase = true) == true
        }
        
        if (isValid) {
            updateState { 
                copy(
                    isVerified = true,
                    step = E2EESetupStep.COMPLETE
                )
            }
        } else {
            updateState { copy(error = "Verification failed. Please check your words.") }
        }
    }

    // ===== Complete =====

    private fun completeSetup() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                // Finalize key setup
                e2eeRepository.finalizeKeySetup()
                updateState { copy(isLoading = false) }
                sendEffect(E2EESetupEffect.SetupComplete)
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isLoading = false, 
                        error = e.message ?: "Failed to complete setup"
                    ) 
                }
            }
        }
    }

    // ===== Navigation =====

    private fun goBack() {
        val previousStep = when (currentState.step) {
            E2EESetupStep.INTRO -> {
                sendEffect(E2EESetupEffect.NavigateBack)
                return
            }
            E2EESetupStep.GENERATING_KEYS -> E2EESetupStep.INTRO
            E2EESetupStep.SETUP_PASSKEY -> {
                // Can't go back from passkey to generating (keys already generated)
                // User can only proceed with passkey or password
                E2EESetupStep.SETUP_PASSKEY // Stay here
            }
            E2EESetupStep.SETUP_PASSWORD -> {
                // Can go back to passkey if supported
                if (currentState.isPasskeySupported) {
                    E2EESetupStep.SETUP_PASSKEY
                } else {
                    // Can't go back if passkey not supported
                    E2EESetupStep.SETUP_PASSWORD
                }
            }
            E2EESetupStep.SHOW_RECOVERY_PHRASE -> {
                // Can't go back - unlock method already set up
                // Recovery phrase is shown AFTER passkey/password
                E2EESetupStep.SHOW_RECOVERY_PHRASE
            }
            E2EESetupStep.VERIFY_RECOVERY_PHRASE -> E2EESetupStep.SHOW_RECOVERY_PHRASE
            E2EESetupStep.COMPLETE -> E2EESetupStep.VERIFY_RECOVERY_PHRASE
        }
        updateState { copy(step = previousStep, error = null) }
    }
}
