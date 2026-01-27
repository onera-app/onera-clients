package chat.onera.mobile.presentation.navigation

/**
 * Navigation routes for the app
 */
sealed class Routes(val route: String) {
    
    // Auth flow
    data object Auth : Routes("auth")
    data object Welcome : Routes("welcome")
    data object Onboarding : Routes("onboarding")
    data object SignIn : Routes("sign_in")
    data object SignUp : Routes("sign_up")
    data object RecoverySetup : Routes("recovery_setup")
    data object RecoveryVerify : Routes("recovery_verify")
    
    // Main flow
    data object Main : Routes("main?refresh={refresh}") {
        fun createRoute(refresh: Boolean = false) = "main?refresh=$refresh"
    }
    
    // Notes flow
    data object Notes : Routes("notes")
    data object NoteEditor : Routes("note_editor?noteId={noteId}") {
        fun createRoute(noteId: String?) = if (noteId != null) {
            "note_editor?noteId=$noteId"
        } else {
            "note_editor"
        }
    }
    
    // Folders flow
    data object Folders : Routes("folders")
    data object FolderDetail : Routes("folder/{folderId}") {
        fun createRoute(folderId: String) = "folder/$folderId"
    }
    
    // Settings flow
    data object Settings : Routes("settings")
    data object SecuritySettings : Routes("security_settings")
    data object AccountSettings : Routes("account_settings")
    data object EncryptionKeys : Routes("encryption_keys")
    data object APICredentials : Routes("api_credentials")
    data object AddCredential : Routes("add_credential")
    data object AppearanceSettings : Routes("appearance_settings")
    
    // E2EE flow
    data object E2EESetup : Routes("e2ee_setup")
    data object E2EEUnlock : Routes("e2ee_unlock")
    data object KeyBackup : Routes("key_backup")
    data object KeyRestore : Routes("key_restore")
    
    // API Key flow
    data object AddApiKeyPrompt : Routes("add_api_key_prompt")
}

/**
 * Navigation arguments
 */
object NavArgs {
    const val CHAT_ID = "chatId"
    const val NOTE_ID = "noteId"
    const val FOLDER_ID = "folderId"
}
