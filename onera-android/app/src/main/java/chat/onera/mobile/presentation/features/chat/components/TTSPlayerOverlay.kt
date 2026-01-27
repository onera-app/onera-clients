package chat.onera.mobile.presentation.features.chat.components

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

/**
 * Floating TTS player overlay shown when speech is playing (ChatGPT style)
 */
@Composable
fun TTSPlayerOverlay(
    isPlaying: Boolean,
    startTime: Long?,
    onStop: () -> Unit,
    modifier: Modifier = Modifier
) {
    AnimatedVisibility(
        visible = isPlaying,
        enter = slideInVertically(initialOffsetY = { -it }) + fadeIn(),
        exit = slideOutVertically(targetOffsetY = { -it }) + fadeOut(),
        modifier = modifier.fillMaxWidth()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            TTSPlayerPill(
                startTime = startTime,
                onStop = onStop
            )
        }
    }
}

@Composable
private fun TTSPlayerPill(
    startTime: Long?,
    onStop: () -> Unit
) {
    var elapsedSeconds by remember { mutableIntStateOf(0) }
    
    // Timer effect
    LaunchedEffect(startTime) {
        if (startTime != null) {
            elapsedSeconds = ((System.currentTimeMillis() - startTime) / 1000).toInt()
            while (true) {
                delay(1000)
                elapsedSeconds++
            }
        }
    }
    
    // Pulsing animation for speaker icon
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val iconScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "iconScale"
    )
    
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = Color.Black.copy(alpha = 0.85f),
        shadowElevation = 8.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Speaker icon with animation
            Icon(
                imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                contentDescription = "Speaking",
                tint = Color.White,
                modifier = Modifier
                    .size(20.dp)
                    .scale(iconScale)
            )
            
            // Elapsed time display
            Text(
                text = formatElapsedTime(elapsedSeconds),
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = FontFamily.Monospace
            )
            
            Spacer(modifier = Modifier.weight(1f))
            
            // Stop button
            IconButton(
                onClick = onStop,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.2f))
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Stop",
                    tint = Color.White.copy(alpha = 0.8f),
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

private fun formatElapsedTime(seconds: Int): String {
    val minutes = seconds / 60
    val secs = seconds % 60
    return String.format("%d:%02d", minutes, secs)
}
