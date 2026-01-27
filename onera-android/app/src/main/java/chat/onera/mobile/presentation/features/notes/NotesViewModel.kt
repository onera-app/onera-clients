package chat.onera.mobile.presentation.features.notes

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.repository.NotesRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.features.notes.model.NoteGroup
import chat.onera.mobile.presentation.features.notes.model.NoteSummary
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import javax.inject.Inject

@HiltViewModel
class NotesViewModel @Inject constructor(
    private val notesRepository: NotesRepository
) : BaseViewModel<NotesState, NotesIntent, NotesEffect>(NotesState()) {

    init {
        observeNotes()
        refreshNotes()
    }

    override fun handleIntent(intent: NotesIntent) {
        when (intent) {
            is NotesIntent.LoadNotes -> refreshNotes()
            is NotesIntent.Search -> search(intent.query)
            is NotesIntent.DeleteNote -> deleteNote(intent.noteId)
            is NotesIntent.TogglePin -> togglePin(intent.noteId)
        }
    }

    private fun observeNotes() {
        notesRepository.observeNotes()
            .onEach { notes ->
                val summaries = notes.map { note ->
                    NoteSummary(
                        id = note.id,
                        title = note.title,
                        preview = note.content.take(100),
                        folder = note.folderId,
                        isPinned = note.isPinned,
                        isEncrypted = true,
                        updatedAt = note.updatedAt
                    )
                }
                val grouped = groupNotesByDate(summaries)
                updateState { 
                    copy(
                        notes = summaries,
                        groupedNotes = grouped,
                        isLoading = false
                    ) 
                }
            }
            .catch { e ->
                updateState { copy(isLoading = false) }
                sendEffect(NotesEffect.ShowError(e.message ?: "Failed to load notes"))
            }
            .launchIn(viewModelScope)
    }
    
    private fun refreshNotes() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                notesRepository.refreshNotes()
                // Set loading to false after refresh completes (even if E2EE is locked)
                updateState { copy(isLoading = false) }
            } catch (e: Exception) {
                updateState { copy(isLoading = false) }
                sendEffect(NotesEffect.ShowError(e.message ?: "Failed to refresh notes"))
            }
        }
    }

    private fun search(query: String) {
        updateState { copy(searchQuery = query) }
        
        val filtered = if (query.isBlank()) {
            currentState.notes
        } else {
            currentState.notes.filter {
                it.title.contains(query, ignoreCase = true) ||
                it.preview.contains(query, ignoreCase = true)
            }
        }
        
        val grouped = groupNotesByDate(filtered)
        updateState { copy(groupedNotes = grouped) }
    }

    private fun deleteNote(noteId: String) {
        viewModelScope.launch {
            try {
                notesRepository.deleteNote(noteId)
            } catch (e: Exception) {
                sendEffect(NotesEffect.ShowError(e.message ?: "Failed to delete note"))
            }
        }
    }

    private fun togglePin(noteId: String) {
        viewModelScope.launch {
            try {
                val note = notesRepository.getNote(noteId) ?: return@launch
                notesRepository.updateNote(note.copy(isPinned = !note.isPinned))
            } catch (e: Exception) {
                sendEffect(NotesEffect.ShowError(e.message ?: "Failed to update note"))
            }
        }
    }

    private fun groupNotesByDate(notes: List<NoteSummary>): List<Pair<NoteGroup, List<NoteSummary>>> {
        val now = LocalDate.now()
        
        // Separate pinned notes
        val pinnedNotes = notes.filter { it.isPinned }
        val unpinnedNotes = notes.filter { !it.isPinned }
        
        val result = mutableListOf<Pair<NoteGroup, List<NoteSummary>>>()
        
        // Add pinned first
        if (pinnedNotes.isNotEmpty()) {
            result.add(NoteGroup.PINNED to pinnedNotes.sortedByDescending { it.updatedAt })
        }
        
        // Group unpinned by date
        val grouped = unpinnedNotes
            .groupBy { note ->
                val noteDate = Instant.ofEpochMilli(note.updatedAt)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                
                val daysDiff = ChronoUnit.DAYS.between(noteDate, now)
                
                when {
                    daysDiff == 0L -> NoteGroup.TODAY
                    daysDiff == 1L -> NoteGroup.YESTERDAY
                    daysDiff <= 7L -> NoteGroup.PREVIOUS_7_DAYS
                    daysDiff <= 30L -> NoteGroup.PREVIOUS_30_DAYS
                    else -> NoteGroup.OLDER
                }
            }
            .toSortedMap(compareBy { it.ordinal })
            .map { (group, groupNotes) -> 
                group to groupNotes.sortedByDescending { it.updatedAt }
            }
        
        result.addAll(grouped)
        return result
    }
}
