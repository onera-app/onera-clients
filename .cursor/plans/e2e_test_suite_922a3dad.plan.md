---
name: E2E Test Suite
overview: "Implement comprehensive XCTest UI Testing suite with mock services, covering all app features: authentication, chat/LLM, notes, folders, settings, and navigation."
todos:
  - id: setup-targets
    content: Create OneraTests and OneraUITests targets in Xcode project
    status: completed
  - id: mock-services
    content: Implement mock services (MockAuthService, MockNetworkService, MockLLMService, etc.)
    status: completed
  - id: test-di
    content: Create TestDependencyContainer and add --uitesting launch argument handling
    status: completed
  - id: accessibility-ids
    content: Add accessibility identifiers to all interactive UI elements
    status: completed
  - id: page-objects
    content: Create Page Object classes for each screen (AuthScreen, ChatScreen, etc.)
    status: completed
  - id: auth-tests
    content: Implement AuthenticationTests suite (6 tests)
    status: completed
  - id: chat-tests
    content: Implement ChatTests suite (10 tests)
    status: completed
  - id: navigation-tests
    content: Implement NavigationTests suite (8 tests)
    status: completed
  - id: notes-tests
    content: Implement NotesTests suite (7 tests)
    status: completed
  - id: folders-tests
    content: Implement FoldersTests suite (5 tests)
    status: completed
  - id: settings-tests
    content: Implement SettingsTests suite (5 tests)
    status: completed
  - id: verify-coverage
    content: Run full test suite and verify all features are covered
    status: completed
---

# E2E Test Suite Implementation

## 1. Test Infrastructure Setup

### Create Test Targets

Add two new targets to the Xcode project:

- **OneraTests** - Unit and integration tests for ViewModels, Services, and business logic
- **OneraUITests** - End-to-end UI tests using XCTest UI Testing

### Mock Service Layer

Create mock implementations in `Onera/Services/Mocks/` for isolated testing:

- `MockAuthService.swift` - Simulates authentication states
- `MockNetworkService.swift` - Returns predefined API responses
- `MockE2EEService.swift` - Bypasses encryption for testing
- `MockChatRepository.swift` - In-memory chat storage
- `MockLLMService.swift` - Simulates streaming LLM responses
- `MockSecureSession.swift` - Already exists, extend if needed

### Test Configuration

Create `TestDependencyContainer.swift` that injects mock services:

```swift
final class TestDependencyContainer: DependencyContaining {
    static let shared = TestDependencyContainer()
    // Inject mock services instead of real ones
}
```

Add launch argument handling in [OneraApp.swift](Onera/App/OneraApp.swift):

```swift
if CommandLine.arguments.contains("--uitesting") {
    // Use TestDependencyContainer
}
```

## 2. Accessibility Identifiers

Add identifiers to all interactive elements for UI test targeting. Key files to modify:

### Authentication Views

- [AuthenticationView.swift](Onera/Features/Auth/Views/AuthenticationView.swift)
  - `"signInWithApple"` - Apple sign-in button
  - `"signInWithGoogle"` - Google sign-in button

### Main Navigation

- [MainView.swift](Onera/Features/Main/Views/MainView.swift)
  - `"sidebarDrawer"` - Drawer container
  - `"menuButton"` - Hamburger menu
  - `"newChatButton"` - New conversation button

### Sidebar

- [SidebarDrawerView.swift](Onera/Features/Main/Views/SidebarDrawerView.swift)
  - `"searchField"` - Chat search
  - `"chatRow_{id}"` - Individual chat rows
  - `"settingsButton"` - Settings navigation
  - `"notesButton"` - Notes navigation
  - `"foldersSection"` - Folders toggle

### Chat Views

- [ChatView.swift](Onera/Features/Chat/Views/ChatView.swift)
  - `"messageInput"` - Text input field
  - `"sendButton"` - Send message
  - `"modelSelector"` - Model dropdown
- [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift)
  - `"message_{id}"` - Message bubble
  - `"copyButton"` - Copy action
  - `"regenerateButton"` - Regenerate action
  - `"speakButton"` - TTS action
  - `"branchPrevious"` / `"branchNext"` - Branch navigation

### Notes Views

- [NotesListView.swift](Onera/Features/Notes/Views/NotesListView.swift)
  - `"createNoteButton"` - New note
  - `"noteRow_{id}"` - Note rows
- [NoteEditorView.swift](Onera/Features/Notes/Views/NoteEditorView.swift)
  - `"noteTitleField"` - Title input
  - `"noteContentField"` - Content editor
  - `"saveNoteButton"` - Save action

### Settings Views

- [SettingsView.swift](Onera/Features/Settings/Views/SettingsView.swift)
  - `"signOutButton"` - Sign out
  - `"recoveryPhraseButton"` - View recovery phrase
  - `"themeSelector"` - Theme picker

## 3. Test Suites Organization

```
OneraUITests/
├── Helpers/
│   ├── XCTestCase+Extensions.swift    # Common test utilities
│   ├── TestData.swift                  # Mock data factories
│   └── AppLauncher.swift               # Launch configuration
├── Screens/
│   ├── AuthScreen.swift                # Page object for auth
│   ├── ChatScreen.swift                # Page object for chat
│   ├── SidebarScreen.swift             # Page object for sidebar
│   ├── NotesScreen.swift               # Page object for notes
│   └── SettingsScreen.swift            # Page object for settings
└── Tests/
    ├── AuthenticationTests.swift
    ├── ChatTests.swift
    ├── NavigationTests.swift
    ├── NotesTests.swift
    ├── FoldersTests.swift
    └── SettingsTests.swift
```

