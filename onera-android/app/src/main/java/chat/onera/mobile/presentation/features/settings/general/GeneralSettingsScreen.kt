package chat.onera.mobile.presentation.features.settings.general

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GeneralSettingsScreen(
    viewModel: GeneralSettingsViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is GeneralSettingsEffect.DefaultsReset -> {
                    Toast.makeText(context, "Reset to defaults", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("General") },
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
            // ── System Prompt ───────────────────────────────────────
            item {
                SectionHeader("System Prompt")
            }
            item {
                OutlinedTextField(
                    value = state.systemPrompt,
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetSystemPrompt(it))
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 120.dp),
                    placeholder = { Text("Enter a system prompt for the model…") },
                    shape = RoundedCornerShape(12.dp),
                    minLines = 4
                )
            }

            // ── Streaming ───────────────────────────────────────────
            item {
                SectionHeader("Response", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                SwitchSettingItem(
                    title = "Stream Response",
                    subtitle = "Show tokens as they are generated",
                    checked = state.streamResponse,
                    onCheckedChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetStreamResponse(it))
                    }
                )
            }

            // ── Sampling Parameters ─────────────────────────────────
            item {
                SectionHeader("Sampling Parameters", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                SliderSettingItem(
                    title = "Temperature",
                    value = state.temperature,
                    valueRange = 0f..2f,
                    steps = 199,
                    valueLabel = formatFloat(state.temperature),
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetTemperature(it))
                    }
                )
            }
            item {
                SliderSettingItem(
                    title = "Top P",
                    value = state.topP,
                    valueRange = 0f..1f,
                    steps = 99,
                    valueLabel = formatFloat(state.topP),
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetTopP(it))
                    }
                )
            }
            item {
                SliderSettingItem(
                    title = "Top K",
                    value = state.topK.toFloat(),
                    valueRange = 1f..100f,
                    steps = 98,
                    valueLabel = state.topK.toString(),
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetTopK(it.roundToInt()))
                    }
                )
            }

            // ── Token Limits ────────────────────────────────────────
            item {
                SectionHeader("Token Limits", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                NumberInputSettingItem(
                    title = "Max Tokens",
                    subtitle = "0 = model default",
                    value = state.maxTokens,
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetMaxTokens(it))
                    }
                )
            }

            // ── Penalties ───────────────────────────────────────────
            item {
                SectionHeader("Penalties", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                SliderSettingItem(
                    title = "Frequency Penalty",
                    value = state.frequencyPenalty,
                    valueRange = -2f..2f,
                    steps = 399,
                    valueLabel = formatFloat(state.frequencyPenalty),
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetFrequencyPenalty(it))
                    }
                )
            }
            item {
                SliderSettingItem(
                    title = "Presence Penalty",
                    value = state.presencePenalty,
                    valueRange = -2f..2f,
                    steps = 399,
                    valueLabel = formatFloat(state.presencePenalty),
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetPresencePenalty(it))
                    }
                )
            }

            // ── Reproducibility ─────────────────────────────────────
            item {
                SectionHeader("Reproducibility", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                NumberInputSettingItem(
                    title = "Seed",
                    subtitle = "0 = random",
                    value = state.seed,
                    onValueChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetSeed(it))
                    }
                )
            }

            // ── Provider-Specific ────────────────────────────────────
            item {
                SectionHeader("Provider-Specific", modifier = Modifier.padding(top = 16.dp))
            }
            item {
                OpenAISettingsSection(
                    reasoningEffort = state.openaiReasoningEffort,
                    reasoningSummary = state.openaiReasoningSummary,
                    onReasoningEffortChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetOpenaiReasoningEffort(it))
                    },
                    onReasoningSummaryChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetOpenaiReasoningSummary(it))
                    }
                )
            }
            item {
                AnthropicSettingsSection(
                    extendedThinking = state.anthropicExtendedThinking,
                    onExtendedThinkingChange = {
                        viewModel.sendIntent(GeneralSettingsIntent.SetAnthropicExtendedThinking(it))
                    }
                )
            }

            // ── Reset ───────────────────────────────────────────────
            item {
                Spacer(modifier = Modifier.height(24.dp))
                OutlinedButton(
                    onClick = { viewModel.sendIntent(GeneralSettingsIntent.ResetDefaults) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Reset to Defaults")
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
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
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        ListItem(
            headlineContent = { Text(title) },
            supportingContent = subtitle?.let { { Text(it) } },
            trailingContent = {
                Switch(checked = checked, onCheckedChange = onCheckedChange)
            },
            colors = ListItemDefaults.colors(
                containerColor = androidx.compose.ui.graphics.Color.Transparent
            )
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
                Text(text = title, style = MaterialTheme.typography.bodyLarge)
                Text(
                    text = valueLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
            }
            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = valueRange,
                steps = steps,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun NumberInputSettingItem(
    title: String,
    subtitle: String? = null,
    value: Int,
    onValueChange: (Int) -> Unit
) {
    var textValue by remember(value) { mutableStateOf(value.toString()) }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.bodyLarge)
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            OutlinedTextField(
                value = textValue,
                onValueChange = { newText ->
                    textValue = newText
                    newText.toIntOrNull()?.let { onValueChange(it) }
                },
                modifier = Modifier.width(100.dp),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                shape = RoundedCornerShape(8.dp)
            )
        }
    }
}

// ── Provider-Specific Sections ──────────────────────────────────────────

@Composable
private fun OpenAISettingsSection(
    reasoningEffort: String,
    reasoningSummary: String,
    onReasoningEffortChange: (String) -> Unit,
    onReasoningSummaryChange: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column {
            ListItem(
                headlineContent = { Text("OpenAI") },
                supportingContent = { Text("For o1, o3, and GPT-5 models") },
                trailingContent = {
                    Icon(
                        imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        contentDescription = if (expanded) "Collapse" else "Expand"
                    )
                },
                modifier = Modifier.clickable { expanded = !expanded },
                colors = ListItemDefaults.colors(
                    containerColor = androidx.compose.ui.graphics.Color.Transparent
                )
            )

            AnimatedVisibility(visible = expanded) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Reasoning Effort
                    DropdownSettingItem(
                        title = "Reasoning Effort",
                        selectedValue = reasoningEffort.replaceFirstChar { it.uppercase() },
                        options = listOf("Low", "Medium", "High"),
                        onOptionSelected = { onReasoningEffortChange(it.lowercase()) }
                    )

                    // Reasoning Summary
                    DropdownSettingItem(
                        title = "Reasoning Summary",
                        selectedValue = reasoningSummary.replaceFirstChar { it.uppercase() },
                        options = listOf("Detailed", "Auto", "None"),
                        onOptionSelected = { onReasoningSummaryChange(it.lowercase()) }
                    )

                    Spacer(modifier = Modifier.height(4.dp))
                }
            }
        }
    }
}

