package chat.onera.mobile.presentation.features.settings.audio

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AudioSettingsScreen(
    viewModel: AudioSettingsViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Audio") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // ── Text-to-Speech ──────────────────────────────────────
            item {
                SectionHeader("Text-to-Speech")
            }
            item {
                SwitchSettingItem(
                    title = "Enable TTS",
                    subtitle = "Read responses aloud",
                    checked = state.ttsEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetTtsEnabled(it))
                    }
                )
            }
            item {
                SliderSettingItem(
                    title = "Speed",
                    value = state.ttsSpeed,
                    valueRange = 0.5f..2.0f,
                    steps = 14,
                    valueLabel = "%.1f×".format(state.ttsSpeed),
                    enabled = state.ttsEnabled,
                    onValueChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetTtsSpeed(it))
                    }
                )
            }
            item {
                SliderSettingItem(
                    title = "Pitch",
                    value = state.ttsPitch,
                    valueRange = 0.5f..2.0f,
                    steps = 14,
                    valueLabel = "%.1f×".format(state.ttsPitch),
                    enabled = state.ttsEnabled,
                    onValueChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetTtsPitch(it))
                    }
                )
            }
            item {
                SwitchSettingItem(
                    title = "Auto-play Responses",
                    subtitle = "Automatically read new AI responses",
                    checked = state.ttsAutoPlay,
                    enabled = state.ttsEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetTtsAutoPlay(it))
                    }
                )
            }

            // ── Speech-to-Text ──────────────────────────────────────
            item {
                SectionHeader("Speech-to-Text", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                SwitchSettingItem(
                    title = "Enable STT",
                    subtitle = "Use microphone for voice input",
                    checked = state.sttEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetSttEnabled(it))
                    }
                )
            }
            item {
                SwitchSettingItem(
                    title = "Auto-send After Speech",
                    subtitle = "Send message when speech ends",
                    checked = state.sttAutoSend,
                    enabled = state.sttEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(AudioSettingsIntent.SetSttAutoSend(it))
                    }
                )
            }

            item { Spacer(modifier = Modifier.height(32.dp)) }
        }
    }
}

// ── Reusable composables ────────────────────────────────────────────────

@Composable
private fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(vertical = 4.dp)
    )
}

@Composable
private fun SwitchSettingItem(
    title: String,
    subtitle: String? = null,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        ListItem(
            headlineContent = {
                Text(
                    text = title,
                    color = if (enabled) Color.Unspecified
                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                )
            },
            supportingContent = subtitle?.let {
                {
                    Text(
                        text = it,
                        color = if (enabled) MaterialTheme.colorScheme.onSurfaceVariant
                        else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.38f)
                    )
                }
            },
            trailingContent = {
                Switch(
                    checked = checked,
                    onCheckedChange = onCheckedChange,
                    enabled = enabled
                )
            },
            colors = ListItemDefaults.colors(containerColor = Color.Transparent)
        )
    }
}

@Composable
private fun SliderSettingItem(
    title: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    valueLabel: String,
    enabled: Boolean = true,
    onValueChange: (Float) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (enabled) Color.Unspecified
                    else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                )
                Text(
                    text = valueLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (enabled) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.primary.copy(alpha = 0.38f),
                    fontWeight = FontWeight.Medium
                )
            }
            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = valueRange,
                steps = steps,
                enabled = enabled,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
