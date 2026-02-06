# Onera Mobile & Desktop Apps

Native iOS, iPadOS, macOS, watchOS, and Android applications for Onera - an end-to-end encrypted AI chat app.

## Golden Rule: Native First

**ALWAYS use native components. NEVER customize when Apple/Google provides a solution.**

## Project Structure

```
onera-clients/
├── Onera/                    # iOS, iPadOS, macOS (SwiftUI)
│   ├── Onera/
│   │   ├── App/              # App entry, DI, coordinator
│   │   ├── Core/             # Shared models, extensions
│   │   │   ├── Models/       # Chat, Message, Folder, Note, User
│   │   │   ├── Platform/     # Platform-specific utilities
│   │   │   └── Extensions/
│   │   ├── Features/         # Feature modules
│   │   │   ├── Auth/
│   │   │   ├── Chat/
│   │   │   ├── Notes/
│   │   │   ├── Folders/
│   │   │   ├── Settings/
│   │   │   ├── Main/
│   │   │   │   ├── Views/    # Shared views
│   │   │   │   └── macOS/    # Mac-specific main view
│   │   │   └── MenuBar/      # macOS menu bar extra
│   │   ├── DesignSystem/     # Theme, typography, colors
│   │   └── Services/         # API, auth, encryption
│   └── Onera-watchOS Watch App/
│       ├── Features/
│       │   ├── Chat/         # WatchChatListView
│       │   └── QuickReply/   # WatchQuickReplyView
│       ├── Services/         # WatchConnectivityManager
│       └── App/              # WatchAppState
│
└── onera-android/            # Android app (Kotlin)
    └── app/src/main/java/chat/onera/mobile/
        ├── di/               # Hilt modules
        ├── data/             # Repositories, remote, local
        ├── domain/           # Models, use cases
        └── presentation/
            ├── base/         # BaseViewModel, MVI
            ├── features/     # Feature screens
            ├── components/   # Shared composables
            ├── navigation/   # NavHost, routes
            └── theme/        # Material 3
```

## Architecture

### Apple Platforms: MVVM with @Observable

```swift
@MainActor
@Observable
final class ChatViewModel {
    // Read-only state
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    // Writable input
    var inputText = ""
    
    // Dependencies (protocol-based)
    private let chatService: ChatServiceProtocol
    
    func sendMessage() async {
        guard !inputText.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        // ...
    }
}
```

### Android: MVI Pattern

```kotlin
data class ChatState(
    val messages: List<Message> = emptyList(),
    val isLoading: Boolean = false,
    val inputText: String = ""
) : UiState

sealed interface ChatIntent : UiIntent {
    data object LoadChat : ChatIntent
    data class SendMessage(val content: String) : ChatIntent
}

sealed interface ChatEffect : UiEffect {
    data object ScrollToBottom : ChatEffect
    data class ShowError(val message: String) : ChatEffect
}
```

## Platform-Specific Patterns

### iOS (iPhone)

- `NavigationStack` for navigation
- `TabView` for tabs
- `List` for all lists
- Liquid Glass for navigation chrome only
- 44pt minimum touch targets

### iPadOS

- `NavigationSplitView` with 2-3 columns
- Keyboard shortcuts for all actions
- Trackpad hover states
- Apple Pencil support where appropriate
- Stage Manager multi-window support

### macOS

- `NavigationSplitView` with sidebar
- `Commands` for menu bar
- `Settings { }` scene for preferences
- `MenuBarExtra` for quick access
- Multiple window types (Chat, Note pop-outs)
- Full keyboard navigation

### watchOS (Companion)

- Syncs from iPhone via WatchConnectivity
- Quick interactions (< 10 seconds)
- No authentication (iPhone handles)
- Pre-set quick replies + dictation
- Complications for glanceable info

### Android

- Jetpack Compose with Material 3
- MVI architecture
- Hilt for DI
- 48dp minimum touch targets
- Material You dynamic colors

