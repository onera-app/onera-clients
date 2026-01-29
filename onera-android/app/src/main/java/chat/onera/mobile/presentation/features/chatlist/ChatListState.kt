package chat.onera.mobile.presentation.features.chatlist

import chat.onera.mobile.domain.model.User
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary

/**
 * UI State for the chat list sidebar.
 */
data class ChatListState(
    val chats: List<ChatSummary> = emptyList(),
    val groupedChats: List<Pair<ChatGroup, List<ChatSummary>>> = emptyList(),
    val isLoading: Boolean = true,
    val searchQuery: String = "",
    val selectedChatId: String? = null,
    val currentUser: User? = null,
    val error: String? = null
) : UiState

/**
 * User intents for the chat list.
 */
sealed interface ChatListIntent : UiIntent {
    data object LoadChats : ChatListIntent
    data object RefreshChats : ChatListIntent
    data class SelectChat(val chatId: String) : ChatListIntent
    data object CreateNewChat : ChatListIntent
    data class DeleteChat(val chatId: String) : ChatListIntent
    data class UpdateSearchQuery(val query: String) : ChatListIntent
    data object SignOut : ChatListIntent
    data object ClearError : ChatListIntent
}

/**
 * One-time effects for the chat list.
 */
sealed interface ChatListEffect : UiEffect {
    data class ChatSelected(val chatId: String) : ChatListEffect
    data class NewChatCreated(val chatId: String?) : ChatListEffect
    data object SignOutComplete : ChatListEffect
    data class ShowError(val message: String) : ChatListEffect
}
