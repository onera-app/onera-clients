package chat.onera.mobile.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

// Extension for DataStore
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "theme_preferences")

/**
 * Theme mode for light/dark appearance
 */
enum class ThemeMode(val displayName: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark")
}

/**
 * App theme variants
 */
enum class AppTheme(val displayName: String) {
    DEFAULT("Default"),
    CLAUDE("Claude"),
    OCEAN("Ocean"),
    FOREST("Forest")
}

/**
 * Manages theme preferences using DataStore.
 * Provides reactive flows for theme settings and suspend functions for updates.
 */
@Singleton
class ThemePreferences @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    private object PreferencesKeys {
        val THEME_MODE = stringPreferencesKey("theme_mode")
        val APP_THEME = stringPreferencesKey("app_theme")
    }
    
    /**
     * Flow of current theme mode (System/Light/Dark)
     */
    val themeMode: Flow<ThemeMode> = context.dataStore.data.map { preferences ->
        val modeString = preferences[PreferencesKeys.THEME_MODE] ?: ThemeMode.SYSTEM.name
        try {
            ThemeMode.valueOf(modeString)
        } catch (e: IllegalArgumentException) {
            ThemeMode.SYSTEM
        }
    }
    
    /**
     * Flow of current app theme (Default/Claude/etc)
     */
    val appTheme: Flow<AppTheme> = context.dataStore.data.map { preferences ->
        val themeString = preferences[PreferencesKeys.APP_THEME] ?: AppTheme.DEFAULT.name
        try {
            AppTheme.valueOf(themeString)
        } catch (e: IllegalArgumentException) {
            AppTheme.DEFAULT
        }
    }
    
    /**
     * Set the theme mode
     */
    suspend fun setThemeMode(mode: ThemeMode) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.THEME_MODE] = mode.name
        }
    }
    
    /**
     * Set the app theme
     */
    suspend fun setAppTheme(theme: AppTheme) {
        context.dataStore.edit { preferences ->
            preferences[PreferencesKeys.APP_THEME] = theme.name
        }
    }
}
