package chat.onera.mobile.presentation.features.apikey

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * LLM Provider types
 */
enum class LLMProvider(
    val displayName: String,
    val description: String,
    val icon: ImageVector,
    val iconTint: Color,
    val badge: String? = null,
    val category: ProviderCategory
) {
    // Popular
    OPENAI(
        displayName = "OpenAI",
        description = "GPT-4o, o1, o3",
        icon = Icons.Default.AutoAwesome,
        iconTint = Color(0xFF34C759),
        category = ProviderCategory.POPULAR
    ),
    ANTHROPIC(
        displayName = "Anthropic",
        description = "Claude 4, Claude 3.7",
        icon = Icons.Default.Psychology,
        iconTint = Color(0xFFFF9500),
        category = ProviderCategory.POPULAR
    ),
    GOOGLE(
        displayName = "Google",
        description = "Gemini 2.0, Gemini 1.5",
        icon = Icons.Default.Circle,
        iconTint = Color(0xFF007AFF),
        category = ProviderCategory.POPULAR
    ),
    XAI(
        displayName = "xAI",
        description = "Grok 2, Grok 3",
        icon = Icons.Default.Close,
        iconTint = Color(0xFF000000),
        category = ProviderCategory.POPULAR
    ),
    
    // Open Source
    GROQ(
        displayName = "Groq",
        description = "Ultra-fast Llama, Mixtral",
        icon = Icons.Default.Bolt,
        iconTint = Color(0xFFFF9500),
        category = ProviderCategory.OPEN_SOURCE
    ),
    MISTRAL(
        displayName = "Mistral",
        description = "Mistral Large, Codestral",
        icon = Icons.Default.Air,
        iconTint = Color(0xFF007AFF),
        category = ProviderCategory.OPEN_SOURCE
    ),
    DEEPSEEK(
        displayName = "DeepSeek",
        description = "DeepSeek V3, DeepSeek-R1",
        icon = Icons.Default.Search,
        iconTint = Color(0xFFAF52DE),
        category = ProviderCategory.OPEN_SOURCE
    ),
    
    // Aggregators
    OPENROUTER(
        displayName = "OpenRouter",
        description = "200+ models, one API",
        icon = Icons.Default.AccountTree,
        iconTint = Color(0xFFFF2D55),
        category = ProviderCategory.AGGREGATORS
    ),
    TOGETHER(
        displayName = "Together",
        description = "Llama, Qwen, and more",
        icon = Icons.Default.Groups,
        iconTint = Color(0xFF007AFF),
        category = ProviderCategory.AGGREGATORS
    ),
    FIREWORKS(
        displayName = "Fireworks",
        description = "Fast inference",
        icon = Icons.Default.LocalFireDepartment,
        iconTint = Color(0xFFFF9500),
        category = ProviderCategory.AGGREGATORS
    ),
    
    // Local
    OLLAMA(
        displayName = "Ollama",
        description = "Run models locally",
        icon = Icons.Default.Computer,
        iconTint = Color(0xFF34C759),
        badge = "No API Key",
        category = ProviderCategory.LOCAL
    ),
    LMSTUDIO(
        displayName = "LM Studio",
        description = "Local LM Studio server",
        icon = Icons.Default.Storage,
        iconTint = Color(0xFFAF52DE),
        badge = "No API Key",
        category = ProviderCategory.LOCAL
    )
}

enum class ProviderCategory(val displayName: String) {
    POPULAR("Popular"),
    OPEN_SOURCE("Open Source"),
    AGGREGATORS("Aggregators"),
    LOCAL("Local")
}

/**
 * Add API Key Prompt screen
 * Shown after E2EE setup to prompt user to add their first API key
 * Matches iOS AddApiKeyPromptView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddApiKeyPromptScreen(
    onSelectProvider: (LLMProvider) -> Unit,
    onSkip: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Connection") }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(vertical = 16.dp)
        ) {
            // Header
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                        .padding(bottom = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.Key,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = Color(0xFFFF9500)
                    )
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Text(
                        text = "Add Your First API Key",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    Text(
                        text = "Connect an AI provider to start chatting",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            // Provider categories
            ProviderCategory.entries.forEach { category ->
                val providers = LLMProvider.entries.filter { it.category == category }
                
                item {
                    Text(
                        text = category.displayName,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
                    )
                }
                
                providers.forEach { provider ->
                    item {
                        ProviderCard(
                            provider = provider,
                            onClick = { onSelectProvider(provider) }
                        )
                    }
                }
                
                // Footer for Local category
                if (category == ProviderCategory.LOCAL) {
                    item {
                        Text(
                            text = "Run AI completely offline on your own hardware.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp)
                        )
                    }
                }
                
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }
            
            // Skip button
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                        .padding(top = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    TextButton(onClick = onSkip) {
                        Text(
                            text = "I'll do this later",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(4.dp))
                    
                    Text(
                        text = "You can add API keys anytime in Settings.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun ProviderCard(
    provider: LLMProvider,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = provider.icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = provider.iconTint
            )
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = provider.displayName,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                    
                    provider.badge?.let { badge ->
                        Spacer(modifier = Modifier.width(8.dp))
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = Color(0xFF34C759).copy(alpha = 0.15f)
                        ) {
                            Text(
                                text = badge,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                style = MaterialTheme.typography.labelSmall,
                                color = Color(0xFF34C759)
                            )
                        }
                    }
                }
                
                Text(
                    text = provider.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            )
        }
    }
}
