//
//  DemoDependencyContainer.swift
//  Onera
//
//  Dependency container for Demo Mode (App Store review)
//  Provides mock services that simulate real app functionality
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Demo Dependency Container

@MainActor
final class DemoDependencyContainer: DependencyContaining, @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = DemoDependencyContainer()
    
    // MARK: - Mock Services
    
    let demoAuthService = DemoAuthService()
    let demoCryptoService = CryptoService()  // Use real crypto for extended operations
    let demoKeychainService = DemoKeychainService()
    let demoNetworkService = DemoNetworkService()
    let demoE2EEService = DemoE2EEService()
    let demoChatRepository = DemoChatRepository()
    let demoNoteRepository = DemoNoteRepository()
    let demoFolderRepository = DemoFolderRepository()
    let demoSecureSession = DemoSecureSession()
    let demoCredentialService = DemoCredentialService()
    let demoLLMService = DemoLLMService()
    let demoChatTasksService = DemoChatTasksService()
    let demoSpeechService = DemoSpeechService()
    let demoSpeechRecognitionService = DemoSpeechRecognitionService()
    let demoFileProcessingService = DemoFileProcessingService()
    let demoPasskeyService = DemoPasskeyService()
    let demoPromptRepository = DemoPromptRepository()
    
    // MARK: - Protocol Conformance
    
    var authService: AuthServiceProtocol { demoAuthService }
    var cryptoService: CryptoServiceProtocol { demoCryptoService }
    var extendedCryptoService: ExtendedCryptoServiceProtocol { demoCryptoService }
    var keychainService: KeychainServiceProtocol { demoKeychainService }
    var networkService: NetworkServiceProtocol { demoNetworkService }
    var e2eeService: E2EEServiceProtocol { demoE2EEService }
    var chatRepository: ChatRepositoryProtocol { demoChatRepository }
    var noteRepository: NoteRepositoryProtocol { demoNoteRepository }
    var folderRepository: FolderRepositoryProtocol { demoFolderRepository }
    var secureSession: SecureSessionProtocol { demoSecureSession }
    var credentialService: CredentialServiceProtocol { demoCredentialService }
    var llmService: LLMServiceProtocol { demoLLMService }
    var chatTasksService: ChatTasksServiceProtocol { demoChatTasksService }
    var speechService: SpeechServiceProtocol { demoSpeechService }
    var speechRecognitionService: SpeechRecognitionServiceProtocol { demoSpeechRecognitionService }
    var fileProcessingService: FileProcessingServiceProtocol { demoFileProcessingService }
    var passkeyService: PasskeyServiceProtocol { demoPasskeyService }
    var promptRepository: PromptRepositoryProtocol { demoPromptRepository }
    
    // MARK: - Initialization
    
    private init() {
        // Pre-configure demo state
        demoAuthService.isAuthenticated = false  // Start unauthenticated
        demoE2EEService.hasKeys = true  // Skip E2EE setup
        demoSecureSession.isUnlocked = true  // Session is "unlocked"
    }
}

// MARK: - Demo Auth Service

@MainActor
final class DemoAuthService: AuthServiceProtocol {
    
    var isAuthenticated = false
    var currentUser: User?
    
    func getToken() async throws -> String {
        guard isAuthenticated else { throw AuthError.notAuthenticated }
        return "demo-token-\(UUID().uuidString)"
    }
    
    func signInWithApple() async throws {
        try await Task.sleep(for: .milliseconds(800))
        currentUser = DemoData.demoUser
        isAuthenticated = true
        print("[DemoMode] Signed in with Apple (demo)")
    }
    
    func signInWithGoogle() async throws {
        try await Task.sleep(for: .milliseconds(800))
        currentUser = DemoData.demoUser
        isAuthenticated = true
        print("[DemoMode] Signed in with Google (demo)")
    }
    
    func signOut() async {
        currentUser = nil
        isAuthenticated = false
        print("[DemoMode] Signed out (demo)")
    }
    
    func handleOAuthCallback(url: URL) async throws {
        // No-op in demo mode
    }
}

// MARK: - Demo E2EE Service

final class DemoE2EEService: E2EEServiceProtocol, @unchecked Sendable {
    
    var hasKeys = true
    var hasPassword = false
    var hasPasskey = false
    
    func checkSetupStatus(token: String) async throws -> Bool {
        return hasKeys
    }
    
