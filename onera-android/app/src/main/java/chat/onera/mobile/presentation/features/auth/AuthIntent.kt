package chat.onera.mobile.presentation.features.auth

import chat.onera.mobile.presentation.base.UiIntent

sealed interface AuthIntent : UiIntent {
    data object SignInWithGoogle : AuthIntent
    data object SignInWithApple : AuthIntent
    data object CheckAuthStatus : AuthIntent
    data object ClearError : AuthIntent
    data object SignOut : AuthIntent
    
    /** Activate demo mode for Play Store review */
    data object ActivateDemoMode : AuthIntent
}
