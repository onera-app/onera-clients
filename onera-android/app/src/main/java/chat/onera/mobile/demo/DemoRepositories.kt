package chat.onera.mobile.demo

import android.app.Activity
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Credential
import chat.onera.mobile.domain.model.LLMProvider
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.E2EERepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import timber.log.Timber

/**
 * Demo implementation of AuthRepository.
 * Auto-authenticates with demo user for Play Store review.
 */
class DemoAuthRepository : AuthRepository {
    
    private val _isAuthenticated = MutableStateFlow(false)
    
    override suspend fun isAuthenticated(): Boolean = _isAuthenticated.value
    
    override suspend fun getCurrentUser(): User? = if (_isAuthenticated.value) DemoData.demoUser else null
    
    override fun observeAuthState(): Flow<Boolean> = _isAuthenticated
    
    override suspend fun signInWithGoogle() {
        Timber.d("DemoAuth: Simulating Google sign-in")
        delay(500) // Simulate network delay
        _isAuthenticated.value = true
    }
    
    override suspend fun signInWithApple() {
        Timber.d("DemoAuth: Simulating Apple sign-in")
        delay(500)
        _isAuthenticated.value = true
    }
    
    override suspend fun signInWithEmail(email: String) {
        Timber.d("DemoAuth: Simulating email sign-in for $email")
        delay(500)
        _isAuthenticated.value = true
    }
    
    override suspend fun signOut() {
        Timber.d("DemoAuth: Signing out")
        _isAuthenticated.value = false
        DemoModeManager.deactivate()
    }
    
    override suspend fun deleteAccount() {
        Timber.d("DemoAuth: Delete account (simulated)")
        _isAuthenticated.value = false
        DemoModeManager.deactivate()
    }
    
    fun autoSignIn() {
        _isAuthenticated.value = true
    }
}

/**
 * Demo implementation of E2EERepository.
 * Auto-unlocks and skips E2EE setup for demo mode.
 */
class DemoE2EERepository : E2EERepository {
    
    private var _isUnlocked = true
    private val fakeMasterKey = ByteArray(32) { it.toByte() }
    
    // ===== Setup Status =====
    
    override suspend fun hasEncryptionKeys(): Boolean = true
    
    override suspend fun checkSetupStatus(): Boolean = true
    
    // ===== New User Setup =====
    
    override suspend fun setupNewUser(): String {
        Timber.d("DemoE2EE: Setup new user (simulated)")
        return "demo word one two three four five six seven eight nine ten eleven twelve"
    }
    
    override suspend fun generateKeys(): List<String> {
        Timber.d("DemoE2EE: Generate keys (simulated)")
        return listOf("demo", "word", "one", "two", "three", "four", 
                      "five", "six", "seven", "eight", "nine", "ten", 
                      "eleven", "twelve")
    }
    
    override suspend fun finalizeKeySetup() {
        Timber.d("DemoE2EE: Finalize key setup (simulated)")
    }
    
    // ===== Encryption/Decryption =====
    
    override suspend fun encryptMessage(plaintext: String): String {
        // In demo mode, just return the plaintext (no encryption)
        return plaintext
    }
    
    override suspend fun decryptMessage(ciphertext: String): String {
        // In demo mode, just return the ciphertext (no decryption)
        return ciphertext
    }
    
    // ===== Recovery =====
    
    override suspend fun exportRecoveryPhrase(): List<String> {
        return listOf("demo", "word", "one", "two", "three", "four", 
                      "five", "six", "seven", "eight", "nine", "ten", 
                      "eleven", "twelve")
    }
    
    override suspend fun restoreFromRecoveryPhrase(phrase: List<String>) {
        Timber.d("DemoE2EE: Restore from recovery phrase (simulated)")
        _isUnlocked = true
    }
    
    override suspend fun unlockWithRecoveryPhrase(phrase: String) {
        Timber.d("DemoE2EE: Unlock with recovery phrase (simulated)")
        _isUnlocked = true
    }
    
    // ===== Key Management =====
    
    override suspend fun rotateKeys() {
        Timber.d("DemoE2EE: Rotate keys (simulated)")
    }
    
    override suspend fun clearKeys() {
        Timber.d("DemoE2EE: Clear keys (simulated)")
    }
    
    // ===== Unlock Methods =====
    
    override suspend fun hasLocalPasskey(): Boolean = true
    
    override suspend fun hasServerPasskeys(): Boolean = true
    
