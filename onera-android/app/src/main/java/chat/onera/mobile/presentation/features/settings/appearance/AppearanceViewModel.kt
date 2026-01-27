package chat.onera.mobile.presentation.features.settings.appearance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.data.preferences.AppTheme
import chat.onera.mobile.data.preferences.ThemeMode
import chat.onera.mobile.data.preferences.ThemePreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AppearanceState(
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val appTheme: AppTheme = AppTheme.DEFAULT
)

@HiltViewModel
class AppearanceViewModel @Inject constructor(
    private val themePreferences: ThemePreferences
) : ViewModel() {
    
    val state = combine(
        themePreferences.themeMode,
        themePreferences.appTheme
    ) { themeMode, appTheme ->
        AppearanceState(
            themeMode = themeMode,
            appTheme = appTheme
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = AppearanceState()
    )
    
    fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch {
            themePreferences.setThemeMode(mode)
        }
    }
    
    fun setAppTheme(theme: AppTheme) {
        viewModelScope.launch {
            themePreferences.setAppTheme(theme)
        }
    }
}
