package chat.onera.mobile.presentation.features.chat

import androidx.compose.runtime.Stable
import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.presentation.features.main.model.ModelOption

/**
 * Consolidates all chat-related event callbacks into a single stable object.
 * This reduces the number of parameters passed through composables and prevents
 * unnecessary recompositions from lambda recreation.
 * 
 * Usage:
 * ```kotlin
 * val eventHandler = remember(viewModel) {
 *     ChatEventHandler.from(viewModel)
 * }
 * 
 * ChatContent(
 *     state = chatState,
 *     eventHandler = eventHandler
 * )
 * ```
 */
@Stable
class ChatEventHandler(
    // Message operations
    val onSendMessage: (String) -> Unit,
    val onUpdateInput: (String) -> Unit,
    val onStopStreaming: () -> Unit,
    val onRegenerateResponse: (String) -> Unit,
    val onCopyMessage: (String) -> Unit,
    val onEditMessage: (messageId: String, newContent: String, regenerate: Boolean) -> Unit,
    
    // Model selection
    val onSelectModel: (ModelOption) -> Unit,
    
    // Voice operations
    val onStartRecording: () -> Unit,
    val onStopRecording: () -> Unit,
    val onSpeakMessage: (text: String, messageId: String) -> Unit,
    val onStopSpeaking: () -> Unit,
    
    // Attachment operations
    val onAddAttachment: (Attachment) -> Unit,
    val onRemoveAttachment: (String) -> Unit,
    
    // Branch navigation
    val onNavigateToPreviousBranch: (String) -> Unit,
    val onNavigateToNextBranch: (String) -> Unit,
    
    // Navigation
    val onMenuTap: () -> Unit,
    val onNewConversation: () -> Unit
) {
    companion object {
        /**
         * Creates a no-op event handler for previews and testing.
         */
        val Empty = ChatEventHandler(
            onSendMessage = {},
            onUpdateInput = {},
            onStopStreaming = {},
            onRegenerateResponse = {},
            onCopyMessage = {},
            onEditMessage = { _, _, _ -> },
            onSelectModel = {},
            onStartRecording = {},
            onStopRecording = {},
            onSpeakMessage = { _, _ -> },
            onStopSpeaking = {},
            onAddAttachment = {},
            onRemoveAttachment = {},
            onNavigateToPreviousBranch = {},
            onNavigateToNextBranch = {},
            onMenuTap = {},
            onNewConversation = {}
        )
    }
}

/**
 * Consolidates chat list related callbacks.
 */
@Stable
class ChatListEventHandler(
    val onSelectChat: (String) -> Unit,
    val onNewChat: () -> Unit,
    val onDeleteChat: (String) -> Unit,
    val onSearchQueryChange: (String) -> Unit,
    val onOpenSettings: () -> Unit,
    val onOpenNotes: () -> Unit,
    val onRefresh: () -> Unit
) {
    companion object {
        val Empty = ChatListEventHandler(
            onSelectChat = {},
            onNewChat = {},
            onDeleteChat = {},
            onSearchQueryChange = {},
            onOpenSettings = {},
            onOpenNotes = {},
            onRefresh = {}
        )
    }
}
