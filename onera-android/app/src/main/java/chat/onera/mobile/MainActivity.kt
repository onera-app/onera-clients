package chat.onera.mobile

import android.content.Intent
import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.data.preferences.AppTheme
import chat.onera.mobile.data.preferences.ThemeMode
import chat.onera.mobile.data.preferences.ThemePreferences
import chat.onera.mobile.presentation.navigation.OneraNavHost
import chat.onera.mobile.presentation.theme.OneraTheme
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.handleDeeplinks
import timber.log.Timber
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {
    
    @Inject
    lateinit var themePreferences: ThemePreferences
    
    @Inject
    lateinit var supabaseClient: SupabaseClient
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        // Let Supabase SDK handle OAuth deep link callbacks
        supabaseClient.handleDeeplinks(intent)
        
        setContent {
            // Collect theme preferences
            val themeMode by themePreferences.themeMode.collectAsStateWithLifecycle(initialValue = ThemeMode.SYSTEM)
            val appTheme by themePreferences.appTheme.collectAsStateWithLifecycle(initialValue = AppTheme.DEFAULT)
            
            // Determine if dark theme based on mode
            val systemDarkTheme = isSystemInDarkTheme()
            val isDarkTheme = when (themeMode) {
                ThemeMode.SYSTEM -> systemDarkTheme
                ThemeMode.LIGHT -> false
                ThemeMode.DARK -> true
            }
            
            OneraTheme(
                darkTheme = isDarkTheme,
                appTheme = appTheme
            ) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    OneraNavHost()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Handle deep link when activity is already running (singleTask launch mode)
        supabaseClient.handleDeeplinks(intent)
    }
}
