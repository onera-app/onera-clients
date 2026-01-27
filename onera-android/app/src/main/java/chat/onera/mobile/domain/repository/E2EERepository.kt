package chat.onera.mobile.domain.repository

/**
 * E2EE Repository interface - matches iOS E2EEServiceProtocol
 * Handles encryption key management with server sync.
 */
interface E2EERepository {
    
    // ===== Setup Status =====
    
    /** Check if user has local encryption keys */
    suspend fun hasEncryptionKeys(): Boolean
    
    /** Check if user has key shares on server */
    suspend fun checkSetupStatus(): Boolean
    
    // ===== New User Setup =====
    
    /** Generate keys and sync to server. Returns BIP39 recovery phrase. */
    suspend fun setupNewUser(): String
    
    /** Legacy: Generate keys locally only. Returns BIP39 recovery phrase words. */
    suspend fun generateKeys(): List<String>
    
    /** Finalize key setup (mark as complete) */
    suspend fun finalizeKeySetup()
    
    // ===== Encryption/Decryption =====
    
    suspend fun encryptMessage(plaintext: String): String
    suspend fun decryptMessage(ciphertext: String): String
    
    // ===== Recovery =====
    
    suspend fun exportRecoveryPhrase(): List<String>
    suspend fun restoreFromRecoveryPhrase(phrase: List<String>)
    
    /** Unlock using BIP39 recovery phrase (server sync) */
    suspend fun unlockWithRecoveryPhrase(phrase: String)
    
    // ===== Key Management =====
    
    suspend fun rotateKeys()
    suspend fun clearKeys()
    
    // ===== Unlock Methods =====
    
    /** Check if device has local passkey KEK */
    suspend fun hasLocalPasskey(): Boolean
    
    /** Check if user has passkeys registered on server */
    suspend fun hasServerPasskeys(): Boolean
    
    /** Check if user has password encryption set up (query server) */
    suspend fun hasPasswordEncryption(): Boolean
    
    /** Unlock using biometric/passkey (legacy - uses local KEK only) */
    suspend fun unlockWithPasskey()
    
    /** Unlock using passkey with activity (supports PRF-based synced passkeys) */
    suspend fun unlockWithPasskeyAuth(activity: android.app.Activity)
    
    /** Register a new passkey (requires master key to be unlocked) */
    suspend fun registerPasskey(name: String?, activity: android.app.Activity): String
    
    /** Unlock using password (decrypts master key from server) */
    suspend fun unlockWithPassword(password: String)
    
    // ===== Password Encryption =====
    
    /** Set up password-based encryption (encrypts master key to server) */
    suspend fun setupPasswordEncryption(password: String)
    
    /** Remove password encryption from server */
    suspend fun removePasswordEncryption()
    
    // ===== Session State =====
    
    /** Check if E2EE session is unlocked (master key available in memory) */
    fun isSessionUnlocked(): Boolean
    
    /** Get master key for encryption operations (throws if locked) */
    fun getMasterKey(): ByteArray
    
    /** Lock the session (clear master key from memory) */
    fun lockSession()
    
    /** Reset encryption - deletes all key shares and local data. THIS IS DESTRUCTIVE! */
    suspend fun resetEncryption(confirmPhrase: String)
}
