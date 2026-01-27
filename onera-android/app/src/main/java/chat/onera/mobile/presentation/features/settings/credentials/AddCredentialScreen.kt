package chat.onera.mobile.presentation.features.settings.credentials

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.presentation.features.main.ModelProvider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddCredentialScreen(
    viewModel: CredentialsViewModel = hiltViewModel(),
    onBack: () -> Unit,
    onCredentialAdded: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    
    var selectedProvider by remember { mutableStateOf<ModelProvider?>(null) }
    var customName by remember { mutableStateOf("") }
    var apiKey by remember { mutableStateOf("") }
    var showApiKey by remember { mutableStateOf(false) }
    val context = LocalContext.current
    
    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is CredentialsEffect.CredentialAdded -> onCredentialAdded()
                is CredentialsEffect.ShowError -> {
                    Toast.makeText(context, effect.message, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add API Key") },
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
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Provider selection
            item {
                Text(
                    text = "Select Provider",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                ProviderGrid(
                    selectedProvider = selectedProvider,
                    onSelectProvider = { selectedProvider = it }
                )
            }
            
            // API key input (shown after provider selection)
            if (selectedProvider != null) {
                item {
                    Text(
                        text = "API Key",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    OutlinedTextField(
                        value = apiKey,
                        onValueChange = { apiKey = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Enter your ${selectedProvider!!.displayName} API key") },
                        placeholder = { Text("sk-...") },
                        visualTransformation = if (showApiKey) {
                            VisualTransformation.None
                        } else {
                            PasswordVisualTransformation()
                        },
                        trailingIcon = {
                            IconButton(onClick = { showApiKey = !showApiKey }) {
                                Icon(
                                    imageVector = if (showApiKey) {
                                        Icons.Outlined.VisibilityOff
                                    } else {
                                        Icons.Outlined.Visibility
                                    },
                                    contentDescription = if (showApiKey) "Hide" else "Show"
                                )
                            }
                        },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password
                        ),
                        singleLine = true,
                        shape = RoundedCornerShape(12.dp)
                    )
                }
                
                // Custom name (optional)
                item {
                    OutlinedTextField(
                        value = customName,
                        onValueChange = { customName = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Custom Name (optional)") },
                        placeholder = { Text("My ${selectedProvider!!.displayName} Key") },
                        singleLine = true,
                        shape = RoundedCornerShape(12.dp)
                    )
                }
                
                // Help text
                item {
                    HelpSection(provider = selectedProvider!!)
                }
                
                // Save button
                item {
                    Button(
                        onClick = {
                            viewModel.sendIntent(
                                CredentialsIntent.AddCredential(
                                    provider = selectedProvider!!,
                                    name = customName,
                                    apiKey = apiKey
                                )
                            )
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = apiKey.isNotBlank() && !state.isValidating,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        if (state.isValidating) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text("Save API Key")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProviderGrid(
    selectedProvider: ModelProvider?,
    onSelectProvider: (ModelProvider) -> Unit
) {
    val providers = listOf(
        ModelProvider.OPENAI,
        ModelProvider.ANTHROPIC,
        ModelProvider.GOOGLE,
        ModelProvider.XAI,
        ModelProvider.GROQ,
        ModelProvider.MISTRAL,
        ModelProvider.DEEPSEEK,
        ModelProvider.OPENROUTER,
        ModelProvider.TOGETHER,
        ModelProvider.FIREWORKS,
        ModelProvider.OLLAMA,
        ModelProvider.LMSTUDIO,
        ModelProvider.CUSTOM
    )
    
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        providers.chunked(3).forEach { rowProviders ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                rowProviders.forEach { provider ->
                    ProviderChip(
                        provider = provider,
                        isSelected = selectedProvider == provider,
                        onClick = { onSelectProvider(provider) },
                        modifier = Modifier.weight(1f)
                    )
                }
                // Fill empty space if row is not full
                repeat(3 - rowProviders.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun ProviderChip(
    provider: ModelProvider,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    FilterChip(
        onClick = onClick,
        selected = isSelected,
        label = { 
            Text(
                text = provider.displayName,
                style = MaterialTheme.typography.labelMedium
            ) 
        },
        leadingIcon = if (isSelected) {
            {
                Icon(
                    imageVector = Icons.Outlined.Check,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
            }
        } else null,
        modifier = modifier
    )
}

@Composable
private fun HelpSection(provider: ModelProvider) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Help,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "How to get your API key",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Medium
                )
            }
            
            Text(
                text = getHelpText(provider),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun getHelpText(provider: ModelProvider): String {
    return when (provider) {
        ModelProvider.OPENAI -> "Visit platform.openai.com to create an API key. Go to Settings > API Keys and click 'Create new secret key'."
        ModelProvider.ANTHROPIC -> "Visit console.anthropic.com to create an API key. Navigate to Settings > API Keys."
        ModelProvider.GOOGLE -> "Visit aistudio.google.com to create an API key for Gemini models."
        ModelProvider.XAI -> "Visit x.ai to get your Grok API key."
        ModelProvider.GROQ -> "Visit console.groq.com to create a free API key for fast inference."
        ModelProvider.MISTRAL -> "Visit console.mistral.ai to create an API key."
        ModelProvider.DEEPSEEK -> "Visit platform.deepseek.com to create an API key."
        ModelProvider.OPENROUTER -> "Visit openrouter.ai to create an API key that works with multiple providers."
        ModelProvider.TOGETHER -> "Visit together.ai to create an API key."
        ModelProvider.FIREWORKS -> "Visit fireworks.ai to create an API key."
        ModelProvider.OLLAMA -> "No API key needed for local Ollama. Just enter your server URL (default: http://localhost:11434)."
        ModelProvider.LMSTUDIO -> "No API key needed for local LM Studio. Enter your server URL."
        ModelProvider.CUSTOM -> "Enter your custom OpenAI-compatible API endpoint and key."
    }
}
