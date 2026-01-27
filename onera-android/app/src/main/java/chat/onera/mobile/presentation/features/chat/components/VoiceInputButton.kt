package chat.onera.mobile.presentation.features.chat.components

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import chat.onera.mobile.data.speech.SpeechRecognitionManager

@Composable
fun VoiceInputButton(
    speechRecognitionManager: SpeechRecognitionManager,
    onTranscription: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val isListening by speechRecognitionManager.isListening.collectAsState()
    val transcribedText by speechRecognitionManager.transcribedText.collectAsState()
    val error by speechRecognitionManager.error.collectAsState()
    val isAvailable by speechRecognitionManager.isAvailable.collectAsState()
    
    var hasPermission by remember { mutableStateOf(false) }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasPermission = isGranted
        if (isGranted) {
            speechRecognitionManager.startListening { result ->
                onTranscription(result)
            }
        }
    }
    
    // Check permission on composition
    LaunchedEffect(Unit) {
        hasPermission = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
    }
    
    // Pulse animation when recording
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )
    
    val backgroundColor by animateColorAsState(
        targetValue = if (isListening) {
            MaterialTheme.colorScheme.error
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        },
        label = "backgroundColor"
    )
    
    val iconTint by animateColorAsState(
        targetValue = if (isListening) {
            MaterialTheme.colorScheme.onError
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        label = "iconTint"
    )

    IconButton(
        onClick = {
            if (isListening) {
                val result = speechRecognitionManager.stopListening()
                if (result.isNotBlank()) {
                    onTranscription(result)
                }
            } else {
                if (hasPermission) {
                    speechRecognitionManager.startListening { result ->
                        onTranscription(result)
                    }
                } else {
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
            }
        },
        enabled = isAvailable,
        modifier = modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(backgroundColor)
            .then(
                if (isListening) {
                    Modifier.scale(pulseScale)
                } else {
                    Modifier
                }
            )
    ) {
        Icon(
            imageVector = if (isListening) Icons.Filled.Stop else Icons.Filled.Mic,
            contentDescription = if (isListening) "Stop recording" else "Voice input",
            tint = iconTint
        )
    }
}

@Composable
fun RecordingIndicator(
    isRecording: Boolean,
    transcribedText: String,
    onDone: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (!isRecording) return
    
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )
    
    Surface(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Recording indicator dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.error.copy(alpha = alpha))
            )
            
            // Transcribed text or "Recording..."
            Text(
                text = transcribedText.ifBlank { "Recording..." },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            
            // Done button
            TextButton(onClick = onDone) {
                Text(
                    text = "Done",
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}
