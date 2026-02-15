package chat.onera.mobile.presentation.features.settings.general

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.preferences.UserPreferences
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

// State
data class GeneralSettingsState(
    val systemPrompt: String = UserPreferences.DEFAULT_SYSTEM_PROMPT,
    val streamResponse: Boolean = UserPreferences.DEFAULT_STREAM_RESPONSE,
    val temperature: Float = UserPreferences.DEFAULT_TEMPERATURE,
    val topP: Float = UserPreferences.DEFAULT_TOP_P,
    val topK: Int = UserPreferences.DEFAULT_TOP_K,
    val maxTokens: Int = UserPreferences.DEFAULT_MAX_TOKENS,
    val frequencyPenalty: Float = UserPreferences.DEFAULT_FREQUENCY_PENALTY,
    val presencePenalty: Float = UserPreferences.DEFAULT_PRESENCE_PENALTY,
    val seed: Int = UserPreferences.DEFAULT_SEED,
    // Provider-specific
    val openaiReasoningEffort: String = UserPreferences.DEFAULT_OPENAI_REASONING_EFFORT,
    val openaiReasoningSummary: String = UserPreferences.DEFAULT_OPENAI_REASONING_SUMMARY,
    val anthropicExtendedThinking: Boolean = UserPreferences.DEFAULT_ANTHROPIC_EXTENDED_THINKING
) : UiState

// Intent
sealed interface GeneralSettingsIntent : UiIntent {
    data class SetSystemPrompt(val value: String) : GeneralSettingsIntent
    data class SetStreamResponse(val value: Boolean) : GeneralSettingsIntent
    data class SetTemperature(val value: Float) : GeneralSettingsIntent
    data class SetTopP(val value: Float) : GeneralSettingsIntent
    data class SetTopK(val value: Int) : GeneralSettingsIntent
    data class SetMaxTokens(val value: Int) : GeneralSettingsIntent
    data class SetFrequencyPenalty(val value: Float) : GeneralSettingsIntent
    data class SetPresencePenalty(val value: Float) : GeneralSettingsIntent
    data class SetSeed(val value: Int) : GeneralSettingsIntent
    // Provider-specific
    data class SetOpenaiReasoningEffort(val value: String) : GeneralSettingsIntent
    data class SetOpenaiReasoningSummary(val value: String) : GeneralSettingsIntent
    data class SetAnthropicExtendedThinking(val value: Boolean) : GeneralSettingsIntent
    data object ResetDefaults : GeneralSettingsIntent
}

// Effect
sealed interface GeneralSettingsEffect : UiEffect {
    data object DefaultsReset : GeneralSettingsEffect
}

