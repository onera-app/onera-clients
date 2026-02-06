# Onera - Private AI Chat

Native iOS, iPadOS, macOS, watchOS, and Android clients for [Onera](https://onera.chat) - the end-to-end encrypted AI chat app.

[![App Store](https://img.shields.io/badge/App_Store-0D96F6?style=flat&logo=app-store&logoColor=white)](https://apps.apple.com/app/onera-private-ai-chat/id6758128954)
[![License](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)

## What is Onera?

Onera lets you chat with 13+ AI providers (OpenAI, Anthropic, Google, Mistral, Groq, DeepSeek, xAI, and more) while keeping your conversations private. Every message, note, and credential is protected by end-to-end encryption before it leaves your device.

- **Zero-knowledge architecture** - we can't read your data
- **Bring your own API keys** - encrypted on-device
- **Cross-platform sync** via [onera.chat](https://onera.chat)
- **No tracking, no ads**

## Repository Structure

```
onera-mobile/
├── onera-ios/              # iOS, iPadOS, macOS, watchOS (SwiftUI)
│   ├── Onera/              # Main app target
│   ├── Onera-watchOS Watch App/
│   ├── ci_scripts/         # Xcode Cloud CI/CD
│   └── Onera.xcodeproj
├── onera-android/          # Android (Kotlin, Jetpack Compose)
│   └── app/
├── metadata/               # App Store listing (descriptions, keywords)
└── CHANGELOG.md
```

## Getting Started

### Prerequisites

**iOS/macOS:**
- Xcode 16.2+
- iOS 18.6+ / macOS 15.6+ / watchOS 11.6+ deployment targets
- An Apple Developer account for device builds

**Android:**
- Android Studio Ladybug+
- JDK 17+
- Min SDK 26 (Android 8.0)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/onera-app/onera-mobile.git
   cd onera-mobile
   ```

2. **iOS/macOS** - Configure environment:
   ```bash
   cd onera-ios/Onera/Config
   cp Staging.xcconfig.example ../Staging.xcconfig
   cp Production.xcconfig.example ../Production.xcconfig
   ```
   Edit the `.xcconfig` files and fill in your values (Clerk publishable key, etc.).

3. **Android** - Configure environment:

   Add to `onera-android/local.properties`:
   ```properties
   CLERK_PUBLISHABLE_KEY=pk_test_your_key_here
   ```

### Build & Run

**iOS:**
```bash
cd onera-ios
xcodebuild -scheme Onera -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**macOS:**
```bash
cd onera-ios
xcodebuild -scheme Onera -destination 'platform=macOS'
```

**Android:**
```bash
cd onera-android
./gradlew assembleDebug
```

## Architecture

### Apple Platforms (SwiftUI)

- **MVVM** with `@Observable` (iOS 17+)
- Protocol-based services for dependency injection
- Platform-adaptive UI: `NavigationStack` (iPhone), `NavigationSplitView` (iPad/Mac)
- Native components throughout - no custom UI where Apple provides one

### Android (Kotlin)

- **MVI** pattern (Model-View-Intent)
- Jetpack Compose with Material Design 3
- Hilt for dependency injection
- Kotlin Coroutines + Flow

### Encryption

- End-to-end encryption using libsodium (XSalsa20-Poly1305)
- BIP39 mnemonic recovery phrases
- Passkey authentication (WebAuthn)
- All API keys encrypted at rest in the Keychain/Keystore

## CI/CD

Xcode Cloud is configured for tag-triggered releases:

```bash
# Update CHANGELOG.md, then:
git tag v1.0.2
git push origin main --tags
# -> Xcode Cloud builds iOS + macOS + watchOS -> TestFlight
```

See [`onera-ios/ci_scripts/`](onera-ios/ci_scripts/) for the pipeline configuration.

## Contributing

We welcome contributions. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Follow existing code conventions (SwiftUI MVVM / Kotlin MVI)
4. Use native platform components
5. Submit a pull request

## Security

If you discover a security vulnerability, please report it responsibly by emailing **security@onera.chat** rather than opening a public issue.

## License

This project is licensed under the [AGPL-3.0 License](LICENSE).

## Links

- [Website](https://onera.chat)
- [App Store](https://apps.apple.com/app/onera-private-ai-chat/id6758128954)
- [Privacy Policy](https://onera.chat/privacy)
- [Support](https://onera.chat/help)
