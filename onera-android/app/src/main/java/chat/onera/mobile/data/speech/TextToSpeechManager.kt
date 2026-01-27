package chat.onera.mobile.data.speech

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages Text-to-Speech for reading messages aloud
 */
@Singleton
class TextToSpeechManager @Inject constructor(
    private val context: Context
) : TextToSpeech.OnInitListener {

    private var textToSpeech: TextToSpeech? = null
    
    private val _isInitialized = MutableStateFlow(false)
    val isInitialized: StateFlow<Boolean> = _isInitialized.asStateFlow()
    
    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()
    
    private val _speakingMessageId = MutableStateFlow<String?>(null)
    val speakingMessageId: StateFlow<String?> = _speakingMessageId.asStateFlow()
    
    private val _speakingStartTime = MutableStateFlow<Long?>(null)
    val speakingStartTime: StateFlow<Long?> = _speakingStartTime.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    init {
        initializeTTS()
    }
    
    private fun initializeTTS() {
        textToSpeech = TextToSpeech(context, this)
    }
    
    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = textToSpeech?.setLanguage(Locale.getDefault())
            _isInitialized.value = result != TextToSpeech.LANG_MISSING_DATA && 
                                   result != TextToSpeech.LANG_NOT_SUPPORTED
            
            textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    _isSpeaking.value = true
                }
                
                override fun onDone(utteranceId: String?) {
                    _isSpeaking.value = false
                    _speakingMessageId.value = null
                    _speakingStartTime.value = null
                }
                
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    _isSpeaking.value = false
                    _speakingMessageId.value = null
                    _speakingStartTime.value = null
                    _error.value = "Failed to speak text"
                }
            })
        } else {
            _isInitialized.value = false
            _error.value = "Failed to initialize Text-to-Speech"
        }
    }
    
    /**
     * Speak the given text
     * @param text The text to speak
     * @param messageId Optional message ID to track which message is being spoken
     */
    fun speak(text: String, messageId: String? = null) {
        if (!_isInitialized.value) {
            _error.value = "Text-to-Speech is not initialized"
            return
        }
        
        // Stop any current speech
        stop()
        
        _speakingMessageId.value = messageId
        _speakingStartTime.value = System.currentTimeMillis()
        _error.value = null
        
        val utteranceId = UUID.randomUUID().toString()
        
        textToSpeech?.speak(
            text,
            TextToSpeech.QUEUE_FLUSH,
            null,
            utteranceId
        )
    }
    
    /**
     * Stop any current speech
     */
    fun stop() {
        textToSpeech?.stop()
        _isSpeaking.value = false
        _speakingMessageId.value = null
        _speakingStartTime.value = null
    }
    
    /**
     * Set the speech rate
     * @param rate Speech rate (1.0 is normal speed)
     */
    fun setSpeechRate(rate: Float) {
        textToSpeech?.setSpeechRate(rate.coerceIn(0.5f, 2.0f))
    }
    
    /**
     * Set the pitch
     * @param pitch Pitch (1.0 is normal pitch)
     */
    fun setPitch(pitch: Float) {
        textToSpeech?.setPitch(pitch.coerceIn(0.5f, 2.0f))
    }
    
    /**
     * Clean up resources
     */
    fun shutdown() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        _isInitialized.value = false
    }
}
