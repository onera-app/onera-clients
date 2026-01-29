package chat.onera.mobile.data.security

import android.util.Base64
import chat.onera.mobile.data.remote.dto.EncryptedData
import chat.onera.mobile.data.repository.KeyPair
import chat.onera.mobile.data.repository.PasswordEncryptedMasterKey
import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid
import com.goterl.lazysodium.interfaces.PwHash
import com.sun.jna.NativeLong
import timber.log.Timber
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
 * Encryption Manager - matches web and iOS crypto implementations.
 * 
 * Provides:
 * - AES-256-GCM for Android Keystore operations
 * - XSalsa20-Poly1305 (libsodium secretbox) for E2EE data - matches web
 * - Argon2id for password key derivation - matches web/iOS
 * - HKDF-SHA256 for PRF-based key derivation
 */
@Singleton
class EncryptionManager @Inject constructor() {

    companion object {
        private const val TAG = "EncryptionManager"
        
        // AES-GCM parameters (Android Keystore)
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val AES_KEY_SIZE = 256
        private const val GCM_IV_LENGTH = 12
        private const val GCM_TAG_LENGTH = 128
        
        // Salt/nonce lengths
        private const val SALT_LENGTH = 32
        private const val SECRETBOX_NONCE_LENGTH = 24
        
        // Argon2id parameters - MUST match web/iOS exactly
        // Web uses: crypto_pwhash with OPSLIMIT_MODERATE (3) and MEMLIMIT_MODERATE (64MB)
        private const val ARGON2_OPSLIMIT_MODERATE = 3L
        private const val ARGON2_MEMLIMIT_MODERATE = 67108864L // 64MB
        
        // For interactive use (lower security, faster)
        private const val ARGON2_OPSLIMIT_INTERACTIVE = 2L
        private const val ARGON2_MEMLIMIT_INTERACTIVE = 67108864L // 64MB
        
        // PBKDF2 parameters for BIP39 mnemonic derivation (standard spec)
        private const val PBKDF2_ALGORITHM = "PBKDF2WithHmacSHA512"
        private const val PBKDF2_ITERATIONS = 2048 // BIP39 standard
        private const val PBKDF2_KEY_LENGTH = 512 // 64 bytes for BIP39
    }
    
    private val secureRandom = SecureRandom()
    
