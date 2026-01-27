package chat.onera.mobile.presentation.features.e2ee

import chat.onera.mobile.presentation.base.UiIntent

sealed interface E2EESetupIntent : UiIntent {
    data object StartSetup : E2EESetupIntent
    data object GenerateKeys : E2EESetupIntent
    data object PhraseConfirmed : E2EESetupIntent
    data class VerifyWord(val index: Int, val word: String) : E2EESetupIntent
    data object SubmitVerification : E2EESetupIntent
    // Passkey setup
    data object RegisterPasskey : E2EESetupIntent
    data object SkipPasskey : E2EESetupIntent // Now goes to password setup, not skip entirely
    // Password setup (alternative to passkey)
    data class UpdateSetupPassword(val password: String) : E2EESetupIntent
    data class UpdateConfirmPassword(val password: String) : E2EESetupIntent
    data object ToggleSetupPasswordVisibility : E2EESetupIntent
    data object SetupPassword : E2EESetupIntent
    // Complete
    data object CompleteSetup : E2EESetupIntent
    data object GoBack : E2EESetupIntent
    data object ClearError : E2EESetupIntent
}

/**
 * Intents for E2EE Unlock screen
 */
sealed interface E2EEUnlockIntent : UiIntent {
    data object CheckUnlockMethods : E2EEUnlockIntent
    data object UnlockWithPasskey : E2EEUnlockIntent
    data object UnlockWithPassword : E2EEUnlockIntent
    data object UnlockWithRecoveryPhrase : E2EEUnlockIntent
    data class UpdatePassword(val password: String) : E2EEUnlockIntent
    data object TogglePasswordVisibility : E2EEUnlockIntent
    data class UpdateRecoveryWord(val index: Int, val word: String) : E2EEUnlockIntent
    data class UpdatePastedPhrase(val phrase: String) : E2EEUnlockIntent
    data object ToggleInputMode : E2EEUnlockIntent
    data object GoBack : E2EEUnlockIntent
    data object ClearError : E2EEUnlockIntent
    // Reset encryption
    data object ShowResetEncryption : E2EEUnlockIntent
    data class UpdateResetConfirmInput(val input: String) : E2EEUnlockIntent
    data object ConfirmResetEncryption : E2EEUnlockIntent
    data object CancelResetEncryption : E2EEUnlockIntent
}