    override suspend fun hasPasswordEncryption(): Boolean = true
    
    override suspend fun unlockWithPasskey() {
        Timber.d("DemoE2EE: Unlock with passkey (simulated)")
        _isUnlocked = true
    }
    
    override suspend fun unlockWithPasskeyAuth(activity: Activity) {
        Timber.d("DemoE2EE: Unlock with passkey auth (simulated)")
        _isUnlocked = true
    }
    
    override suspend fun registerPasskey(name: String?, activity: Activity): String {
        Timber.d("DemoE2EE: Register passkey (simulated)")
        return "demo-passkey-${System.currentTimeMillis()}"
    }
    
    override suspend fun unlockWithPassword(password: String) {
        Timber.d("DemoE2EE: Unlock with password (simulated)")
        _isUnlocked = true
    }
    
    // ===== Password Encryption =====
    
    override suspend fun setupPasswordEncryption(password: String) {
        Timber.d("DemoE2EE: Setup password encryption (simulated)")
    }
    
    override suspend fun removePasswordEncryption() {
        Timber.d("DemoE2EE: Remove password encryption (simulated)")
    }
    
    // ===== Session State =====
    
    override fun isSessionUnlocked(): Boolean = _isUnlocked
    
    override fun getMasterKey(): ByteArray = fakeMasterKey
    
    override fun lockSession() {
        Timber.d("DemoE2EE: Session locked (simulated)")
        _isUnlocked = false
    }
    
    override suspend fun resetEncryption(confirmPhrase: String) {
        Timber.d("DemoE2EE: Reset encryption (simulated)")
        _isUnlocked = false
    }
}

/**
 * Demo implementation of ChatRepository.
 * Provides in-memory chat storage with pre-populated demo data.
 */
class DemoChatRepository : ChatRepository {
    
    private val _chats = MutableStateFlow<List<Chat>>(emptyList())
    private val _messages = mutableMapOf<String, MutableStateFlow<List<Message>>>()
    
    init {
        // Initialize with demo chats
        val demoChats = DemoData.demoChatSummaries.map { summary ->
            Chat(
                id = summary.id,
                title = summary.title,
                lastMessage = summary.lastMessage,
                createdAt = summary.updatedAt - 3600_000, // Created 1 hour before last update
                updatedAt = summary.updatedAt,
                messages = DemoData.getDemoChatMessages(summary.id)
            )
        }
        _chats.value = demoChats
        
        // Initialize messages map
        demoChats.forEach { chat ->
            _messages[chat.id] = MutableStateFlow(chat.messages)
        }
    }
    
    override fun observeChats(): Flow<List<Chat>> = _chats
    
    override suspend fun getChats(): List<Chat> = _chats.value
    
    override suspend fun getChat(chatId: String): Chat? {
        return _chats.value.find { it.id == chatId }
    }
    
    override suspend fun createChat(title: String): String {
        val chatId = "demo-chat-${System.currentTimeMillis()}"
        val now = System.currentTimeMillis()
        val newChat = Chat(
            id = chatId,
            title = title,
            lastMessage = null,
            createdAt = now,
            updatedAt = now,
            messages = emptyList()
        )
        _chats.value = _chats.value + newChat
        _messages[chatId] = MutableStateFlow(emptyList())
        Timber.d("DemoChat: Created chat $chatId")
        return chatId
    }
    
    override suspend fun updateChat(chat: Chat) {
        _chats.value = _chats.value.map { 
            if (it.id == chat.id) chat else it 
        }
        Timber.d("DemoChat: Updated chat ${chat.id}")
    }
    
    override suspend fun updateChatFolder(chatId: String, folderId: String?) {
        _chats.value = _chats.value.map { chat ->
            if (chat.id == chatId) chat.copy(folderId = folderId) else chat
        }
        Timber.d("DemoChat: Moved chat $chatId to folder $folderId")
    }
    
    override suspend fun deleteChat(chatId: String) {
        _chats.value = _chats.value.filter { it.id != chatId }
        _messages.remove(chatId)
        Timber.d("DemoChat: Deleted chat $chatId")
    }
    
    override suspend fun refreshChats() {
        Timber.d("DemoChat: Refreshing chats (no-op in demo)")
    }
    
    override suspend fun fetchChat(chatId: String): Chat? {
        return getChat(chatId)
    }
    
    override suspend fun syncChat(chatId: String) {
        Timber.d("DemoChat: Sync chat $chatId (no-op in demo)")
    }
    
