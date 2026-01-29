package chat.onera.mobile.demo

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import timber.log.Timber

/**
 * Manages demo mode state for Play Store review.
 * 
 * Demo mode allows App Store/Play Store reviewers to test the app
 * without requiring real credentials or API keys.
 * 
 * Activation: 10 rapid taps on the login screen header
 */
object DemoModeManager {
    
    private const val TAG = "DemoModeManager"
    
    /** Number of taps required to activate demo mode */
    const val REQUIRED_TAPS = 10
    
    /** Maximum time between taps before count resets (milliseconds) */
    const val TAP_TIMEOUT_MS = 1500L
    
    private val _isActive = MutableStateFlow(false)
    
    /** Whether demo mode is currently active */
    val isActive: StateFlow<Boolean> = _isActive.asStateFlow()
    
    /** Whether demo mode was activated this session */
    var wasActivatedThisSession: Boolean = false
        private set
    
    /**
     * Activates demo mode.
     * Called when the user completes the activation gesture.
     */
    fun activate() {
        if (_isActive.value) return
        
        _isActive.value = true
        wasActivatedThisSession = true
        
        Timber.d("$TAG: Demo mode activated")
    }
    
    /**
     * Deactivates demo mode (e.g., on sign out).
     */
    fun deactivate() {
        _isActive.value = false
        Timber.d("$TAG: Demo mode deactivated")
    }
    
    /**
     * Resets demo mode completely.
     */
    fun reset() {
        _isActive.value = false
        wasActivatedThisSession = false
        Timber.d("$TAG: Demo mode reset")
    }
    
    /**
     * Check if currently in demo mode (non-flow access).
     */
    fun isActiveNow(): Boolean = _isActive.value
}
