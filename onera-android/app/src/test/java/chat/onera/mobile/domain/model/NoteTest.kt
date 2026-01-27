package chat.onera.mobile.domain.model

import org.junit.Assert.*
import org.junit.Test

class NoteTest {

    @Test
    fun `note should have default unpinned state`() {
        val note = Note(
            id = "1",
            title = "Test Note",
            content = "Content",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        assertFalse(note.isPinned)
    }

    @Test
    fun `note can be pinned`() {
        val note = Note(
            id = "1",
            title = "Test Note",
            content = "Content",
            isPinned = true,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        assertTrue(note.isPinned)
    }

    @Test
    fun `note can have folder assignment`() {
        val note = Note(
            id = "1",
            title = "Test Note",
            content = "Content",
            folderId = "folder-1",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        assertEquals("folder-1", note.folderId)
    }

    @Test
    fun `note without folder should have null folderId`() {
        val note = Note(
            id = "1",
            title = "Test Note",
            content = "Content",
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        assertNull(note.folderId)
    }

    @Test
    fun `note copy should preserve all fields`() {
        val originalTime = System.currentTimeMillis()
        val note = Note(
            id = "1",
            title = "Original Title",
            content = "Original Content",
            folderId = "folder-1",
            isPinned = true,
            isEncrypted = true,
            createdAt = originalTime,
            updatedAt = originalTime
        )
        
        val updated = note.copy(title = "Updated Title")
        
        assertEquals("Updated Title", updated.title)
        assertEquals("Original Content", updated.content)
        assertEquals("folder-1", updated.folderId)
        assertTrue(updated.isPinned)
        assertTrue(updated.isEncrypted)
        assertEquals(originalTime, updated.createdAt)
    }
}
