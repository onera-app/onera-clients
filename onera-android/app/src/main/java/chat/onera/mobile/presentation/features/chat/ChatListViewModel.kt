package chat.onera.mobile.presentation.features.chat

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.usecase.chat.DeleteChatUseCase
import chat.onera.mobile.domain.usecase.chat.GetChatsUseCase
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChatListViewModel @Inject constructor(
    private val getChatsUseCase: GetChatsUseCase,
    private val deleteChatUseCase: DeleteChatUseCase
) : BaseViewModel<ChatListState, ChatListIntent, ChatListEffect>(ChatListState()) {

    init {
        sendIntent(ChatListIntent.LoadChats)
    }

    override fun handleIntent(intent: ChatListIntent) {
        when (intent) {
            is ChatListIntent.LoadChats -> loadChats()
            is ChatListIntent.DeleteChat -> deleteChat(intent.chatId)
            is ChatListIntent.RefreshChats -> loadChats()
        }
    }

    private fun loadChats() {
        viewModelScope.launch {
            updateState { copy(isLoading = true, error = null) }
            getChatsUseCase()
                .catch { e ->
                    updateState { copy(isLoading = false, error = e.message) }
                }
                .collect { chats ->
                    updateState { copy(isLoading = false, chats = chats) }
                }
        }
    }

    private fun deleteChat(chatId: String) {
        viewModelScope.launch {
            try {
                deleteChatUseCase(chatId)
            } catch (e: Exception) {
                sendEffect(ChatListEffect.ShowError(e.message ?: "Failed to delete chat"))
            }
        }
    }
}
