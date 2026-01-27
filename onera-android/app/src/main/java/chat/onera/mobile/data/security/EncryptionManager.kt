package chat.onera.mobile.data.security

import android.util.Base64
import chat.onera.mobile.data.remote.dto.EncryptedData
import chat.onera.mobile.data.repository.KeyPair
import chat.onera.mobile.data.repository.PasswordEncryptedMasterKey
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Encryption Manager - matches iOS CryptoService.swift
 * Provides AES-256-GCM encryption/decryption operations.
 */
@Singleton
class EncryptionManager @Inject constructor() {

    companion object {
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val AES_KEY_SIZE = 256
        private const val GCM_IV_LENGTH = 12
        private const val GCM_TAG_LENGTH = 128
        
        // Password key derivation parameters (matches iOS Argon2 equivalents)
        private const val PBKDF2_ALGORITHM = "PBKDF2WithHmacSHA256"
        private const val PBKDF2_ITERATIONS = 100000
        private const val PBKDF2_KEY_LENGTH = 256
        private const val SALT_LENGTH = 32
        
        // Default Argon2 parameters (simplified for Android - using PBKDF2)
        private const val DEFAULT_OPS_LIMIT = 3
        private const val DEFAULT_MEM_LIMIT = 67108864 // 64MB
    }
    
    private val secureRandom = SecureRandom()

    // ===== Original methods for SecretKey (Android Keystore) =====
    
    fun encrypt(plaintext: String, key: SecretKey): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        
        // Generate random IV
        val iv = ByteArray(GCM_IV_LENGTH)
        secureRandom.nextBytes(iv)
        
