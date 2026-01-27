package chat.onera.mobile.presentation.features.notes

import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import chat.onera.mobile.presentation.features.notes.model.NoteGroup
import chat.onera.mobile.presentation.features.notes.model.NoteSummary

data class NotesState(
    val notes: List<NoteSummary> = emptyList(),
    val groupedNotes: List<Pair<NoteGroup, List<NoteSummary>>> = emptyList(),
    val isLoading: Boolean = true,
    val searchQuery: String = ""
) : UiState

sealed interface NotesIntent : UiIntent {
    data object LoadNotes : NotesIntent
    data class Search(val query: String) : NotesIntent
    data class DeleteNote(val noteId: String) : NotesIntent
    data class TogglePin(val noteId: String) : NotesIntent
}

sealed interface NotesEffect : UiEffect {
    data class ShowError(val message: String) : NotesEffect
}
