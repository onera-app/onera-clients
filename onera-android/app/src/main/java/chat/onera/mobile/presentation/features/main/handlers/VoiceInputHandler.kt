package chat.onera.mobile.presentation.features.main.handlers

import chat.onera.mobile.data.speech.SpeechRecognitionManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

/**
 * Data class representing voice input state.
 */
data class VoiceInputState(
    val isRecording: Boolean = false,
    val transcribedText: String = ""
)

/**
 * Sealed class for voice input events that need to be handled by the parent.
 */
sealed interface VoiceInputEvent {
    data class TranscriptionResult(val text: String) : VoiceInputEvent
    data class Error(val message: String) : VoiceInputEvent
}

/**
 * Handler for voice input functionality.
 * Encapsulates speech recognition logic and state management.
 */
class VoiceInputHandler @Inject constructor(
    private val speechRecognitionManager: SpeechRecognitionManager
) {
    private val _events = MutableSharedFlow<VoiceInputEvent>()
    val events: Flow<VoiceInputEvent> = _events.asSharedFlow()

    /**
     * Observe speech recognition state changes.
     * Call this in the ViewModel's init block.
     */
    fun observeState(
        scope: CoroutineScope,
        onStateChange: (VoiceInputState) -> Unit
    ) {
        scope.launch {
            speechRecognitionManager.isListening.collect { isRecording ->
                onStateChange(
                    VoiceInputState(
                        isRecording = isRecording,
                        transcribedText = speechRecognitionManager.transcribedText.value
                    )
                )
            }
        }
        scope.launch {
            speechRecognitionManager.transcribedText.collect { text ->
                onStateChange(
                    VoiceInputState(
                        isRecording = speechRecognitionManager.isListening.value,
                        transcribedText = text
                    )
                )
            }
        }
        // Observe errors
        scope.launch {
            speechRecognitionManager.error.collect { error ->
                if (error != null) {
                    Timber.e("Speech recognition error: $error")
                    _events.emit(VoiceInputEvent.Error(error))
                }
            }
        }
    }

    /**
     * Start recording voice input.
     * @param onResult Callback invoked when transcription is complete
     */
    fun startRecording(onResult: (String) -> Unit) {
        speechRecognitionManager.clearError()
        speechRecognitionManager.startListening { result ->
            onResult(result)
        }
    }

    /**
     * Stop recording and get the final transcription.
     * @return The final transcribed text
     */
    fun stopRecording(): String {
        return speechRecognitionManager.stopListening()
    }

    /**
     * Check if currently recording.
     */
    val isRecording: Boolean
        get() = speechRecognitionManager.isListening.value
}
