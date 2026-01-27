package chat.onera.mobile.presentation.features.e2ee

import chat.onera.mobile.presentation.base.UiEffect

sealed interface E2EESetupEffect : UiEffect {
    data object SetupComplete : E2EESetupEffect
    data object NavigateBack : E2EESetupEffect
    data class ShowError(val message: String) : E2EESetupEffect
    data class CopyToClipboard(val text: String) : E2EESetupEffect
}

/**
 * Effects for E2EE Unlock screen
 */
sealed interface E2EEUnlockEffect : UiEffect {
    data object UnlockComplete : E2EEUnlockEffect
    data object NavigateBack : E2EEUnlockEffect
    data class ShowError(val message: String) : E2EEUnlockEffect
    // Reset encryption
    data object ResetComplete : E2EEUnlockEffect // Navigate to setup after reset
}
