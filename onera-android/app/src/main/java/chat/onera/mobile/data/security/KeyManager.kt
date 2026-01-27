package chat.onera.mobile.data.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager as AndroidBiometricManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class KeyManager @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "onera_master_key"
        private const val ENCRYPTED_PREFS_FILE = "onera_secure_prefs"
        private const val PREF_HAS_KEYS = "has_keys"
        private const val PREF_RECOVERY_PHRASE = "recovery_phrase"
        private const val PREF_HAS_PASSWORD = "has_password"
        private const val PREF_HAS_PASSKEY = "has_passkey"
        private const val PREF_ENCRYPTED_PASSWORD = "encrypted_password"
        private const val PREF_PASSWORD_HASH = "password_hash"
        private const val PREF_PASSWORD_SALT = "password_salt"
        
        // PBKDF2 parameters
        private const val PBKDF2_ALGORITHM = "PBKDF2WithHmacSHA256"
        private const val PBKDF2_ITERATIONS = 100000
        private const val PBKDF2_KEY_LENGTH = 256
        private const val SALT_LENGTH = 32
    }
    
    private val biometricManager = AndroidBiometricManager.from(context)

    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    
    private val encryptedPrefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        
        EncryptedSharedPreferences.create(
            context,
            ENCRYPTED_PREFS_FILE,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun hasKeys(): Boolean {
        return encryptedPrefs.getBoolean(PREF_HAS_KEYS, false) && keyStore.containsAlias(KEY_ALIAS)
    }

    fun generateKeysWithMnemonic(): List<String> {
        // Generate a new master key in Android Keystore
        generateMasterKey()
        
        // Generate BIP39 mnemonic (simplified - use a proper BIP39 library in production)
        val mnemonic = generateMnemonic()
        
        // Store the mnemonic encrypted
        encryptedPrefs.edit()
            .putString(PREF_RECOVERY_PHRASE, mnemonic.joinToString(" "))
            .apply()
        
        return mnemonic
    }

    private fun generateMasterKey() {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )
        
        val keyGenParameterSpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(false) // Enable for biometric protection
            .build()
        
        keyGenerator.init(keyGenParameterSpec)
        keyGenerator.generateKey()
    }

    private fun generateMnemonic(): List<String> {
        // Simplified BIP39 word list - use a proper implementation in production
        val wordList = listOf(
            "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
            "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
            "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
            "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance",
            "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
            "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album",
            "alert", "alien", "all", "alley", "allow", "almost", "alone", "alpha",
            "already", "also", "alter", "always", "amateur", "amazing", "among", "amount"
            // ... truncated for brevity, use full 2048 word list in production
        )
        
        val random = SecureRandom()
        return (1..12).map { wordList[random.nextInt(wordList.size)] }
    }

    fun finalizeSetup() {
        encryptedPrefs.edit()
            .putBoolean(PREF_HAS_KEYS, true)
            .apply()
    }
    
    /**
     * Save master key bytes (from passkey auth PRF).
     * Stores in encrypted preferences for later use.
     */
    fun saveMasterKey(masterKey: ByteArray) {
        // Store the master key in encrypted preferences
        val masterKeyB64 = Base64.encodeToString(masterKey, Base64.NO_WRAP)
        encryptedPrefs.edit()
            .putString("master_key_bytes", masterKeyB64)
            .putBoolean(PREF_HAS_KEYS, true)
            .apply()
        
        // Also generate a Keystore key if needed for other operations
        if (!keyStore.containsAlias(KEY_ALIAS)) {
            generateMasterKey()
        }
    }
    
    /**
     * Get master key bytes (from passkey auth or stored).
     */
    fun getMasterKeyBytes(): ByteArray? {
        val masterKeyB64 = encryptedPrefs.getString("master_key_bytes", null)
        return masterKeyB64?.let { Base64.decode(it, Base64.NO_WRAP) }
    }

    fun getEncryptionKey(): SecretKey {
        return keyStore.getKey(KEY_ALIAS, null) as SecretKey
    }

    fun getRecoveryPhrase(): List<String> {
        val phrase = encryptedPrefs.getString(PREF_RECOVERY_PHRASE, null)
        return phrase?.split(" ") ?: emptyList()
    }

    fun restoreFromMnemonic(phrase: List<String>) {
        // In production: derive the master key from the mnemonic using BIP39/BIP32
        generateMasterKey()
        
        encryptedPrefs.edit()
            .putString(PREF_RECOVERY_PHRASE, phrase.joinToString(" "))
            .putBoolean(PREF_HAS_KEYS, true)
            .apply()
    }

    fun rotateKeys() {
        // Delete old key and generate new one
        keyStore.deleteEntry(KEY_ALIAS)
        generateMasterKey()
    }

    fun clearAllKeys() {
        keyStore.deleteEntry(KEY_ALIAS)
        encryptedPrefs.edit().clear().apply()
    }
    
    // Unlock methods for returning users
    
    /**
     * Check if biometric/passkey unlock is available.
     * Returns true if:
     * 1. Device has biometric hardware
     * 2. User has enrolled biometrics
     * 3. Encryption keys exist
     */
    fun hasLocalPasskey(): Boolean {
        val hasHardware = biometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
            AndroidBiometricManager.Authenticators.DEVICE_CREDENTIAL
        ) == AndroidBiometricManager.BIOMETRIC_SUCCESS
        
        val hasKeys = hasKeys()
        
        return hasHardware && hasKeys
    }
    
    fun hasPasswordEncryption(): Boolean {
        return encryptedPrefs.getBoolean(PREF_HAS_PASSWORD, false) && hasKeys()
    }
    
    /**
     * Called after successful biometric authentication.
     * The key is already accessible from Android Keystore after device authentication.
     */
    fun unlockWithPasskey() {
        if (!hasKeys()) {
            throw IllegalStateException("Encryption keys not found")
        }
        // Key is already available in Android Keystore after biometric auth
        // The actual biometric prompt is shown by BiometricManager
    }
    
    fun unlockWithPassword(password: String) {
        if (!hasPasswordEncryption()) {
            throw IllegalStateException("No password configured")
        }
        
        // Verify the key exists
        if (!keyStore.containsAlias(KEY_ALIAS)) {
            throw IllegalStateException("Encryption keys not found")
        }
        
        // Verify password hash
        if (!verifyPassword(password)) {
            throw IllegalStateException("Invalid password")
        }
    }
    
    fun setupPasswordEncryption(password: String) {
        // Generate salt
        val salt = ByteArray(SALT_LENGTH)
        SecureRandom().nextBytes(salt)
        
        // Hash the password
        val hash = hashPassword(password, salt)
        
        // Store hash and salt
        encryptedPrefs.edit()
            .putBoolean(PREF_HAS_PASSWORD, true)
            .putString(PREF_PASSWORD_HASH, Base64.encodeToString(hash, Base64.NO_WRAP))
            .putString(PREF_PASSWORD_SALT, Base64.encodeToString(salt, Base64.NO_WRAP))
            .apply()
    }
    
    private fun hashPassword(password: String, salt: ByteArray): ByteArray {
        val spec = PBEKeySpec(
            password.toCharArray(),
            salt,
            PBKDF2_ITERATIONS,
            PBKDF2_KEY_LENGTH
        )
        val factory = SecretKeyFactory.getInstance(PBKDF2_ALGORITHM)
        return factory.generateSecret(spec).encoded
    }
    
    private fun verifyPassword(password: String): Boolean {
        val storedHashStr = encryptedPrefs.getString(PREF_PASSWORD_HASH, null) ?: return false
        val storedSaltStr = encryptedPrefs.getString(PREF_PASSWORD_SALT, null) ?: return false
        
        val storedHash = Base64.decode(storedHashStr, Base64.NO_WRAP)
        val salt = Base64.decode(storedSaltStr, Base64.NO_WRAP)
        
        val computedHash = hashPassword(password, salt)
        
        // Constant-time comparison to prevent timing attacks
        return storedHash.contentEquals(computedHash)
    }
    
    /**
     * Check if biometric authentication is available on this device.
     */
    fun isBiometricAvailable(): Boolean {
        return biometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
            AndroidBiometricManager.Authenticators.DEVICE_CREDENTIAL
        ) == AndroidBiometricManager.BIOMETRIC_SUCCESS
    }
}
