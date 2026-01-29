package chat.onera.mobile.demo

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import timber.log.Timber

/**
 * Composable that wraps content and adds demo mode activation gesture.
 * Requires 10 rapid taps within 1.5 seconds between taps to activate.
 * 
 * @param onDemoModeActivated Callback when demo mode is successfully activated
 * @param content The content to wrap with the gesture
 */
@Composable
fun DemoModeActivationWrapper(
    onDemoModeActivated: () -> Unit,
    content: @Composable () -> Unit
) {
    val context = LocalContext.current
    var tapCount by remember { mutableIntStateOf(0) }
    var lastTapTime by remember { mutableLongStateOf(0L) }
    var showActivationFeedback by remember { mutableStateOf(false) }
    
    // Get vibrator service
    val vibrator = remember {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(VibratorManager::class.java)
            vibratorManager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
    }
    
    fun vibrateTap() {
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createOneShot(30, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(30)
            }
        }
    }
    
    fun vibrateSuccess() {
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(100)
            }
        }
    }
    
    fun handleTap() {
        val now = System.currentTimeMillis()
        
        // Reset count if too much time has passed since last tap
        if (now - lastTapTime > DemoModeManager.TAP_TIMEOUT_MS) {
            tapCount = 0
        }
        
        tapCount++
        lastTapTime = now
        vibrateTap()
        
        // Show progress feedback after 5 taps
        if (tapCount >= 5 && tapCount < DemoModeManager.REQUIRED_TAPS) {
            Timber.d("DemoMode: ${DemoModeManager.REQUIRED_TAPS - tapCount} more taps to activate...")
        }
        
        // Check if we've reached the required tap count
        if (tapCount >= DemoModeManager.REQUIRED_TAPS) {
            tapCount = 0
            lastTapTime = 0
            vibrateSuccess()
            showActivationFeedback = true
            DemoModeManager.activate()
            onDemoModeActivated()
        }
    }
    
    // Hide feedback after delay
    LaunchedEffect(showActivationFeedback) {
        if (showActivationFeedback) {
            delay(2000)
            showActivationFeedback = false
        }
    }
    
    Box {
        // Wrapped content with tap gesture
        Box(
            modifier = Modifier.clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null // No ripple - secret gesture
            ) {
                handleTap()
            }
        ) {
            content()
        }
        
        // Activation feedback overlay
        AnimatedVisibility(
            visible = showActivationFeedback,
            enter = fadeIn() + scaleIn(
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessMedium
                )
            ),
            exit = fadeOut() + scaleOut(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            DemoModeActivatedBanner()
        }
    }
}

/**
 * Banner shown when demo mode is activated.
 */
@Composable
private fun DemoModeActivatedBanner() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .background(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f),
                shape = RoundedCornerShape(16.dp)
            )
            .padding(24.dp)
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            tint = Color(0xFF4CAF50),
            modifier = Modifier.size(60.dp)
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        Text(
            text = "Demo Mode Activated",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        
        Spacer(modifier = Modifier.height(4.dp))
        
        Text(
            text = "Signing in...",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

/**
 * Full-screen overlay for demo mode activation feedback.
 * Use when you want the banner centered on the full screen.
 */
@Composable
fun DemoModeActivationOverlay(
    visible: Boolean,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.3f)),
            contentAlignment = Alignment.Center
        ) {
            DemoModeActivatedBanner()
        }
    }
}
