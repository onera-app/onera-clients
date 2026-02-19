package chat.onera.mobile.presentation.features.auth

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.demo.DemoData
import chat.onera.mobile.demo.DemoModeManager
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val e2eeRepository: E2EERepository
) : BaseViewModel<AuthState, AuthIntent, AuthEffect>(AuthState()) {

    init {
        sendIntent(AuthIntent.CheckAuthStatus)
    }

    override fun handleIntent(intent: AuthIntent) {
        when (intent) {
            is AuthIntent.SignInWithGoogle -> handleGoogleSignIn()
            is AuthIntent.SignInWithApple -> handleAppleSignIn()
            is AuthIntent.CheckAuthStatus -> checkAuthStatus()
            is AuthIntent.ClearError -> updateState { copy(error = null) }
            is AuthIntent.SignOut -> handleSignOut()
            is AuthIntent.ActivateDemoMode -> handleDemoModeActivation()
        }
    }
    
    /**
     * Handle demo mode activation for Play Store review.
     * Bypasses real authentication and E2EE setup.
     */
    private fun handleDemoModeActivation() {
        Timber.d("Demo mode activation requested")
        
        viewModelScope.launch {
            updateState { copy(isLoading = true, authMethod = AuthMethod.DEMO) }
            
            // Small delay for visual feedback
            delay(500)
            
            // Demo mode skips E2EE - go directly to main
            Timber.d("Demo mode activated - navigating to main")
            updateState { 
                copy(
                    isLoading = false,
                    isAuthenticated = true,
                    needsE2EESetup = false,
                    authMethod = AuthMethod.DEMO
                )
            }
            sendEffect(AuthEffect.NavigateToMain)
        }
    }

    private fun checkAuthStatus() {
        // In demo mode, skip auth check
        if (DemoModeManager.isActiveNow()) {
            Timber.d("Demo mode active - skipping auth check")
            updateState { 
                copy(
                    isLoading = false,
                    isAuthenticated = true,
                    needsE2EESetup = false
                )
            }
            sendEffect(AuthEffect.NavigateToMain)
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                Timber.d("Checking authentication status...")
                val isAuthenticated = authRepository.isAuthenticated()
                Timber.d("isAuthenticated: $isAuthenticated")
                
                if (isAuthenticated) {
                    // Query SERVER for E2EE setup status (not just local)
                    // This matches iOS AppCoordinator behavior
                    val hasServerE2EEKeys = e2eeRepository.checkSetupStatus()
                    Timber.d("hasServerE2EEKeys: $hasServerE2EEKeys")
                    
                    if (!hasServerE2EEKeys) {
                        // New user - needs E2EE setup (onboarding -> setup -> recovery phrase)
                        Timber.d("New user - navigating to E2EE Setup")
                        updateState { 
                            copy(
                                isLoading = false, 
                                isAuthenticated = true,
                                needsE2EESetup = true
                            ) 
                        }
                        sendEffect(AuthEffect.NavigateToE2EESetup)
                    } else {
                        // Returning user - check if session is already unlocked
                        val isSessionUnlocked = e2eeRepository.isSessionUnlocked()
                        Timber.d("isSessionUnlocked: $isSessionUnlocked")
                        
                        if (isSessionUnlocked) {
                            // Session already unlocked (e.g., app was backgrounded)
                            Timber.d("Session unlocked - navigating to Main")
                            updateState { 
                                copy(
                                    isLoading = false, 
                                    isAuthenticated = true,
                                    needsE2EESetup = false
                                ) 
                            }
                            sendEffect(AuthEffect.NavigateToMain)
                        } else {
                            // Session locked - needs unlock (password/passkey/recovery)
                            Timber.d("Session locked - navigating to E2EE Unlock")
                            updateState { 
                                copy(
                                    isLoading = false, 
                                    isAuthenticated = true,
                                    needsE2EESetup = false
                                ) 
                            }
                            sendEffect(AuthEffect.NavigateToE2EEUnlock)
                        }
                    }
                } else {
                    Timber.d("Not authenticated, showing login screen")
                    updateState { copy(isLoading = false, isAuthenticated = false) }
                }
            } catch (e: Exception) {
                Timber.e(e, "Error checking auth status")
                updateState { copy(isLoading = false, error = e.message) }
            }
        }
    }

    private fun handleGoogleSignIn() {
        viewModelScope.launch {
            updateState { copy(isLoading = true, authMethod = AuthMethod.GOOGLE) }
            try {
                authRepository.signInWithGoogle()
                checkAuthStatus()
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isLoading = false, 
                        error = e.message ?: "Google sign in failed",
                        authMethod = AuthMethod.NONE
                    ) 
                }
            }
        }
    }

    private fun handleAppleSignIn() {
        viewModelScope.launch {
            updateState { copy(isLoading = true, authMethod = AuthMethod.APPLE) }
            try {
                authRepository.signInWithApple()
                checkAuthStatus()
            } catch (e: Exception) {
                updateState { 
                    copy(
                        isLoading = false, 
                        error = e.message ?: "Apple sign in failed",
                        authMethod = AuthMethod.NONE
                    ) 
                }
            }
        }
    }

    private fun handleSignOut() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                authRepository.signOut()
                updateState { AuthState() }
            } catch (e: Exception) {
                updateState { copy(isLoading = false, error = e.message) }
            }
        }
    }
}