    func setupNewUser(token: String) async throws -> String {
        hasKeys = true
        return "demo abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    }
    
    func unlockWithDeviceShare(token: String) async throws {
        // Auto-unlock in demo mode
    }
    
    func unlockWithRecoveryPhrase(mnemonic: String, token: String) async throws {
        // Auto-unlock in demo mode
    }
    
    func hasPasswordEncryption(token: String) async throws -> Bool {
        return hasPassword
    }
    
    func setupPasswordEncryption(password: String, token: String) async throws {
        hasPassword = true
    }
    
    func unlockWithPassword(password: String, token: String) async throws {
        // Auto-unlock in demo mode
    }
    
    func removePasswordEncryption(token: String) async throws {
        hasPassword = false
    }
    
    func isPasskeySupported() -> Bool { true }
    func hasPasskeys(token: String) async throws -> Bool { hasPasskey }
    func hasLocalPasskey() -> Bool { hasPasskey }
    func registerPasskey(name: String?, token: String) async throws { hasPasskey = true }
    func unlockWithPasskey(token: String) async throws {}
    func getRecoveryPhrase(token: String) async throws -> String {
        return "demo abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    }
    func verifyMasterKey(token: String) async throws -> Bool {
        return true // Always valid in demo mode
    }
}

// MARK: - Demo Secure Session

@MainActor
final class DemoSecureSession: SecureSessionProtocol {
    
    var isUnlocked = true
    var lastActivityDate = Date()
    
    var masterKey: Data? = Data(repeating: 0xDE, count: 32)
    var privateKey: Data? = Data(repeating: 0xAA, count: 32)
    var publicKey: Data? = Data(repeating: 0xBB, count: 32)
    
    var shouldRestoreSucceed = true
    
    func unlock(masterKey: Data, privateKey: Data, publicKey: Data, recoveryKey: Data?) {
        self.masterKey = masterKey
        self.privateKey = privateKey
        self.publicKey = publicKey
        isUnlocked = true
    }
    
    func lock() {
        masterKey = nil
        privateKey = nil
        publicKey = nil
        isUnlocked = false
    }
    
    func tryRestoreSession() async -> Bool {
        if shouldRestoreSucceed {
            isUnlocked = true
            masterKey = Data(repeating: 0xDE, count: 32)
            return true
        }
        return false
    }
    
    func clearPersistedSession() {
        // No-op for demo mode
    }
    
    func recordActivity() {
        lastActivityDate = Date()
    }
}

// MARK: - Demo Chat Repository

final class DemoChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    
    var chats: [String: Chat] = [:]
    
    init() {
        // Pre-populate with demo chats
        for summary in DemoData.demoChats {
            let chat = DemoData.demoChat(id: summary.id)
            chats[chat.id] = chat
        }
    }
    
    func fetchChats(token: String) async throws -> [ChatSummary] {
        try await Task.sleep(for: .milliseconds(300))
        return DemoData.demoChats
    }
    
    func fetchChat(id: String, token: String) async throws -> Chat {
        try await Task.sleep(for: .milliseconds(200))
        
        if let chat = chats[id] {
            return chat
        }
        return DemoData.demoChat(id: id)
    }
    
    func createChat(_ chat: Chat, token: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(200))
        let newId = "demo-\(UUID().uuidString)"
        var newChat = chat
        newChat.id = newId
        chats[newId] = newChat
        return newId
    }
    
    func updateChat(_ chat: Chat, token: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        chats[chat.id] = chat
    }
    
    func updateChatFolder(chatId: String, folderId: String?, token: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        if var chat = chats[chatId] {
            chat.folderId = folderId
            chats[chatId] = chat
        }
    }
    
    func deleteChat(id: String, token: String) async throws {
        chats.removeValue(forKey: id)
    }
    
    func generateChatKey() throws -> Data {
        Data(repeating: 0xAB, count: 32)
    }
}

// MARK: - Demo Credential Service

@MainActor
final class DemoCredentialService: CredentialServiceProtocol {
    
    var credentials: [DecryptedCredential] = []
    var isLoading = false
    
    func fetchCredentials(token: String) async throws {
        isLoading = true
        try await Task.sleep(for: .milliseconds(300))
        credentials = DemoData.demoCredentials
        isLoading = false
    }
    
    func refreshCredentials(token: String) async throws {
        try await fetchCredentials(token: token)
    }
    
    func clearCredentials() {
        credentials = []
    }
    
