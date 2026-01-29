# Onera Mobile & Desktop Apps

Native iOS, iPadOS, macOS, and Android applications for Onera - an end-to-end encrypted AI chat app.

## Project Structure

```
onera-mob/
├── Onera-ios/           # iOS & iPadOS app (SwiftUI)
│   ├── Onera/
│   │   ├── App/         # App entry, DI, coordinator
│   │   ├── Core/        # Models, extensions, errors
│   │   ├── Features/    # Feature modules
│   │   │   ├── Auth/
│   │   │   ├── Chat/
│   │   │   ├── Notes/
│   │   │   ├── Folders/
│   │   │   └── Settings/
│   │   ├── DesignSystem/ # Liquid Glass, typography, colors
│   │   └── Services/     # API, auth, encryption
│   └── OneraUITests/    # UI tests
│
├── Onera-macos/         # macOS app (SwiftUI native)
│   ├── Onera/
│   │   ├── App/         # App entry, scenes, commands
│   │   ├── Core/        # Shared models, extensions
│   │   ├── Features/    # Feature modules (mirroring iOS)
│   │   ├── DesignSystem/ # macOS-adapted design system
│   │   └── Services/     # Shared services
│   └── OneraTests/      # Unit tests
│
└── onera-android/       # Android app (Kotlin)
    └── app/src/main/java/chat/onera/mobile/
        ├── di/          # Hilt modules
        ├── data/        # Repositories, remote, local
        ├── domain/      # Models, use cases, repositories
        └── presentation/
            ├── base/    # BaseViewModel, MVI contracts
            ├── features/ # Feature screens
            │   ├── auth/
            │   ├── chat/
            │   ├── notes/
            │   └── settings/
            ├── components/ # Shared composables
            ├── navigation/ # NavHost, routes
            └── theme/    # Material 3 theming
```

## iOS Architecture

### MVVM with @Observable
```swift
@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    var inputText = ""
    
    private let chatService: ChatServiceProtocol
    
    func sendMessage() async { ... }
}
```

### Design System - Liquid Glass (iOS 26+)
- Use `glassEffect()` modifier for glass morphism
- Dark mode: `ultraThinMaterial` with gradient borders
- Light mode: solid backgrounds with subtle borders
- Use `GlassEffectContainer` for multiple glass elements
- Typography: `OneraTypography`, spacing: `OneraSpacing`

### Services
- Protocol-based for testability
- DependencyContainer for injection
- Async/await for all network calls

## iPadOS Architecture

iPadOS shares the iOS codebase but adds tablet-specific features.

### Stage Manager & Multi-Window
```swift
@main
struct OneraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(CGSize(width: 1024, height: 768))
        
        WindowGroup("Chat", for: Chat.ID.self) { $chatId in
            ChatWindowView(chatId: chatId)
        }
    }
}
```

### Adaptive Layouts
- Use `NavigationSplitView` with 2-3 columns
- Support all size classes (full, split, slide over)
- Test in Stage Manager with various window sizes

### Keyboard & Trackpad
- Add keyboard shortcuts via `.keyboardShortcut()` and `Commands`
- Support hover states with `.onHover`
- Full keyboard navigation with `@FocusState`

### Apple Pencil
- PencilKit for drawing/annotation
- Double-tap and squeeze gestures
- Hover preview (Apple Pencil Pro)

## macOS Architecture

macOS uses the same MVVM pattern but with Mac-native UI patterns.

### App Structure
```swift
@main
struct OneraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
        }
    }
}
```

### Navigation Pattern
```swift
NavigationSplitView {
    SidebarView(selection: $selectedFolder)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
} content: {
    ContentListView(folder: selectedFolder)
} detail: {
    DetailView(item: selectedItem)
}
```

### Key macOS Features
- **Menus**: Custom `CommandMenu` and `CommandGroup`
- **Keyboard shortcuts**: All common actions (⌘N, ⌘S, ⌘W, etc.)
- **Settings**: ⌘, opens tabbed settings
- **Windows**: Multiple window types, remember positions
- **Inspector**: Right sidebar for item details
- **Table**: Native `Table` view for data

### Design Considerations
- Respect menu bar conventions
- Support keyboard-first navigation
- Use standard window controls
- Follow sidebar/content/detail patterns

## Android Architecture

### MVI Pattern
```kotlin
// State
data class ChatState(
    val messages: List<Message> = emptyList(),
    val isLoading: Boolean = false,
    val inputText: String = "",
    val isSending: Boolean = false
) : UiState

// Intent
sealed interface ChatIntent : UiIntent {
    data object LoadChat : ChatIntent
    data class SendMessage(val content: String) : ChatIntent
}

// Effect
sealed interface ChatEffect : UiEffect {
    data object ScrollToBottom : ChatEffect
    data class ShowError(val message: String) : ChatEffect
}
```

### Clean Architecture Layers
1. **Presentation**: ViewModels, Composables, MVI
2. **Domain**: Models, Use Cases, Repository interfaces
3. **Data**: Repository implementations, Remote/Local sources

### Material Design 3
- Use `MaterialTheme` colors and typography
- Support dynamic colors (Material You)
- Follow touch target guidelines (48dp)

## Shared Requirements

### E2EE
- All chat content encrypted client-side
- Use platform crypto (Keychain/Keystore)
- Key derivation from passkey

### Authentication
- Clerk SDK for auth
- Biometric unlock support
- Passkey/WebAuthn support

### Offline Support
- Cache messages locally
- Queue actions for sync
- Conflict resolution on reconnect

### Accessibility
- Dynamic Type (iOS/macOS) / Font scaling (Android)
- VoiceOver / TalkBack support
- Full keyboard navigation (all platforms)
- Minimum touch targets (44pt iOS / 48dp Android)

## Development Commands

### iOS / iPadOS
```bash
cd Onera-ios
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

### macOS
```bash
cd Onera-macos
xcodebuild -scheme Onera -destination 'platform=macOS'
```

### Android
```bash
cd onera-android
./gradlew assembleDebug
./gradlew test
```

## Feature Parity Checklist

When implementing features, ensure all platforms support:
- [ ] Core functionality matches
- [ ] Error handling consistent
- [ ] Loading states similar
- [ ] Offline behavior aligned
- [ ] Accessibility supported
- [ ] Keyboard shortcuts (iPadOS, macOS)
- [ ] Multi-window support (iPadOS Stage Manager, macOS)
