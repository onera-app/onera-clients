package chat.onera.mobile.presentation.features.chatlist

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.usecase.chat.DeleteChatUseCase
import chat.onera.mobile.domain.usecase.chat.GetChatsUseCase
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import timber.log.Timber
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import javax.inject.Inject

/**
 * ViewModel for the chat list sidebar.
 * Handles chat list operations separately from individual chat functionality.
 */
@HiltViewModel
class ChatListViewModel @Inject constructor(
    private val getChatsUseCase: GetChatsUseCase,
    private val deleteChatUseCase: DeleteChatUseCase,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository
) : BaseViewModel<ChatListState, ChatListIntent, ChatListEffect>(ChatListState()) {

    init {
        loadInitialData()
        observeChats()
    }

    override fun handleIntent(intent: ChatListIntent) {
        when (intent) {
            is ChatListIntent.LoadChats -> loadInitialData()
            is ChatListIntent.RefreshChats -> refreshChats()
            is ChatListIntent.SelectChat -> selectChat(intent.chatId)
            is ChatListIntent.CreateNewChat -> createNewChat()
            is ChatListIntent.DeleteChat -> deleteChat(intent.chatId)
            is ChatListIntent.UpdateSearchQuery -> updateSearchQuery(intent.query)
            is ChatListIntent.SignOut -> signOut()
            is ChatListIntent.ClearError -> updateState { copy(error = null) }
        }
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            try {
                val user = authRepository.getCurrentUser()
                updateState { copy(currentUser = user) }
                refreshChats()
            } catch (e: Exception) {
                Timber.e(e, "Failed to load initial data")
                sendEffect(ChatListEffect.ShowError(e.message ?: "Failed to load data"))
            }
        }
    }

    private fun observeChats() {
        getChatsUseCase()
            .onEach { chats ->
                val summaries = chats.map { chat ->
                    ChatSummary(
                        id = chat.id,
                        title = chat.title,
                        lastMessage = chat.lastMessage,
                        updatedAt = chat.updatedAt,
                        isEncrypted = true
                    )
                }
                val grouped = groupChatsByDate(summaries)
                updateState { 
                    copy(
                        chats = summaries,
                        groupedChats = grouped,
                        isLoading = false
                    ) 
                }
            }
            .catch { e ->
                Timber.e(e, "Failed to observe chats")
                updateState { copy(isLoading = false, error = e.message) }
            }
            .launchIn(viewModelScope)
    }

    private fun refreshChats() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                chatRepository.refreshChats()
                updateState { copy(isLoading = false) }
            } catch (e: Exception) {
                Timber.e(e, "Failed to refresh chats")
                updateState { copy(isLoading = false) }
                sendEffect(ChatListEffect.ShowError(e.message ?: "Failed to refresh chats"))
            }
        }
    }

    private fun selectChat(chatId: String) {
        updateState { copy(selectedChatId = chatId) }
        sendEffect(ChatListEffect.ChatSelected(chatId))
    }

    private fun createNewChat() {
        updateState { copy(selectedChatId = null) }
        sendEffect(ChatListEffect.NewChatCreated(null))
    }

    private fun deleteChat(chatId: String) {
        viewModelScope.launch {
            try {
                deleteChatUseCase(chatId)
                // If deleted chat was selected, clear selection
                if (currentState.selectedChatId == chatId) {
                    updateState { copy(selectedChatId = null) }
                    sendEffect(ChatListEffect.NewChatCreated(null))
                }
                Timber.d("Chat deleted: $chatId")
            } catch (e: Exception) {
                Timber.e(e, "Failed to delete chat")
                sendEffect(ChatListEffect.ShowError(e.message ?: "Failed to delete chat"))
            }
        }
    }

    private fun updateSearchQuery(query: String) {
        updateState { copy(searchQuery = query) }
    }

    private fun signOut() {
        viewModelScope.launch {
            try {
                chatRepository.clearKeyCache()
                authRepository.signOut()
                sendEffect(ChatListEffect.SignOutComplete)
            } catch (e: Exception) {
                Timber.e(e, "Failed to sign out")
                sendEffect(ChatListEffect.ShowError(e.message ?: "Failed to sign out"))
            }
        }
    }

    /**
     * Groups chats by date for organized display in the sidebar.
     */
    private fun groupChatsByDate(chats: List<ChatSummary>): List<Pair<ChatGroup, List<ChatSummary>>> {
        val now = LocalDate.now()
        
        return chats
            .groupBy { chat ->
                val chatDate = Instant.ofEpochMilli(chat.updatedAt)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                
                val daysDiff = ChronoUnit.DAYS.between(chatDate, now)
                
                when {
                    daysDiff == 0L -> ChatGroup.TODAY
                    daysDiff == 1L -> ChatGroup.YESTERDAY
                    daysDiff <= 7L -> ChatGroup.PREVIOUS_7_DAYS
                    daysDiff <= 30L -> ChatGroup.PREVIOUS_30_DAYS
                    else -> ChatGroup.OLDER
                }
            }
            .toSortedMap(compareBy { it.ordinal })
            .map { (group, groupChats) -> 
                group to groupChats.sortedByDescending { it.updatedAt }
            }
    }

    /**
     * Called after E2EE unlock to refresh data.
     */
    fun onE2EEUnlocked() {
        Timber.d("E2EE unlocked, refreshing chat list...")
        refreshChats()
    }
}
