package chat.onera.mobile.presentation.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
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
// OCEAN THEME SCHEMES
// ==============================================================================

private val OceanDarkColorScheme = darkColorScheme(
    primary = OceanPrimary,
    onPrimary = OceanOnPrimary,
    primaryContainer = OceanPrimaryVariant,
    onPrimaryContainer = OceanOnPrimary,
    secondary = OceanSecondary,
    onSecondary = OceanOnSecondary,
    secondaryContainer = OceanSecondaryVariant,
    onSecondaryContainer = OceanOnSecondary,
    tertiary = OceanTertiary,
    onTertiary = OceanOnTertiary,
    background = OceanBackgroundDark,
    onBackground = OceanOnBackgroundDark,
    surface = OceanSurfaceDark,
    onSurface = OceanOnSurfaceDark,
    surfaceVariant = OceanSurfaceVariantDark,
    onSurfaceVariant = OceanOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = OceanOutlineDark
)

private val OceanLightColorScheme = lightColorScheme(
    primary = OceanPrimary,
    onPrimary = OceanOnPrimary,
    primaryContainer = OceanPrimaryVariant,
    onPrimaryContainer = OceanOnPrimary,
    secondary = OceanSecondary,
    onSecondary = OceanOnSecondary,
    secondaryContainer = OceanSecondaryVariant,
    onSecondaryContainer = OceanOnSecondary,
    tertiary = OceanTertiary,
    onTertiary = OceanOnTertiary,
    background = OceanBackgroundLight,
    onBackground = OceanOnBackgroundLight,
    surface = OceanSurfaceLight,
    onSurface = OceanOnSurfaceLight,
    surfaceVariant = OceanSurfaceVariantLight,
    onSurfaceVariant = OceanOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = OceanOutlineLight
)

// ==============================================================================
// FOREST THEME SCHEMES
// ==============================================================================

private val ForestDarkColorScheme = darkColorScheme(
    primary = ForestPrimary,
    onPrimary = ForestOnPrimary,
    primaryContainer = ForestPrimaryVariant,
    onPrimaryContainer = ForestOnPrimary,
    secondary = ForestSecondary,
    onSecondary = ForestOnSecondary,
    secondaryContainer = ForestSecondaryVariant,
    onSecondaryContainer = ForestOnSecondary,
    tertiary = ForestTertiary,
    onTertiary = ForestOnTertiary,
    background = ForestBackgroundDark,
    onBackground = ForestOnBackgroundDark,
    surface = ForestSurfaceDark,
    onSurface = ForestOnSurfaceDark,
    surfaceVariant = ForestSurfaceVariantDark,
    onSurfaceVariant = ForestOnSurfaceVariantDark,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ForestOutlineDark
)

private val ForestLightColorScheme = lightColorScheme(
    primary = ForestPrimary,
    onPrimary = ForestOnPrimary,
    primaryContainer = ForestPrimaryVariant,
    onPrimaryContainer = ForestOnPrimary,
    secondary = ForestSecondary,
    onSecondary = ForestOnSecondary,
    secondaryContainer = ForestSecondaryVariant,
    onSecondaryContainer = ForestOnSecondary,
    tertiary = ForestTertiary,
    onTertiary = ForestOnTertiary,
    background = ForestBackgroundLight,
    onBackground = ForestOnBackgroundLight,
    surface = ForestSurfaceLight,
    onSurface = ForestOnSurfaceLight,
    surfaceVariant = ForestSurfaceVariantLight,
    onSurfaceVariant = ForestOnSurfaceVariantLight,
    error = Error,
    onError = OnError,
    errorContainer = ErrorContainer,
    onErrorContainer = OnErrorContainer,
    outline = ForestOutlineLight
)

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
        AppTheme.OCEAN -> if (isDark) OceanDarkColorScheme else OceanLightColorScheme
        AppTheme.FOREST -> if (isDark) ForestDarkColorScheme else ForestLightColorScheme
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
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