## Native Components - Always Use

| Need | iOS/iPad/Mac | Android |
|------|--------------|---------|
| Lists | `List` | `LazyColumn` |
| Forms | `Form` | `Column` + Material fields |
| Navigation | `NavigationStack`/`SplitView` | `NavHost` |
| Tabs | `TabView` | `TabRow` |
| Modals | `.sheet` | `BottomSheet` |
| Alerts | `.alert` | `AlertDialog` |
| Search | `.searchable` | `SearchBar` |
| Loading | `ProgressView` | `CircularProgressIndicator` |
| Empty | `ContentUnavailableView` | Custom (no standard) |
| Icons | SF Symbols | Material Icons |

## Available Agents

| Agent | Use For |
|-------|---------|
| `@apple-platform` | Shared SwiftUI patterns, MVVM, DI |
| `@ios-dev` | iPhone UI, Liquid Glass |
| `@ipados-dev` | iPad UI, Stage Manager, Pencil |
| `@macos-dev` | Mac UI, menus, windows |
| `@watchos-dev` | Watch companion app |
| `@android-dev` | Android UI, MVI |
| `@ui-ux` | Native-first design review |

## Available Skills

| Skill | Contents |
|-------|----------|
| `apple-hig` | Core HIG principles, all platforms |
| `ios-liquid-glass` | Liquid Glass design system |
| `ipados-features` | Stage Manager, Pencil, keyboard |
| `macos-native` | Sidebars, menus, windows, keyboard |
| `watchos-patterns` | WatchConnectivity, complications |
| `swift-mvvm` | @Observable MVVM patterns |
| `kotlin-mvi` | Android MVI patterns |
| `android-material3` | Material 3 components |

## Commands

| Command | Description |
|---------|-------------|
| `/ios-ui` | iOS UI with Liquid Glass |
| `/ipad-ui` | iPadOS UI with Stage Manager |
| `/macos-ui` | macOS UI with menus |
| `/watch-ui` | watchOS companion UI |
| `/android-ui` | Android UI with Material 3 |
| `/apple-ui` | Cross-platform Apple UI |
| `/native-check` | Review for unnecessary customization |
| `/hig` | Apple HIG compliance check |

## Session Prompt

Use this when starting a new session:

```
I'm working on Onera, a multiplatform SwiftUI app for iOS, iPadOS, macOS, and watchOS.

Key principles:
1. NATIVE FIRST - Always use standard SwiftUI components
2. Apple HIG - Follow Human Interface Guidelines strictly
3. Liquid Glass - iOS 26+ design for navigation chrome only
4. Minimal customization - Only when Apple has no solution
5. watchOS is companion-only (syncs from iPhone)

Architecture:
- MVVM with @Observable
- Protocol-based services for DI
- Shared Core module across platforms
- Platform-specific Features modules

When I ask for UI, ALWAYS:
1. Start with native SwiftUI components
2. Explain if/why any customization is needed
3. Reference Apple HIG for the pattern
4. Ensure accessibility (Dynamic Type, VoiceOver, keyboard)

Load skills as needed: apple-hig, ios-liquid-glass, macos-native,
ipados-features, watchos-patterns
```

## Development Commands

```bash
# iOS / iPadOS
cd Onera
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'

# macOS
xcodebuild -scheme Onera -destination 'platform=macOS'

# watchOS
xcodebuild -scheme Onera-watchOS -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'

# Android
cd onera-android
./gradlew assembleDebug
./gradlew test
```

## Feature Parity Checklist

When implementing features:

- [ ] Core functionality matches across platforms
- [ ] Uses native components on each platform
- [ ] Error handling consistent
- [ ] Loading states similar
- [ ] Offline behavior aligned
- [ ] Accessibility supported
- [ ] Keyboard shortcuts (iPad, Mac)
- [ ] Multi-window support (iPad Stage Manager, Mac)
- [ ] watchOS shows relevant summary
