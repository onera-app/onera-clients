package chat.onera.mobile.presentation.features.settings.appearance

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.preferences.AppTheme
import chat.onera.mobile.data.preferences.ThemeMode
import chat.onera.mobile.data.preferences.ThemePreferences
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

// State
data class AppearanceState(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val appTheme: AppTheme = AppTheme.DEFAULT
) : UiState

// Intent
sealed interface AppearanceIntent : UiIntent {
    data class SetThemeMode(val mode: ThemeMode) : AppearanceIntent
    data class SetAppTheme(val theme: AppTheme) : AppearanceIntent
}

// Effect (none needed currently, but included for completeness)
sealed interface AppearanceEffect : UiEffect

@HiltViewModel
class AppearanceViewModel @Inject constructor(
    private val themePreferences: ThemePreferences
) : BaseViewModel<AppearanceState, AppearanceIntent, AppearanceEffect>(AppearanceState()) {

    init {
        observeThemePreferences()
    }

    private fun observeThemePreferences() {
        viewModelScope.launch {
            themePreferences.themeMode.collect { mode ->
                updateState { copy(themeMode = mode) }
            }
        }
        viewModelScope.launch {
            themePreferences.appTheme.collect { theme ->
                updateState { copy(appTheme = theme) }
            }
        }
    }

    override fun handleIntent(intent: AppearanceIntent) {
        when (intent) {
            is AppearanceIntent.SetThemeMode -> setThemeMode(intent.mode)
            is AppearanceIntent.SetAppTheme -> setAppTheme(intent.theme)
        }
    }

    private fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch {
            themePreferences.setThemeMode(mode)
        }
    }

    private fun setAppTheme(theme: AppTheme) {
        viewModelScope.launch {
            themePreferences.setAppTheme(theme)
        }
    }
}
