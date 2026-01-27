//
//  NotesScreen.swift
//  OneraUITests
//
//  Page Object for the Notes screen
//

import XCTest

struct NotesScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var createNoteButton: XCUIElement {
        app.buttons["createNoteButton"]
    }
    
    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }
    
    var doneButton: XCUIElement {
        app.buttons["Done"]
    }
    
    var navigationTitle: XCUIElement {
        app.navigationBars["Notes"]
    }
    
    // MARK: - Note Row Elements
    
    func noteRow(id: String) -> XCUIElement {
        app.buttons["noteRow_\(id)"]
    }
    
    func noteRowByIndex(_ index: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'noteRow_'")).element(boundBy: index)
    }
    
    var allNoteRows: [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'noteRow_'")).allElementsBoundByIndex
    }
    
    // MARK: - Empty State
    
    var emptyStateText: XCUIElement {
        app.staticTexts["No Notes"]
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        navigationTitle.waitForExistence(timeout: 5) || createNoteButton.waitForExistence(timeout: 5)
    }
    
    var isEmpty: Bool {
        emptyStateText.exists
    }
    
    var noteCount: Int {
        allNoteRows.count
    }
    
    // MARK: - Actions
    
    @discardableResult
    func tapCreateNote() -> NoteEditorScreen {
        createNoteButton.tap()
        return NoteEditorScreen(app: app)
    }
    
    @discardableResult
    func selectNote(id: String) -> NoteEditorScreen {
        noteRow(id: id).tap()
        return NoteEditorScreen(app: app)
    }
    
    @discardableResult
    func selectNoteAtIndex(_ index: Int) -> NoteEditorScreen {
        noteRowByIndex(index).tap()
        return NoteEditorScreen(app: app)
    }
    
    @discardableResult
    func searchNotes(_ query: String) -> NotesScreen {
        searchField.tap()
        searchField.typeText(query)
        return self
    }
    
    @discardableResult
    func dismiss() -> SidebarScreen {
        doneButton.tap()
        return SidebarScreen(app: app)
    }
    
    func deleteNoteAtIndex(_ index: Int) {
        let noteRow = noteRowByIndex(index)
        noteRow.swipeLeft()
        app.buttons["Delete"].tap()
    }
}

// MARK: - Note Editor Screen

struct NoteEditorScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var titleField: XCUIElement {
        app.textFields["noteTitleField"]
    }
    
    var contentField: XCUIElement {
        app.textViews["noteContentField"]
    }
    
    var saveButton: XCUIElement {
        app.buttons["saveNoteButton"]
    }
    
    var cancelButton: XCUIElement {
        app.buttons["Cancel"]
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        titleField.waitForExistence(timeout: 5) || saveButton.waitForExistence(timeout: 5)
    }
    
    // MARK: - Actions
    
    @discardableResult
    func setTitle(_ title: String) -> NoteEditorScreen {
        titleField.tap()
        titleField.typeText(title)
        return self
    }
    
    @discardableResult
    func setContent(_ content: String) -> NoteEditorScreen {
        contentField.tap()
        contentField.typeText(content)
        return self
    }
    
    @discardableResult
    func save() -> NotesScreen {
        saveButton.tap()
        return NotesScreen(app: app)
    }
    
    @discardableResult
    func cancel() -> NotesScreen {
        cancelButton.tap()
        // Handle discard confirmation if appears
        if app.buttons["Discard"].waitForExistence(timeout: 2) {
            app.buttons["Discard"].tap()
        }
        return NotesScreen(app: app)
    }
    
    func clearTitle() {
        titleField.tap()
        if let text = titleField.value as? String, !text.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
            titleField.typeText(deleteString)
        }
    }
    
    func clearContent() {
        contentField.tap()
        if let text = contentField.value as? String, !text.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
            contentField.typeText(deleteString)
        }
    }
}