## 4. Test Cases by Feature

### Authentication Tests (AuthenticationTests.swift)

- `testLaunchShowsLoadingState` - Verify app shows loading on launch
- `testUnauthenticatedShowsSignInOptions` - Sign-in buttons visible
- `testSignInWithAppleFlow` - Complete Apple auth flow (mocked)
- `testE2EESetupFlowForNewUser` - Recovery phrase shown, can proceed
- `testE2EEUnlockFlowForReturningUser` - Unlock with recovery phrase
- `testSignOutFlow` - Settings -> Sign out -> Returns to auth screen

### Chat Tests (ChatTests.swift)

- `testEmptyStateShown` - New chat shows empty state message
- `testSendMessageAndReceiveResponse` - Send text, verify streaming response
- `testModelSelectionDropdown` - Open dropdown, select model
- `testCopyMessageContent` - Long-press/tap copy, verify feedback
- `testRegenerateResponse` - Tap regenerate, new response appears
- `testResponseBranching` - Regenerate, navigate between versions
- `testEditMessage` - Edit user message, verify update
- `testTTSPlayback` - Tap speak, verify player overlay appears
- `testMessageWithReasoning` - Response with thinking tags shows drawer

### Navigation Tests (NavigationTests.swift)

- `testOpenSidebarWithSwipe` - Swipe from left edge opens drawer
- `testCloseSidebarWithSwipe` - Swipe left closes drawer
- `testCloseSidebarWithTapOutside` - Tap overlay closes drawer
- `testNewChatFromNavBar` - Tap new chat, empty state shown
- `testSelectChatFromHistory` - Tap chat row, loads messages
- `testSearchChats` - Type in search, list filters
- `testNavigateToSettings` - Open settings sheet
- `testNavigateToNotes` - Open notes sheet

### Notes Tests (NotesTests.swift)

- `testCreateNewNote` - Tap create, editor opens
- `testSaveNote` - Enter title/content, save, appears in list
- `testEditExistingNote` - Tap note, edit, save changes
- `testDeleteNote` - Swipe to delete, removed from list
- `testArchiveNote` - Archive action, note moves to archived
- `testSearchNotes` - Search by title, list filters
- `testFilterByFolder` - Select folder filter, notes filtered

### Folders Tests (FoldersTests.swift)

- `testCreateFolder` - Add folder, appears in tree
- `testRenameFolder` - Rename via context menu
- `testDeleteFolder` - Delete folder, removed from tree
- `testExpandCollapseFolder` - Toggle folder expansion
- `testNestedFolderCreation` - Create subfolder

### Settings Tests (SettingsTests.swift)

- `testProfileDisplayed` - User info shown correctly
- `testThemeSelection` - Change theme, UI updates
- `testViewRecoveryPhrase` - Button opens phrase sheet
- `testSignOutConfirmation` - Sign out shows confirmation dialog
- `testAPICredentialsNavigation` - Navigate to credentials list

## 5. Page Object Pattern

Use Page Object pattern for maintainable tests. Example:

```swift
// Screens/ChatScreen.swift
struct ChatScreen {
    let app: XCUIApplication
    
    var messageInput: XCUIElement {
        app.textFields["messageInput"]
    }
    
    var sendButton: XCUIElement {
        app.buttons["sendButton"]
    }
    
    func sendMessage(_ text: String) {
        messageInput.tap()
        messageInput.typeText(text)
        sendButton.tap()
    }
    
    func waitForResponse(timeout: TimeInterval = 30) -> Bool {
        // Wait for streaming to complete
        app.staticTexts.matching(identifier: "message_").element.waitForExistence(timeout: timeout)
    }
}
```

## 6. Mock LLM Streaming

Create `MockLLMService` that simulates streaming:

```swift
class MockLLMService: LLMServiceProtocol {
    var mockResponse = "This is a test response from the AI."
    var streamDelay: TimeInterval = 0.05
    
    func streamChat(..., onEvent: @escaping (StreamEvent) -> Void) async throws {
        // Simulate streaming word by word
        for word in mockResponse.split(separator: " ") {
            try await Task.sleep(for: .milliseconds(Int(streamDelay * 1000)))
            onEvent(.text(String(word) + " "))
        }
        onEvent(.done)
    }
}
```

## 7. Test Execution

### Run All Tests

```bash
xcodebuild test \
  -project Onera.xcodeproj \
  -scheme Onera \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testPlan AllTests
```

### Run Specific Test Suite

```bash
xcodebuild test \
  -project Onera.xcodeproj \
  -scheme OneraUITests \
  -only-testing:OneraUITests/ChatTests
```

## Files to Create

| File | Purpose |

|------|---------|

| `OneraTests/` | Unit test target folder |

| `OneraUITests/` | UI test target folder |

| `Onera/Services/Mocks/*.swift` | Mock service implementations |

| `Onera/Testing/TestDependencyContainer.swift` | Test-specific DI |

| `OneraUITests/Helpers/*.swift` | Test utilities |

| `OneraUITests/Screens/*.swift` | Page objects |

| `OneraUITests/Tests/*.swift` | Test cases |

## Estimated Test Count

- Authentication: ~6 tests
- Chat: ~10 tests  
- Navigation: ~8 tests
- Notes: ~7 tests
- Folders: ~5 tests
- Settings: ~5 tests

**Total: ~41 E2E UI tests**