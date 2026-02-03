package chat.onera.mobile.data.security

import android.content.Context
import android.content.pm.PackageManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid
import dagger.hilt.android.qualifiers.ApplicationContext
import timber.log.Timber
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.ECGenParameterSpec
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure Enclave Manager for StrongBox/TEE key management.
 * 
 * Provides hardware-backed key generation and storage with fallback to standard TEE.
 * Uses StrongBox when available for maximum security, falls back to standard TEE with warning.
 * 
 * Key Features:
 * - StrongBox hardware security module support (when available)
 * - EC P-256 keys for hardware operations
 * - X25519 operations via lazysodium for Noise Protocol compatibility
 * - Secure key deletion and lifecycle management
 */
@Singleton
class SecureEnclaveManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "SecureEnclaveManager"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val EC_CURVE = "secp256r1" // P-256 curve for hardware compatibility
    }
    
    private val keyStore: KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    
    // Lazy-initialized sodium instance for X25519 operations
    private val sodium: LazySodiumAndroid by lazy {
        LazySodiumAndroid(SodiumAndroid())
    }
    
    /**
     * Check if StrongBox hardware security module is available.
     * StrongBox provides the highest level of hardware security on Android.
     */
    val isHardwareBacked: Boolean by lazy {
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE).also { hasStrongBox ->
            if (hasStrongBox) {
                Timber.i("$TAG: StrongBox hardware security module available")
            } else {
                Timber.w("$TAG: StrongBox not available, falling back to standard TEE")
            }
        }
    }
    
    /**
     * Generate a hardware-backed EC P-256 key pair.
     * 
     * Attempts to use StrongBox when available, falls back to standard TEE.
     * The generated keys are stored in Android Keystore and cannot be extracted.
     * 
     * @param alias Unique identifier for the key pair
     * @return KeyPair with public/private keys (private key is hardware-backed)
     * @throws SecurityException if key generation fails
     */
    fun generateKeyPair(alias: String): KeyPair {
        try {
            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                ANDROID_KEYSTORE
            )
            
            val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY or KeyProperties.PURPOSE_AGREE_KEY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec(EC_CURVE))
                .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
                .setUserAuthenticationRequired(false) // Can be enabled for additional security
                .apply {
                    // Try StrongBox first, fall back to standard TEE
                    if (isHardwareBacked) {
                        try {
                            setIsStrongBoxBacked(true)
                            Timber.d("$TAG: Generating key pair with StrongBox backing for alias: $alias")
                        } catch (e: Exception) {
                            Timber.w("$TAG: StrongBox failed, falling back to standard TEE: ${e.message}")
                        }
                    } else {
                        Timber.d("$TAG: Generating key pair with standard TEE for alias: $alias")
                    }
                }
                .build()
            
            keyPairGenerator.initialize(keyGenParameterSpec)
            val keyPair = keyPairGenerator.generateKeyPair()
            
            Timber.i("$TAG: Successfully generated key pair for alias: $alias")
            return keyPair
            
        } catch (e: Exception) {
            Timber.e("$TAG: Failed to generate key pair for alias: $alias", e)
            throw SecurityException("Failed to generate hardware-backed key pair", e)
        }
    }
    
    /**
     * Retrieve the private key for a given alias.
     * 
     * The private key remains in hardware and cannot be extracted.
     * This method returns a reference that can be used for cryptographic operations.
     * 
     * @param alias Key pair identifier
     * @return PrivateKey reference or null if not found
     */
    fun getPrivateKey(alias: String): PrivateKey? {
        return try {
            val privateKey = keyStore.getKey(alias, null) as? PrivateKey
            if (privateKey != null) {
                Timber.d("$TAG: Retrieved private key for alias: $alias")
            } else {
                Timber.w("$TAG: Private key not found for alias: $alias")
            }
            privateKey
        } catch (e: Exception) {
            Timber.e("$TAG: Failed to retrieve private key for alias: $alias", e)
            null
        }
    }
    
    /**
     * Securely delete a key pair from hardware storage.
     * 
     * This permanently removes both public and private keys from the hardware.
     * The operation cannot be undone.
     * 
     * @param alias Key pair identifier to delete
     * @return true if deletion was successful, false otherwise
     */
    fun deleteKey(alias: String): Boolean {
        return try {
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
                Timber.i("$TAG: Successfully deleted key pair for alias: $alias")
                true
            } else {
                Timber.w("$TAG: Key pair not found for deletion, alias: $alias")
                false
            }
        } catch (e: Exception) {
            Timber.e("$TAG: Failed to delete key pair for alias: $alias", e)
            false
        }
    }
    
    /**
     * Check if a key pair exists for the given alias.
     * 
     * @param alias Key pair identifier
     * @return true if key pair exists, false otherwise
     */
    fun hasKey(alias: String): Boolean {
        return try {
            keyStore.containsAlias(alias)
        } catch (e: Exception) {
            Timber.e("$TAG: Failed to check key existence for alias: $alias", e)
            false
        }
    }
    
    /**
     * Generate X25519 key pair for Noise Protocol operations.
     * 
     * Since hardware keystores typically don't support X25519 directly,
     * this uses libsodium for compatibility with the Noise Protocol implementation.
     * 
     * Note: These keys are generated in software and should be used only for
     * ephemeral operations like Noise Protocol handshakes.
     * 
     * @return Pair of (publicKey, privateKey) as ByteArrays
     */
    fun generateX25519KeyPair(): Pair<ByteArray, ByteArray> {
        val keyPair = sodium.cryptoBoxKeypair()
        val publicKey = keyPair.publicKey.asBytes
        val privateKey = keyPair.secretKey.asBytes
        
        Timber.d("$TAG: Generated X25519 key pair for Noise Protocol")
        return Pair(publicKey, privateKey)
    }
    
    /**
     * Perform X25519 Diffie-Hellman key exchange.
     * 
     * @param privateKey Our private key (32 bytes)
     * @param publicKey Remote public key (32 bytes)
     * @return Shared secret (32 bytes)
     */
    fun performX25519DH(privateKey: ByteArray, publicKey: ByteArray): ByteArray {
        require(privateKey.size == 32) { "Private key must be 32 bytes" }
        require(publicKey.size == 32) { "Public key must be 32 bytes" }
        
        val sharedSecret = ByteArray(32)
        sodium.cryptoScalarMult(sharedSecret, privateKey, publicKey)
        Timber.d("$TAG: Performed X25519 DH operation")
        return sharedSecret
    }
    
    /**
     * List all key aliases managed by this instance.
     * 
     * @return List of key aliases
     */
    fun listKeyAliases(): List<String> {
        return try {
            keyStore.aliases().toList().also { aliases ->
                Timber.d("$TAG: Found ${aliases.size} key aliases")
            }
        } catch (e: Exception) {
            Timber.e("$TAG: Failed to list key aliases", e)
            emptyList()
        }
    }
    
    /**
     * Get hardware security information for debugging/logging.
     * 
     * @return Map of security features and their availability
     */
    fun getSecurityInfo(): Map<String, Any> {
        return mapOf(
            "strongbox_available" to isHardwareBacked,
            "keystore_provider" to ANDROID_KEYSTORE,
            "ec_curve" to EC_CURVE,
            "key_count" to listKeyAliases().size
        )
    }
}