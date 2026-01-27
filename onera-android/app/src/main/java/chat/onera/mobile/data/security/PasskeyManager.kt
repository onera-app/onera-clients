package chat.onera.mobile.data.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.remote.trpc.WebAuthnProcedures
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Passkey Manager - handles WebAuthn passkey registration and authentication
 * 
 * Supports two modes:
 * 1. PRF-based: Uses WebAuthn PRF extension (works with synced passkeys from web)
 * 2. KEK-based: Uses local device-bound key (fallback for older devices)
 * 
 * Android 14+ supports PRF extension which allows synced passkeys from web to work.
 */
@Singleton
class PasskeyManager @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager
) {
    companion object {
        private const val TAG = "PasskeyManager"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEK_ALIAS = "onera_passkey_kek"
        private const val PREFS_NAME = "passkey_prefs"
        private const val PREF_CREDENTIAL_ID = "credential_id"
    }
    
    private val json = Json { 
        ignoreUnknownKeys = true 
        encodeDefaults = true
    }
    
    private val credentialManager = CredentialManager.create(context)
    private val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // Store PRF salts during authentication flow
    private var currentPrfSalts: Map<String, String> = emptyMap()
    
    // ===== Support Check =====
    
    /**
     * Check if passkey/biometric authentication is supported on this device.
     */
    fun isPasskeySupported(): Boolean {
        return try {
            // Android 14+ has native passkey support via Credential Manager
            android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        } catch (e: Exception) {
            Log.e(TAG, "Error checking passkey support", e)
            false
        }
    }
    
    // ===== Registration =====
    
    /**
     * Register a new passkey for the user.
     * Uses PRF extension to derive key for encrypting master key.
     * 
     * @param masterKey The master encryption key to encrypt with PRF-derived key
     * @param name Optional display name for the passkey
     * @param activity The activity context for the credential dialog
     * @return The credential ID of the registered passkey
     */
    suspend fun registerPasskey(
        masterKey: ByteArray,
        name: String?,
        activity: android.app.Activity
    ): String {
        Log.d(TAG, "Starting passkey registration...")
        
        // 1. Get registration options from server (includes prfSalt)
        val optionsRequest = WebAuthnRegistrationOptionsRequest(name = name)
        val optionsResult = trpcClient.mutation<WebAuthnRegistrationOptionsRequest, WebAuthnRegistrationOptionsResponse>(
            WebAuthnProcedures.GENERATE_REGISTRATION,
            optionsRequest
        )
        
        val optionsResponse = optionsResult.getOrThrow()
        val prfSalt = optionsResponse.prfSalt
        Log.d(TAG, "Got registration options from server, prfSalt: ${prfSalt.take(10)}...")
        
        // 2. Create credential using Credential Manager with PRF extension
        val createRequest = CreatePublicKeyCredentialRequest(
            requestJson = buildRegistrationRequestJson(optionsResponse.options, prfSalt)
        )
        
        val createResult = credentialManager.createCredential(activity, createRequest)
        
        val credential = createResult as? PublicKeyCredential
            ?: throw IllegalStateException("Invalid credential type")
        
        Log.d(TAG, "Passkey credential created")
        
        // 3. Parse the response and get PRF output
        val responseJson = credential.authenticationResponseJson
        Log.d(TAG, "Registration response: $responseJson")
        
        val registrationResponse = parseRegistrationResponse(responseJson)
        
        // 4. Get PRF output from the response to derive encryption key
        val prfOutput = extractPRFOutputFromRegistration(responseJson)
        
        val encryptionKey: ByteArray
        if (prfOutput != null) {
            // Use PRF output to derive encryption key
            Log.d(TAG, "Using PRF output to derive encryption key")
            encryptionKey = derivePRFKey(prfOutput, prfSalt)
        } else {
            // Fallback: Generate local KEK
            Log.w(TAG, "PRF not available, using local KEK fallback")
            encryptionKey = generateKEK()
            saveKEKToKeystore(encryptionKey)
        }
        
        // 5. Encrypt master key with the derived/generated key
        val (encryptedMasterKey, masterKeyNonce) = encryptionManager.encryptBytesForServer(masterKey, encryptionKey)
        
        // 6. Verify registration with server
        val verifyRequest = WebAuthnVerifyRegistrationRequest(
            response = registrationResponse,
            prfSalt = prfSalt,
            encryptedMasterKey = encryptedMasterKey,
            masterKeyNonce = masterKeyNonce,
            name = name
        )
        
        val verifyResult = trpcClient.mutation<WebAuthnVerifyRegistrationRequest, WebAuthnVerifyRegistrationResponse>(
            WebAuthnProcedures.VERIFY_REGISTRATION,
            verifyRequest
        )
        
        val verifyResponse = verifyResult.getOrThrow()
        
        if (!verifyResponse.verified) {
            throw IllegalStateException("Passkey verification failed")
        }
        
        val credentialId = verifyResponse.credentialId ?: registrationResponse.id
        
        // 7. Save credential ID
        prefs.edit().putString(PREF_CREDENTIAL_ID, credentialId).apply()
        
        // 8. Secure cleanup
        encryptionKey.fill(0)
        
        Log.d(TAG, "Passkey registration successful: $credentialId")
        return credentialId
    }
    
    // ===== Authentication =====
    
    /**
     * Authenticate with passkey and retrieve decrypted master key.
     * Supports both synced passkeys (via PRF) and local passkeys (via KEK).
     * 
     * @param activity The activity context for the credential dialog
     * @return The decrypted master key
     */
    suspend fun authenticateWithPasskey(activity: android.app.Activity): ByteArray {
        Log.d(TAG, "Starting passkey authentication...")
        
        // 1. Get authentication options from server (includes prfSalts)
        val optionsResult = trpcClient.mutation<Unit, WebAuthnAuthOptionsResponse>(
            WebAuthnProcedures.GENERATE_AUTH,
            Unit
        )
        
        val optionsResponse = optionsResult.getOrThrow()
        currentPrfSalts = optionsResponse.prfSalts
        Log.d(TAG, "Got authentication options, ${currentPrfSalts.size} PRF salts available")
        
        // 2. Authenticate with passkey (include PRF extension)
        val getRequest = GetCredentialRequest(
            listOf(
                GetPublicKeyCredentialOption(
                    requestJson = buildAuthenticationRequestJson(optionsResponse.options, currentPrfSalts)
                )
            )
        )
        
        val getResult = credentialManager.getCredential(activity, getRequest)
        
        val credential = getResult.credential as? PublicKeyCredential
            ?: throw IllegalStateException("Invalid credential type")
        
        Log.d(TAG, "Passkey authentication successful")
        
        // 3. Parse the response
        val responseJson = credential.authenticationResponseJson
        Log.d(TAG, "Auth response: $responseJson")
        
        val authResponse = parseAuthenticationResponse(responseJson)
        val credentialId = authResponse.id
        
        // 4. Verify authentication with server and get encrypted master key
        val verifyRequest = WebAuthnVerifyAuthRequest(response = authResponse)
        val verifyResult = trpcClient.mutation<WebAuthnVerifyAuthRequest, WebAuthnVerifyAuthResponse>(
            WebAuthnProcedures.VERIFY_AUTH,
            verifyRequest
        )
        
        val verifyResponse = verifyResult.getOrThrow()
        
        if (!verifyResponse.verified) {
            throw IllegalStateException("Passkey verification failed")
        }
        
        // 5. Get PRF output and derive decryption key
        val prfOutput = extractPRFOutputFromAuth(responseJson)
        val prfSalt = verifyResponse.prfSalt ?: currentPrfSalts[credentialId]
        
        val decryptionKey: ByteArray
        if (prfOutput != null && prfSalt != null) {
            // Use PRF output to derive decryption key
            Log.d(TAG, "Using PRF output to derive decryption key")
            decryptionKey = derivePRFKey(prfOutput, prfSalt)
        } else if (hasLocalPasskeyKEK()) {
            // Fallback: Use local KEK
            Log.d(TAG, "PRF not available, using local KEK")
            decryptionKey = getKEKFromKeystore()
        } else {
            throw IllegalStateException("Cannot decrypt: no PRF output and no local KEK available")
        }
        
        // 6. Decrypt master key using XSalsa20-Poly1305 (libsodium secretbox)
        // This matches the web's encryption using crypto_secretbox_easy
        val masterKey = encryptionManager.decryptSecretBox(
            verifyResponse.encryptedMasterKey,
            verifyResponse.masterKeyNonce,
            decryptionKey
        )
        
        // 7. Secure cleanup
        decryptionKey.fill(0)
        
        Log.d(TAG, "Master key decrypted successfully")
        return masterKey
    }
    
    // ===== Management =====
    
    /**
     * Check if user has any passkeys registered on server.
     */
    suspend fun hasPasskeys(): Boolean {
        return try {
            val result = trpcClient.query<Unit, WebAuthnHasPasskeysResponse>(
                WebAuthnProcedures.HAS_PASSKEYS,
                Unit
            )
            result.getOrNull()?.hasPasskeys ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking passkeys", e)
            false
        }
    }
    
    /**
     * Check if local passkey KEK exists.
     */
    fun hasLocalPasskeyKEK(): Boolean {
        return keyStore.containsAlias(KEK_ALIAS)
    }
    
    /**
     * Remove local passkey KEK.
     */
    fun removeLocalPasskeyKEK() {
        try {
            keyStore.deleteEntry(KEK_ALIAS)
            prefs.edit().remove(PREF_CREDENTIAL_ID).apply()
            prefs.edit().remove("encrypted_kek").apply()
            Log.d(TAG, "Local passkey KEK removed")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing KEK", e)
        }
    }
    
    // ===== Private Methods - PRF =====
    
    private fun derivePRFKey(prfOutput: ByteArray, prfSalt: String): ByteArray {
        // The PRF output combined with salt gives us the encryption key
        // Use HKDF or similar to derive a 32-byte key
        val saltBytes = Base64.decode(prfSalt, Base64.NO_WRAP)
        return encryptionManager.deriveKey(prfOutput, saltBytes, 32)
    }
    
    private fun extractPRFOutputFromRegistration(responseJson: String): ByteArray? {
        return try {
            val responseMap = json.decodeFromString<JsonObject>(responseJson)
            val clientExtensionResults = responseMap["clientExtensionResults"]?.jsonObject
            val prf = clientExtensionResults?.get("prf")?.jsonObject
            val results = prf?.get("results")?.jsonObject
            val first = results?.get("first")?.jsonPrimitive?.content
            
            if (first != null) {
                Base64.decode(first, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not extract PRF output from registration: ${e.message}")
            null
        }
    }
    
    private fun extractPRFOutputFromAuth(responseJson: String): ByteArray? {
        return try {
            val responseMap = json.decodeFromString<JsonObject>(responseJson)
            val clientExtensionResults = responseMap["clientExtensionResults"]?.jsonObject
            val prf = clientExtensionResults?.get("prf")?.jsonObject
            val results = prf?.get("results")?.jsonObject
            val first = results?.get("first")?.jsonPrimitive?.content
            
            if (first != null) {
                Base64.decode(first, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not extract PRF output from auth: ${e.message}")
            null
        }
    }
    
    // ===== Private Methods - KEK Management =====
    
    private fun generateKEK(): ByteArray {
        return encryptionManager.generateRandomBytes(32)
    }
    
    private fun saveKEKToKeystore(kek: ByteArray) {
        // Delete existing KEK
        if (keyStore.containsAlias(KEK_ALIAS)) {
            keyStore.deleteEntry(KEK_ALIAS)
        }
        
        // Generate a wrapping key in Keystore with biometric protection
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )
        
        val keySpec = KeyGenParameterSpec.Builder(
            KEK_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL)
            .build()
        
        keyGenerator.init(keySpec)
        keyGenerator.generateKey()
        
        // Store the KEK encrypted with the Keystore key
        val kekBase64 = Base64.encodeToString(kek, Base64.NO_WRAP)
        prefs.edit().putString("encrypted_kek", kekBase64).apply()
        
        Log.d(TAG, "KEK saved to Keystore")
    }
    
    private fun getKEKFromKeystore(): ByteArray {
        val kekBase64 = prefs.getString("encrypted_kek", null)
            ?: throw IllegalStateException("KEK not found")
        
        return Base64.decode(kekBase64, Base64.NO_WRAP)
    }
    
    // ===== Private Methods - JSON Building =====
    
    private fun buildRegistrationRequestJson(options: WebAuthnCreationOptions, prfSalt: String): String {
        // Convert PRF salt to base64url for the extension
        val saltBytes = Base64.decode(prfSalt, Base64.NO_WRAP)
        val saltBase64Url = Base64.encodeToString(saltBytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        
        val jsonObject = buildJsonObject {
            put("challenge", options.challenge)
            putJsonObject("rp") {
                put("id", options.rp.id)
                put("name", options.rp.name)
            }
            putJsonObject("user") {
                put("id", options.user.id)
                put("name", options.user.name)
                put("displayName", options.user.displayName)
            }
            putJsonArray("pubKeyCredParams") {
                options.pubKeyCredParams.forEach { param ->
                    add(buildJsonObject {
                        put("type", param.type)
                        put("alg", param.alg)
                    })
                }
            }
            put("timeout", options.timeout ?: 60000L)
            put("attestation", options.attestation ?: "none")
            putJsonObject("authenticatorSelection") {
                put("authenticatorAttachment", "platform")
                put("residentKey", "required")
                put("userVerification", "required")
            }
            putJsonObject("extensions") {
                putJsonObject("prf") {
                    putJsonObject("eval") {
                        put("first", saltBase64Url)
                    }
                }
            }
        }
        return jsonObject.toString()
    }
    
    private fun buildAuthenticationRequestJson(options: WebAuthnRequestOptions, prfSalts: Map<String, String>): String {
        val jsonObject = buildJsonObject {
            put("challenge", options.challenge)
            put("timeout", options.timeout ?: 60000L)
            put("userVerification", options.userVerification ?: "required")
            
            options.rpId?.let { put("rpId", it) }
            
            options.allowCredentials?.let { credentials ->
                putJsonArray("allowCredentials") {
                    credentials.forEach { cred ->
                        add(buildJsonObject {
                            put("id", cred.id)
                            put("type", cred.type)
                            putJsonArray("transports") {
                                (cred.transports ?: listOf("internal", "hybrid")).forEach { add(JsonPrimitive(it)) }
                            }
                        })
                    }
                }
            }
            
            // Add PRF extension for authentication
            // Use evalByCredential to provide different salts per credential
            if (prfSalts.isNotEmpty()) {
                putJsonObject("extensions") {
                    putJsonObject("prf") {
                        putJsonObject("evalByCredential") {
                            prfSalts.forEach { (credentialId, salt) ->
                                val saltBytes = Base64.decode(salt, Base64.NO_WRAP)
                                val saltBase64Url = Base64.encodeToString(saltBytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                                putJsonObject(credentialId) {
                                    put("first", saltBase64Url)
                                }
                            }
                        }
                    }
                }
            }
        }
        return jsonObject.toString()
    }
    
    // ===== Private Methods - Response Parsing =====
    
    private fun parseRegistrationResponse(responseJson: String): WebAuthnRegistrationResponse {
        val responseObj = json.decodeFromString<JsonObject>(responseJson)
        
        val id = responseObj["id"]?.jsonPrimitive?.content ?: ""
        val rawId = responseObj["rawId"]?.jsonPrimitive?.content ?: id
        val type = responseObj["type"]?.jsonPrimitive?.content ?: "public-key"
        
        val response = responseObj["response"]?.jsonObject
        val clientDataJSON = response?.get("clientDataJSON")?.jsonPrimitive?.content ?: ""
        val attestationObject = response?.get("attestationObject")?.jsonPrimitive?.content ?: ""
        
        return WebAuthnRegistrationResponse(
            id = id,
            rawId = rawId,
            type = type,
            response = WebAuthnAttestationResponse(
                clientDataJSON = clientDataJSON,
                attestationObject = attestationObject
            ),
            clientExtensionResults = WebAuthnClientExtensionResults(
                prf = WebAuthnPRFExtensionResult(enabled = true)
            )
        )
    }
    
    private fun parseAuthenticationResponse(responseJson: String): WebAuthnAuthenticationResponse {
        val responseObj = json.decodeFromString<JsonObject>(responseJson)
        
        val id = responseObj["id"]?.jsonPrimitive?.content ?: ""
        val rawId = responseObj["rawId"]?.jsonPrimitive?.content ?: id
        val type = responseObj["type"]?.jsonPrimitive?.content ?: "public-key"
        
        val response = responseObj["response"]?.jsonObject
        val clientDataJSON = response?.get("clientDataJSON")?.jsonPrimitive?.content ?: ""
        val authenticatorData = response?.get("authenticatorData")?.jsonPrimitive?.content ?: ""
        val signature = response?.get("signature")?.jsonPrimitive?.content ?: ""
        val userHandle = response?.get("userHandle")?.jsonPrimitive?.content
        
        // Include clientExtensionResults - server requires it to be an object (not null)
        val clientExtensionResults = responseObj["clientExtensionResults"]?.jsonObject
        
        return WebAuthnAuthenticationResponse(
            id = id,
            rawId = rawId,
            type = type,
            response = WebAuthnAssertionResponse(
                clientDataJSON = clientDataJSON,
                authenticatorData = authenticatorData,
                signature = signature,
                userHandle = userHandle
            ),
            clientExtensionResults = clientExtensionResults
        )
    }
}
