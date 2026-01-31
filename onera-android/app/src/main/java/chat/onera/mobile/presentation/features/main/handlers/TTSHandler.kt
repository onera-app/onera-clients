package chat.onera.mobile.presentation.features.main.handlers

import chat.onera.mobile.data.speech.TextToSpeechManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Data class representing TTS state.
 */
data class TTSState(
    val isSpeaking: Boolean = false,
    val speakingMessageId: String? = null,
    val speakingStartTime: Long? = null
)

/**
 * Handler for Text-to-Speech functionality.
 * Encapsulates TTS logic and state management.
 */
class TTSHandler @Inject constructor(
    private val textToSpeechManager: TextToSpeechManager
) {
    /**
     * Observe TTS state changes.
     * Call this in the ViewModel's init block.
     */
    fun observeState(
        scope: CoroutineScope,
        onStateChange: (TTSState) -> Unit
    ) {
        scope.launch {
            textToSpeechManager.isSpeaking.collect { isSpeaking ->
                onStateChange(
                    TTSState(
                        isSpeaking = isSpeaking,
                        speakingMessageId = textToSpeechManager.speakingMessageId.value,
                        speakingStartTime = textToSpeechManager.speakingStartTime.value
                    )
                )
            }
        }
        scope.launch {
            textToSpeechManager.speakingMessageId.collect { messageId ->
                onStateChange(
                    TTSState(
                        isSpeaking = textToSpeechManager.isSpeaking.value,
                        speakingMessageId = messageId,
                        speakingStartTime = textToSpeechManager.speakingStartTime.value
                    )
                )
            }
        }
        scope.launch {
            textToSpeechManager.speakingStartTime.collect { startTime ->
                onStateChange(
                    TTSState(
                        isSpeaking = textToSpeechManager.isSpeaking.value,
                        speakingMessageId = textToSpeechManager.speakingMessageId.value,
                        speakingStartTime = startTime
                    )
                )
            }
        }
    }

    /**
     * Start speaking the given text.
     * @param text The text to speak
     * @param messageId The ID of the message being spoken (for UI tracking)
     */
    fun speak(text: String, messageId: String) {
        textToSpeechManager.speak(text, messageId)
    }

    /**
     * Stop any ongoing speech.
     */
    fun stop() {
        textToSpeechManager.stop()
    }

    /**
     * Check if currently speaking.
     */
    val isSpeaking: Boolean
        get() = textToSpeechManager.isSpeaking.value
}
