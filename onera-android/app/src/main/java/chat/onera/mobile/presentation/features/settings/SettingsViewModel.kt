package chat.onera.mobile.presentation.features.settings

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.preferences.UserPreferences
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val e2eeRepository: E2EERepository,
    private val chatRepository: ChatRepository,
    private val credentialRepository: CredentialRepository,
    private val userPreferences: UserPreferences
) : BaseViewModel<SettingsState, SettingsIntent, SettingsEffect>(SettingsState()) {

    init {
        loadSettings()
        observeTheme()
    }

    override fun handleIntent(intent: SettingsIntent) {
        when (intent) {
            is SettingsIntent.LoadSettings -> loadSettings()
            is SettingsIntent.SetTheme -> setTheme(intent.theme)
            is SettingsIntent.LockSession -> lockSession()
            is SettingsIntent.SignOut -> signOut()
        }
    }
    
    private fun observeTheme() {
        viewModelScope.launch {
            userPreferences.themeModeFlow.collect { theme ->
                updateState { copy(themeMode = theme) }
            }
        }
    }
    
    private fun signOut() {
        viewModelScope.launch {
            try {
                // Clear encryption key cache
                chatRepository.clearKeyCache()
                // Sign out from Supabase
                authRepository.signOut()
                // Notify UI to navigate
                sendEffect(SettingsEffect.SignOutComplete)
            } catch (e: Exception) {
                sendEffect(SettingsEffect.ShowError(e.message ?: "Failed to sign out"))
            }
        }
    }

    private fun loadSettings() {
        viewModelScope.launch {
            try {
                val user = authRepository.getCurrentUser()
                val hasKeys = e2eeRepository.hasEncryptionKeys()
                val theme = userPreferences.themeModeFlow.first()
                
                // Refresh and get credential count
                credentialRepository.refreshCredentials()
                val credentials = credentialRepository.getCredentials()
                
                updateState { 
                    copy(
                        user = user,
                        isE2EEActive = hasKeys,
                        credentialCount = credentials.size,
                        themeMode = theme,
                        isLoading = false
                    ) 
                }
            } catch (e: Exception) {
                updateState { copy(isLoading = false) }
                sendEffect(SettingsEffect.ShowError(e.message ?: "Failed to load settings"))
            }
        }
    }

    private fun setTheme(theme: String) {
        viewModelScope.launch {
            updateState { copy(themeMode = theme) }
            userPreferences.setThemeMode(theme)
        }
    }

    private fun lockSession() {
        viewModelScope.launch {
            try {
                // Clear chat key cache to "lock" the session
                // The user will need to unlock E2EE again to decrypt chats
                chatRepository.clearKeyCache()
                updateState { copy(isE2EEActive = false) }
                // Navigate to E2EE unlock screen
                sendEffect(SettingsEffect.SessionLocked)
            } catch (e: Exception) {
                sendEffect(SettingsEffect.ShowError(e.message ?: "Failed to lock session"))
            }
        }
    }
}

data class SettingsState(
    val user: User? = null,
    val isE2EEActive: Boolean = true,
    val deviceCount: Int = 1,
    val credentialCount: Int = 0,
    val themeMode: String = "System",
    val appVersion: String = "1.0.0",
    val isLoading: Boolean = true
) : UiState

sealed interface SettingsIntent : UiIntent {
    data object LoadSettings : SettingsIntent
    data class SetTheme(val theme: String) : SettingsIntent
    data object LockSession : SettingsIntent
    data object SignOut : SettingsIntent
}

sealed interface SettingsEffect : UiEffect {
    data class ShowError(val message: String) : SettingsEffect
    data object SignOutComplete : SettingsEffect
    data object SessionLocked : SettingsEffect
}
