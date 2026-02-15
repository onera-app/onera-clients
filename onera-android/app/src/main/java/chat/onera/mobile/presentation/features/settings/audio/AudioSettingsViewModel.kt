package chat.onera.mobile.presentation.features.settings.audio

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
data class AudioSettingsState(
    val ttsEnabled: Boolean = UserPreferences.DEFAULT_TTS_ENABLED,
    val ttsSpeed: Float = UserPreferences.DEFAULT_TTS_SPEED,
    val ttsPitch: Float = UserPreferences.DEFAULT_TTS_PITCH,
    val ttsAutoPlay: Boolean = UserPreferences.DEFAULT_TTS_AUTO_PLAY,
    val sttEnabled: Boolean = UserPreferences.DEFAULT_STT_ENABLED,
    val sttAutoSend: Boolean = UserPreferences.DEFAULT_STT_AUTO_SEND
) : UiState

// Intent
sealed interface AudioSettingsIntent : UiIntent {
    data class SetTtsEnabled(val value: Boolean) : AudioSettingsIntent
    data class SetTtsSpeed(val value: Float) : AudioSettingsIntent
    data class SetTtsPitch(val value: Float) : AudioSettingsIntent
    data class SetTtsAutoPlay(val value: Boolean) : AudioSettingsIntent
    data class SetSttEnabled(val value: Boolean) : AudioSettingsIntent
    data class SetSttAutoSend(val value: Boolean) : AudioSettingsIntent
}

// Effect
sealed interface AudioSettingsEffect : UiEffect

@HiltViewModel
class AudioSettingsViewModel @Inject constructor(
    private val userPreferences: UserPreferences
) : BaseViewModel<AudioSettingsState, AudioSettingsIntent, AudioSettingsEffect>(
    AudioSettingsState()
) {

    init {
        observePreferences()
    }

    private fun observePreferences() {
        viewModelScope.launch {
            userPreferences.ttsEnabledFlow.collect { updateState { copy(ttsEnabled = it) } }
        }
        viewModelScope.launch {
            userPreferences.ttsSpeedFlow.collect { updateState { copy(ttsSpeed = it) } }
        }
        viewModelScope.launch {
            userPreferences.ttsPitchFlow.collect { updateState { copy(ttsPitch = it) } }
        }
        viewModelScope.launch {
            userPreferences.ttsAutoPlayFlow.collect { updateState { copy(ttsAutoPlay = it) } }
        }
        viewModelScope.launch {
            userPreferences.sttEnabledFlow.collect { updateState { copy(sttEnabled = it) } }
        }
        viewModelScope.launch {
            userPreferences.sttAutoSendFlow.collect { updateState { copy(sttAutoSend = it) } }
        }
    }

    override fun handleIntent(intent: AudioSettingsIntent) {
        when (intent) {
            is AudioSettingsIntent.SetTtsEnabled -> viewModelScope.launch {
                userPreferences.setTtsEnabled(intent.value)
            }
            is AudioSettingsIntent.SetTtsSpeed -> viewModelScope.launch {
                userPreferences.setTtsSpeed(intent.value)
            }
            is AudioSettingsIntent.SetTtsPitch -> viewModelScope.launch {
                userPreferences.setTtsPitch(intent.value)
            }
            is AudioSettingsIntent.SetTtsAutoPlay -> viewModelScope.launch {
                userPreferences.setTtsAutoPlay(intent.value)
            }
            is AudioSettingsIntent.SetSttEnabled -> viewModelScope.launch {
                userPreferences.setSttEnabled(intent.value)
            }
            is AudioSettingsIntent.SetSttAutoSend -> viewModelScope.launch {
                userPreferences.setSttAutoSend(intent.value)
            }
        }
    }
}