    func getCredential(byId id: String) -> DecryptedCredential? {
        credentials.first { $0.id == id }
    }
    
    func getCredentials(for provider: LLMProvider) -> [DecryptedCredential] {
        credentials.filter { $0.provider == provider }
    }
}

// MARK: - Demo LLM Service

actor DemoLLMService: LLMServiceProtocol {
    
    private var isCancelled = false
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        isCancelled = false
        
        // Get the last user message
        let userMessage = messages.last { $0.role == .user }?.content ?? ""
        
        // Generate appropriate demo response
        let response = DemoData.generateResponse(for: userMessage)
        
        // Stream the response character by character with natural typing speed
        for char in response {
            if isCancelled { break }
            
            // Variable delay for more natural typing feel
            let delay: UInt64 = char == "\n" ? 100_000_000 : UInt64.random(in: 5_000_000...20_000_000)
            try? await Task.sleep(nanoseconds: delay)
            
            if isCancelled { break }
            onEvent(.text(String(char)))
        }
        
        onEvent(.done)
    }
    
    func fetchModels(credential: DecryptedCredential) async throws -> [ModelOption] {
        try await Task.sleep(for: .milliseconds(200))
        // Get demo models from MainActor context
        let allModels = await MainActor.run { DemoData.demoModels }
        return allModels.filter { $0.credentialId == credential.id }
    }
    
    func cancelStream() async {
        isCancelled = true
    }
    
    func streamChat(
        messages: [ChatMessage],
        credential: DecryptedCredential?,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        enclaveConfig: EnclaveConfig?,
        onEvent: @escaping @Sendable (StreamEvent) -> Void
    ) async throws {
        // For demo, just delegate to regular streamChat if we have a credential
        // Private inference models in demo mode just show a placeholder response
        if isPrivateModel(model) {
            isCancelled = false
            let response = "[Private Inference Demo] This would be an encrypted response from a TEE."
            for char in response {
                if isCancelled { break }
                try? await Task.sleep(nanoseconds: 15_000_000)
                if isCancelled { break }
                onEvent(.text(String(char)))
            }
            onEvent(.done)
        } else if let credential = credential {
            try await streamChat(
                messages: messages,
                credential: credential,
                model: model,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                onEvent: onEvent
            )
        } else {
            throw LLMError.invalidCredential
        }
    }
}

// MARK: - Demo Note Repository

final class DemoNoteRepository: NoteRepositoryProtocol, @unchecked Sendable {
    
    func fetchNotes(token: String, folderId: String?, archived: Bool) async throws -> [NoteSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return [
            NoteSummary(
                id: "demo-note-1",
                title: "Demo Note",
                folderId: nil,
                pinned: false,
                archived: false,
                createdAt: Date(),
                updatedAt: Date()
            ),
            NoteSummary(
                id: "demo-note-2",
                title: "Getting Started Guide",
                folderId: nil,
                pinned: true,
                archived: false,
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            ),
        ]
    }
    
    func fetchNote(id: String, token: String) async throws -> Note {
        if id == "demo-note-1" {
            return Note(
                id: id,
                title: "Demo Note",
                content: "This is a demo note for App Store review.\n\n## Features\n- Markdown support\n- E2EE encryption\n- Cross-device sync",
                createdAt: Date(),
                updatedAt: Date()
            )
        } else {
            return Note(
                id: id,
                title: "Getting Started Guide",
                content: "# Welcome to Onera!\n\nOnera is your AI-powered chat assistant with end-to-end encryption.\n\n## Key Features\n\n1. **Private Conversations** - All chats are encrypted\n2. **Multiple AI Models** - Choose from various providers\n3. **Notes** - Take encrypted notes\n4. **Folders** - Organize your content",
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            )
        }
    }
    
    func createNote(_ note: Note, token: String) async throws -> String {
        "demo-note-\(UUID().uuidString)"
    }
    
    func updateNote(_ note: Note, token: String) async throws {}
    func deleteNote(id: String, token: String) async throws {}
}

// MARK: - Demo Folder Repository

final class DemoFolderRepository: FolderRepositoryProtocol, @unchecked Sendable {
    