@HiltViewModel
class GeneralSettingsViewModel @Inject constructor(
    private val userPreferences: UserPreferences
) : BaseViewModel<GeneralSettingsState, GeneralSettingsIntent, GeneralSettingsEffect>(
    GeneralSettingsState()
) {

    init {
        observePreferences()
    }

    private fun observePreferences() {
        viewModelScope.launch {
            userPreferences.systemPromptFlow.collect { updateState { copy(systemPrompt = it) } }
        }
        viewModelScope.launch {
            userPreferences.streamResponseFlow.collect { updateState { copy(streamResponse = it) } }
        }
        viewModelScope.launch {
            userPreferences.temperatureFlow.collect { updateState { copy(temperature = it) } }
        }
        viewModelScope.launch {
            userPreferences.topPFlow.collect { updateState { copy(topP = it) } }
        }
        viewModelScope.launch {
            userPreferences.topKFlow.collect { updateState { copy(topK = it) } }
        }
        viewModelScope.launch {
            userPreferences.maxTokensFlow.collect { updateState { copy(maxTokens = it) } }
        }
        viewModelScope.launch {
            userPreferences.frequencyPenaltyFlow.collect { updateState { copy(frequencyPenalty = it) } }
        }
        viewModelScope.launch {
            userPreferences.presencePenaltyFlow.collect { updateState { copy(presencePenalty = it) } }
        }
        viewModelScope.launch {
            userPreferences.seedFlow.collect { updateState { copy(seed = it) } }
        }
        viewModelScope.launch {
            userPreferences.openaiReasoningEffortFlow.collect { updateState { copy(openaiReasoningEffort = it) } }
        }
        viewModelScope.launch {
            userPreferences.openaiReasoningSummaryFlow.collect { updateState { copy(openaiReasoningSummary = it) } }
        }
        viewModelScope.launch {
            userPreferences.anthropicExtendedThinkingFlow.collect { updateState { copy(anthropicExtendedThinking = it) } }
        }
    }

    override fun handleIntent(intent: GeneralSettingsIntent) {
        when (intent) {
            is GeneralSettingsIntent.SetSystemPrompt -> setSystemPrompt(intent.value)
            is GeneralSettingsIntent.SetStreamResponse -> setStreamResponse(intent.value)
            is GeneralSettingsIntent.SetTemperature -> setTemperature(intent.value)
            is GeneralSettingsIntent.SetTopP -> setTopP(intent.value)
            is GeneralSettingsIntent.SetTopK -> setTopK(intent.value)
            is GeneralSettingsIntent.SetMaxTokens -> setMaxTokens(intent.value)
            is GeneralSettingsIntent.SetFrequencyPenalty -> setFrequencyPenalty(intent.value)
            is GeneralSettingsIntent.SetPresencePenalty -> setPresencePenalty(intent.value)
            is GeneralSettingsIntent.SetSeed -> setSeed(intent.value)
            is GeneralSettingsIntent.SetOpenaiReasoningEffort -> setOpenaiReasoningEffort(intent.value)
            is GeneralSettingsIntent.SetOpenaiReasoningSummary -> setOpenaiReasoningSummary(intent.value)
            is GeneralSettingsIntent.SetAnthropicExtendedThinking -> setAnthropicExtendedThinking(intent.value)
            is GeneralSettingsIntent.ResetDefaults -> resetDefaults()
        }
    }

    private fun setSystemPrompt(value: String) {
        viewModelScope.launch { userPreferences.setSystemPrompt(value) }
    }

    private fun setStreamResponse(value: Boolean) {
        viewModelScope.launch { userPreferences.setStreamResponse(value) }
    }

    private fun setTemperature(value: Float) {
        viewModelScope.launch { userPreferences.setTemperature(value) }
    }

    private fun setTopP(value: Float) {
        viewModelScope.launch { userPreferences.setTopP(value) }
    }

    private fun setTopK(value: Int) {
        viewModelScope.launch { userPreferences.setTopK(value) }
    }

    private fun setMaxTokens(value: Int) {
        viewModelScope.launch { userPreferences.setMaxTokens(value) }
    }

    private fun setFrequencyPenalty(value: Float) {
        viewModelScope.launch { userPreferences.setFrequencyPenalty(value) }
    }

    private fun setPresencePenalty(value: Float) {
        viewModelScope.launch { userPreferences.setPresencePenalty(value) }
    }

    private fun setSeed(value: Int) {
        viewModelScope.launch { userPreferences.setSeed(value) }
    }

    private fun setOpenaiReasoningEffort(value: String) {
        viewModelScope.launch { userPreferences.setOpenaiReasoningEffort(value) }
    }

    private fun setOpenaiReasoningSummary(value: String) {
        viewModelScope.launch { userPreferences.setOpenaiReasoningSummary(value) }
    }

    private fun setAnthropicExtendedThinking(value: Boolean) {
        viewModelScope.launch { userPreferences.setAnthropicExtendedThinking(value) }
    }

    private fun resetDefaults() {
        viewModelScope.launch {
            userPreferences.resetGeneralDefaults()
            sendEffect(GeneralSettingsEffect.DefaultsReset)
        }
    }
}
