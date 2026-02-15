package chat.onera.mobile.presentation.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import chat.onera.mobile.data.preferences.AppTheme

// ==============================================================================
// DEFAULT THEME SCHEMES
// ==============================================================================

private val DefaultDarkColorScheme = darkColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = PrimaryVariant,
    onPrimaryContainer = OnPrimary,
    secondary = Secondary,
    onSecondary = OnSecondary,
    secondaryContainer = SecondaryVariant,
    onSecondaryContainer = OnSecondary,
    tertiary = Tertiary,
    onTertiary = OnTertiary,
    background = BackgroundDark,
    onBackground = OnBackgroundDark,
    surface = SurfaceDark,
    onSurface = OnSurfaceDark,
    surfaceVariant = SurfaceVariantDark,
    onSurfaceVariant = OnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = OutlineDark
)

private val DefaultLightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = PrimaryVariant,
    onPrimaryContainer = OnPrimary,
    secondary = Secondary,
    onSecondary = OnSecondary,
    secondaryContainer = SecondaryVariant,
    onSecondaryContainer = OnSecondary,
    tertiary = Tertiary,
    onTertiary = OnTertiary,
    background = BackgroundLight,
    onBackground = OnBackgroundLight,
    surface = SurfaceLight,
    onSurface = OnSurfaceLight,
    surfaceVariant = SurfaceVariantLight,
    onSurfaceVariant = OnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = OutlineLight
)

// ==============================================================================
// CLAUDE THEME SCHEMES
// ==============================================================================

private val ClaudeDarkColorScheme = darkColorScheme(
    primary = ClaudePrimary,
    onPrimary = ClaudeOnPrimary,
    primaryContainer = ClaudePrimaryVariant,
    onPrimaryContainer = ClaudeOnPrimary,
    secondary = ClaudeSecondary,
    onSecondary = ClaudeOnSecondary,
    secondaryContainer = ClaudeSecondaryVariant,
    onSecondaryContainer = ClaudeOnSecondary,
    tertiary = ClaudeTertiary,
    onTertiary = ClaudeOnTertiary,
    background = ClaudeBackgroundDark,
    onBackground = ClaudeOnBackgroundDark,
    surface = ClaudeSurfaceDark,
    onSurface = ClaudeOnSurfaceDark,
    surfaceVariant = ClaudeSurfaceVariantDark,
    onSurfaceVariant = ClaudeOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ClaudeOutlineDark
)

private val ClaudeLightColorScheme = lightColorScheme(
    primary = ClaudePrimary,
    onPrimary = ClaudeOnPrimary,
    primaryContainer = ClaudePrimaryVariant,
    onPrimaryContainer = ClaudeOnPrimary,
    secondary = ClaudeSecondary,
    onSecondary = ClaudeOnSecondary,
    secondaryContainer = ClaudeSecondaryVariant,
    onSecondaryContainer = ClaudeOnSecondary,
    tertiary = ClaudeTertiary,
    onTertiary = ClaudeOnTertiary,
    background = ClaudeBackgroundLight,
    onBackground = ClaudeOnBackgroundLight,
    surface = ClaudeSurfaceLight,
    onSurface = ClaudeOnSurfaceLight,
    surfaceVariant = ClaudeSurfaceVariantLight,
    onSurfaceVariant = ClaudeOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ClaudeOutlineLight
)

// ==============================================================================
// CHATGPT THEME SCHEMES
// ==============================================================================

private val ChatGPTDarkColorScheme = darkColorScheme(
    primary = ChatGPTPrimary,
    onPrimary = ChatGPTOnPrimary,
    primaryContainer = ChatGPTPrimaryVariant,
    onPrimaryContainer = ChatGPTOnPrimary,
    secondary = ChatGPTSecondary,
    onSecondary = ChatGPTOnSecondary,
    secondaryContainer = ChatGPTSecondaryVariant,
    onSecondaryContainer = ChatGPTOnSecondary,
    tertiary = ChatGPTTertiary,
    onTertiary = ChatGPTOnTertiary,
    background = ChatGPTBackgroundDark,
    onBackground = ChatGPTOnBackgroundDark,
    surface = ChatGPTSurfaceDark,
    onSurface = ChatGPTOnSurfaceDark,
    surfaceVariant = ChatGPTSurfaceVariantDark,
    onSurfaceVariant = ChatGPTOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ChatGPTOutlineDark
)

