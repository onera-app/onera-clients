//
//  DependencyContainer.swift
//  Onera
//
//  Dependency Injection container for managing app dependencies
//

import Foundation

// MARK: - Dependency Container Protocol

protocol DependencyContaining: Sendable {
    var authService: AuthServiceProtocol { get }
    var cryptoService: CryptoServiceProtocol { get }
    var keychainService: KeychainServiceProtocol { get }
    var networkService: NetworkServiceProtocol { get }
    var e2eeService: E2EEServiceProtocol { get }
    var chatRepository: ChatRepositoryProtocol { get }
    var noteRepository: NoteRepositoryProtocol { get }
    var folderRepository: FolderRepositoryProtocol { get }
    var secureSession: SecureSessionProtocol { get }
    var credentialService: CredentialServiceProtocol { get }
    var llmService: LLMServiceProtocol { get }
    var chatTasksService: ChatTasksServiceProtocol { get }
    var speechService: SpeechServiceProtocol { get }
    var speechRecognitionService: SpeechRecognitionServiceProtocol { get }
    var fileProcessingService: FileProcessingServiceProtocol { get }
}

// MARK: - Live Dependency Container

final class DependencyContainer: DependencyContaining, @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - Services (Lazy Initialization)
    
    private lazy var _keychainService: KeychainServiceProtocol = KeychainService()
    private lazy var _cryptoService: CryptoServiceProtocol = CryptoService()
    private lazy var _networkService: NetworkServiceProtocol = NetworkService()
    private lazy var _secureSession: SecureSessionProtocol = SecureSession(
        cryptoService: _cryptoService,
        keychainService: _keychainService,
        timeoutMinutes: Configuration.Security.sessionTimeoutMinutes
    )
    private lazy var _authService: AuthServiceProtocol = AuthService(
        networkService: _networkService
    )
    private lazy var _e2eeService: E2EEServiceProtocol = E2EEService(
        cryptoService: _cryptoService,
        keychainService: _keychainService,
        networkService: _networkService,
        secureSession: _secureSession
    )
    private lazy var _chatRepository: ChatRepositoryProtocol = ChatRepository(
        networkService: _networkService,
        cryptoService: _cryptoService,
        secureSession: _secureSession
    )
    private lazy var _noteRepository: NoteRepositoryProtocol = NoteRepository(
        networkService: _networkService,
        cryptoService: _cryptoService,
        secureSession: _secureSession
    )
    private lazy var _folderRepository: FolderRepositoryProtocol = FolderRepository(
        networkService: _networkService
    )
    private lazy var _credentialService: CredentialServiceProtocol = CredentialService(
        networkService: _networkService,
        secureSession: _secureSession,
        cryptoService: _cryptoService
    )
    private lazy var _llmService: LLMServiceProtocol = LLMService()
    private lazy var _chatTasksService: ChatTasksServiceProtocol = ChatTasksService()
    private var _speechService: SpeechServiceProtocol?
    private var _speechRecognitionService: SpeechRecognitionServiceProtocol?
    
    // MARK: - Protocol Conformance
    
    var authService: AuthServiceProtocol { _authService }
    var cryptoService: CryptoServiceProtocol { _cryptoService }
    var keychainService: KeychainServiceProtocol { _keychainService }
    var networkService: NetworkServiceProtocol { _networkService }
    var e2eeService: E2EEServiceProtocol { _e2eeService }
    var chatRepository: ChatRepositoryProtocol { _chatRepository }
    var noteRepository: NoteRepositoryProtocol { _noteRepository }
    var folderRepository: FolderRepositoryProtocol { _folderRepository }
    var secureSession: SecureSessionProtocol { _secureSession }
    var credentialService: CredentialServiceProtocol { _credentialService }
    var llmService: LLMServiceProtocol { _llmService }
    var chatTasksService: ChatTasksServiceProtocol { _chatTasksService }
    
    @MainActor
    var speechService: SpeechServiceProtocol {
        if _speechService == nil {
            _speechService = SpeechService()
        }
        return _speechService!
    }
    
    @MainActor
    var speechRecognitionService: SpeechRecognitionServiceProtocol {
        if _speechRecognitionService == nil {
            _speechRecognitionService = SpeechRecognitionService()
        }
        return _speechRecognitionService!
    }
    
    var fileProcessingService: FileProcessingServiceProtocol {
        FileProcessingService()
    }
    
    // MARK: - Initialization
    
    private init() {}
}

// MARK: - Mock Dependency Container (for Testing/Previews)

#if DEBUG
final class MockDependencyContainer: DependencyContaining, @unchecked Sendable {
    
    var authService: AuthServiceProtocol
    var cryptoService: CryptoServiceProtocol
    var keychainService: KeychainServiceProtocol
    var networkService: NetworkServiceProtocol
    var e2eeService: E2EEServiceProtocol
    var chatRepository: ChatRepositoryProtocol
    var noteRepository: NoteRepositoryProtocol
    var folderRepository: FolderRepositoryProtocol
    var secureSession: SecureSessionProtocol
    var credentialService: CredentialServiceProtocol
    var llmService: LLMServiceProtocol
    var chatTasksService: ChatTasksServiceProtocol
    var speechService: SpeechServiceProtocol
    var speechRecognitionService: SpeechRecognitionServiceProtocol
    var fileProcessingService: FileProcessingServiceProtocol
    
    init(
        authService: AuthServiceProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil,
        keychainService: KeychainServiceProtocol? = nil,
        networkService: NetworkServiceProtocol? = nil,
        e2eeService: E2EEServiceProtocol? = nil,
        chatRepository: ChatRepositoryProtocol? = nil,
        noteRepository: NoteRepositoryProtocol? = nil,
        folderRepository: FolderRepositoryProtocol? = nil,
        secureSession: SecureSessionProtocol? = nil,
        credentialService: CredentialServiceProtocol? = nil,
        llmService: LLMServiceProtocol? = nil,
        chatTasksService: ChatTasksServiceProtocol? = nil,
        speechService: SpeechServiceProtocol? = nil,
        speechRecognitionService: SpeechRecognitionServiceProtocol? = nil,
        fileProcessingService: FileProcessingServiceProtocol? = nil
    ) {
        let crypto = cryptoService ?? MockCryptoService()
        let keychain = keychainService ?? MockKeychainService()
        let network = networkService ?? MockNetworkService()
        let session = secureSession ?? MockSecureSession()
        
        self.cryptoService = crypto
        self.keychainService = keychain
        self.networkService = network
        self.secureSession = session
        self.authService = authService ?? MockAuthService()
        self.e2eeService = e2eeService ?? MockE2EEService()
        self.chatRepository = chatRepository ?? MockChatRepository()
        self.noteRepository = noteRepository ?? MockNoteRepository()
        self.folderRepository = folderRepository ?? MockFolderRepository()
        self.credentialService = credentialService ?? MockCredentialService()
        self.llmService = llmService ?? MockLLMService()
        self.chatTasksService = chatTasksService ?? MockChatTasksService()
        self.speechService = speechService ?? MockSpeechService()
        self.speechRecognitionService = speechRecognitionService ?? MockSpeechRecognitionService()
        self.fileProcessingService = fileProcessingService ?? MockFileProcessingService()
    }
}
#endif

// MARK: - Environment Key for SwiftUI

import SwiftUI

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContaining = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContaining {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

extension View {
    func withDependencies(_ container: DependencyContaining) -> some View {
        environment(\.dependencies, container)
    }
}
