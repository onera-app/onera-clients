package chat.onera.mobile.presentation.features.chat

import chat.onera.mobile.presentation.base.UiIntent

// Chat List Intents
sealed interface ChatListIntent : UiIntent {
    data object LoadChats : ChatListIntent
    data class DeleteChat(val chatId: String) : ChatListIntent
    data object RefreshChats : ChatListIntent
}

// Individual Chat Intents
sealed interface ChatIntent : UiIntent {
    data class LoadChat(val chatId: String?) : ChatIntent
    data class UpdateInput(val text: String) : ChatIntent
    data object SendMessage : ChatIntent
    data object StopStreaming : ChatIntent
    data class RegenerateResponse(val messageId: String) : ChatIntent
    data class DeleteMessage(val messageId: String) : ChatIntent
    data class EditMessage(
        val messageId: String,
        val newContent: String,
        val regenerate: Boolean
    ) : ChatIntent
    data object ClearError : ChatIntent
}
