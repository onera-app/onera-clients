package chat.onera.mobile.data.repository

import android.app.Activity
import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.KeySharesProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.data.security.KeyManager
import chat.onera.mobile.data.security.PasskeyManager
import chat.onera.mobile.domain.repository.E2EERepository
import javax.inject.Inject
import javax.inject.Singleton

/**
 * E2EE Repository implementation - matches iOS E2EEService.swift
 * Handles encryption key management with server synchronization.
 */
@Singleton
class E2EERepositoryImpl @Inject constructor(
    private val keyManager: KeyManager,
    private val encryptionManager: EncryptionManager,
    private val trpcClient: TRPCClient,
    private val passkeyManager: PasskeyManager
) : E2EERepository {
    
    companion object {
        private const val TAG = "E2EERepository"
    }
    
    // In-memory master key for the session (cleared on lock)
    @Volatile
    private var sessionMasterKey: ByteArray? = null
    
    @Volatile
    private var sessionPrivateKey: ByteArray? = null
    
    @Volatile
    private var sessionPublicKey: ByteArray? = null
    
    // ===== Setup Status =====
    
    override suspend fun hasEncryptionKeys(): Boolean {
        return keyManager.hasKeys()
    }
    
    override suspend fun checkSetupStatus(): Boolean {
        return try {
            val result = trpcClient.query<Unit, KeySharesCheckResponse>(
                KeySharesProcedures.CHECK,
                Unit
            )
            result.getOrNull()?.hasShares ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check setup status", e)
            // Fall back to local check
            keyManager.hasKeys()
        }
    }
    
    // ===== New User Setup =====
    
    override suspend fun setupNewUser(): String {
        Log.d(TAG, "Setting up new user with E2EE...")
        
        // 1. Generate master key
        val masterKey = encryptionManager.generateChatKey() // 32-byte key
        
        // 2. Generate key pair for device
        val keyPair = encryptionManager.generateKeyPair()
        
        // 3. Generate BIP39 mnemonic
        val mnemonic = keyManager.generateKeysWithMnemonic().joinToString(" ")
        
        // 4. Derive recovery key from mnemonic
        val recoveryKey = encryptionManager.deriveKeyFromMnemonic(mnemonic)
        
        // 5. Split master key into shares (simplified - iOS uses Shamir's Secret Sharing)
        val authShare = encryptionManager.generateRandomBytes(32)
        val deviceShare = encryptionManager.generateRandomBytes(32)
        val recoveryShare = encryptionManager.generateRandomBytes(32)
        
        // 6. Encrypt shares and keys
        val (encryptedRecoveryShare, recoveryShareNonce) = encryptionManager.encryptBytesForServer(
            recoveryShare, recoveryKey
        )
        
        val (encryptedPrivateKey, privateKeyNonce) = encryptionManager.encryptBytesForServer(
            keyPair.privateKey, masterKey
        )
        
        val (masterKeyRecovery, masterKeyRecoveryNonce) = encryptionManager.encryptBytesForServer(
            masterKey, recoveryKey
        )
        
        val (encryptedRecoveryKey, recoveryKeyNonce) = encryptionManager.encryptBytesForServer(
            recoveryKey, masterKey
        )
        
        // 7. Send to server
        val request = KeySharesCreateRequest(
            authShare = android.util.Base64.encodeToString(authShare, android.util.Base64.NO_WRAP),
            encryptedRecoveryShare = encryptedRecoveryShare,
            recoveryShareNonce = recoveryShareNonce,
            publicKey = android.util.Base64.encodeToString(keyPair.publicKey, android.util.Base64.NO_WRAP),
            encryptedPrivateKey = encryptedPrivateKey,
            privateKeyNonce = privateKeyNonce,
            masterKeyRecovery = masterKeyRecovery,
            masterKeyRecoveryNonce = masterKeyRecoveryNonce,
            encryptedRecoveryKey = encryptedRecoveryKey,
            recoveryKeyNonce = recoveryKeyNonce
        )
        
        val result = trpcClient.mutation<KeySharesCreateRequest, KeySharesCreateResponse>(
            KeySharesProcedures.CREATE,
            request
        )
        
        result.onSuccess {
            Log.d(TAG, "Key shares created on server")
            
            // 8. Store locally and unlock session
            keyManager.finalizeSetup()
            unlockSession(masterKey, keyPair.privateKey, keyPair.publicKey)
        }.onFailure { e ->
            Log.e(TAG, "Failed to create key shares on server", e)
            throw e
        }
        
        return mnemonic
    }
    
    override suspend fun generateKeys(): List<String> {
        return keyManager.generateKeysWithMnemonic()
    }
    
    override suspend fun finalizeKeySetup() {
        keyManager.finalizeSetup()
    }
    
    // ===== Encryption/Decryption =====
    
    override suspend fun encryptMessage(plaintext: String): String {
        val key = keyManager.getEncryptionKey()
        return encryptionManager.encrypt(plaintext, key)
    }
    
    override suspend fun decryptMessage(ciphertext: String): String {
        val key = keyManager.getEncryptionKey()
        return encryptionManager.decrypt(ciphertext, key)
    }
    
    // ===== Recovery =====
    
    override suspend fun exportRecoveryPhrase(): List<String> {
        return keyManager.getRecoveryPhrase()
    }
    
    override suspend fun restoreFromRecoveryPhrase(phrase: List<String>) {
        keyManager.restoreFromMnemonic(phrase)
    }
    
    override suspend fun unlockWithRecoveryPhrase(phrase: String) {
        Log.d(TAG, "Unlocking with recovery phrase...")
        
        // 1. Derive recovery key from mnemonic
        val recoveryKey = encryptionManager.deriveKeyFromMnemonic(phrase)
        
        // 2. Get key shares from server
        val result = trpcClient.query<Unit, KeySharesGetResponse>(
            KeySharesProcedures.GET,
            Unit
        )
        
        val keyShares = result.getOrThrow()
        
        // 3. Decrypt master key using recovery key (XSalsa20-Poly1305)
        val masterKey = encryptionManager.decryptSecretBox(
            keyShares.masterKeyRecovery,
            keyShares.masterKeyRecoveryNonce,
            recoveryKey
        )
        
        // 4. Decrypt private key (XSalsa20-Poly1305)
        val privateKey = encryptionManager.decryptSecretBox(
            keyShares.encryptedPrivateKey,
            keyShares.privateKeyNonce,
            masterKey
        )
        
        // 5. Decode public key
        val publicKey = android.util.Base64.decode(keyShares.publicKey, android.util.Base64.NO_WRAP)
        
        // 6. Restore local keys and unlock session
        val words = phrase.trim().split("\\s+".toRegex())
        keyManager.restoreFromMnemonic(words)
        unlockSession(masterKey, privateKey, publicKey)
        
        Log.d(TAG, "Unlocked with recovery phrase successfully")
    }
    
    // ===== Key Management =====
    
    override suspend fun rotateKeys() {
        keyManager.rotateKeys()
    }
    
    override suspend fun clearKeys() {
        lockSession()
        keyManager.clearAllKeys()
    }
    
    // ===== Unlock Methods =====
    
    override suspend fun hasLocalPasskey(): Boolean {
        return passkeyManager.hasLocalPasskeyKEK()
    }
    
    override suspend fun hasServerPasskeys(): Boolean {
        return try {
            passkeyManager.hasPasskeys()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check server passkeys", e)
            false
        }
    }
    
    override suspend fun hasPasswordEncryption(): Boolean {
        return try {
            val result = trpcClient.query<Unit, PasswordEncryptionCheckResponse>(
                KeySharesProcedures.HAS_PASSWORD,
                Unit
            )
            result.getOrNull()?.hasPassword ?: keyManager.hasPasswordEncryption()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check password encryption status", e)
            keyManager.hasPasswordEncryption()
        }
    }
    
    override suspend fun unlockWithPasskey() {
        Log.d(TAG, "Unlocking with passkey (legacy - local KEK only)...")
        
        // Legacy method - requires local KEK
        if (!passkeyManager.hasLocalPasskeyKEK()) {
            throw IllegalStateException("No local passkey KEK found. Use unlockWithPasskeyAuth() for synced passkeys.")
        }
        
        keyManager.unlockWithPasskey()
        
        // After passkey auth via BiometricManager, the session is unlocked
        // Load master key from local storage
        val masterKey = keyManager.getEncryptionKey().encoded
        unlockSession(masterKey, null, null)
    }
    
    override suspend fun unlockWithPasskeyAuth(activity: Activity) {
        Log.d(TAG, "Unlocking with passkey auth (PRF/KEK)...")
        
        // This method uses PasskeyManager.authenticateWithPasskey() which:
        // 1. Shows the passkey selector via CredentialManager
        // 2. Uses PRF extension if available (for synced passkeys from web)
        // 3. Falls back to local KEK if PRF not available
        // 4. Decrypts and returns the master key
        
        val masterKey = passkeyManager.authenticateWithPasskey(activity)
        
        // Get key shares from server for private/public keys
        val keySharesResult = trpcClient.query<Unit, KeySharesGetResponse>(
            KeySharesProcedures.GET,
            Unit
        )
        
        keySharesResult.onSuccess { keyShares ->
            val publicKey = android.util.Base64.decode(keyShares.publicKey, android.util.Base64.NO_WRAP)
            
            // Decrypt private key with master key using XSalsa20-Poly1305 (libsodium secretbox)
            // The web encrypts ALL keys using libsodium's crypto_secretbox
            val privateKey = encryptionManager.decryptSecretBox(
                keyShares.encryptedPrivateKey,
                keyShares.privateKeyNonce,
                masterKey
            )
            
            // Unlock session
            unlockSession(masterKey, privateKey, publicKey)
            
            // Also save master key locally for future use
            keyManager.saveMasterKey(masterKey)
            
            Log.d(TAG, "Unlocked with passkey auth successfully")
        }.onFailure { e ->
            // Clean up master key on failure
            masterKey.fill(0)
            Log.e(TAG, "Failed to get key shares after passkey auth", e)
            throw e
        }
    }
    
    override suspend fun registerPasskey(name: String?, activity: Activity): String {
        Log.d(TAG, "Registering passkey...")
        
        // Must be unlocked to register passkey
        val masterKey = getMasterKey()
        
        return passkeyManager.registerPasskey(masterKey, name, activity)
    }
    
    override suspend fun unlockWithPassword(password: String) {
        Log.d(TAG, "Unlocking with password...")
        
        // 1. Fetch encrypted master key from server
        val result = trpcClient.query<Unit, PasswordEncryptionGetResponse>(
            KeySharesProcedures.GET_PASSWORD,
            Unit
        )
        
        val encryptedData = result.getOrThrow()
        
        // 2. Decrypt master key with password (using Argon2/PBKDF2)
        val masterKey = encryptionManager.decryptMasterKeyWithPassword(
            encryptedMasterKey = encryptedData.encryptedMasterKey,
            nonce = encryptedData.nonce,
            salt = encryptedData.salt,
            password = password,
            opsLimit = encryptedData.opsLimit,
            memLimit = encryptedData.memLimit
        )
        
        // 3. Get key shares to get private/public keys
        val keySharesResult = trpcClient.query<Unit, KeySharesGetResponse>(
            KeySharesProcedures.GET,
            Unit
        )
        
        val keyShares = keySharesResult.getOrThrow()
        
        // 4. Decrypt private key (XSalsa20-Poly1305)
        val privateKey = encryptionManager.decryptSecretBox(
            keyShares.encryptedPrivateKey,
            keyShares.privateKeyNonce,
            masterKey
        )
        
        val publicKey = android.util.Base64.decode(keyShares.publicKey, android.util.Base64.NO_WRAP)
        
        // 5. Unlock session
        unlockSession(masterKey, privateKey, publicKey)
        
        // 6. Verify local password as well
        keyManager.unlockWithPassword(password)
        
        Log.d(TAG, "Unlocked with password successfully")
    }
    
    // ===== Password Encryption =====
    
    override suspend fun setupPasswordEncryption(password: String) {
        Log.d(TAG, "Setting up password encryption...")
        
        val masterKey = getMasterKey()
        
        // Encrypt master key with password
        val encrypted = encryptionManager.encryptMasterKeyWithPassword(masterKey, password)
        
        // Send to server
        val request = PasswordEncryptionSetRequest(
            encryptedMasterKey = encrypted.ciphertext,
            nonce = encrypted.nonce,
            salt = encrypted.salt,
            opsLimit = encrypted.opsLimit,
            memLimit = encrypted.memLimit
        )
        
        val result = trpcClient.mutation<PasswordEncryptionSetRequest, PasswordEncryptionSetResponse>(
            KeySharesProcedures.SET_PASSWORD,
            request
        )
        
        result.onSuccess {
            Log.d(TAG, "Password encryption set up on server")
            keyManager.setupPasswordEncryption(password)
        }.onFailure { e ->
            Log.e(TAG, "Failed to set up password encryption", e)
            throw e
        }
    }
    
    override suspend fun removePasswordEncryption() {
        Log.d(TAG, "Removing password encryption...")
        
        val result = trpcClient.mutation<Unit, PasswordEncryptionRemoveResponse>(
            KeySharesProcedures.REMOVE_PASSWORD,
            Unit
        )
        
        result.onSuccess {
            Log.d(TAG, "Password encryption removed from server")
        }.onFailure { e ->
            Log.e(TAG, "Failed to remove password encryption", e)
            throw e
        }
    }
    
    // ===== Session State =====
    
    override fun isSessionUnlocked(): Boolean {
        return sessionMasterKey != null
    }
    
    override fun getMasterKey(): ByteArray {
        return sessionMasterKey ?: throw IllegalStateException("E2EE session is locked")
    }
    
    override fun lockSession() {
        Log.d(TAG, "Locking E2EE session")
        sessionMasterKey?.fill(0)
        sessionMasterKey = null
        sessionPrivateKey?.fill(0)
        sessionPrivateKey = null
        sessionPublicKey = null
    }
    
    override suspend fun resetEncryption(confirmPhrase: String) {
        Log.d(TAG, "Resetting encryption...")
        
        if (confirmPhrase != "RESET MY ENCRYPTION") {
            throw IllegalArgumentException("Please type 'RESET MY ENCRYPTION' to confirm")
        }
        
        // 1. Call server to reset encryption
        val request = ResetEncryptionRequest(confirmPhrase = confirmPhrase)
        val result = trpcClient.mutation<ResetEncryptionRequest, ResetEncryptionResponse>(
            KeySharesProcedures.RESET_ENCRYPTION,
            request
        )
        
        result.onSuccess {
            Log.d(TAG, "Encryption reset on server")
            
            // 2. Clear local session
            lockSession()
            
            // 3. Clear local keys
            keyManager.clearAllKeys()
            
            // 4. Clear local passkey KEK
            passkeyManager.removeLocalPasskeyKEK()
            
            Log.d(TAG, "Local encryption data cleared")
        }.onFailure { e ->
            Log.e(TAG, "Failed to reset encryption", e)
            throw e
        }
    }
    
    // ===== Private Helpers =====
    
    private fun unlockSession(masterKey: ByteArray, privateKey: ByteArray?, publicKey: ByteArray?) {
        sessionMasterKey = masterKey.copyOf()
        sessionPrivateKey = privateKey?.copyOf()
        sessionPublicKey = publicKey?.copyOf()
        Log.d(TAG, "E2EE session unlocked")
    }
}

/**
 * Data class for encrypted password result
 */
data class PasswordEncryptedMasterKey(
    val ciphertext: String,
    val nonce: String,
    val salt: String,
    val opsLimit: Int,
    val memLimit: Int
)

/**
 * Data class for key pair
 */
data class KeyPair(
    val publicKey: ByteArray,
    val privateKey: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as KeyPair
        if (!publicKey.contentEquals(other.publicKey)) return false
        if (!privateKey.contentEquals(other.privateKey)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = publicKey.contentHashCode()
        result = 31 * result + privateKey.contentHashCode()
        return result
    }
}
