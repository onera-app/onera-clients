package chat.onera.mobile.presentation.features.auth

import android.util.Log
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val e2eeRepository: E2EERepository
) : BaseViewModel<AuthState, AuthIntent, AuthEffect>(AuthState()) {

    companion object {
        private const val TAG = "AuthViewModel"
    }

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
        }
    }

    private fun checkAuthStatus() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                // Give Clerk SDK time to load
                delay(500)
                
                Log.d(TAG, "Checking authentication status...")
                val isAuthenticated = authRepository.isAuthenticated()
                Log.d(TAG, "isAuthenticated: $isAuthenticated")
                
                if (isAuthenticated) {
                    // Query SERVER for E2EE setup status (not just local)
                    // This matches iOS AppCoordinator behavior
                    val hasServerE2EEKeys = e2eeRepository.checkSetupStatus()
                    Log.d(TAG, "hasServerE2EEKeys: $hasServerE2EEKeys")
                    
                    if (!hasServerE2EEKeys) {
                        // New user - needs E2EE setup (onboarding -> setup -> recovery phrase)
                        Log.d(TAG, "New user - navigating to E2EE Setup")
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
                        Log.d(TAG, "isSessionUnlocked: $isSessionUnlocked")
                        
                        if (isSessionUnlocked) {
                            // Session already unlocked (e.g., app was backgrounded)
                            Log.d(TAG, "Session unlocked - navigating to Main")
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
                            Log.d(TAG, "Session locked - navigating to E2EE Unlock")
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
                    Log.d(TAG, "Not authenticated, showing login screen")
                    updateState { copy(isLoading = false, isAuthenticated = false) }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking auth status: ${e.message}", e)
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
