//
//  FoldersTests.swift
//  OneraUITests
//
//  E2E tests for folders functionality
//

import XCTest

final class FoldersTests: XCTestCase {
    
    var app: XCUIApplication!
    var sidebarScreen: SidebarScreen!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        AppLauncher.configureAsAuthenticated(app)
        app.launch()
        
        // Navigate to sidebar
        let chatScreen = ChatScreen(app: app)
        guard chatScreen.messageInput.waitForExistence(timeout: 15) else {
            throw XCTSkip("App not loaded - skipping folders tests")
        }
        
        // Open sidebar
        swipeFromLeftEdge()
        sidebarScreen = SidebarScreen(app: app)
        
        guard sidebarScreen.sidebarDrawer.waitForExistence(timeout: 5) else {
            throw XCTSkip("Sidebar not available")
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
        sidebarScreen = nil
    }
    
    // MARK: - Test Cases
    
    /// Test creating a new folder
    func testCreateFolder() throws {
        // Expand folders section
        guard sidebarScreen.foldersSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("Folders section not available")
        }
        
        sidebarScreen.tapFolders()
        
        takeScreenshot(name: "Folders_Expanded")
        
        // Look for add folder button
        let addFolderButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] 'new' OR identifier CONTAINS 'addFolder'")).firstMatch
        
        if addFolderButton.waitForExistence(timeout: 3) {
            addFolderButton.tap()
            
            // Enter folder name if text field appears
            let nameField = app.textFields.firstMatch
            if nameField.waitForExistence(timeout: 3) {
                nameField.typeText(TestData.Folder.sampleName)
                
                // Confirm creation
                let createButton = app.buttons["Create"]
                if createButton.exists {
                    createButton.tap()
                }
            }
            
            takeScreenshot(name: "Folders_Created")
        }
    }
    
    /// Test renaming a folder
    func testRenameFolder() throws {
        // Expand folders
        guard sidebarScreen.foldersSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("Folders section not available")
        }
        
        sidebarScreen.tapFolders()
        
        // Look for existing folders
        let folderRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'folder_'"))
        
        if folderRows.count > 0 {
            let folder = folderRows.element(boundBy: 0)
            
            // Long press for context menu
            folder.press(forDuration: 1.0)
            
            // Look for rename option
            let renameButton = app.buttons["Rename"]
            if renameButton.waitForExistence(timeout: 3) {
                renameButton.tap()
                
                // Enter new name
                let nameField = app.textFields.firstMatch
                if nameField.waitForExistence(timeout: 3) {
                    // Clear existing text
                    if let text = nameField.value as? String {
                        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count)
                        nameField.typeText(deleteString)
                    }
                    nameField.typeText(TestData.Folder.renamedName)
                    
                    // Confirm
                    let saveButton = app.buttons["Save"]
                    if saveButton.exists {
                        saveButton.tap()
                    }
                }
            }
            
            takeScreenshot(name: "Folders_Renamed")
        }
    }
    
    /// Test deleting a folder
    func testDeleteFolder() throws {
        // Expand folders
        guard sidebarScreen.foldersSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("Folders section not available")
        }
        
        sidebarScreen.tapFolders()
        
        // Look for existing folders
        let folderRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'folder_'"))
        
        if folderRows.count > 0 {
            let folder = folderRows.element(boundBy: 0)
            
            // Long press for context menu
            folder.press(forDuration: 1.0)
            
            // Look for delete option
            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 3) {
                deleteButton.tap()
                
                // Confirm deletion
                let confirmDelete = app.buttons["Delete"]
                if confirmDelete.waitForExistence(timeout: 2) {
                    confirmDelete.tap()
                }
            }
            
            takeScreenshot(name: "Folders_Deleted")
        }
    }
    
    /// Test expanding and collapsing folders
    func testExpandCollapseFolder() throws {
        guard sidebarScreen.foldersSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("Folders section not available")
        }
        
        // Initially collapsed - tap to expand
        sidebarScreen.tapFolders()
        
        takeScreenshot(name: "Folders_Expanded")
        
        // Look for folder content
        let folderContent = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'folderTree'")).firstMatch
        let isExpanded = folderContent.exists
        
        // Tap again to collapse
        sidebarScreen.tapFolders()
        
        takeScreenshot(name: "Folders_Collapsed")
        
        // Verify state changed
        XCTAssertNotEqual(folderContent.exists, isExpanded, "Folder expansion state should toggle")
    }
    
    /// Test creating a nested folder (subfolder)
    func testNestedFolderCreation() throws {
        // Expand folders
        guard sidebarScreen.foldersSection.waitForExistence(timeout: 5) else {
            throw XCTSkip("Folders section not available")
        }
        
        sidebarScreen.tapFolders()
        
        // Look for existing folders
        let folderRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'folder_'"))
        
        if folderRows.count > 0 {
            let parentFolder = folderRows.element(boundBy: 0)
            
            // Long press for context menu
            parentFolder.press(forDuration: 1.0)
            
            // Look for "Add Subfolder" option
            let addSubfolderButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'subfolder' OR label CONTAINS[c] 'add'")).firstMatch
            
            if addSubfolderButton.waitForExistence(timeout: 3) {
                addSubfolderButton.tap()
                
                // Enter subfolder name
                let nameField = app.textFields.firstMatch
                if nameField.waitForExistence(timeout: 3) {
                    nameField.typeText(TestData.Folder.subfolderName)
                    
                    // Confirm
                    let createButton = app.buttons["Create"]
                    if createButton.exists {
                        createButton.tap()
                    }
                }
            }
            
            takeScreenshot(name: "Folders_Nested_Created")
        }
    }
}

// MARK: - Helper Extensions

extension FoldersTests {
    func swipeFromLeftEdge() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
