package chat.onera.mobile.presentation.features.main

import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.features.main.model.ModelOption

sealed interface MainIntent : UiIntent {
    // Sidebar intents
    data object RefreshChats : MainIntent
    data class SelectChat(val chatId: String) : MainIntent
    data object CreateNewChat : MainIntent
    data class DeleteChat(val chatId: String) : MainIntent
    data class UpdateSearchQuery(val query: String) : MainIntent
    
    // Folder intents
    data object LoadFolders : MainIntent
    data class CreateFolder(val name: String, val parentId: String? = null) : MainIntent
    data class DeleteFolder(val folderId: String) : MainIntent
    data class RenameFolder(val folderId: String, val newName: String) : MainIntent
    data class SelectFolder(val folderId: String?) : MainIntent
    data class MoveChatToFolder(val chatId: String, val folderId: String?) : MainIntent
    data class ToggleFolderExpanded(val folderId: String) : MainIntent
    
    // Chat intents
    data class SendMessage(val content: String) : MainIntent
    data class UpdateChatInput(val input: String) : MainIntent
    data object StopStreaming : MainIntent
    data class RegenerateResponse(val messageId: String) : MainIntent
    data class CopyMessage(val content: String) : MainIntent
    data class SelectModel(val model: ModelOption) : MainIntent
    data class EditMessage(
        val messageId: String,
        val newContent: String,
        val regenerate: Boolean
    ) : MainIntent
    
    // Branch navigation intents
    data class NavigateToPreviousBranch(val messageId: String) : MainIntent
    data class NavigateToNextBranch(val messageId: String) : MainIntent
    
    // Voice input intents
    data object StartRecording : MainIntent
    data object StopRecording : MainIntent
    
    // TTS intents
    data class SpeakMessage(val text: String, val messageId: String) : MainIntent
    data object StopSpeaking : MainIntent
    
    // Attachment intents
    data class AddAttachment(val attachment: Attachment) : MainIntent
    data class RemoveAttachment(val attachmentId: String) : MainIntent
    data object ClearAttachments : MainIntent
    
    // Auth intents
    data object SignOut : MainIntent
    
    // E2EE intents
    data object OnE2EEUnlocked : MainIntent
}
