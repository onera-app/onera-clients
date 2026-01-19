# Onera - E2EE Chat App

A SwiftUI iOS app with Clerk authentication and end-to-end encryption using Privy-style key sharding.

## Architecture

This project follows **Clean Architecture** with **MVVM** presentation pattern:

```
Onera/
├── App/                          # Application entry point & configuration
│   ├── OneraApp.swift           # @main entry point
│   ├── AppCoordinator.swift     # App state machine & navigation coordinator
│   ├── Configuration.swift      # Environment-based configuration
│   └── DependencyContainer.swift # DI container with protocols
│
├── Core/                         # Shared utilities
│   ├── Errors.swift             # Domain-specific error types
│   └── Extensions.swift         # Swift/SwiftUI extensions
│
├── Domain/                       # Business logic layer (pure Swift)
│   ├── Models/                  # Domain entities
│   │   ├── User.swift
│   │   ├── Chat.swift
│   │   ├── Message.swift
│   │   └── KeyShares.swift
│   │
│   ├── Services/                # Service protocols (interfaces)
│   │   ├── AuthServiceProtocol.swift
│   │   ├── CryptoServiceProtocol.swift
│   │   ├── KeychainServiceProtocol.swift
│   │   ├── NetworkServiceProtocol.swift
│   │   └── E2EEServiceProtocol.swift
│   │
│   └── Repositories/            # Repository protocols
│       └── ChatRepositoryProtocol.swift
│
├── Data/                         # Data layer implementations
│   ├── Services/                # Service implementations
│   │   ├── AuthService.swift    # Clerk SDK integration
│   │   ├── CryptoService.swift  # libsodium crypto
│   │   ├── KeychainService.swift
│   │   ├── NetworkService.swift # tRPC client
│   │   ├── E2EEService.swift    # Key management
│   │   └── SecureSession.swift  # In-memory key session
│   │
│   └── Repositories/            # Repository implementations
│       └── ChatRepository.swift
│
└── Presentation/                 # UI layer
    ├── ViewModels/              # MVVM ViewModels
    │   ├── AuthViewModel.swift
    │   ├── E2EESetupViewModel.swift
    │   ├── E2EEUnlockViewModel.swift
    │   ├── ChatListViewModel.swift
    │   ├── ChatViewModel.swift
    │   └── SettingsViewModel.swift
    │
    └── Views/                   # SwiftUI Views
        ├── RootView.swift
        ├── Auth/
        │   ├── AuthenticationView.swift
        │   ├── E2EESetupView.swift
        │   └── E2EEUnlockView.swift
        ├── Main/
        │   └── MainView.swift
        ├── Chat/
        │   ├── ChatListView.swift
        │   ├── ChatView.swift
        │   ├── MessageBubbleView.swift
        │   └── MessageInputView.swift
        └── Settings/
            └── SettingsView.swift
```

## Architecture Principles

### 1. **Dependency Inversion**
- All services depend on protocols, not concrete implementations
- `DependencyContainer` manages all dependencies
- Easy to swap implementations for testing

### 2. **Clean Separation of Concerns**
- **Domain**: Pure business logic, no framework dependencies
- **Data**: Implementation details (network, storage, crypto)
- **Presentation**: UI and state management

### 3. **Unidirectional Data Flow**
- ViewModels expose `@Observable` state
- Views bind to state and dispatch actions
- State changes flow down, actions flow up

### 4. **Testability**
- All services have mock implementations
- ViewModels accept dependencies via constructor
- `MockDependencyContainer` for SwiftUI previews

## Setup Instructions

### 1. Add SPM Dependencies

```swift
// Package.swift or Xcode SPM
dependencies: [
    .package(url: "https://github.com/clerk/clerk-ios", from: "1.0.0"),
    .package(url: "https://github.com/jedisct1/swift-sodium", from: "0.9.1"),
    .package(url: "https://github.com/pengpengliu/BIP39", from: "1.0.0")
]
```

### 2. Configure Environment

Update `Configuration.swift`:
```swift
case .production:
    return URL(string: "https://api.onera.app")!
```

### 3. Configure Info.plist

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>onera</string>
        </array>
    </dict>
</array>

<key>NSPhotoLibraryUsageDescription</key>
<string>Attach images to messages</string>
```

## E2EE Architecture

### Key Sharding (3-of-3 XOR)

```
masterKey = deviceShare ⊕ authShare ⊕ recoveryShare
```

| Share | Storage | Protection |
|-------|---------|------------|
| Device | iOS Keychain (encrypted) | Device-bound key derivation |
| Auth | Server (plaintext) | Clerk authentication |
| Recovery | Server (encrypted) | BIP39 mnemonic |

### Key Derivation

```swift
deviceShareKey = BLAKE2b-256(deviceId || fingerprint || deviceSecret)
recoveryKey = BIP39.mnemonicToEntropy(mnemonic)
```

### Encryption Algorithms

- **Symmetric**: XSalsa20-Poly1305 (`crypto_secretbox`)
- **Asymmetric**: X25519 + XSalsa20-Poly1305 (`crypto_box`)
- **Hashing**: BLAKE2b for key derivation

## Security Best Practices

1. **Memory Security**
   - Keys zeroed after use (`secureZero`)
   - Session auto-locks after 30 min
   - Aggressive timeout (5 min) when backgrounded

2. **Keychain Security**
   - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
   - Device-bound (non-transferable backup)

3. **Error Handling**
   - No sensitive data in error messages
   - Generic user-facing errors

## Testing

```swift
import Testing

@Suite("CryptoService Tests")
struct CryptoServiceTests {
    
    let sut = CryptoService()
    
    @Test("Master key splits and reconstructs correctly")
    func masterKeySplitReconstruct() throws {
        let masterKey = try sut.generateMasterKey()
        let shares = try sut.splitMasterKey(masterKey)
        let reconstructed = try sut.reconstructMasterKey(shares: shares)
        
        #expect(reconstructed == masterKey)
    }
    
    @Test("Encryption roundtrip succeeds")
    func encryptDecrypt() throws {
        let key = try sut.generateMasterKey()
        let plaintext = Data("Hello, World!".utf8)
        
        let (ciphertext, nonce) = try sut.encrypt(plaintext: plaintext, key: key)
        let decrypted = try sut.decrypt(ciphertext: ciphertext, nonce: nonce, key: key)
        
        #expect(decrypted == plaintext)
    }
}

@Suite("AuthViewModel Tests")
struct AuthViewModelTests {
    
    @Test("Sign in updates state correctly")
    @MainActor
    func signInSuccess() async throws {
        let mockAuth = MockAuthService()
        let viewModel = AuthViewModel(authService: mockAuth, onSuccess: {})
        
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        
        await viewModel.submit()
        
        #expect(mockAuth.isAuthenticated)
        #expect(viewModel.error == nil)
    }
}
```

## TODO

Search for `TODO:` in the codebase:
- [ ] Integrate Clerk iOS SDK
- [ ] Replace CryptoKit placeholders with libsodium
- [ ] Implement BIP39 mnemonic generation
- [ ] Add AI streaming response integration
- [ ] Implement push notifications
- [ ] Add biometric unlock option

## License

[Your License]
