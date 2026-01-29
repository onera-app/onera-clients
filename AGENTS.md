# Onera Mobile Apps

Native iOS and Android applications for Onera - an end-to-end encrypted AI chat app.

## Project Structure

```
onera-mob/
├── Onera-ios/           # iOS app (SwiftUI)
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
- Dynamic Type (iOS) / Font scaling (Android)
- VoiceOver / TalkBack support
- Minimum touch targets (44pt iOS / 48dp Android)

## Development Commands

### iOS
```bash
cd Onera-ios
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Android
```bash
cd onera-android
./gradlew assembleDebug
./gradlew test
```

## Feature Parity Checklist

When implementing features, ensure both platforms support:
- [ ] Core functionality matches
- [ ] Error handling consistent
- [ ] Loading states similar
- [ ] Offline behavior aligned
- [ ] Accessibility supported