    func fetchFolders(token: String) async throws -> [EncryptedFolderResponse] {
        try await Task.sleep(for: .milliseconds(200))
        return [
            EncryptedFolderResponse(
                id: "demo-folder-1",
                userId: "demo-user-001",
                encryptedName: "Work",
                nameNonce: "demo-nonce-1",
                parentId: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            EncryptedFolderResponse(
                id: "demo-folder-2",
                userId: "demo-user-001",
                encryptedName: "Personal",
                nameNonce: "demo-nonce-2",
                parentId: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
        ]
    }
    
    func fetchFolder(id: String, token: String) async throws -> EncryptedFolderResponse {
        EncryptedFolderResponse(
            id: id,
            userId: "demo-user-001",
            encryptedName: "Demo Folder",
            nameNonce: "demo-nonce",
            parentId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func createFolder(encryptedName: String, nameNonce: String, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        EncryptedFolderResponse(
            id: "demo-folder-\(UUID().uuidString)",
            userId: "demo-user-001",
            encryptedName: encryptedName,
            nameNonce: nameNonce,
            parentId: parentId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func updateFolder(id: String, encryptedName: String?, nameNonce: String?, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        EncryptedFolderResponse(
            id: id,
            userId: "demo-user-001",
            encryptedName: encryptedName,
            nameNonce: nameNonce,
            parentId: parentId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func deleteFolder(id: String, token: String) async throws {}
}

// MARK: - Demo Network Service

final class DemoNetworkService: NetworkServiceProtocol, @unchecked Sendable {
    
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        throw NetworkError.serverError(statusCode: 999)
    }
    
    func call<Output: Decodable>(
        procedure: String,
        token: String?
    ) async throws -> Output {
        throw NetworkError.serverError(statusCode: 999)
    }
    
    func query<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output {
        throw NetworkError.serverError(statusCode: 999)
    }
}

// MARK: - Demo Keychain Service

final class DemoKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    
    private var storage: [String: Data] = [:]
    private let deviceId = UUID().uuidString
    
    func getOrCreateDeviceId() throws -> String {
        return deviceId
    }
    
    func saveDeviceShare(encryptedShare: Data, nonce: Data) throws {
        storage["deviceShare"] = encryptedShare
        storage["deviceShareNonce"] = nonce
    }
    
    func getDeviceShare() throws -> (encryptedShare: Data, nonce: Data) {
        guard let share = storage["deviceShare"], let nonce = storage["deviceShareNonce"] else {
            throw KeychainError.itemNotFound
        }
        return (share, nonce)
    }
    
    func hasDeviceShare() -> Bool {
        storage["deviceShare"] != nil
    }
    
    func removeDeviceShare() throws {
        storage.removeValue(forKey: "deviceShare")
        storage.removeValue(forKey: "deviceShareNonce")
    }
    
    func hasPasskeyKEK() -> Bool {
        storage["passkeyKEK"] != nil
    }
    
    func getPasskeyCredentialId() throws -> String? {
        guard let data = storage["passkeyCredentialId"] else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func save(_ data: Data, forKey key: String) throws {
        storage[key] = data
    }
    
    func get(forKey key: String) throws -> Data {
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }
    
    func clearAll() throws {
        storage.removeAll()
    }
}

// MARK: - Demo Passkey Service

final class DemoPasskeyService: PasskeyServiceProtocol, @unchecked Sendable {
    
    func isPasskeySupported() -> Bool {
        true
    }
    
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String {
        throw PasskeyError.notSupported
    }
    
    func authenticateWithPasskey(token: String) async throws -> Data {
        throw PasskeyError.notSupported
    }
    
    func hasPasskeys(token: String) async throws -> Bool {
        false
    }
    
    func hasLocalPasskeyKEK() -> Bool {
        false
    }
    
    func removeLocalPasskeyKEK() throws {
        // No-op
    }
}

// MARK: - Demo Chat Tasks Service

actor DemoChatTasksService: ChatTasksServiceProtocol {
    
    func generateTitle(for messages: [ChatMessage], credential: DecryptedCredential, model: String) async -> String? {
        guard let firstUserMessage = messages.first(where: { $0.role == .user })?.content else {
            return "New Chat"
        }
        let title = firstUserMessage.components(separatedBy: .newlines).first ?? firstUserMessage
        return String(title.prefix(50))
    }
    
    func generateFollowUps(for messages: [ChatMessage], credential: DecryptedCredential, model: String, count: Int) async -> [String] {
        return [
            "Can you explain that in more detail?",
            "What are some practical examples?",
            "How does this compare to alternatives?"
        ].prefix(count).map { $0 }
    }
}

// MARK: - Demo Speech Service

@MainActor
final class DemoSpeechService: SpeechServiceProtocol {
    var isSpeaking: Bool = false
    
    func speak(_ text: String) async {
        isSpeaking = true
        try? await Task.sleep(for: .seconds(2))
        isSpeaking = false
    }
    
    func stop() {
        isSpeaking = false
    }
}

// MARK: - Demo Speech Recognition Service

@MainActor
final class DemoSpeechRecognitionService: SpeechRecognitionServiceProtocol, @unchecked Sendable {
    var isAuthorized: Bool = true
    var isRecording: Bool = false
    var transcribedText: String = ""
    var onTranscriptionUpdate: ((String) -> Void)?
    
    func requestAuthorization() async -> Bool { true }
    func startRecording() async throws {
        isRecording = true
        transcribedText = ""
    }
    func stopRecording() -> String? {
        isRecording = false
        return transcribedText.isEmpty ? "Demo transcription" : transcribedText
    }
}

// MARK: - Demo File Processing Service

final class DemoFileProcessingService: FileProcessingServiceProtocol, @unchecked Sendable {
    
    func processFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        ProcessedFile(
            type: .file,
            data: data.base64EncodedString(),
            mimeType: mimeType,
            fileName: fileName,
            fileSize: data.count,
            metadata: FileMetadata(extractedText: "Demo extracted text")
        )
    }
    
    func processImage(_ image: PlatformImage, fileName: String) async throws -> ProcessedFile {
        let data = image.jpegData(compressionQuality: 0.8) ?? Data()
        return ProcessedFile(
            type: .image,
            data: data.base64EncodedString(),
            mimeType: "image/jpeg",
            fileName: fileName,
            fileSize: data.count,
            metadata: FileMetadata(width: Int(image.size.width), height: Int(image.size.height))
        )
    }
    
    func compressImage(_ data: Data, maxSizeMB: Double, maxDimension: Int) async throws -> Data {
        return data
    }
    
    func extractPDFText(_ data: Data) async throws -> (text: String, pageCount: Int) {
        return ("Demo PDF text", 1)
    }
    
    func validateFile(_ data: Data, mimeType: String) -> FileValidationResult {
        FileValidationResult(isValid: true, error: nil)
    }
}

// MARK: - Demo Prompt Repository

final class DemoPromptRepository: PromptRepositoryProtocol, @unchecked Sendable {
    
    private var prompts: [String: Prompt] = [:]
    
    init() {
        // Pre-populate with demo prompts
        let demoPrompt1 = Prompt(
            id: "demo-prompt-1",
            name: "Code Review",
            description: "Analyze code for bugs and improvements",
            content: "Please review this code and suggest improvements:\n\n{code}",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-86400)
        )
        let demoPrompt2 = Prompt(
            id: "demo-prompt-2",
            name: "Explain Concept",
            description: "Explain a concept in simple terms",
            content: "Explain {concept} in simple terms that a beginner would understand. Use examples where helpful.",
            createdAt: Date().addingTimeInterval(-172800),
            updatedAt: Date().addingTimeInterval(-172800)
        )
        prompts[demoPrompt1.id] = demoPrompt1
        prompts[demoPrompt2.id] = demoPrompt2
    }
    
    func fetchPrompts(token: String) async throws -> [PromptSummary] {
        try await Task.sleep(for: .milliseconds(200))
        return prompts.values.map { prompt in
            PromptSummary(
                id: prompt.id,
                name: prompt.name,
                description: prompt.description,
                createdAt: prompt.createdAt,
                updatedAt: prompt.updatedAt
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    func fetchPrompt(id: String, token: String) async throws -> Prompt {
        try await Task.sleep(for: .milliseconds(100))
        guard let prompt = prompts[id] else {
            throw PromptError.promptNotFound
        }
        return prompt
    }
    
    func createPrompt(_ prompt: Prompt, token: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(200))
        let newId = "demo-prompt-\(UUID().uuidString)"
        let newPrompt = Prompt(
            id: newId,
            name: prompt.name,
            description: prompt.description,
            content: prompt.content,
            createdAt: prompt.createdAt,
            updatedAt: prompt.updatedAt
        )
        prompts[newId] = newPrompt
        return newId
    }
    
    func updatePrompt(_ prompt: Prompt, token: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        prompts[prompt.id] = prompt
    }
    
    func deletePrompt(id: String, token: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        prompts.removeValue(forKey: id)
    }
}
