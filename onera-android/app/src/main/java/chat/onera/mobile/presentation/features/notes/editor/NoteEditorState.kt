package chat.onera.mobile.presentation.features.notes.editor

import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState

data class NoteEditorState(
    val noteId: String? = null,
    val title: String = "",
    val content: String = "",
    val folderId: String? = null,
    val folderName: String? = null,
    val isPinned: Boolean = false,
    val isArchived: Boolean = false,
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val isNewNote: Boolean = true,
    val hasChanges: Boolean = false,
    val originalTitle: String = "",
    val originalContent: String = ""
) : UiState

sealed interface NoteEditorIntent : UiIntent {
    data class LoadNote(val noteId: String?) : NoteEditorIntent
    data class UpdateTitle(val title: String) : NoteEditorIntent
    data class UpdateContent(val content: String) : NoteEditorIntent
    data class UpdateFolder(val folderId: String?, val folderName: String?) : NoteEditorIntent
    data object TogglePin : NoteEditorIntent
    data object ToggleArchive : NoteEditorIntent
    data object Save : NoteEditorIntent
    data class SaveAndClose(val regenerate: Boolean = false) : NoteEditorIntent
    data object Discard : NoteEditorIntent
}

sealed interface NoteEditorEffect : UiEffect {
    data object NoteSaved : NoteEditorEffect
    data object NoteDiscarded : NoteEditorEffect
    data class ShowError(val message: String) : NoteEditorEffect
    data object ShowDiscardConfirmation : NoteEditorEffect
}
