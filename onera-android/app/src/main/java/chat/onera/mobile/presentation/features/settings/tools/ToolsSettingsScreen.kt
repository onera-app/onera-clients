package chat.onera.mobile.presentation.features.settings.tools

import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToolsSettingsScreen(
    viewModel: ToolsSettingsViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is ToolsSettingsEffect.ApiKeySaved -> {
                    Toast.makeText(context, "${effect.provider} API key saved", Toast.LENGTH_SHORT).show()
                }
                is ToolsSettingsEffect.ApiKeyDeleted -> {
                    Toast.makeText(context, "${effect.provider} API key removed", Toast.LENGTH_SHORT).show()
                }
                is ToolsSettingsEffect.ShowError -> {
                    Toast.makeText(context, effect.message, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Tools") },
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
            // ── Web Search ──────────────────────────────────────────
            item {
                SectionHeader("Web Search")
            }
            item {
                SwitchSettingItem(
                    title = "Enable Web Search by Default",
                    subtitle = "Attach web search to new conversations",
                    checked = state.webSearchEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(ToolsSettingsIntent.SetWebSearchEnabled(it))
                    }
                )
            }
            item {
                ProviderDropdown(
                    selectedProvider = state.webSearchProvider,
                    enabled = state.webSearchEnabled,
                    onProviderSelected = {
                        viewModel.sendIntent(ToolsSettingsIntent.SetWebSearchProvider(it))
                    }
                )
            }

            // ── Native AI Search ────────────────────────────────────
            item {
                SectionHeader(
                    "Native AI Search",
                    modifier = Modifier.padding(top = 16.dp)
                )
                Text(
                    text = "Built-in search powered by AI models — no API keys needed.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }
            item {
                SwitchSettingItem(
                    title = "Google Search (Gemini)",
                    subtitle = "Use Gemini's built-in Google Search grounding",
                    checked = state.googleSearchEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(ToolsSettingsIntent.SetGoogleSearchEnabled(it))
                    }
                )
            }
            item {
                SwitchSettingItem(
                    title = "xAI Web Search (Grok)",
                    subtitle = "Use Grok's native real-time web search",
                    checked = state.xaiSearchEnabled,
                    onCheckedChange = {
                        viewModel.sendIntent(ToolsSettingsIntent.SetXaiSearchEnabled(it))
                    }
                )
            }

            // ── External Search Providers ───────────────────────────
            item {
                SectionHeader(
                    "External Search Providers",
                    modifier = Modifier.padding(top = 16.dp)
                )
            }
            items(SearchProvider.entries.toList(), key = { it.name }) { provider ->
                val apiKey = viewModel.getApiKeyForProvider(provider)
                ExternalProviderCard(
                    provider = provider,
                    currentApiKey = apiKey,
                    onSave = { key ->
                        viewModel.sendIntent(
                            ToolsSettingsIntent.SaveProviderApiKey(provider.displayName, key)
                        )
                    },
                    onDelete = {
                        viewModel.sendIntent(
                            ToolsSettingsIntent.DeleteProviderApiKey(provider.displayName)
                        )
                    }
                )
            }

            item { Spacer(modifier = Modifier.height(32.dp)) }
        }
    }
}

// ── Composables ─────────────────────────────────────────────────────────

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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProviderDropdown(
    selectedProvider: String,
    enabled: Boolean,
    onProviderSelected: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val providers = SearchProvider.entries.map { it.displayName }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text(
                text = "Default Provider",
                style = MaterialTheme.typography.bodyLarge,
                color = if (enabled) Color.Unspecified
                else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
            )
            Spacer(modifier = Modifier.height(8.dp))
            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { if (enabled) expanded = it }
            ) {
                OutlinedTextField(
                    value = selectedProvider,
                    onValueChange = {},
                    readOnly = true,
                    enabled = enabled,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    shape = RoundedCornerShape(8.dp)
                )
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    providers.forEach { provider ->
                        DropdownMenuItem(
                            text = { Text(provider) },
                            onClick = {
                                onProviderSelected(provider)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ExternalProviderCard(
    provider: SearchProvider,
    currentApiKey: String,
    onSave: (String) -> Unit,
    onDelete: () -> Unit
) {
    var editableKey by remember(currentApiKey) { mutableStateOf(currentApiKey) }
    var isKeyVisible by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    val isConnected = currentApiKey.isNotBlank()

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Header row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = provider.displayName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold
                )
                if (isConnected) {
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(
                            text = "Connected",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }

            // Description
            Text(
                text = provider.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            // API key input
            OutlinedTextField(
                value = editableKey,
                onValueChange = { editableKey = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("API Key") },
                placeholder = { Text("Enter your ${provider.displayName} API key") },
                singleLine = true,
                visualTransformation = if (isKeyVisible) VisualTransformation.None
                else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                trailingIcon = {
                    IconButton(onClick = { isKeyVisible = !isKeyVisible }) {
                        Icon(
                            imageVector = if (isKeyVisible) Icons.Default.VisibilityOff
                            else Icons.Default.Visibility,
                            contentDescription = if (isKeyVisible) "Hide" else "Show"
                        )
                    }
                },
                shape = RoundedCornerShape(8.dp)
            )

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End)
            ) {
                if (isConnected) {
                    OutlinedButton(
                        onClick = { showDeleteDialog = true },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Delete")
                    }
                }
                Button(
                    onClick = { onSave(editableKey) },
                    enabled = editableKey.isNotBlank() && editableKey != currentApiKey
                ) {
                    Text(if (isConnected) "Update" else "Add")
                }
            }
        }
    }

    // Delete confirmation dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete API Key?") },
            text = {
                Text("Remove the ${provider.displayName} API key? You can add it again later.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        onDelete()
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
