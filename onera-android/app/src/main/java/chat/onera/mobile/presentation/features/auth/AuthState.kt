package chat.onera.mobile.presentation.features.auth

import chat.onera.mobile.presentation.base.UiState

data class AuthState(
    val isLoading: Boolean = false,
    val isAuthenticated: Boolean = false,
    val needsE2EESetup: Boolean = false,
    val error: String? = null,
    val authMethod: AuthMethod = AuthMethod.NONE
) : UiState

enum class AuthMethod {
    NONE,
    GOOGLE,
    APPLE,
    DEMO  // For Play Store review mode
}