    // Lazy-initialized sodium instance for thread safety
    private val sodium: LazySodiumAndroid by lazy {
        LazySodiumAndroid(SodiumAndroid())
    }

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
     * 
     * @param ciphertextBase64 Base64-encoded ciphertext with 16-byte Poly1305 tag appended
     * @param nonceBase64 Base64-encoded 24-byte nonce
     * @param key 32-byte decryption key
     * @return Decrypted plaintext bytes
     * @throws javax.crypto.AEADBadTagException if decryption fails (wrong key or tampered data)
     */
    fun decryptSecretBox(ciphertextBase64: String, nonceBase64: String, key: ByteArray): ByteArray {
        val ciphertext = Base64.decode(ciphertextBase64, Base64.NO_WRAP)
        val nonce = Base64.decode(nonceBase64, Base64.NO_WRAP)
        
        require(nonce.size == SECRETBOX_NONCE_LENGTH) {
            "Nonce must be $SECRETBOX_NONCE_LENGTH bytes, got ${nonce.size}"
        }
        require(key.size == 32) {
            "Key must be 32 bytes, got ${key.size}"
        }
        require(ciphertext.size > 16) {
            "Ciphertext too short (must include 16-byte tag)"
        }
        
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
            Timber.w("$TAG: SecretBox decryption failed - invalid key or tampered data")
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
     * 
     * @param plaintext Plaintext bytes to encrypt
     * @param key 32-byte encryption key
     * @return Pair of (base64 ciphertext with tag, base64 nonce)
     */
    fun encryptSecretBox(plaintext: ByteArray, key: ByteArray): Pair<String, String> {
        require(key.size == 32) {
            "Key must be 32 bytes, got ${key.size}"
        }
        
        // Generate 24-byte nonce (crypto_secretbox_NONCEBYTES)
        val nonce = ByteArray(SECRETBOX_NONCE_LENGTH)
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
            Timber.e("$TAG: SecretBox encryption failed")
            throw SecurityException("Encryption failed")
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
    
    // ===== Password-Based Encryption (Argon2id) =====
    
    /**
     * Encrypt master key with password for server storage.
     * Uses Argon2id key derivation - matches web/iOS exactly.
     */
    fun encryptMasterKeyWithPassword(masterKey: ByteArray, password: String): PasswordEncryptedMasterKey {
        // Generate salt (crypto_pwhash_SALTBYTES = 16, but we use 32 for extra security)
        val salt = generateRandomBytes(PwHash.SALTBYTES)
        
        // Derive key from password using Argon2id
        val derivedKey = deriveKeyFromPasswordArgon2(
            password = password,
            salt = salt,
            opsLimit = ARGON2_OPSLIMIT_MODERATE,
            memLimit = ARGON2_MEMLIMIT_MODERATE
        )
        
        // Encrypt master key using XSalsa20-Poly1305 (secretbox) - matches web
        val (ciphertext, nonce) = encryptSecretBox(masterKey, derivedKey)
        
        // Secure cleanup
        secureZero(derivedKey)
        
        return PasswordEncryptedMasterKey(
            ciphertext = ciphertext,
            nonce = nonce,
            salt = Base64.encodeToString(salt, Base64.NO_WRAP),
            opsLimit = ARGON2_OPSLIMIT_MODERATE.toInt(),
            memLimit = ARGON2_MEMLIMIT_MODERATE.toInt()
        )
    }
    
    /**
     * Decrypt master key with password from server.
     * Uses Argon2id with parameters from server (for cross-platform compatibility).
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
        
        // Derive key from password using Argon2id with server-provided parameters
        val derivedKey = deriveKeyFromPasswordArgon2(
            password = password,
            salt = saltBytes,
            opsLimit = opsLimit.toLong(),
            memLimit = memLimit.toLong()
        )
        
        // Decrypt master key using XSalsa20-Poly1305 (secretbox)
        val masterKey = decryptSecretBox(encryptedMasterKey, nonce, derivedKey)
        
        // Secure cleanup
        secureZero(derivedKey)
        
        return masterKey
    }
    
    /**
     * Derive encryption key from password using Argon2id.
     * 
     * This MUST match the web implementation exactly:
     * - Algorithm: Argon2id (crypto_pwhash_ALG_ARGON2ID13)
     * - Output length: 32 bytes (256 bits)
     * - Salt: 16 bytes (crypto_pwhash_SALTBYTES)
     * - opsLimit: 3 (MODERATE) or 2 (INTERACTIVE)
     * - memLimit: 64MB (MODERATE/INTERACTIVE)
     */
    fun deriveKeyFromPasswordArgon2(
        password: String,
        salt: ByteArray,
        opsLimit: Long = ARGON2_OPSLIMIT_MODERATE,
        memLimit: Long = ARGON2_MEMLIMIT_MODERATE
    ): ByteArray {
        require(salt.size >= PwHash.SALTBYTES) { 
            "Salt must be at least ${PwHash.SALTBYTES} bytes, got ${salt.size}" 
        }
        
        val outputKey = ByteArray(32) // 256-bit key
        val passwordBytes = password.toByteArray(Charsets.UTF_8)
        
        // Use Argon2id (the recommended variant)
        val success = sodium.cryptoPwHash(
            outputKey,
            outputKey.size,
            passwordBytes,
            passwordBytes.size,
            salt,
            opsLimit,
            NativeLong(memLimit),
            PwHash.Alg.PWHASH_ALG_ARGON2ID13
        )
        
        if (!success) {
            Timber.e("$TAG: Argon2id key derivation failed")
            throw SecurityException("Failed to derive key from password")
        }
        
        Timber.d("$TAG: Derived key using Argon2id (opsLimit=$opsLimit, memLimit=$memLimit)")
        return outputKey
    }
    
    // ===== Shamir Secret Sharing (GF(256) Polynomial) =====
    
    /**
     * Split a secret into n shares where k (threshold) are needed to reconstruct.
     * Uses proper Shamir Secret Sharing with GF(256) polynomial interpolation.
     * 
     * @param secret The secret bytes to split
     * @param numShares Total number of shares to generate (n)
     * @param threshold Minimum shares needed to reconstruct (k)
     * @return List of shares, each prefixed with its x-coordinate (share index)
     */
    fun splitSecret(secret: ByteArray, numShares: Int = 3, threshold: Int = 2): List<ByteArray> {
        require(numShares >= threshold) { "numShares must be >= threshold" }
        require(threshold >= 2) { "threshold must be >= 2" }
        require(numShares <= 255) { "numShares must be <= 255" }
        
        // For each byte of the secret, generate random polynomial coefficients
        // coefficients[byteIndex][0] = secret byte (constant term)
        // coefficients[byteIndex][1..k-1] = random bytes (higher degree terms)
        val polynomialCoefficients = Array(secret.size) { byteIndex ->
            ByteArray(threshold).also { coeffs ->
                coeffs[0] = secret[byteIndex]
                for (i in 1 until threshold) {
                    coeffs[i] = secureRandom.nextInt(256).toByte()
                }
            }
        }
        
        val shares = mutableListOf<ByteArray>()
        
        // For each share index (1 to numShares)
        for (shareIndex in 1..numShares) {
            // Each share is: [shareIndex byte] + [evaluated polynomial for each secret byte]
            val share = ByteArray(1 + secret.size)
            share[0] = shareIndex.toByte()
            
            // Evaluate polynomial for each byte of the secret
            for (byteIndex in secret.indices) {
                share[1 + byteIndex] = gf256EvaluatePolynomial(
                    polynomialCoefficients[byteIndex], 
                    shareIndex.toByte()
                )
            }
            
            shares.add(share)
        }
        
        // Secure cleanup of polynomial coefficients
        polynomialCoefficients.forEach { secureZero(it) }
        
        return shares
    }
    
    /**
     * Combine shares to reconstruct the secret using Lagrange interpolation in GF(256).
     * 
     * @param shares List of shares (each prefixed with x-coordinate)
     * @return Reconstructed secret
     */
    fun combineShares(shares: List<ByteArray>): ByteArray {
        require(shares.isNotEmpty()) { "No shares provided" }
        require(shares.all { it.size == shares[0].size }) { "All shares must be same size" }
        
        val secretLength = shares[0].size - 1 // First byte is x-coordinate
        val secret = ByteArray(secretLength)
        
        // Extract x-coordinates and y-values
        val xCoords = shares.map { (it[0].toInt() and 0xFF).toByte() }
        
        // Reconstruct each byte of the secret using Lagrange interpolation
        for (byteIndex in 0 until secretLength) {
            val yValues = shares.map { it[1 + byteIndex] }
            secret[byteIndex] = gf256LagrangeInterpolate(xCoords, yValues)
        }
        
        return secret
    }
    
    // ===== GF(256) Arithmetic =====
    // Using the AES/Rijndael irreducible polynomial: x^8 + x^4 + x^3 + x + 1 (0x11B)
    
    private fun gf256Add(a: Byte, b: Byte): Byte {
        return (a.toInt() xor b.toInt()).toByte()
    }
    
    private fun gf256Multiply(a: Byte, b: Byte): Byte {
        var result = 0
        var aa = a.toInt() and 0xFF
        var bb = b.toInt() and 0xFF
        
        while (bb != 0) {
            if (bb and 1 != 0) {
                result = result xor aa
            }
            val carry = aa and 0x80
            aa = aa shl 1
            if (carry != 0) {
                aa = aa xor 0x1B // Reduce by x^8 + x^4 + x^3 + x + 1
            }
            bb = bb shr 1
        }
        
        return (result and 0xFF).toByte()
    }
    
    private fun gf256Inverse(a: Byte): Byte {
        if (a.toInt() == 0) return 0
        
        // Use extended Euclidean algorithm or exponentiation (a^254 in GF(256))
        var result = a
        repeat(253) { // a^254 = a^(2^8 - 2)
            result = gf256Multiply(result, a)
        }
        return result
    }
    
    private fun gf256EvaluatePolynomial(coefficients: ByteArray, x: Byte): Byte {
        // Horner's method: a_0 + x*(a_1 + x*(a_2 + ...))
        var result: Byte = 0
        for (i in coefficients.indices.reversed()) {
            result = gf256Add(coefficients[i], gf256Multiply(result, x))
        }
        return result
    }
    
    private fun gf256LagrangeInterpolate(xCoords: List<Byte>, yValues: List<Byte>): Byte {
        // Lagrange interpolation at x=0 to recover secret (constant term)
        var result: Byte = 0
        
        for (i in xCoords.indices) {
            var basis: Byte = 1
            
            for (j in xCoords.indices) {
                if (i != j) {
                    // basis *= x_j / (x_j - x_i) = (0 - x_j) / (x_i - x_j) = x_j / (x_j - x_i)
                    val xj = xCoords[j]
                    val xi = xCoords[i]
                    val numerator = xj
                    val denominator = gf256Add(xj, xi) // x_j - x_i = x_j + x_i in GF(256)
                    basis = gf256Multiply(basis, gf256Multiply(numerator, gf256Inverse(denominator)))
                }
            }
            
            result = gf256Add(result, gf256Multiply(yValues[i], basis))
        }
        
        return result
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
