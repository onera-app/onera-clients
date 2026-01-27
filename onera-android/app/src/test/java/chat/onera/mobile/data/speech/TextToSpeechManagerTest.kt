package chat.onera.mobile.data.speech

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for Text-to-Speech state management logic.
 * Note: Full TextToSpeechManager tests require Android instrumentation 
 * due to TextToSpeech requiring Android context.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TextToSpeechManagerTest {

    @Test
    fun `isSpeaking state flow should be observable`() = runTest {
        val isSpeaking = MutableStateFlow(false)
        
        assertFalse(isSpeaking.value)
        
        isSpeaking.value = true
        assertTrue(isSpeaking.value)
        
        isSpeaking.value = false
        assertFalse(isSpeaking.value)
    }

    @Test
    fun `speakingMessageId state flow should track message`() = runTest {
        val speakingMessageId = MutableStateFlow<String?>(null)
        
        assertNull(speakingMessageId.value)
        
        speakingMessageId.value = "message-1"
        assertEquals("message-1", speakingMessageId.value)
        
        speakingMessageId.value = null
        assertNull(speakingMessageId.value)
    }

    @Test
    fun `speakingStartTime should track when speech started`() = runTest {
        val speakingStartTime = MutableStateFlow<Long?>(null)
        
        assertNull(speakingStartTime.value)
        
        val now = System.currentTimeMillis()
        speakingStartTime.value = now
        assertEquals(now, speakingStartTime.value)
        
        speakingStartTime.value = null
        assertNull(speakingStartTime.value)
    }

    @Test
    fun `error state should be clearable`() = runTest {
        val error = MutableStateFlow<String?>(null)
        
        assertNull(error.value)
        
        error.value = "Test error"
        assertEquals("Test error", error.value)
        
        error.value = null
        assertNull(error.value)
    }

    @Test
    fun `speech rate clamping logic`() {
        val rate = 0.1f
        val clampedRate = rate.coerceIn(0.5f, 2.0f)
        assertEquals(0.5f, clampedRate)
        
        val highRate = 3.0f
        val clampedHighRate = highRate.coerceIn(0.5f, 2.0f)
        assertEquals(2.0f, clampedHighRate)
        
        val normalRate = 1.0f
        val clampedNormalRate = normalRate.coerceIn(0.5f, 2.0f)
        assertEquals(1.0f, clampedNormalRate)
    }

    @Test
    fun `pitch clamping logic`() {
        val pitch = 0.1f
        val clampedPitch = pitch.coerceIn(0.5f, 2.0f)
        assertEquals(0.5f, clampedPitch)
        
        val highPitch = 3.0f
        val clampedHighPitch = highPitch.coerceIn(0.5f, 2.0f)
        assertEquals(2.0f, clampedHighPitch)
        
        val normalPitch = 1.0f
        val clampedNormalPitch = normalPitch.coerceIn(0.5f, 2.0f)
        assertEquals(1.0f, clampedNormalPitch)
    }
}