private val ChatGPTLightColorScheme = lightColorScheme(
    primary = ChatGPTPrimary,
    onPrimary = ChatGPTOnPrimary,
    primaryContainer = ChatGPTPrimaryVariant,
    onPrimaryContainer = ChatGPTOnPrimary,
    secondary = ChatGPTSecondary,
    onSecondary = ChatGPTOnSecondary,
    secondaryContainer = ChatGPTSecondaryVariant,
    onSecondaryContainer = ChatGPTOnSecondary,
    tertiary = ChatGPTTertiary,
    onTertiary = ChatGPTOnTertiary,
    background = ChatGPTBackgroundLight,
    onBackground = ChatGPTOnBackgroundLight,
    surface = ChatGPTSurfaceLight,
    onSurface = ChatGPTOnSurfaceLight,
    surfaceVariant = ChatGPTSurfaceVariantLight,
    onSurfaceVariant = ChatGPTOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ChatGPTOutlineLight
)

// ==============================================================================
// T3 CHAT THEME SCHEMES
// ==============================================================================

private val T3ChatDarkColorScheme = darkColorScheme(
    primary = T3ChatPrimary,
    onPrimary = T3ChatOnPrimary,
    primaryContainer = T3ChatPrimaryVariant,
    onPrimaryContainer = T3ChatOnPrimary,
    secondary = T3ChatSecondary,
    onSecondary = T3ChatOnSecondary,
    secondaryContainer = T3ChatSecondaryVariant,
    onSecondaryContainer = T3ChatOnSecondary,
    tertiary = T3ChatTertiary,
    onTertiary = T3ChatOnTertiary,
    background = T3ChatBackgroundDark,
    onBackground = T3ChatOnBackgroundDark,
    surface = T3ChatSurfaceDark,
    onSurface = T3ChatOnSurfaceDark,
    surfaceVariant = T3ChatSurfaceVariantDark,
    onSurfaceVariant = T3ChatOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = T3ChatOutlineDark
)

private val T3ChatLightColorScheme = lightColorScheme(
    primary = T3ChatPrimary,
    onPrimary = T3ChatOnPrimary,
    primaryContainer = T3ChatPrimaryVariant,
    onPrimaryContainer = T3ChatOnPrimary,
    secondary = T3ChatSecondary,
    onSecondary = T3ChatOnSecondary,
    secondaryContainer = T3ChatSecondaryVariant,
    onSecondaryContainer = T3ChatOnSecondary,
    tertiary = T3ChatTertiary,
    onTertiary = T3ChatOnTertiary,
    background = T3ChatBackgroundLight,
    onBackground = T3ChatOnBackgroundLight,
    surface = T3ChatSurfaceLight,
    onSurface = T3ChatOnSurfaceLight,
    surfaceVariant = T3ChatSurfaceVariantLight,
    onSurfaceVariant = T3ChatOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = T3ChatOutlineLight
)

// ==============================================================================
// GEMINI THEME SCHEMES
// ==============================================================================

private val GeminiDarkColorScheme = darkColorScheme(
    primary = GeminiPrimaryDark,
    onPrimary = GeminiOnPrimary,
    primaryContainer = GeminiPrimaryVariantDark,
    onPrimaryContainer = GeminiOnPrimary,
    secondary = GeminiSecondary,
    onSecondary = GeminiOnSecondary,
    secondaryContainer = GeminiSecondaryVariant,
    onSecondaryContainer = GeminiOnSecondary,
    tertiary = GeminiTertiary,
    onTertiary = GeminiOnTertiary,
    background = GeminiBackgroundDark,
    onBackground = GeminiOnBackgroundDark,
    surface = GeminiSurfaceDark,
    onSurface = GeminiOnSurfaceDark,
    surfaceVariant = GeminiSurfaceVariantDark,
    onSurfaceVariant = GeminiOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = GeminiOutlineDark
)

private val GeminiLightColorScheme = lightColorScheme(
    primary = GeminiPrimary,
    onPrimary = GeminiOnPrimary,
    primaryContainer = GeminiPrimaryVariant,
    onPrimaryContainer = GeminiOnPrimary,
    secondary = GeminiSecondary,
    onSecondary = GeminiOnSecondary,
    secondaryContainer = GeminiSecondaryVariant,
    onSecondaryContainer = GeminiOnSecondary,
    tertiary = GeminiTertiary,
    onTertiary = GeminiOnTertiary,
    background = GeminiBackgroundLight,
    onBackground = GeminiOnBackgroundLight,
    surface = GeminiSurfaceLight,
    onSurface = GeminiOnSurfaceLight,
    surfaceVariant = GeminiSurfaceVariantLight,
    onSurfaceVariant = GeminiOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = GeminiOutlineLight
)

