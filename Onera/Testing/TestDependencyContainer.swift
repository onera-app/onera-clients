//
//  TestDependencyContainer.swift
//  Onera
//
//  Dependency container for UI testing with mock services
//

import Foundation

#if DEBUG

// MARK: - UI Testing Configuration

enum UITestingConfiguration {
    
    /// Check if the app is running in UI testing mode
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
    
    /// Check if animations should be disabled
    static var disableAnimations: Bool {
        CommandLine.arguments.contains("--disable-animations")
    }
    
    /// Check if state should be reset
    static var shouldResetState: Bool {
        CommandLine.arguments.contains("--reset-state")
    }
    
    /// Check if the user should be authenticated
    static var isAuthenticated: Bool {
        CommandLine.arguments.contains("--authenticated")
    }
    
    /// Check if the user should be unauthenticated
    static var isUnauthenticated: Bool {
        CommandLine.arguments.contains("--unauthenticated")
    }
    
    /// Check if biometrics should be skipped
    static var skipBiometrics: Bool {
        CommandLine.arguments.contains("--skip-biometrics")
    }
    
    /// Check if user needs E2EE setup
    static var needsE2EESetup: Bool {
        CommandLine.arguments.contains("--needs-e2ee-setup")
    }
    
    /// Check if user needs E2EE unlock
    static var needsE2EEUnlock: Bool {
        CommandLine.arguments.contains("--needs-e2ee-unlock")
    }
    
    /// Check if mock chats should be preloaded
    static var includeMockChats: Bool {
        CommandLine.arguments.contains("--mock-chats")
    }
    
    /// Check if mock notes should be preloaded
    static var includeMockNotes: Bool {
        CommandLine.arguments.contains("--mock-notes")
    }
}

// MARK: - Test Dependency Container

@MainActor
final class TestDependencyContainer: DependencyContaining, @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = TestDependencyContainer()
    
    // MARK: - Mock Services (exposed for test configuration)
    
    let mockAuthService = MockAuthService()
    let mockCryptoService = MockCryptoService()
    let mockKeychainService = MockKeychainService()
    let mockNetworkService = MockNetworkService()
    let mockE2EEService = MockE2EEService()
    let mockChatRepository = MockChatRepository()
    let mockNoteRepository = MockNoteRepository()
    let mockFolderRepository = MockFolderRepository()
    let mockSecureSession = MockSecureSession()
    let mockCredentialService = MockCredentialService()
    let mockLLMService = MockLLMService()
    let mockChatTasksService = MockChatTasksService()
    let mockSpeechService = MockSpeechService()
    let mockSpeechRecognitionService = MockSpeechRecognitionService()
    let mockFileProcessingService = MockFileProcessingService()
    let mockPasskeyService = MockPasskeyService()
    
    // MARK: - Protocol Conformance
    
    var authService: AuthServiceProtocol { mockAuthService }
    var cryptoService: CryptoServiceProtocol { mockCryptoService }
    var keychainService: KeychainServiceProtocol { mockKeychainService }
    var networkService: NetworkServiceProtocol { mockNetworkService }
    var e2eeService: E2EEServiceProtocol { mockE2EEService }
    var chatRepository: ChatRepositoryProtocol { mockChatRepository }
    var noteRepository: NoteRepositoryProtocol { mockNoteRepository }
    var folderRepository: FolderRepositoryProtocol { mockFolderRepository }
    var secureSession: SecureSessionProtocol { mockSecureSession }
    var credentialService: CredentialServiceProtocol { mockCredentialService }
    var llmService: LLMServiceProtocol { mockLLMService }
    var chatTasksService: ChatTasksServiceProtocol { mockChatTasksService }
    var speechService: SpeechServiceProtocol { mockSpeechService }
    var speechRecognitionService: SpeechRecognitionServiceProtocol { mockSpeechRecognitionService }
    var fileProcessingService: FileProcessingServiceProtocol { mockFileProcessingService }
    var passkeyService: PasskeyServiceProtocol { mockPasskeyService }
    
    // MARK: - Initialization
    
    private init() {
        configureForLaunchArguments()
    }
    
    // MARK: - Configuration
    
    /// Configure services based on launch arguments
    private func configureForLaunchArguments() {
        // Configure authentication state
        if UITestingConfiguration.isAuthenticated {
            mockAuthService.isAuthenticated = true
            mockAuthService.currentUser = .mock()
            
            // Configure E2EE keys as already set up
            mockE2EEService.hasKeys = true
            
            // Configure E2EE/session state
            if UITestingConfiguration.skipBiometrics {
                mockSecureSession.isUnlocked = true
                mockSecureSession.shouldRestoreSucceed = true
            }
            
            // Check if user needs E2EE setup (override hasKeys)
            if UITestingConfiguration.needsE2EESetup {
                mockE2EEService.hasKeys = false
                mockSecureSession.isUnlocked = false
            }
            
            // Check if user needs E2EE unlock
            if UITestingConfiguration.needsE2EEUnlock {
                mockE2EEService.hasKeys = true
                mockSecureSession.isUnlocked = false
                mockSecureSession.shouldRestoreSucceed = false
            }
        } else if UITestingConfiguration.isUnauthenticated {
            mockAuthService.isAuthenticated = false
            mockAuthService.currentUser = nil
            mockE2EEService.hasKeys = false
            mockSecureSession.isUnlocked = false
        }
    }
    
    // MARK: - Reset
    
    /// Resets all mock services to their default state
    func reset() {
        mockAuthService.isAuthenticated = false
        mockAuthService.currentUser = nil
        mockSecureSession.lock()
    }
}

// MARK: - Active Dependencies Resolver

enum DependencyResolver {
    
    /// Returns the appropriate dependency container based on the current context
    @MainActor
    static var current: DependencyContaining {
        if UITestingConfiguration.isUITesting {
            return TestDependencyContainer.shared
        }
        return DependencyContainer.shared
    }
}

#endif
