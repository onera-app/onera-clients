package chat.onera.mobile.presentation.features.settings.appearance

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.data.preferences.AppTheme
import chat.onera.mobile.data.preferences.ThemeMode

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppearanceScreen(
    viewModel: AppearanceViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Appearance") },
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
            // Theme Mode Section
            item {
                Text(
                    text = "MODE",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                
                ThemeModeSelector(
                    selectedMode = state.themeMode,
                    onModeSelected = { viewModel.sendIntent(AppearanceIntent.SetThemeMode(it)) }
                )
            }
            
            // App Theme Section
            item {
                Text(
                    text = "THEME",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                
                AppThemeSelector(
                    selectedTheme = state.appTheme,
                    onThemeSelected = { viewModel.sendIntent(AppearanceIntent.SetAppTheme(it)) }
                )
            }
        }
    }
}

@Composable
private fun ThemeModeSelector(
    selectedMode: ThemeMode,
    onModeSelected: (ThemeMode) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column {
            ThemeMode.entries.forEach { mode ->
                ListItem(
                    headlineContent = { Text(mode.displayName) },
                    trailingContent = {
                        if (selectedMode == mode) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Selected",
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    },
                    modifier = Modifier.clickable { onModeSelected(mode) },
                    colors = ListItemDefaults.colors(
                        containerColor = Color.Transparent
                    )
                )
                if (mode != ThemeMode.entries.last()) {
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }
}

@Composable
private fun AppThemeSelector(
    selectedTheme: AppTheme,
    onThemeSelected: (AppTheme) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column {
            AppTheme.entries.forEach { theme ->
                ListItem(
                    headlineContent = { 
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            // Color preview dot
                            Box(
                                modifier = Modifier
                                    .size(24.dp)
                                    .clip(CircleShape)
                                    .background(getThemePreviewColor(theme))
                                    .then(
                                        if (selectedTheme == theme) {
                                            Modifier.border(
                                                width = 2.dp,
                                                color = MaterialTheme.colorScheme.primary,
                                                shape = CircleShape
                                            )
                                        } else Modifier
                                    )
                            )
                            
                            Text(theme.displayName)
                            
                            // "New" badge for new themes
                            if (theme in listOf(AppTheme.CHATGPT, AppTheme.T3CHAT, AppTheme.GEMINI, AppTheme.GROQ)) {
                                Surface(
                                    shape = RoundedCornerShape(4.dp),
                                    color = getThemePreviewColor(theme)
                                ) {
                                    Text(
                                        text = "New",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = Color.White,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }
                    },
                    trailingContent = {
                        if (selectedTheme == theme) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Selected",
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    },
                    modifier = Modifier.clickable { onThemeSelected(theme) },
                    colors = ListItemDefaults.colors(
                        containerColor = Color.Transparent
                    )
                )
                if (theme != AppTheme.entries.last()) {
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }
}

private fun getThemePreviewColor(theme: AppTheme): Color {
    return when (theme) {
        AppTheme.DEFAULT -> Color(0xFF6366F1) // Indigo
        AppTheme.CLAUDE -> Color(0xFFD97757) // Claude coral
        AppTheme.CHATGPT -> Color(0xFF10A37F) // ChatGPT teal
        AppTheme.T3CHAT -> Color(0xFFA855F7) // T3 Chat purple
        AppTheme.GEMINI -> Color(0xFF4285F4) // Gemini blue
        AppTheme.GROQ -> Color(0xFFF55036) // Groq orange-red
    }
}