    override suspend fun getChatMessages(chatId: String): List<Message> {
        return _messages[chatId]?.value ?: emptyList()
    }
    
    override fun observeMessages(chatId: String): Flow<List<Message>> {
        return _messages.getOrPut(chatId) { MutableStateFlow(emptyList()) }
    }
    
    override fun sendMessageStream(
        chatId: String?,
        message: String,
        model: String,
        images: List<ImageData>
    ): Flow<String> = flow {
        Timber.d("DemoChat: Streaming response for: $message")
        
        // Generate demo response
        val response = DemoData.generateResponse(message)
        
        // Stream character by character with natural typing delay
        for (char in response) {
            emit(char.toString())
            delay(15 + (Math.random() * 20).toLong()) // 15-35ms per char
        }
    }
    
    override suspend fun saveMessage(message: Message) {
        val chatId = message.chatId
        val messagesFlow = _messages.getOrPut(chatId) { MutableStateFlow(emptyList()) }
        messagesFlow.value = messagesFlow.value + message
        
        // Update chat's last message
        _chats.value = _chats.value.map { chat ->
            if (chat.id == chatId) {
                chat.copy(
                    lastMessage = message.content.take(50),
                    updatedAt = System.currentTimeMillis()
                )
            } else chat
        }
    }
    
    override suspend fun deleteMessage(messageId: String) {
        // Find and remove the message from all chats
        _messages.forEach { (_, messagesFlow) ->
            messagesFlow.value = messagesFlow.value.filter { it.id != messageId }
        }
        Timber.d("DemoChat: Deleted message $messageId")
    }
    
    override fun clearKeyCache() {
        Timber.d("DemoChat: Clear key cache (no-op in demo)")
    }
}

/**
 * Demo implementation of CredentialRepository.
 * Returns mock API credentials for demo mode.
 */
class DemoCredentialRepository : CredentialRepository {
    
    private val _credentials = MutableStateFlow(DemoData.getDemoCredentials())
    
    override fun observeCredentials(): Flow<List<Credential>> = _credentials
    
    override suspend fun getCredentials(): List<Credential> = _credentials.value
    
    override suspend fun getCredential(id: String): Credential? {
        return _credentials.value.find { it.id == id }
    }
    
    override suspend fun getCredentialsForProvider(provider: LLMProvider): List<Credential> {
        return _credentials.value.filter { it.provider == provider }
    }
    
    override suspend fun refreshCredentials() {
        Timber.d("DemoCredential: Refresh credentials (no-op in demo)")
    }
    
    override suspend fun createCredential(
        provider: LLMProvider,
        name: String,
        apiKey: String,
        baseUrl: String?,
        orgId: String?
    ): String {
        val id = "demo-credential-${System.currentTimeMillis()}"
        val newCredential = Credential(
            id = id,
            provider = provider,
            name = name,
            apiKey = apiKey,
            baseUrl = baseUrl,
            orgId = orgId
        )
        _credentials.value = _credentials.value + newCredential
        Timber.d("DemoCredential: Created credential $id")
        return id
    }
    
    override suspend fun updateCredential(credential: Credential) {
        _credentials.value = _credentials.value.map { 
            if (it.id == credential.id) credential else it 
        }
        Timber.d("DemoCredential: Updated credential ${credential.id}")
    }
    
    override suspend fun deleteCredential(id: String) {
        _credentials.value = _credentials.value.filter { it.id != id }
        Timber.d("DemoCredential: Deleted credential $id")
    }
    
    override fun clearCredentials() {
        _credentials.value = emptyList()
        Timber.d("DemoCredential: Cleared all credentials")
    }
}

/**
 * Container for all demo repositories.
 * Provides a single point of access for demo mode.
 */
object DemoRepositoryContainer {
    val authRepository: DemoAuthRepository by lazy { DemoAuthRepository() }
    val e2eeRepository: DemoE2EERepository by lazy { DemoE2EERepository() }
    val chatRepository: DemoChatRepository by lazy { DemoChatRepository() }
    val credentialRepository: DemoCredentialRepository by lazy { DemoCredentialRepository() }
    
    /**
     * Reset all demo repositories to initial state.
     * Call this when exiting demo mode.
     */
    fun reset() {
        // Re-initialize repositories by clearing lazy delegates
        // For now, the repositories maintain state, which is fine for a demo session
        Timber.d("DemoRepositoryContainer: Reset requested")
    }
}