@Composable
private fun AnthropicSettingsSection(
    extendedThinking: Boolean,
    onExtendedThinkingChange: (Boolean) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column {
            ListItem(
                headlineContent = { Text("Anthropic") },
                supportingContent = { Text("For Claude models") },
                trailingContent = {
                    Icon(
                        imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                        contentDescription = if (expanded) "Collapse" else "Expand"
                    )
                },
                modifier = Modifier.clickable { expanded = !expanded },
                colors = ListItemDefaults.colors(
                    containerColor = androidx.compose.ui.graphics.Color.Transparent
                )
            )

            AnimatedVisibility(visible = expanded) {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    SwitchSettingItem(
                        title = "Extended Thinking",
                        subtitle = "Enables chain-of-thought reasoning for Claude models",
                        checked = extendedThinking,
                        onCheckedChange = onExtendedThinkingChange
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DropdownSettingItem(
    title: String,
    selectedValue: String,
    options: List<String>,
    onOptionSelected: (String) -> Unit
) {
    var dropdownExpanded by remember { mutableStateOf(false) }

    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
        Spacer(modifier = Modifier.height(4.dp))
        ExposedDropdownMenuBox(
            expanded = dropdownExpanded,
            onExpandedChange = { dropdownExpanded = it }
        ) {
            OutlinedTextField(
                value = selectedValue,
                onValueChange = {},
                readOnly = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(),
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = dropdownExpanded) },
                shape = RoundedCornerShape(12.dp),
                singleLine = true
            )
            ExposedDropdownMenu(
                expanded = dropdownExpanded,
                onDismissRequest = { dropdownExpanded = false }
            ) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option) },
                        onClick = {
                            onOptionSelected(option)
                            dropdownExpanded = false
                        }
                    )
                }
            }
        }
    }
}

private fun formatFloat(value: Float): String =
    "%.2f".format(value)
