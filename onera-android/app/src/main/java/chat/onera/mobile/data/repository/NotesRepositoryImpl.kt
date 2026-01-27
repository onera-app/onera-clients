package chat.onera.mobile.data.repository

import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.NotesProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.domain.model.Note
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.domain.repository.NotesRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Notes Repository implementation - matches iOS NoteRepository.swift
 * 
 * Server-first approach (matching iOS):
 * - All create/update/delete operations call server FIRST
 * - Local state only updated AFTER server confirms success
 * - Throws exceptions on failure (caller handles UI feedback)
 * - No local-first creates or pending sync mechanisms
 */
@Singleton
class NotesRepositoryImpl @Inject constructor(
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager,
    private val e2eeRepository: E2EERepository
) : NotesRepository {
    
    companion object {
        private const val TAG = "NotesRepository"
    }
    
    private val notesFlow = MutableStateFlow<List<Note>>(emptyList())

    override fun observeNotes(): Flow<List<Note>> = notesFlow.asStateFlow()

    override suspend fun getNotes(): List<Note> = notesFlow.value

    override suspend fun getNote(noteId: String): Note? {
        // First check local cache
        val cachedNote = notesFlow.value.find { it.id == noteId }
        
        // If found in cache and has content, return it
        // If content is empty (from summary), fetch full note from server
        if (cachedNote != null && cachedNote.content.isNotEmpty()) {
            return cachedNote
        }
        
        // Fetch full note from server (to get content)
        return fetchNoteFromServer(noteId)
    }

    /**
     * Create a note - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun createNote(title: String, content: String, folderId: String?): String {
        Log.d(TAG, "Creating note...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot create note")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt note data
        val (encryptedTitle, titleNonce) = encryptionManager.encryptSecretBoxString(title, masterKey)
        val (encryptedContent, contentNonce) = encryptionManager.encryptSecretBoxString(content, masterKey)
        
        val request = NoteCreateRequest(
            encryptedTitle = encryptedTitle,
            titleNonce = titleNonce,
            encryptedContent = encryptedContent,
            contentNonce = contentNonce,
            folderId = folderId
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<NoteCreateRequest, NoteCreateResponse>(
            NotesProcedures.CREATE,
            request
        )
        val response = result.getOrThrow()
        Log.d(TAG, "Note created on server: ${response.id}")
        
        // Only update local state AFTER server success
        val note = Note(
            id = response.id,
            title = title,
            content = content,
            folderId = folderId,
            isPinned = false,
            isEncrypted = true,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        notesFlow.value = notesFlow.value + note
        
        return response.id
    }

    /**
     * Update a note - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun updateNote(note: Note) {
        Log.d(TAG, "Updating note ${note.id}...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot update note")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt note data
        val (encryptedTitle, titleNonce) = encryptionManager.encryptSecretBoxString(note.title, masterKey)
        val (encryptedContent, contentNonce) = encryptionManager.encryptSecretBoxString(note.content, masterKey)
        
        val request = NoteUpdateRequest(
            noteId = note.id,
            encryptedTitle = encryptedTitle,
            titleNonce = titleNonce,
            encryptedContent = encryptedContent,
            contentNonce = contentNonce,
            folderId = note.folderId,
            pinned = note.isPinned,
            archived = false
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<NoteUpdateRequest, NoteUpdateResponse>(
            NotesProcedures.UPDATE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Note updated on server: ${note.id}")
        
        // Only update local state AFTER server success
        val updatedNote = note.copy(updatedAt = System.currentTimeMillis())
        notesFlow.value = notesFlow.value.map { 
            if (it.id == note.id) updatedNote else it 
        }
    }

    /**
     * Delete a note - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun deleteNote(noteId: String) {
        Log.d(TAG, "Deleting note $noteId...")
        
        val request = NoteDeleteRequest(noteId = noteId)
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<NoteDeleteRequest, NoteDeleteResponse>(
            NotesProcedures.REMOVE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Note deleted from server: $noteId")
        
        // Only update local state AFTER server success
        notesFlow.value = notesFlow.value.filter { it.id != noteId }
    }

    /**
     * Refresh notes from server.
     * Fetches all notes from server and updates local state.
     */
    override suspend fun refreshNotes() {
        Log.d(TAG, "Refreshing notes from server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot decrypt notes")
            return
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Fetch from server
        val result = trpcClient.query<Unit, List<EncryptedNoteSummary>>(
            NotesProcedures.LIST,
            Unit
        )
        
        val encryptedNotes = result.getOrThrow()
        Log.d(TAG, "Received ${encryptedNotes.size} encrypted notes from server")
        
        // Decrypt and update local state
        val decryptedNotes = encryptedNotes.mapNotNull { encrypted ->
            try {
                decryptNoteSummary(encrypted, masterKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decrypt note ${encrypted.id}", e)
                null
            }
        }
        
        notesFlow.value = decryptedNotes
        Log.d(TAG, "Decrypted ${decryptedNotes.size} notes")
    }
    
    // ===== Private Helpers =====
    
    private suspend fun fetchNoteFromServer(noteId: String): Note? {
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot fetch note")
            return null
        }
        
        try {
            val masterKey = e2eeRepository.getMasterKey()
            val request = NoteGetRequest(noteId = noteId)
            
            val result = trpcClient.query<NoteGetRequest, EncryptedNoteResponse>(
                NotesProcedures.GET,
                request
            )
            
            return result.fold(
                onSuccess = { encrypted ->
                    val note = decryptFullNote(encrypted, masterKey)
                    // Add to cache
                    if (note != null) {
                        notesFlow.value = notesFlow.value.filter { it.id != noteId } + note
                    }
                    note
                },
                onFailure = { e ->
                    Log.e(TAG, "Failed to fetch note from server", e)
                    null
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching note", e)
            return null
        }
    }
    
    private fun decryptNoteSummary(encrypted: EncryptedNoteSummary, masterKey: ByteArray): Note {
        val title = encryptionManager.decryptSecretBoxString(
            encrypted.encryptedTitle,
            encrypted.titleNonce,
            masterKey
        )
        
        return Note(
            id = encrypted.id,
            title = title,
            content = "", // Content not included in summary
            folderId = encrypted.folderId,
            isPinned = encrypted.pinned,
            isEncrypted = true,
            createdAt = encrypted.createdAt,
            updatedAt = encrypted.updatedAt
        )
    }
    
    private fun decryptFullNote(encrypted: EncryptedNoteResponse, masterKey: ByteArray): Note? {
        return try {
            val title = encryptionManager.decryptSecretBoxString(
                encrypted.encryptedTitle,
                encrypted.titleNonce,
                masterKey
            )
            
            val content = encryptionManager.decryptSecretBoxString(
                encrypted.encryptedContent,
                encrypted.contentNonce,
                masterKey
            )
            
            Note(
                id = encrypted.id,
                title = title,
                content = content,
                folderId = encrypted.folderId,
                isPinned = encrypted.pinned,
                isEncrypted = true,
                createdAt = encrypted.createdAt,
                updatedAt = encrypted.updatedAt
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decrypt full note", e)
            null
        }
    }
}