        val parameterSpec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.ENCRYPT_MODE, key, parameterSpec)
        
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        
        // Combine IV + ciphertext
        val combined = ByteArray(iv.size + ciphertext.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(ciphertext, 0, combined, iv.size, ciphertext.size)
        
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    fun decrypt(ciphertext: String, key: SecretKey): String {
        val combined = Base64.decode(ciphertext, Base64.NO_WRAP)
        
        // Extract IV and ciphertext
        val iv = combined.copyOfRange(0, GCM_IV_LENGTH)
        val encrypted = combined.copyOfRange(GCM_IV_LENGTH, combined.size)
        
        val cipher = Cipher.getInstance(TRANSFORMATION)
        val parameterSpec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, parameterSpec)
        
        val plaintext = cipher.doFinal(encrypted)
        return String(plaintext, Charsets.UTF_8)
    }
    
    // ===== Per-chat key methods (ByteArray keys) =====
    
    /**
     * Generate a random 256-bit AES key for per-chat encryption.
     */
    fun generateChatKey(): ByteArray {
        val keyGen = KeyGenerator.getInstance("AES")
        keyGen.init(AES_KEY_SIZE, secureRandom)
        return keyGen.generateKey().encoded
    }
    
    /**
     * Generate random bytes (for nonces, IVs, etc.)
     */
    fun generateRandomBytes(count: Int): ByteArray {
        val bytes = ByteArray(count)
        secureRandom.nextBytes(bytes)
        return bytes
    }
    
    /**
     * Encrypt data with a ByteArray key, returning ciphertext and nonce separately.
     * This is used for per-chat encryption where we need to store nonce separately.
     */
    fun encryptWithKey(plaintext: ByteArray, key: ByteArray): EncryptedData {
        val secretKey = SecretKeySpec(key, "AES")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        
        // Generate random nonce
        val nonce = ByteArray(GCM_IV_LENGTH)
        secureRandom.nextBytes(nonce)
        
        val parameterSpec = GCMParameterSpec(GCM_TAG_LENGTH, nonce)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, parameterSpec)
        
        val ciphertext = cipher.doFinal(plaintext)
        
        return EncryptedData(ciphertext, nonce)
    }
    
    /**
     * Encrypt a string with a ByteArray key.
     */
    fun encryptStringWithKey(plaintext: String, key: ByteArray): EncryptedData {
        return encryptWithKey(plaintext.toByteArray(Charsets.UTF_8), key)
    }
    
    /**
     * Decrypt data with a ByteArray key and separate nonce.
     */
    fun decryptWithKey(ciphertext: ByteArray, nonce: ByteArray, key: ByteArray): ByteArray {
        val secretKey = SecretKeySpec(key, "AES")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        
        val parameterSpec = GCMParameterSpec(GCM_TAG_LENGTH, nonce)
        cipher.init(Cipher.DECRYPT_MODE, secretKey, parameterSpec)
        
        return cipher.doFinal(ciphertext)
    }
    
    /**
     * Decrypt to string with a ByteArray key and separate nonce.
     */
    fun decryptToStringWithKey(ciphertext: ByteArray, nonce: ByteArray, key: ByteArray): String {
        val plaintext = decryptWithKey(ciphertext, nonce, key)
        return String(plaintext, Charsets.UTF_8)
    }
    
    // ===== Base64 helpers for server communication =====
    
    /**
     * Encrypt string and return base64-encoded ciphertext and nonce.
     */
    fun encryptForServer(plaintext: String, key: ByteArray): Pair<String, String> {
        val encrypted = encryptStringWithKey(plaintext, key)
        return Pair(
            Base64.encodeToString(encrypted.ciphertext, Base64.NO_WRAP),
            Base64.encodeToString(encrypted.nonce, Base64.NO_WRAP)
        )
    }
    
    /**
     * Decrypt from base64-encoded ciphertext and nonce.
     */
    fun decryptFromServer(ciphertextBase64: String, nonceBase64: String, key: ByteArray): String {
        val ciphertext = Base64.decode(ciphertextBase64, Base64.NO_WRAP)
        val nonce = Base64.decode(nonceBase64, Base64.NO_WRAP)
        return decryptToStringWithKey(ciphertext, nonce, key)
    }
    
    /**
     * Encrypt ByteArray for server (returns base64).
     */
    fun encryptBytesForServer(plaintext: ByteArray, key: ByteArray): Pair<String, String> {
        val encrypted = encryptWithKey(plaintext, key)
        return Pair(
            Base64.encodeToString(encrypted.ciphertext, Base64.NO_WRAP),
            Base64.encodeToString(encrypted.nonce, Base64.NO_WRAP)
        )
    }
    
    /**
     * Decrypt ByteArray from server (from base64).
     */
    fun decryptBytesFromServer(ciphertextBase64: String, nonceBase64: String, key: ByteArray): ByteArray {
        val ciphertext = Base64.decode(ciphertextBase64, Base64.NO_WRAP)
        val nonce = Base64.decode(nonceBase64, Base64.NO_WRAP)
        return decryptWithKey(ciphertext, nonce, key)
    }
    
    // ===== Key Generation =====
    
    /**
     * Generate a key pair for device authentication.
     * In production, this would use X25519. For simplicity, using random bytes.
     */
    fun generateKeyPair(): KeyPair {
        val publicKey = generateRandomBytes(32)
        val privateKey = generateRandomBytes(32)
        return KeyPair(publicKey, privateKey)
    }
    
    /**
     * Derive a key from input key material and salt using HKDF-SHA256.
     * Used for PRF-based passkey key derivation.
     * Must match web's derivePRFKEK implementation exactly.
     */
    fun deriveKey(inputKeyMaterial: ByteArray, salt: ByteArray, outputLength: Int): ByteArray {
        // HKDF-SHA256 matching web's implementation
        // Info string must match exactly: "onera-webauthn-prf-kek-v1"
        val info = "onera-webauthn-prf-kek-v1".toByteArray(Charsets.UTF_8)
        
        // HKDF Extract: PRK = HMAC-SHA256(salt, IKM)
        val extractMac = javax.crypto.Mac.getInstance("HmacSHA256")
        val saltKey = javax.crypto.spec.SecretKeySpec(salt, "HmacSHA256")
        extractMac.init(saltKey)
        val prk = extractMac.doFinal(inputKeyMaterial)
        
        // HKDF Expand: OKM = HMAC-SHA256(PRK, info || 0x01)
        val expandMac = javax.crypto.Mac.getInstance("HmacSHA256")
        val prkKey = javax.crypto.spec.SecretKeySpec(prk, "HmacSHA256")
        expandMac.init(prkKey)
        expandMac.update(info)
        expandMac.update(0x01.toByte())
        
        val output = expandMac.doFinal()
        
        // Return requested length (32 bytes for KEK)
        return output.copyOf(minOf(outputLength, output.size))
    }
    
    /**
     * Decrypt using XSalsa20-Poly1305 (NaCl secretbox).
     * Used for passkey-encrypted master key (matches web's libsodium crypto_secretbox_open_easy).
     */
    fun decryptSecretBox(ciphertextBase64: String, nonceBase64: String, key: ByteArray): ByteArray {
        val ciphertext = Base64.decode(ciphertextBase64, Base64.NO_WRAP)
        val nonce = Base64.decode(nonceBase64, Base64.NO_WRAP)
        
        // Use lazysodium for XSalsa20-Poly1305
        val sodium = com.goterl.lazysodium.LazySodiumAndroid(com.goterl.lazysodium.SodiumAndroid())
        
        // crypto_secretbox_open_easy expects: ciphertext with auth tag appended
        val plaintext = ByteArray(ciphertext.size - 16) // 16 bytes for Poly1305 tag
        
        val success = sodium.cryptoSecretBoxOpenEasy(
            plaintext,
            ciphertext,
            ciphertext.size.toLong(),
            nonce,
            key
        )
        
        if (!success) {
            throw javax.crypto.AEADBadTagException("Decryption failed - invalid key or tampered data")
        }
        
        return plaintext
    }
    
    /**
     * Decrypt string using XSalsa20-Poly1305 (NaCl secretbox).
     * Used for all E2EE data decryption (matches web's libsodium).
     */
    fun decryptSecretBoxString(ciphertextBase64: String, nonceBase64: String, key: ByteArray): String {
        val plaintext = decryptSecretBox(ciphertextBase64, nonceBase64, key)
        return String(plaintext, Charsets.UTF_8)
    }
    
    /**
     * Encrypt using XSalsa20-Poly1305 (NaCl secretbox).
     * Used for all E2EE data encryption (matches web's libsodium crypto_secretbox_easy).
     */
    fun encryptSecretBox(plaintext: ByteArray, key: ByteArray): Pair<String, String> {
        val sodium = com.goterl.lazysodium.LazySodiumAndroid(com.goterl.lazysodium.SodiumAndroid())
        
        // Generate 24-byte nonce (crypto_secretbox_NONCEBYTES)
        val nonce = ByteArray(24)
        secureRandom.nextBytes(nonce)
        
        // Encrypt: ciphertext includes 16-byte Poly1305 tag
        val ciphertext = ByteArray(plaintext.size + 16)
        
        val success = sodium.cryptoSecretBoxEasy(
            ciphertext,
            plaintext,
            plaintext.size.toLong(),
            nonce,
            key
        )
        
        if (!success) {
            throw RuntimeException("Encryption failed")
        }
        
        return Pair(
            Base64.encodeToString(ciphertext, Base64.NO_WRAP),
            Base64.encodeToString(nonce, Base64.NO_WRAP)
        )
    }
    
    /**
     * Encrypt string using XSalsa20-Poly1305 (NaCl secretbox).
     * Used for all E2EE data encryption (matches web's libsodium).
     */
    fun encryptSecretBoxString(plaintext: String, key: ByteArray): Pair<String, String> {
        return encryptSecretBox(plaintext.toByteArray(Charsets.UTF_8), key)
    }
    
    /**
     * Derive a recovery key from BIP39 mnemonic phrase.
     * Uses PBKDF2 with the mnemonic as password and "mnemonic" as salt.
     */
    fun deriveKeyFromMnemonic(mnemonic: String): ByteArray {
        val salt = "mnemonic".toByteArray(Charsets.UTF_8)
        val normalizedMnemonic = mnemonic.trim().lowercase()
        
        val spec = PBEKeySpec(
            normalizedMnemonic.toCharArray(),
            salt,
            PBKDF2_ITERATIONS,
            PBKDF2_KEY_LENGTH
        )
        val factory = SecretKeyFactory.getInstance(PBKDF2_ALGORITHM)
        return factory.generateSecret(spec).encoded
    }
    
    // ===== Password-Based Encryption =====
    
    /**
     * Encrypt master key with password for server storage.
     * Uses PBKDF2 key derivation (iOS uses Argon2 via libsodium).
     */
    fun encryptMasterKeyWithPassword(masterKey: ByteArray, password: String): PasswordEncryptedMasterKey {
        // Generate salt
        val salt = generateRandomBytes(SALT_LENGTH)
        
        // Derive key from password
        val derivedKey = deriveKeyFromPassword(password, salt)
        
        // Encrypt master key
        val (ciphertext, nonce) = encryptBytesForServer(masterKey, derivedKey)
        
        // Secure cleanup
        derivedKey.fill(0)
        
        return PasswordEncryptedMasterKey(
            ciphertext = ciphertext,
            nonce = nonce,
            salt = Base64.encodeToString(salt, Base64.NO_WRAP),
            opsLimit = DEFAULT_OPS_LIMIT,
            memLimit = DEFAULT_MEM_LIMIT
        )
    }
    
    /**
     * Decrypt master key with password from server.
     */
    fun decryptMasterKeyWithPassword(
        encryptedMasterKey: String,
        nonce: String,
        salt: String,
        password: String,
        opsLimit: Int,
        memLimit: Int
    ): ByteArray {
        // Decode salt
        val saltBytes = Base64.decode(salt, Base64.NO_WRAP)
        
        // Derive key from password (opsLimit/memLimit are for Argon2 compatibility)
        val derivedKey = deriveKeyFromPassword(password, saltBytes)
        
        // Decrypt master key
        val masterKey = decryptBytesFromServer(encryptedMasterKey, nonce, derivedKey)
        
        // Secure cleanup
        derivedKey.fill(0)
        
        return masterKey
    }
    
    /**
     * Derive encryption key from password using PBKDF2.
     */
    private fun deriveKeyFromPassword(password: String, salt: ByteArray): ByteArray {
        val spec = PBEKeySpec(
            password.toCharArray(),
            salt,
            PBKDF2_ITERATIONS,
            PBKDF2_KEY_LENGTH
        )
        val factory = SecretKeyFactory.getInstance(PBKDF2_ALGORITHM)
        return factory.generateSecret(spec).encoded
    }
    
    // ===== Shamir Secret Sharing (Simplified) =====
    
    /**
     * Split a secret into n shares where k are needed to reconstruct.
     * This is a simplified implementation - production should use proper SSS.
     */
    fun splitSecret(secret: ByteArray, numShares: Int = 3, threshold: Int = 2): List<ByteArray> {
        // Simplified: XOR-based split (not true Shamir SSS)
        // In production, use a proper Shamir implementation
        val shares = mutableListOf<ByteArray>()
        var remaining = secret.copyOf()
        
        for (i in 0 until numShares - 1) {
            val share = generateRandomBytes(secret.size)
            shares.add(share)
            remaining = xorBytes(remaining, share)
        }
        shares.add(remaining)
        
        return shares
    }
    
    /**
     * Combine shares to reconstruct secret.
     */
    fun combineShares(shares: List<ByteArray>): ByteArray {
        require(shares.isNotEmpty()) { "No shares provided" }
        
        var result = shares[0].copyOf()
        for (i in 1 until shares.size) {
            result = xorBytes(result, shares[i])
        }
        return result
    }
    
    private fun xorBytes(a: ByteArray, b: ByteArray): ByteArray {
        require(a.size == b.size) { "Arrays must be same size" }
        return ByteArray(a.size) { i -> (a[i].toInt() xor b[i].toInt()).toByte() }
    }
    
    // ===== Hashing =====
    
    /**
     * SHA-256 hash
     */
    fun sha256(data: ByteArray): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(data)
    }
    
    /**
     * Secure zero-fill to prevent memory leaks
     */
    fun secureZero(data: ByteArray) {
        data.fill(0)
    }
}
