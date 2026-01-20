//
//  SidebarScreen.swift
//  OneraUITests
//
//  Page Object for the Sidebar drawer
//

import XCTest

struct SidebarScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    
    var sidebarDrawer: XCUIElement {
        app.otherElements["sidebarDrawer"]
    }
    
    var searchField: XCUIElement {
        app.textFields["searchField"]
    }
    
    var newChatButton: XCUIElement {
        app.buttons["newChatButton"]
    }
    
    var settingsButton: XCUIElement {
        app.buttons["settingsButton"]
    }
    
    var notesButton: XCUIElement {
        app.buttons["notesButton"]
    }
    
    var foldersSection: XCUIElement {
        app.buttons["foldersSection"]
    }
    
    // MARK: - Chat Row Elements
    
    func chatRow(id: String) -> XCUIElement {
        app.buttons["chatRow_\(id)"]
    }
    
    func chatRowByIndex(_ index: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chatRow_'")).element(boundBy: index)
    }
    
    var allChatRows: [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chatRow_'")).allElementsBoundByIndex
    }
    
    // MARK: - Verifications
    
    var isDisplayed: Bool {
        sidebarDrawer.waitForExistence(timeout: 5)
    }
    
    var chatCount: Int {
        allChatRows.count
    }
    
    // MARK: - Actions
    
    @discardableResult
    func tapNewChat() -> ChatScreen {
        newChatButton.tap()
        return ChatScreen(app: app)
    }
    
    @discardableResult
    func tapSettings() -> SettingsScreen {
        settingsButton.tap()
        return SettingsScreen(app: app)
    }
    
    @discardableResult
    func tapNotes() -> NotesScreen {
        notesButton.tap()
        return NotesScreen(app: app)
    }
    
    @discardableResult
    func tapFolders() -> SidebarScreen {
        foldersSection.tap()
        return self
    }
    
    @discardableResult
    func selectChat(id: String) -> ChatScreen {
        chatRow(id: id).tap()
        return ChatScreen(app: app)
    }
    
    @discardableResult
    func selectChatAtIndex(_ index: Int) -> ChatScreen {
        chatRowByIndex(index).tap()
        return ChatScreen(app: app)
    }
    
    @discardableResult
    func searchChats(_ query: String) -> SidebarScreen {
        searchField.tap()
        searchField.typeText(query)
        return self
    }
    
    @discardableResult
    func clearSearch() -> SidebarScreen {
        if let text = searchField.value as? String, !text.isEmpty {
            searchField.tap()
            // Clear the text
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
            searchField.typeText(deleteString)
        }
        return self
    }
    
    func swipeToClose() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
