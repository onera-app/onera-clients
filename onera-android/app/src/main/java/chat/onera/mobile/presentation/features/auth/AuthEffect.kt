package chat.onera.mobile.presentation.features.auth

import chat.onera.mobile.presentation.base.UiEffect

sealed interface AuthEffect : UiEffect {
    data object NavigateToMain : AuthEffect
    data object NavigateToE2EESetup : AuthEffect
    data object NavigateToE2EEUnlock : AuthEffect
    data class ShowError(val message: String) : AuthEffect
    data class LaunchGoogleSignIn(val intent: android.content.Intent) : AuthEffect
}
