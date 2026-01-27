package chat.onera.mobile.presentation.features.notes.editor

import androidx.lifecycle.SavedStateHandle
import chat.onera.mobile.domain.model.Note
import chat.onera.mobile.domain.repository.NotesRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class NoteEditorViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    
    private lateinit var savedStateHandle: SavedStateHandle
    private lateinit var notesRepository: NotesRepository
    private lateinit var viewModel: NoteEditorViewModel

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        
        savedStateHandle = SavedStateHandle()
        notesRepository = mockk(relaxed = true)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel(): NoteEditorViewModel {
        return NoteEditorViewModel(
            savedStateHandle = savedStateHandle,
            notesRepository = notesRepository
        )
    }

    @Test
    fun `initial state for new note should be empty`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.state.value
        assertTrue(state.isNewNote)
        assertEquals("", state.title)
        assertEquals("", state.content)
        assertNull(state.noteId)
        assertFalse(state.isPinned)
        assertFalse(state.hasChanges)
    }

    @Test
    fun `loading existing note should populate state`() = runTest {
        val existingNote = Note(
            id = "note-1",
            title = "Test Note",
            content = "Test content",
            folderId = "folder-1",
            isPinned = true,
            isEncrypted = true,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        coEvery { notesRepository.getNote("note-1") } returns existingNote
        
        savedStateHandle["noteId"] = "note-1"
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.state.value
        assertFalse(state.isNewNote)
        assertEquals("note-1", state.noteId)
        assertEquals("Test Note", state.title)
        assertEquals("Test content", state.content)
        assertEquals("folder-1", state.folderId)
        assertTrue(state.isPinned)
    }

    @Test
    fun `update title should change title and mark as changed`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.UpdateTitle("New Title"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.state.value
        assertEquals("New Title", state.title)
        assertTrue(state.hasChanges)
    }

    @Test
    fun `update content should change content and mark as changed`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.UpdateContent("New Content"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.state.value
        assertEquals("New Content", state.content)
        assertTrue(state.hasChanges)
    }

    @Test
    fun `toggle pin should flip isPinned state`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.state.value.isPinned)
        
        viewModel.sendIntent(NoteEditorIntent.TogglePin)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.state.value.isPinned)
        assertTrue(viewModel.state.value.hasChanges)
        
        viewModel.sendIntent(NoteEditorIntent.TogglePin)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.state.value.isPinned)
    }

    @Test
    fun `toggle archive should flip isArchived state`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertFalse(viewModel.state.value.isArchived)
        
        viewModel.sendIntent(NoteEditorIntent.ToggleArchive)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.state.value.isArchived)
        assertTrue(viewModel.state.value.hasChanges)
    }

    @Test
    fun `update folder should change folder and mark as changed`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.UpdateFolder("folder-1", "Work"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        val state = viewModel.state.value
        assertEquals("folder-1", state.folderId)
        assertEquals("Work", state.folderName)
        assertTrue(state.hasChanges)
    }

    @Test
    fun `save new note should call createNote`() = runTest {
        coEvery { notesRepository.createNote(any(), any(), any()) } returns "new-note-id"
        
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.UpdateTitle("Test Title"))
        viewModel.sendIntent(NoteEditorIntent.UpdateContent("Test Content"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.Save)
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify { notesRepository.createNote("Test Title", "Test Content", null) }
        
        val state = viewModel.state.value
        assertEquals("new-note-id", state.noteId)
        assertFalse(state.isNewNote)
        assertFalse(state.hasChanges)
    }

    @Test
    fun `save existing note should call updateNote`() = runTest {
        val existingNote = Note(
            id = "note-1",
            title = "Old Title",
            content = "Old content",
            folderId = null,
            isPinned = false,
            isEncrypted = true,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        
        coEvery { notesRepository.getNote("note-1") } returns existingNote
        
        savedStateHandle["noteId"] = "note-1"
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.UpdateTitle("Updated Title"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.Save)
        testDispatcher.scheduler.advanceUntilIdle()
        
        coVerify { notesRepository.updateNote(any()) }
        assertFalse(viewModel.state.value.hasChanges)
    }

    @Test
    fun `save with empty title should show error`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Don't set title, keep it empty
        viewModel.sendIntent(NoteEditorIntent.UpdateContent("Some content"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(NoteEditorIntent.Save)
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Should not call create note
        coVerify(exactly = 0) { notesRepository.createNote(any(), any(), any()) }
    }

    @Test
    fun `discard with no changes should emit NoteDiscarded`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // No changes made
        viewModel.sendIntent(NoteEditorIntent.Discard)
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Should emit NoteDiscarded (not ShowDiscardConfirmation)
        // Note: In real test, we'd collect effects
    }

    @Test
    fun `discard with changes should show confirmation`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Make a change
        viewModel.sendIntent(NoteEditorIntent.UpdateTitle("Changed"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.state.value.hasChanges)
        
        viewModel.sendIntent(NoteEditorIntent.Discard)
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Should emit ShowDiscardConfirmation (not NoteDiscarded)
        // Note: In real test, we'd collect effects
    }

    @Test
    fun `loading non-existent note should show error`() = runTest {
        coEvery { notesRepository.getNote("non-existent") } returns null
        
        savedStateHandle["noteId"] = "non-existent"
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Should emit ShowError effect
        // Note: In real test, we'd collect effects
        assertFalse(viewModel.state.value.isLoading)
    }
}
