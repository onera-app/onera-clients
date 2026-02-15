package chat.onera.mobile.presentation.features.settings.tools

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.preferences.UserPreferences
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Supported external search providers.
 */
enum class SearchProvider(val displayName: String, val description: String) {
    TAVILY("Tavily", "AI-optimized search API with structured results"),
    SERPER("Serper", "Google Search API with fast, affordable results"),
    BRAVE("Brave", "Privacy-focused search with independent index"),
    EXA("Exa", "Neural search engine for high-quality content")
}

// State
data class ToolsSettingsState(
    val webSearchEnabled: Boolean = UserPreferences.DEFAULT_WEB_SEARCH_ENABLED,
    val webSearchProvider: String = UserPreferences.DEFAULT_WEB_SEARCH_PROVIDER,
    val googleSearchEnabled: Boolean = UserPreferences.DEFAULT_GOOGLE_SEARCH_ENABLED,
    val xaiSearchEnabled: Boolean = UserPreferences.DEFAULT_XAI_SEARCH_ENABLED,
    val tavilyApiKey: String = "",
    val serperApiKey: String = "",
    val braveApiKey: String = "",
    val exaApiKey: String = ""
) : UiState

// Intent
sealed interface ToolsSettingsIntent : UiIntent {
    data class SetWebSearchEnabled(val value: Boolean) : ToolsSettingsIntent
    data class SetWebSearchProvider(val value: String) : ToolsSettingsIntent
    data class SetGoogleSearchEnabled(val value: Boolean) : ToolsSettingsIntent
    data class SetXaiSearchEnabled(val value: Boolean) : ToolsSettingsIntent
    data class SaveProviderApiKey(val provider: String, val key: String) : ToolsSettingsIntent
    data class DeleteProviderApiKey(val provider: String) : ToolsSettingsIntent
}

// Effect
sealed interface ToolsSettingsEffect : UiEffect {
    data class ApiKeySaved(val provider: String) : ToolsSettingsEffect
    data class ApiKeyDeleted(val provider: String) : ToolsSettingsEffect
    data class ShowError(val message: String) : ToolsSettingsEffect
}

@HiltViewModel
class ToolsSettingsViewModel @Inject constructor(
    private val userPreferences: UserPreferences
) : BaseViewModel<ToolsSettingsState, ToolsSettingsIntent, ToolsSettingsEffect>(
    ToolsSettingsState()
) {

    init {
        observePreferences()
    }

    private fun observePreferences() {
        viewModelScope.launch {
            userPreferences.webSearchEnabledFlow.collect { updateState { copy(webSearchEnabled = it) } }
        }
        viewModelScope.launch {
            userPreferences.webSearchProviderFlow.collect { updateState { copy(webSearchProvider = it) } }
        }
        viewModelScope.launch {
            userPreferences.googleSearchEnabledFlow.collect { updateState { copy(googleSearchEnabled = it) } }
        }
        viewModelScope.launch {
            userPreferences.xaiSearchEnabledFlow.collect { updateState { copy(xaiSearchEnabled = it) } }
        }
        viewModelScope.launch {
            userPreferences.tavilyApiKeyFlow.collect { updateState { copy(tavilyApiKey = it) } }
        }
        viewModelScope.launch {
            userPreferences.serperApiKeyFlow.collect { updateState { copy(serperApiKey = it) } }
        }
        viewModelScope.launch {
            userPreferences.braveApiKeyFlow.collect { updateState { copy(braveApiKey = it) } }
        }
        viewModelScope.launch {
            userPreferences.exaApiKeyFlow.collect { updateState { copy(exaApiKey = it) } }
        }
    }

    override fun handleIntent(intent: ToolsSettingsIntent) {
        when (intent) {
            is ToolsSettingsIntent.SetWebSearchEnabled -> viewModelScope.launch {
                userPreferences.setWebSearchEnabled(intent.value)
            }
            is ToolsSettingsIntent.SetWebSearchProvider -> viewModelScope.launch {
                userPreferences.setWebSearchProvider(intent.value)
            }
            is ToolsSettingsIntent.SetGoogleSearchEnabled -> viewModelScope.launch {
                userPreferences.setGoogleSearchEnabled(intent.value)
            }
            is ToolsSettingsIntent.SetXaiSearchEnabled -> viewModelScope.launch {
                userPreferences.setXaiSearchEnabled(intent.value)
            }
            is ToolsSettingsIntent.SaveProviderApiKey -> saveApiKey(intent.provider, intent.key)
            is ToolsSettingsIntent.DeleteProviderApiKey -> deleteApiKey(intent.provider)
        }
    }

    private fun saveApiKey(provider: String, key: String) {
        if (key.isBlank()) {
            sendEffect(ToolsSettingsEffect.ShowError("API key cannot be empty"))
            return
        }
        viewModelScope.launch {
            try {
                when (provider) {
                    "Tavily" -> userPreferences.setTavilyApiKey(key)
                    "Serper" -> userPreferences.setSerperApiKey(key)
                    "Brave" -> userPreferences.setBraveApiKey(key)
                    "Exa" -> userPreferences.setExaApiKey(key)
                }
                sendEffect(ToolsSettingsEffect.ApiKeySaved(provider))
            } catch (e: Exception) {
                sendEffect(ToolsSettingsEffect.ShowError("Failed to save API key: ${e.message}"))
            }
        }
    }

    private fun deleteApiKey(provider: String) {
        viewModelScope.launch {
            try {
                userPreferences.deleteSearchProviderApiKey(provider)
                sendEffect(ToolsSettingsEffect.ApiKeyDeleted(provider))
            } catch (e: Exception) {
                sendEffect(ToolsSettingsEffect.ShowError("Failed to delete API key: ${e.message}"))
            }
        }
    }

    fun getApiKeyForProvider(provider: SearchProvider): String {
        return when (provider) {
            SearchProvider.TAVILY -> currentState.tavilyApiKey
            SearchProvider.SERPER -> currentState.serperApiKey
            SearchProvider.BRAVE -> currentState.braveApiKey
            SearchProvider.EXA -> currentState.exaApiKey
        }
    }
}
