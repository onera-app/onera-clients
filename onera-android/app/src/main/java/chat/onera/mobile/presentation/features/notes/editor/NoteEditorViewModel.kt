package chat.onera.mobile.presentation.features.notes.editor

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.model.Note
import chat.onera.mobile.domain.repository.NotesRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.navigation.NavArgs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class NoteEditorViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val notesRepository: NotesRepository
) : BaseViewModel<NoteEditorState, NoteEditorIntent, NoteEditorEffect>(NoteEditorState()) {

    private var autoSaveJob: Job? = null
    private val noteId: String? = savedStateHandle[NavArgs.NOTE_ID]

    init {
        sendIntent(NoteEditorIntent.LoadNote(noteId))
    }

    override fun handleIntent(intent: NoteEditorIntent) {
        when (intent) {
            is NoteEditorIntent.LoadNote -> loadNote(intent.noteId)
            is NoteEditorIntent.UpdateTitle -> updateTitle(intent.title)
            is NoteEditorIntent.UpdateContent -> updateContent(intent.content)
            is NoteEditorIntent.UpdateFolder -> updateFolder(intent.folderId, intent.folderName)
            is NoteEditorIntent.TogglePin -> togglePin()
            is NoteEditorIntent.ToggleArchive -> toggleArchive()
            is NoteEditorIntent.Save -> saveNote()
            is NoteEditorIntent.SaveAndClose -> saveAndClose()
            is NoteEditorIntent.Discard -> discard()
        }
    }

    private fun loadNote(noteId: String?) {
        if (noteId == null) {
            updateState { 
                copy(
                    isNewNote = true,
                    isLoading = false
                ) 
            }
            return
        }

        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                val note = notesRepository.getNote(noteId)
                if (note != null) {
                    updateState { 
                        copy(
                            noteId = note.id,
                            title = note.title,
                            content = note.content,
                            folderId = note.folderId,
                            isPinned = note.isPinned,
                            isNewNote = false,
                            isLoading = false,
                            originalTitle = note.title,
                            originalContent = note.content
                        ) 
                    }
                } else {
                    updateState { copy(isLoading = false) }
                    sendEffect(NoteEditorEffect.ShowError("Note not found"))
                }
            } catch (e: Exception) {
                updateState { copy(isLoading = false) }
                sendEffect(NoteEditorEffect.ShowError(e.message ?: "Failed to load note"))
            }
        }
    }

    private fun updateTitle(title: String) {
        updateState { 
            copy(
                title = title,
                hasChanges = title != originalTitle || content != originalContent
            ) 
        }
        scheduleAutoSave()
    }

    private fun updateContent(content: String) {
        updateState { 
            copy(
                content = content,
                hasChanges = title != originalTitle || content != originalContent
            ) 
        }
        scheduleAutoSave()
    }

    private fun updateFolder(folderId: String?, folderName: String?) {
        updateState { 
            copy(
                folderId = folderId,
                folderName = folderName,
                hasChanges = true
            ) 
        }
    }

    private fun togglePin() {
        updateState { copy(isPinned = !isPinned, hasChanges = true) }
    }

    private fun toggleArchive() {
        updateState { copy(isArchived = !isArchived, hasChanges = true) }
    }

    private fun scheduleAutoSave() {
        // Only auto-save existing notes with valid content
        if (currentState.isNewNote || currentState.title.isBlank()) return
        
        autoSaveJob?.cancel()
        autoSaveJob = viewModelScope.launch {
            delay(3000) // 3 second debounce
            performAutoSave()
        }
    }

    private suspend fun performAutoSave() {
        if (currentState.title.isBlank()) return
        
        try {
            val noteId = currentState.noteId ?: return
            val note = Note(
                id = noteId,
                title = currentState.title,
                content = currentState.content,
                folderId = currentState.folderId,
                isPinned = currentState.isPinned,
                isEncrypted = true,
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
            notesRepository.updateNote(note)
            updateState { 
                copy(
                    originalTitle = title,
                    originalContent = content,
                    hasChanges = false
                ) 
            }
        } catch (e: Exception) {
            // Silent fail for auto-save
        }
    }

    private fun saveNote() {
        if (currentState.title.isBlank()) {
            sendEffect(NoteEditorEffect.ShowError("Title cannot be empty"))
            return
        }

        viewModelScope.launch {
            updateState { copy(isSaving = true) }
            try {
                if (currentState.isNewNote) {
                    val newId = notesRepository.createNote(
                        title = currentState.title,
                        content = currentState.content,
                        folderId = currentState.folderId
                    )
                    updateState { 
                        copy(
                            noteId = newId,
                            isNewNote = false,
                            isSaving = false,
                            hasChanges = false,
                            originalTitle = title,
                            originalContent = content
                        ) 
                    }
                } else {
                    val note = Note(
                        id = currentState.noteId ?: UUID.randomUUID().toString(),
                        title = currentState.title,
                        content = currentState.content,
                        folderId = currentState.folderId,
                        isPinned = currentState.isPinned,
                        isEncrypted = true,
                        createdAt = System.currentTimeMillis(),
                        updatedAt = System.currentTimeMillis()
                    )
                    notesRepository.updateNote(note)
                    updateState { 
                        copy(
                            isSaving = false,
                            hasChanges = false,
                            originalTitle = title,
                            originalContent = content
                        ) 
                    }
                }
            } catch (e: Exception) {
                updateState { copy(isSaving = false) }
                sendEffect(NoteEditorEffect.ShowError(e.message ?: "Failed to save note"))
            }
        }
    }

    private fun saveAndClose() {
        if (currentState.title.isBlank()) {
            sendEffect(NoteEditorEffect.ShowError("Title cannot be empty"))
            return
        }

        viewModelScope.launch {
            updateState { copy(isSaving = true) }
            try {
                if (currentState.isNewNote) {
                    notesRepository.createNote(
                        title = currentState.title,
                        content = currentState.content,
                        folderId = currentState.folderId
                    )
                } else {
                    val note = Note(
                        id = currentState.noteId ?: UUID.randomUUID().toString(),
                        title = currentState.title,
                        content = currentState.content,
                        folderId = currentState.folderId,
                        isPinned = currentState.isPinned,
                        isEncrypted = true,
                        createdAt = System.currentTimeMillis(),
                        updatedAt = System.currentTimeMillis()
                    )
                    notesRepository.updateNote(note)
                }
                updateState { copy(isSaving = false) }
                sendEffect(NoteEditorEffect.NoteSaved)
            } catch (e: Exception) {
                updateState { copy(isSaving = false) }
                sendEffect(NoteEditorEffect.ShowError(e.message ?: "Failed to save note"))
            }
        }
    }

    private fun discard() {
        if (currentState.hasChanges) {
            sendEffect(NoteEditorEffect.ShowDiscardConfirmation)
        } else {
            sendEffect(NoteEditorEffect.NoteDiscarded)
        }
    }

    override fun onCleared() {
        super.onCleared()
        autoSaveJob?.cancel()
    }
}
