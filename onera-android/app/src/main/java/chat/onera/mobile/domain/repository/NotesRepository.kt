package chat.onera.mobile.domain.repository

import chat.onera.mobile.domain.model.Note
import kotlinx.coroutines.flow.Flow

interface NotesRepository {
    fun observeNotes(): Flow<List<Note>>
    suspend fun getNotes(): List<Note>
    suspend fun getNote(noteId: String): Note?
    suspend fun createNote(title: String, content: String, folderId: String?): String
    suspend fun updateNote(note: Note)
    suspend fun deleteNote(noteId: String)
    suspend fun refreshNotes()
}
