package chat.onera.mobile.presentation.features.settings.recovery

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.security.BiometricManager
import chat.onera.mobile.data.security.BiometricResult
import chat.onera.mobile.data.security.KeyManager
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

// ── State ───────────────────────────────────────────────────────────────

data class RecoveryPhraseState(
    val isAuthenticated: Boolean = false,
    val isAuthenticating: Boolean = false,
    val isBiometricAvailable: Boolean = false,
    val recoveryPhrase: List<String> = emptyList(),

    // Verification
    val verificationWordIndex: Int? = null,
    val verificationInput: String = "",
    val verificationResult: Boolean? = null,

    val error: String? = null
) : UiState

// ── Intent ──────────────────────────────────────────────────────────────

sealed interface RecoveryPhraseIntent : UiIntent {
    data class Authenticate(val activity: androidx.fragment.app.FragmentActivity) : RecoveryPhraseIntent
    data object CopyToClipboard : RecoveryPhraseIntent
    data object StartVerification : RecoveryPhraseIntent
    data class UpdateVerificationInput(val value: String) : RecoveryPhraseIntent
    data object CheckVerification : RecoveryPhraseIntent
    data object ResetVerification : RecoveryPhraseIntent
    data object DismissError : RecoveryPhraseIntent
}

// ── Effect ──────────────────────────────────────────────────────────────

sealed interface RecoveryPhraseEffect : UiEffect {
    data class CopyText(val text: String) : RecoveryPhraseEffect
    data class ShowToast(val message: String) : RecoveryPhraseEffect
}

// ── ViewModel ───────────────────────────────────────────────────────────

@HiltViewModel
class RecoveryPhraseViewModel @Inject constructor(
    private val keyManager: KeyManager,
    private val biometricManager: BiometricManager
) : BaseViewModel<RecoveryPhraseState, RecoveryPhraseIntent, RecoveryPhraseEffect>(
    RecoveryPhraseState()
) {

    init {
        updateState { copy(isBiometricAvailable = biometricManager.isBiometricAvailable()) }
    }

    override fun handleIntent(intent: RecoveryPhraseIntent) {
        when (intent) {
            is RecoveryPhraseIntent.Authenticate -> authenticate(intent.activity)
            is RecoveryPhraseIntent.CopyToClipboard -> copyToClipboard()
            is RecoveryPhraseIntent.StartVerification -> startVerification()
            is RecoveryPhraseIntent.UpdateVerificationInput ->
                updateState { copy(verificationInput = intent.value, verificationResult = null) }
            is RecoveryPhraseIntent.CheckVerification -> checkVerification()
            is RecoveryPhraseIntent.ResetVerification -> startVerification()
            is RecoveryPhraseIntent.DismissError -> updateState { copy(error = null) }
        }
    }

    private fun authenticate(activity: androidx.fragment.app.FragmentActivity) {
        if (currentState.isAuthenticating) return
        updateState { copy(isAuthenticating = true) }

        viewModelScope.launch {
            try {
                val result = biometricManager.authenticate(
                    activity = activity,
                    title = "View Recovery Phrase",
                    subtitle = "Authenticate to reveal your recovery phrase"
                )
                when (result) {
                    is BiometricResult.Success -> {
                        val phrase = keyManager.getRecoveryPhrase()
                        if (phrase.isEmpty()) {
                            updateState {
                                copy(
                                    isAuthenticating = false,
                                    error = "No recovery phrase found. Set up encryption first."
                                )
                            }
                        } else {
                            updateState {
                                copy(
                                    isAuthenticating = false,
                                    isAuthenticated = true,
                                    recoveryPhrase = phrase
                                )
                            }
                        }
                    }
                    is BiometricResult.Cancelled -> {
                        updateState { copy(isAuthenticating = false) }
                    }
                    is BiometricResult.Error -> {
                        updateState {
                            copy(isAuthenticating = false, error = result.message)
                        }
                    }
                    is BiometricResult.NotAvailable -> {
                        // Fallback: show phrase without biometric if not available
                        val phrase = keyManager.getRecoveryPhrase()
                        if (phrase.isEmpty()) {
                            updateState {
                                copy(
                                    isAuthenticating = false,
                                    error = "No recovery phrase found. Set up encryption first."
                                )
                            }
                        } else {
                            updateState {
                                copy(
                                    isAuthenticating = false,
                                    isAuthenticated = true,
                                    recoveryPhrase = phrase
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                updateState {
                    copy(isAuthenticating = false, error = e.message ?: "Authentication failed")
                }
            }
        }
    }

    private fun copyToClipboard() {
        val phrase = currentState.recoveryPhrase.joinToString(" ")
        sendEffect(RecoveryPhraseEffect.CopyText(phrase))
        sendEffect(RecoveryPhraseEffect.ShowToast("Recovery phrase copied to clipboard"))
    }

    private fun startVerification() {
        val phrase = currentState.recoveryPhrase
        if (phrase.isEmpty()) return
        val randomIndex = (phrase.indices).random()
        updateState {
            copy(
                verificationWordIndex = randomIndex,
                verificationInput = "",
                verificationResult = null
            )
        }
    }

    private fun checkVerification() {
        val index = currentState.verificationWordIndex ?: return
        val phrase = currentState.recoveryPhrase
        if (index >= phrase.size) return

        val expected = phrase[index].lowercase().trim()
        val actual = currentState.verificationInput.lowercase().trim()
        val isCorrect = expected == actual

        updateState { copy(verificationResult = isCorrect) }

        if (isCorrect) {
            sendEffect(RecoveryPhraseEffect.ShowToast("Correct!"))
        }
    }
}
