# Onera - E2EE Chat App

A SwiftUI iOS app with Clerk authentication and end-to-end encryption using Privy-style key sharding.

## Setup Instructions

### 1. Add Required Dependencies

Open your Xcode project and add the following Swift Package Manager dependencies:

#### Clerk iOS SDK
```
URL: https://github.com/clerk/clerk-ios
Version: 1.0.0 or later
```

#### Swift Sodium (libsodium)
```
URL: https://github.com/jedisct1/swift-sodium
Version: 0.9.1 or later
```

#### BIP39 Swift (for recovery phrase)
```
URL: https://github.com/pengpengliu/BIP39
Version: 1.0.0 or later
```

### 2. Configure Clerk

1. Create a Clerk account at https://clerk.com
2. Create a new application
3. Get your Publishable Key
4. Update `Configuration.swift`:
```swift
static let clerkPublishableKey = "pk_live_YOUR_KEY_HERE"
```

### 3. Configure Info.plist

Add the following entries to your `Info.plist`:

```xml
<!-- For OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>onera</string>
        </array>
    </dict>
</array>

<!-- For camera/photo access (attachments) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to attach images to messages.</string>
```

### 4. Backend API Setup

Update `Configuration.swift` with your backend URL:
```swift
static let apiBaseURL = URL(string: "https://your-api.com")!
```

Your backend should implement the following tRPC procedures:
- `keyShares.check` - Check if user has E2EE keys
- `keyShares.get` - Get encrypted key shares
- `keyShares.create` - Store key shares
- `devices.register` - Register device
- `devices.getDeviceSecret` - Get device secret
- `chats.list` - List all chats
- `chats.get` - Get a specific chat
- `chats.create` - Create a new chat
- `chats.update` - Update a chat
- `chats.delete` - Delete a chat

## Project Structure

```
Sources/
├── App/
│   └── AppCoordinator.swift      # App state management
├── Auth/
│   └── AuthenticationManager.swift # Clerk integration
├── Core/
│   ├── Configuration.swift       # App configuration
│   └── Errors.swift              # Error types
├── Models/
│   └── ChatModels.swift          # Data models
├── Networking/
│   └── APIClient.swift           # tRPC API client
├── Security/
│   ├── CryptoManager.swift       # Cryptographic operations
│   ├── ChatEncryption.swift      # Chat encryption
│   ├── E2EEManager.swift         # E2EE key management
│   ├── KeychainManager.swift     # iOS Keychain access
│   └── SecureSession.swift       # In-memory key session
├── ViewModels/
│   └── ChatViewModel.swift       # Chat business logic
└── Views/
    ├── Auth/
    │   ├── AuthenticationView.swift
    │   ├── E2EESetupView.swift
    │   └── RecoveryPhraseEntryView.swift
    ├── Chat/
    │   ├── ChatSidebarView.swift
    │   ├── ChatView.swift
    │   ├── MessageBubble.swift
    │   └── MessageInputView.swift
    ├── Settings/
    │   └── SettingsView.swift
    └── MainView.swift
```

## E2EE Architecture

### Key Sharding (Privy-Style)
```
masterKey = deviceShare XOR authShare XOR recoveryShare
```

- **Device Share**: Stored encrypted in iOS Keychain
- **Auth Share**: Stored on server (protected by Clerk auth)
- **Recovery Share**: Encrypted with recovery key derived from BIP39 mnemonic

### Key Derivation
```
deviceShareKey = BLAKE2b-256(deviceId + fingerprint + deviceSecret)
recoveryKey = SHA256(BIP39 mnemonic entropy)
```

### Encryption
- Symmetric: XSalsa20-Poly1305 (crypto_secretbox)
- Asymmetric: X25519 (crypto_box)
- Hashing: BLAKE2b for key derivation, SHA256 for compatibility

## Security Notes

1. **Never** persist master key, private key, or recovery phrase
2. Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for Keychain
3. Zero memory after using sensitive keys
4. Session auto-locks after 30 minutes (configurable)
5. More aggressive timeout (5 minutes) when app is backgrounded

## TODO Items

Search the codebase for `TODO:` comments to find areas that need completion:
- Integrate actual Clerk SDK (currently using placeholders)
- Replace CryptoKit with libsodium for web client compatibility
- Implement BIP39 mnemonic generation/validation
- Add streaming AI response integration
- Implement push notifications
- Add proper error handling and logging

## Testing

```swift
import Testing

@Suite("CryptoManager Tests")
struct CryptoManagerTests {
    
    @Test("XOR operations are reversible")
    func xorReversible() throws {
        let crypto = CryptoManager.shared
        let a = try crypto.generateRandomBytes(count: 32)
        let b = try crypto.generateRandomBytes(count: 32)
        
        let xored = try crypto.xor(a, b)
        let result = try crypto.xor(xored, b)
        
        #expect(result == a)
    }
    
    @Test("Master key splits and reconstructs correctly")
    func masterKeySplitting() throws {
        let crypto = CryptoManager.shared
        let masterKey = try crypto.generateMasterKey()
        
        let (deviceShare, authShare, recoveryShare) = try crypto.splitMasterKey(masterKey)
        let reconstructed = try crypto.reconstructMasterKey(
            deviceShare: deviceShare,
            authShare: authShare,
            recoveryShare: recoveryShare
        )
        
        #expect(reconstructed == masterKey)
    }
}
```

## License

[Your License Here]
