package chat.onera.mobile.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType
import chat.onera.mobile.presentation.features.apikey.AddApiKeyPromptScreen
import chat.onera.mobile.presentation.features.auth.AuthScreen
import chat.onera.mobile.presentation.features.e2ee.E2EESetupScreen
import chat.onera.mobile.presentation.features.e2ee.E2EEUnlockScreen
import chat.onera.mobile.presentation.features.main.MainScreen
import chat.onera.mobile.presentation.features.notes.NotesListScreen
import chat.onera.mobile.presentation.features.notes.editor.NoteEditorScreen
import chat.onera.mobile.presentation.features.onboarding.OnboardingScreen
import chat.onera.mobile.presentation.features.settings.SettingsScreen
import chat.onera.mobile.presentation.features.settings.account.AccountSettingsScreen
import chat.onera.mobile.presentation.features.settings.appearance.AppearanceScreen
import chat.onera.mobile.presentation.features.settings.credentials.AddCredentialScreen
import chat.onera.mobile.presentation.features.settings.credentials.CredentialsListScreen
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Construction
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OneraNavHost(
    navController: NavHostController = rememberNavController(),
    startDestination: String = Routes.Auth.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Auth screen
        composable(Routes.Auth.route) {
            AuthScreen(
                onAuthSuccess = {
                    navController.navigate(Routes.Main.route) {
                        popUpTo(Routes.Auth.route) { inclusive = true }
                    }
                },
                onNeedsE2EESetup = {
                    navController.navigate(Routes.Onboarding.route)
                },
                onNeedsE2EEUnlock = {
                    navController.navigate(Routes.E2EEUnlock.route)
                }
            )
        }
        
        // Onboarding (educational intro for new users)
        composable(Routes.Onboarding.route) {
            OnboardingScreen(
                onComplete = {
                    navController.navigate(Routes.E2EESetup.route) {
                        popUpTo(Routes.Onboarding.route) { inclusive = true }
                    }
                }
            )
        }
        
        // E2EE Setup (new users)
        composable(Routes.E2EESetup.route) {
            E2EESetupScreen(
                onSetupComplete = {
                    navController.navigate(Routes.AddApiKeyPrompt.route) {
                        popUpTo(Routes.Auth.route) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack() }
            )
        }
        
        // E2EE Unlock (returning users)
        composable(Routes.E2EEUnlock.route) {
            E2EEUnlockScreen(
                onUnlockComplete = {
                    // Navigate with refresh=true to trigger data reload
                    navController.navigate(Routes.Main.createRoute(refresh = true)) {
                        popUpTo(Routes.Auth.route) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack() }
            )
        }
        
        // Add API Key Prompt (after E2EE setup)
        composable(Routes.AddApiKeyPrompt.route) {
            AddApiKeyPromptScreen(
                onSelectProvider = { provider ->
                    // Navigate to Main first, clearing auth flow
                    navController.navigate(Routes.Main.route) {
                        popUpTo(Routes.Auth.route) { inclusive = true }
                    }
                    // Then navigate to Add Credential screen
                    navController.navigate(Routes.AddCredential.route)
                },
                onSkip = {
                    navController.navigate(Routes.Main.route) {
                        popUpTo(Routes.Auth.route) { inclusive = true }
                    }
                }
            )
        }
        
        // Main screen with drawer
        composable(
            route = Routes.Main.route,
            arguments = listOf(
                navArgument("refresh") { 
                    type = NavType.BoolType
                    defaultValue = false 
                }
            )
        ) { backStackEntry ->
            val refresh = backStackEntry.arguments?.getBoolean("refresh") ?: false
            MainScreen(
                refreshOnStart = refresh,
                onNavigateToSettings = {
                    navController.navigate(Routes.Settings.route)
                },
                onNavigateToNotes = {
                    navController.navigate(Routes.Notes.route)
                },
                onSignOut = {
                    navController.navigate(Routes.Auth.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
        
        // Notes
        composable(Routes.Notes.route) {
            NotesListScreen(
                onBack = { navController.popBackStack() },
                onNoteSelected = { noteId ->
                    navController.navigate(Routes.NoteEditor.createRoute(noteId))
                },
                onCreateNote = {
                    navController.navigate(Routes.NoteEditor.createRoute(null))
                }
            )
        }
        
        // Note Editor
        composable(
            route = Routes.NoteEditor.route,
            arguments = listOf(
                navArgument(NavArgs.NOTE_ID) {
                    type = NavType.StringType
                    nullable = true
                    defaultValue = null
                }
            )
        ) { backStackEntry ->
            val noteId = backStackEntry.arguments?.getString(NavArgs.NOTE_ID)
            NoteEditorScreen(
                noteId = noteId,
                onBack = { navController.popBackStack() }
            )
        }
        
        // Settings
        composable(Routes.Settings.route) {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onSecuritySettings = {
                    navController.navigate(Routes.SecuritySettings.route)
                },
                onAccountSettings = {
                    navController.navigate(Routes.AccountSettings.route)
                },
                onEncryptionKeys = {
                    navController.navigate(Routes.EncryptionKeys.route)
                },
                onAPICredentials = {
                    navController.navigate(Routes.APICredentials.route)
                },
                onAppearance = {
                    navController.navigate(Routes.AppearanceSettings.route)
                },
                onSignOut = {
                    navController.navigate(Routes.Auth.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
        
        // Appearance Settings
        composable(Routes.AppearanceSettings.route) {
            AppearanceScreen(
                onBack = { navController.popBackStack() }
            )
        }
        
        // Account Settings
        composable(Routes.AccountSettings.route) {
            AccountSettingsScreen(
                onBack = { navController.popBackStack() }
            )
        }
        
        // API Credentials List
        composable(Routes.APICredentials.route) {
            CredentialsListScreen(
                onBack = { navController.popBackStack() },
                onAddCredential = {
                    navController.navigate(Routes.AddCredential.route)
                }
            )
        }
        
        // Add Credential
        composable(Routes.AddCredential.route) {
            AddCredentialScreen(
                onBack = { navController.popBackStack() },
                onCredentialAdded = { navController.popBackStack() }
            )
        }
        
        // Security Settings (placeholder)
        composable(Routes.SecuritySettings.route) {
            ComingSoonScreen(
                title = "E2EE Security",
                onBack = { navController.popBackStack() }
            )
        }
        
        // Encryption Keys (placeholder)
        composable(Routes.EncryptionKeys.route) {
            ComingSoonScreen(
                title = "Recovery Phrase",
                onBack = { navController.popBackStack() }
            )
        }
    }
}

/**
 * Placeholder screen for features coming soon
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ComingSoonScreen(
    title: String,
    onBack: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.Construction,
                contentDescription = null,
                modifier = Modifier.padding(bottom = 16.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Text(
                text = "Coming Soon",
                style = MaterialTheme.typography.headlineSmall,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "This feature is under development",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}
