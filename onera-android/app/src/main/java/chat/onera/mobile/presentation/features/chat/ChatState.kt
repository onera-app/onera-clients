package chat.onera.mobile.presentation.features.chat

import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.presentation.base.UiState

// Chat List State
data class ChatListState(
    val isLoading: Boolean = true,
    val chats: List<Chat> = emptyList(),
    val error: String? = null
) : UiState

// Individual Chat State
data class ChatState(
    val isLoading: Boolean = true,
    val chatId: String? = null,
    val chatTitle: String = "New Chat",
    val messages: List<Message> = emptyList(),
    val inputText: String = "",
    val isSending: Boolean = false,
    val isStreaming: Boolean = false,
    val streamingMessage: String = "",
    val isEncrypted: Boolean = true,
    val error: String? = null,
    val editingMessageId: String? = null
) : UiState
