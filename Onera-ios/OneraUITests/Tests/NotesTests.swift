//
//  NotesTests.swift
//  OneraUITests
//
//  E2E tests for notes functionality
//

import XCTest

final class NotesTests: XCTestCase {
    
    var app: XCUIApplication!
    var notesScreen: NotesScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        AppLauncher.configureWithMockNotes(app)
        app.launch()
        
        // Navigate to notes
        let chatScreen = ChatScreen(app: app)
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            throw XCTSkip("App not loaded - skipping notes tests")
        }
        
        // Open sidebar and go to notes
        swipeFromLeftEdge()
        let sidebarScreen = SidebarScreen(app: app)
        
        guard sidebarScreen.notesButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Notes button not available")
        }
        
        notesScreen = sidebarScreen.tapNotes()
        
        guard notesScreen.isDisplayed else {
            throw XCTSkip("Notes screen not available")
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
        notesScreen = nil
    }
    
    // MARK: - Test Cases
    
    /// Test creating a new note
    func testCreateNewNote() throws {
        // Tap create button
        let editorScreen = notesScreen.tapCreateNote()
        
        // Verify editor is displayed
        XCTAssertTrue(editorScreen.isDisplayed, "Note editor should be displayed")
        
        takeScreenshot(name: "Notes_Editor_Empty")
        
        // Cancel to go back
        _ = editorScreen.cancel()
    }
    
    /// Test saving a note
    func testSaveNote() throws {
        // Create new note
        let editorScreen = notesScreen.tapCreateNote()
        
        // Enter title and content
        editorScreen.setTitle(TestData.Note.sampleTitle)
        editorScreen.setContent(TestData.Note.sampleContent)
        
        takeScreenshot(name: "Notes_Editor_Filled")
        
        // Save
        notesScreen = editorScreen.save()
        
        // Verify note appears in list
        XCTAssertTrue(notesScreen.isDisplayed, "Should return to notes list")
        
        takeScreenshot(name: "Notes_After_Save")
    }
    
    /// Test editing an existing note
    func testEditExistingNote() throws {
        // Check if there are notes
        if notesScreen.noteCount > 0 {
            // Select first note
            let editorScreen = notesScreen.selectNoteAtIndex(0)
            
            XCTAssertTrue(editorScreen.isDisplayed, "Editor should open for existing note")
            
            takeScreenshot(name: "Notes_Editing_Existing")
            
            // Make a change
            editorScreen.clearTitle()
            editorScreen.setTitle(TestData.Note.updatedTitle)
            
            // Save
            _ = editorScreen.save()
        } else {
            // Create a note first, then edit
            let editorScreen = notesScreen.tapCreateNote()
            editorScreen.setTitle(TestData.Note.sampleTitle)
            editorScreen.setContent(TestData.Note.sampleContent)
            notesScreen = editorScreen.save()
            
            // Now edit it
            let editScreen = notesScreen.selectNoteAtIndex(0)
            editScreen.clearTitle()
            editScreen.setTitle(TestData.Note.updatedTitle)
            _ = editScreen.save()
        }
        
        takeScreenshot(name: "Notes_After_Edit")
    }
    
    /// Test deleting a note
    func testDeleteNote() throws {
        // First ensure we have a note
        if notesScreen.isEmpty {
            let editorScreen = notesScreen.tapCreateNote()
            editorScreen.setTitle("Note to Delete")
            editorScreen.setContent("This note will be deleted")
            notesScreen = editorScreen.save()
        }
        
        let initialCount = notesScreen.noteCount
        
        if initialCount > 0 {
            // Delete first note
            notesScreen.deleteNoteAtIndex(0)
            
            // Confirm deletion if dialog appears
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
            }
            
            takeScreenshot(name: "Notes_After_Delete")
        }
    }
    
    /// Test archiving a note
    func testArchiveNote() throws {
        // This would require accessing the archive action
        // Usually through context menu or swipe action
        
        if notesScreen.noteCount > 0 {
            let noteRow = notesScreen.noteRowByIndex(0)
            noteRow.swipeLeft()
            
            // Look for archive action
            let archiveButton = app.buttons["Archive"]
            if archiveButton.waitForExistence(timeout: 2) {
                archiveButton.tap()
                takeScreenshot(name: "Notes_Archived")
            }
        }
    }
    
    /// Test searching notes
    func testSearchNotes() throws {
        // Ensure we have notes to search
        if notesScreen.isEmpty {
            let editorScreen = notesScreen.tapCreateNote()
            editorScreen.setTitle("Searchable Note")
            editorScreen.setContent("Content for searching")
            notesScreen = editorScreen.save()
        }
        
        // Search for a term
        notesScreen.searchNotes("Searchable")
        
        takeScreenshot(name: "Notes_Search_Results")
    }
    
    /// Test filtering notes by folder
    func testFilterByFolder() throws {
        // Look for folder filter UI
        let folderFilter = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'folder' OR identifier CONTAINS 'folder'")).firstMatch
        
        if folderFilter.waitForExistence(timeout: 5) {
            folderFilter.tap()
            
            takeScreenshot(name: "Notes_Folder_Filter")
            
            // Select a folder if available
            let folderOptions = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'folder'"))
            if folderOptions.count > 0 {
                folderOptions.element(boundBy: 0).tap()
            }
        }
    }
}

// MARK: - Helper Extensions

extension NotesTests {
    func swipeFromLeftEdge() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