// ==============================================================================
// GROQ THEME SCHEMES
// ==============================================================================

private val GroqDarkColorScheme = darkColorScheme(
    primary = GroqPrimary,
    onPrimary = GroqOnPrimary,
    primaryContainer = GroqPrimaryVariant,
    onPrimaryContainer = GroqOnPrimary,
    secondary = GroqSecondary,
    onSecondary = GroqOnSecondary,
    secondaryContainer = GroqSecondaryVariant,
    onSecondaryContainer = GroqOnSecondary,
    tertiary = GroqTertiary,
    onTertiary = GroqOnTertiary,
    background = GroqBackgroundDark,
    onBackground = GroqOnBackgroundDark,
    surface = GroqSurfaceDark,
    onSurface = GroqOnSurfaceDark,
    surfaceVariant = GroqSurfaceVariantDark,
    onSurfaceVariant = GroqOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = GroqOutlineDark
)

private val GroqLightColorScheme = lightColorScheme(
    primary = GroqPrimary,
    onPrimary = GroqOnPrimary,
    primaryContainer = GroqPrimaryVariant,
    onPrimaryContainer = GroqOnPrimary,
    secondary = GroqSecondary,
    onSecondary = GroqOnSecondary,
    secondaryContainer = GroqSecondaryVariant,
    onSecondaryContainer = GroqOnSecondary,
    tertiary = GroqTertiary,
    onTertiary = GroqOnTertiary,
    background = GroqBackgroundLight,
    onBackground = GroqOnBackgroundLight,
    surface = GroqSurfaceLight,
    onSurface = GroqOnSurfaceLight,
    surfaceVariant = GroqSurfaceVariantLight,
    onSurfaceVariant = GroqOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = GroqOutlineLight
)

// ==============================================================================
// MATERIAL 3 SHAPES
// ==============================================================================

/**
 * Material 3 shape system for Onera.
 * Provides consistent corner radii across the app.
 */
val OneraShapes = Shapes(
    // Extra small: chips, badges
    extraSmall = RoundedCornerShape(4.dp),
    // Small: buttons, text fields
    small = RoundedCornerShape(8.dp),
    // Medium: cards, dialogs
    medium = RoundedCornerShape(12.dp),
    // Large: sheets, large cards
    large = RoundedCornerShape(16.dp),
    // Extra large: full-screen sheets
    extraLarge = RoundedCornerShape(28.dp)
)

/**
 * Message bubble shapes - asymmetric for visual distinction.
 */
object MessageShapes {
    val userBubble = RoundedCornerShape(
        topStart = 16.dp,
        topEnd = 16.dp,
        bottomStart = 16.dp,
        bottomEnd = 4.dp
    )
    
    val assistantBubble = RoundedCornerShape(
        topStart = 16.dp,
        topEnd = 16.dp,
        bottomStart = 4.dp,
        bottomEnd = 16.dp
    )
    
    val codeBlock = RoundedCornerShape(8.dp)
}

// ==============================================================================
// THEME SELECTION HELPER
// ==============================================================================

/**
 * Get color scheme for given app theme and dark mode state
 */
fun getColorSchemeForTheme(appTheme: AppTheme, isDark: Boolean): ColorScheme {
    return when (appTheme) {
        AppTheme.DEFAULT -> if (isDark) DefaultDarkColorScheme else DefaultLightColorScheme
        AppTheme.CLAUDE -> if (isDark) ClaudeDarkColorScheme else ClaudeLightColorScheme
        AppTheme.CHATGPT -> if (isDark) ChatGPTDarkColorScheme else ChatGPTLightColorScheme
        AppTheme.T3CHAT -> if (isDark) T3ChatDarkColorScheme else T3ChatLightColorScheme
        AppTheme.GEMINI -> if (isDark) GeminiDarkColorScheme else GeminiLightColorScheme
        AppTheme.GROQ -> if (isDark) GroqDarkColorScheme else GroqLightColorScheme
    }
}

// ==============================================================================
// MAIN THEME COMPOSABLE
// ==============================================================================

@Composable
fun OneraTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    appTheme: AppTheme = AppTheme.DEFAULT,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        else -> getColorSchemeForTheme(appTheme, darkTheme)
    }
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            // Use WindowCompat for modern edge-to-edge experience
            WindowCompat.setDecorFitsSystemWindows(window, false)
            val insetsController = WindowCompat.getInsetsController(window, view)
            insetsController.isAppearanceLightStatusBars = !darkTheme
            insetsController.isAppearanceLightNavigationBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = OneraShapes,
        content = content
    )
}
