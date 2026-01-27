package chat.onera.mobile.data.speech

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages speech recognition for voice input
 */
@Singleton
class SpeechRecognitionManager @Inject constructor(
    private val context: Context
) {
    companion object {
        private const val TAG = "SpeechRecognitionManager"
    }
    
    private var speechRecognizer: SpeechRecognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private val _isListening = MutableStateFlow(false)
    val isListening: StateFlow<Boolean> = _isListening.asStateFlow()
    
    private val _transcribedText = MutableStateFlow("")
    val transcribedText: StateFlow<String> = _transcribedText.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    private val _isAvailable = MutableStateFlow(false)
    val isAvailable: StateFlow<Boolean> = _isAvailable.asStateFlow()
    
    private var onResultCallback: ((String) -> Unit)? = null
    
    init {
        _isAvailable.value = SpeechRecognizer.isRecognitionAvailable(context)
        Log.d(TAG, "Speech recognition available: ${_isAvailable.value}")
    }
    
    /**
     * Clear any previous error state
     */
    fun clearError() {
        _error.value = null
    }
    
    fun startListening(onResult: (String) -> Unit) {
        Log.d(TAG, "startListening called")
        
        if (!_isAvailable.value) {
            Log.e(TAG, "Speech recognition not available")
            _error.value = "Speech recognition is not available on this device"
            return
        }
        
        if (_isListening.value) {
            Log.d(TAG, "Already listening, ignoring")
            return
        }
        
        onResultCallback = onResult
        _transcribedText.value = ""
        _error.value = null
        
        // SpeechRecognizer must be created and used on the main thread
        mainHandler.post {
            try {
                // Destroy any existing recognizer
                speechRecognizer?.destroy()
                
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                    setRecognitionListener(createRecognitionListener())
                }
                
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                
                Log.d(TAG, "Starting speech recognizer")
                speechRecognizer?.startListening(intent)
                _isListening.value = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start speech recognition", e)
                _error.value = "Failed to start speech recognition: ${e.message}"
                _isListening.value = false
            }
        }
    }
    
    fun stopListening(): String {
        Log.d(TAG, "stopListening called")
        mainHandler.post {
            speechRecognizer?.stopListening()
        }
        _isListening.value = false
        return _transcribedText.value
    }
    
    fun cancelListening() {
        Log.d(TAG, "cancelListening called")
        mainHandler.post {
            speechRecognizer?.cancel()
        }
        _isListening.value = false
        _transcribedText.value = ""
    }
    
    fun destroy() {
        Log.d(TAG, "destroy called")
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
    
    private fun createRecognitionListener() = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            Log.d(TAG, "onReadyForSpeech")
            _error.value = null
        }
        
        override fun onBeginningOfSpeech() {
            Log.d(TAG, "onBeginningOfSpeech")
        }
        
        override fun onRmsChanged(rmsdB: Float) {
            // Volume level changed - could be used for UI feedback
        }
        
        override fun onBufferReceived(buffer: ByteArray?) {
            // Audio buffer received
        }
        
        override fun onEndOfSpeech() {
            Log.d(TAG, "onEndOfSpeech")
            _isListening.value = false
        }
        
        override fun onError(error: Int) {
            val errorMsg = getErrorMessage(error)
            Log.e(TAG, "onError: $error - $errorMsg")
            _isListening.value = false
            _error.value = errorMsg
        }
        
        override fun onResults(results: Bundle?) {
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val finalText = matches?.firstOrNull() ?: ""
            Log.d(TAG, "onResults: $finalText")
            _transcribedText.value = finalText
            _isListening.value = false
            
            if (finalText.isNotBlank()) {
                onResultCallback?.invoke(finalText)
            }
        }
        
        override fun onPartialResults(partialResults: Bundle?) {
            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val partialText = matches?.firstOrNull() ?: ""
            if (partialText.isNotBlank()) {
                Log.d(TAG, "onPartialResults: $partialText")
                _transcribedText.value = partialText
            }
        }
        
        override fun onEvent(eventType: Int, params: Bundle?) {
            Log.d(TAG, "onEvent: $eventType")
        }
    }
    
    private fun getErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error - please check microphone"
            SpeechRecognizer.ERROR_CLIENT -> "Speech recognition client error"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission required"
            SpeechRecognizer.ERROR_NETWORK -> "Network error - check your connection"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout - try again"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech detected - please try again"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition busy - try again"
            SpeechRecognizer.ERROR_SERVER -> "Server error - try again later"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input detected"
            else -> "Speech recognition error ($error)"
        }
    }
}
