package chat.onera.mobile.presentation.features.search

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Note
import chat.onera.mobile.domain.model.Prompt
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.NotesRepository
import chat.onera.mobile.domain.repository.PromptRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import timber.log.Timber
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import javax.inject.Inject

// MARK: - State

enum class SearchFilterType(val displayName: String) {
    ALL("All"),
    CHATS("Chats"),
    NOTES("Notes"),
    PROMPTS("Prompts")
}

enum class SearchDateGroup(val displayName: String) {
    TODAY("Today"),
    YESTERDAY("Yesterday"),
    PREVIOUS_7_DAYS("Previous 7 Days"),
    PREVIOUS_30_DAYS("Previous 30 Days"),
    OLDER("Older")
}

sealed interface SearchResultItem {
    val id: String
    val title: String
    val subtitle: String?
    val updatedAt: Long

    data class ChatResult(
        override val id: String,
        override val title: String,
        override val subtitle: String?,
        override val updatedAt: Long
    ) : SearchResultItem

    data class NoteResult(
        override val id: String,
        override val title: String,
        override val subtitle: String?,
        override val updatedAt: Long
    ) : SearchResultItem

    data class PromptResult(
        override val id: String,
        override val title: String,
        override val subtitle: String?,
        override val updatedAt: Long
    ) : SearchResultItem
}

data class GlobalSearchState(
    val query: String = "",
    val filter: SearchFilterType = SearchFilterType.ALL,
    val isLoading: Boolean = false,
    val groupedResults: List<Pair<SearchDateGroup, List<SearchResultItem>>> = emptyList(),
    val totalResultCount: Int = 0
) : UiState

// MARK: - Intent

sealed interface GlobalSearchIntent : UiIntent {
    data class UpdateQuery(val query: String) : GlobalSearchIntent
    data class SelectFilter(val filter: SearchFilterType) : GlobalSearchIntent
    data class SelectResult(val result: SearchResultItem) : GlobalSearchIntent
}

// MARK: - Effect

sealed interface GlobalSearchEffect : UiEffect {
    data class NavigateToChat(val chatId: String) : GlobalSearchEffect
    data class NavigateToNote(val noteId: String) : GlobalSearchEffect
    data class NavigateToPrompt(val promptId: String) : GlobalSearchEffect
}

// MARK: - ViewModel

@HiltViewModel
class GlobalSearchViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val notesRepository: NotesRepository,
    private val promptRepository: PromptRepository
) : BaseViewModel<GlobalSearchState, GlobalSearchIntent, GlobalSearchEffect>(GlobalSearchState()) {

    private var searchJob: Job? = null

    override fun handleIntent(intent: GlobalSearchIntent) {
        when (intent) {
            is GlobalSearchIntent.UpdateQuery -> updateQuery(intent.query)
            is GlobalSearchIntent.SelectFilter -> selectFilter(intent.filter)
            is GlobalSearchIntent.SelectResult -> selectResult(intent.result)
        }
    }

    private fun updateQuery(query: String) {
        updateState { copy(query = query) }
        performSearch(query, currentState.filter)
    }

    private fun selectFilter(filter: SearchFilterType) {
        updateState { copy(filter = filter) }
        performSearch(currentState.query, filter)
    }

    private fun selectResult(result: SearchResultItem) {
        when (result) {
            is SearchResultItem.ChatResult -> sendEffect(GlobalSearchEffect.NavigateToChat(result.id))
            is SearchResultItem.NoteResult -> sendEffect(GlobalSearchEffect.NavigateToNote(result.id))
            is SearchResultItem.PromptResult -> sendEffect(GlobalSearchEffect.NavigateToPrompt(result.id))
        }
    }

    private fun performSearch(query: String, filter: SearchFilterType) {
        searchJob?.cancel()

        if (query.isBlank()) {
            updateState { copy(groupedResults = emptyList(), totalResultCount = 0, isLoading = false) }
            return
        }

        searchJob = viewModelScope.launch {
            // Debounce
            delay(250)
            updateState { copy(isLoading = true) }

            try {
                val results = mutableListOf<SearchResultItem>()

                // Search chats
                if (filter == SearchFilterType.ALL || filter == SearchFilterType.CHATS) {
                    val chats = chatRepository.getChats()
                    chats.filter { it.title.contains(query, ignoreCase = true) }
                        .map { chat ->
                            SearchResultItem.ChatResult(
                                id = chat.id,
                                title = chat.title,
                                subtitle = chat.lastMessage?.take(80),
                                updatedAt = chat.updatedAt
                            )
                        }
                        .let { results.addAll(it) }
                }

                // Search notes
                if (filter == SearchFilterType.ALL || filter == SearchFilterType.NOTES) {
                    val notes = notesRepository.getNotes()
                    notes.filter {
                        it.title.contains(query, ignoreCase = true) ||
                            it.content.contains(query, ignoreCase = true)
                    }
                        .map { note ->
                            SearchResultItem.NoteResult(
                                id = note.id,
                                title = note.title,
                                subtitle = note.content.take(80).ifBlank { null },
                                updatedAt = note.updatedAt
                            )
                        }
                        .let { results.addAll(it) }
                }

                // Search prompts
                if (filter == SearchFilterType.ALL || filter == SearchFilterType.PROMPTS) {
                    val prompts = promptRepository.getPrompts()
                    prompts.filter {
                        it.name.contains(query, ignoreCase = true) ||
                            it.description.contains(query, ignoreCase = true)
                    }
                        .map { prompt ->
                            SearchResultItem.PromptResult(
                                id = prompt.id,
                                title = prompt.name,
                                subtitle = prompt.description.ifBlank { null },
                                updatedAt = prompt.updatedAt
                            )
                        }
                        .let { results.addAll(it) }
                }

                val grouped = groupByDate(results)
                updateState {
                    copy(
                        groupedResults = grouped,
                        totalResultCount = results.size,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                Timber.e(e, "Search failed")
                updateState { copy(isLoading = false) }
            }
        }
    }

    private fun groupByDate(results: List<SearchResultItem>): List<Pair<SearchDateGroup, List<SearchResultItem>>> {
        val now = LocalDate.now()

        return results
            .sortedByDescending { it.updatedAt }
            .groupBy { item ->
                val date = Instant.ofEpochMilli(item.updatedAt)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                val daysDiff = ChronoUnit.DAYS.between(date, now)

                when {
                    daysDiff == 0L -> SearchDateGroup.TODAY
                    daysDiff == 1L -> SearchDateGroup.YESTERDAY
                    daysDiff <= 7L -> SearchDateGroup.PREVIOUS_7_DAYS
                    daysDiff <= 30L -> SearchDateGroup.PREVIOUS_30_DAYS
                    else -> SearchDateGroup.OLDER
                }
            }
            .toSortedMap(compareBy { it.ordinal })
            .map { (group, items) -> group to items }
    }
}
