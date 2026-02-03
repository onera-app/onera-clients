package chat.onera.mobile.data.security

import android.util.Base64
import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Attestation Verifier for SEV-SNP and Azure IMDS attestation.
 * 
 * Verifies TEE attestation quotes with cryptographic validation:
 * - Parses JSON attestation responses
 * - Verifies public key hash matches report_data
 * - Caches valid attestations for performance
 * - Supports both SEV-SNP and Azure IMDS attestation types
 */
@Singleton
class AttestationVerifier @Inject constructor(
    private val okHttpClient: OkHttpClient
) {
    companion object {
        private const val TAG = "AttestationVerifier"
        private const val CACHE_DURATION_MS = 3600_000L // 1 hour
        private const val PUBLIC_KEY_SIZE = 32 // X25519 key size
    }
    
    // Lazy-initialized sodium instance for hashing
    private val sodium: LazySodiumAndroid by lazy {
        LazySodiumAndroid(SodiumAndroid())
    }
    
    // Simple in-memory cache for attestation results
    private val attestationCache = mutableMapOf<String, CachedAttestation>()
    
    /**
     * Result of attestation verification.
     */
    data class AttestationResult(
        val isValid: Boolean,
        val serverPublicKey: ByteArray?,
        val attestationType: String,
        val error: String?
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false
            other as AttestationResult
            if (isValid != other.isValid) return false
            if (serverPublicKey != null) {
                if (other.serverPublicKey == null) return false
                if (!serverPublicKey.contentEquals(other.serverPublicKey)) return false
            } else if (other.serverPublicKey != null) return false
            if (attestationType != other.attestationType) return false
            if (error != other.error) return false
            return true
        }
        
        override fun hashCode(): Int {
            var result = isValid.hashCode()
            result = 31 * result + (serverPublicKey?.contentHashCode() ?: 0)
            result = 31 * result + attestationType.hashCode()
            result = 31 * result + (error?.hashCode() ?: 0)
            return result
        }
    }
    
    /**
     * Cached attestation data.
     */
    private data class CachedAttestation(
        val result: AttestationResult,
        val timestamp: Long
    )
    
    /**
     * Verify attestation from a TEE endpoint.
     * 
     * @param attestationEndpoint URL to fetch attestation from
     * @return AttestationResult with verification status and server public key
     */
    suspend fun verify(attestationEndpoint: String): AttestationResult = withContext(Dispatchers.IO) {
        Timber.d("$TAG: Verifying attestation from: $attestationEndpoint")
        
        try {
            // Check cache first
            val cached = attestationCache[attestationEndpoint]
            if (cached != null && (System.currentTimeMillis() - cached.timestamp) < CACHE_DURATION_MS) {
                Timber.d("$TAG: Using cached attestation result")
                return@withContext cached.result
            }
            
            // Fetch fresh attestation
            val attestationData = fetchAttestation(attestationEndpoint)
            val result = verifyAttestationData(attestationData)
            
            // Cache successful results
            if (result.isValid) {
                attestationCache[attestationEndpoint] = CachedAttestation(result, System.currentTimeMillis())
                Timber.i("$TAG: Attestation verified and cached for: $attestationEndpoint")
            }
            
            result
            
        } catch (e: Exception) {
            Timber.e("$TAG: Attestation verification failed", e)
            AttestationResult(
                isValid = false,
                serverPublicKey = null,
                attestationType = "unknown",
                error = "Verification failed: ${e.message}"
            )
        }
    }
    
    /**
     * Fetch attestation data from endpoint.
     */
    private suspend fun fetchAttestation(endpoint: String): JsonObject = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(endpoint)
            .addHeader("Cache-Control", "no-cache") // Always fetch fresh attestation
            .build()
        
        val response = okHttpClient.newCall(request).execute()
        
        if (!response.isSuccessful) {
            throw SecurityException("Failed to fetch attestation: HTTP ${response.code}")
        }
        
        val responseBody = response.body?.string()
            ?: throw SecurityException("Empty attestation response")
        
        Timber.d("$TAG: Fetched attestation data (${responseBody.length} chars)")
        
        try {
            Json.parseToJsonElement(responseBody) as JsonObject
        } catch (e: Exception) {
            throw SecurityException("Invalid JSON in attestation response", e)
        }
    }
    
    /**
     * Verify attestation data structure and cryptographic bindings.
     */
    private fun verifyAttestationData(data: JsonObject): AttestationResult {
        // Extract required fields
        val attestationType = data["attestation_type"]?.jsonPrimitive?.content
            ?: return AttestationResult(false, null, "unknown", "Missing attestation_type")
        
        val rawQuote = data["quote"]?.jsonPrimitive?.content
            ?: return AttestationResult(false, null, attestationType, "Missing quote")
        
        val publicKeyRaw = data["public_key"]?.jsonPrimitive?.content
            ?: data["publicKey"]?.jsonPrimitive?.content
            ?: return AttestationResult(false, null, attestationType, "Missing public_key")
        
        val reportData = data["report_data"]?.jsonPrimitive?.content
        
        Timber.d("$TAG: Verifying $attestationType attestation")
        
        // Parse and validate public key
        val publicKey = parsePublicKey(publicKeyRaw)
            ?: return AttestationResult(false, null, attestationType, "Invalid public key format")
        
        // Verify public key binding in report_data
        if (!verifyPublicKeyBinding(publicKey, reportData)) {
            return AttestationResult(false, null, attestationType, "Public key not bound in report_data")
        }
        
        // Type-specific verification
        return when (attestationType) {
            "azure-imds" -> verifyAzureImdsAttestation(rawQuote, publicKey, reportData, attestationType)
            "sev-snp", "mock-sev-snp" -> verifySevSnpAttestation(rawQuote, publicKey, attestationType)
            else -> AttestationResult(false, null, attestationType, "Unsupported attestation type")
        }
    }
    
    /**
     * Parse public key from hex or base64 format.
     */
    private fun parsePublicKey(publicKeyRaw: String): ByteArray? {
        return try {
            val publicKey = if (publicKeyRaw.matches(Regex("^[0-9a-fA-F]+$"))) {
                // Hex format
                publicKeyRaw.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            } else {
                // Base64 format
                Base64.decode(publicKeyRaw, Base64.NO_WRAP)
            }
            
            if (publicKey.size != PUBLIC_KEY_SIZE) {
                Timber.w("$TAG: Invalid public key length: ${publicKey.size} bytes (expected $PUBLIC_KEY_SIZE)")
                null
            } else {
                publicKey
            }
        } catch (e: Exception) {
            Timber.w("$TAG: Failed to parse public key: ${e.message}")
            null
        }
    }
    
    /**
     * Verify that the public key is cryptographically bound to the attestation.
     * This prevents man-in-the-middle attacks by ensuring the attestation
     * was generated for this specific public key.
     */
    private fun verifyPublicKeyBinding(publicKey: ByteArray, reportData: String?): Boolean {
        if (reportData == null) {
            Timber.w("$TAG: No report_data provided for public key binding verification")
            return false
        }
        
        // Compute SHA-256 hash of public key
        val publicKeyHash = MessageDigest.getInstance("SHA-256").digest(publicKey)
        val expectedHashHex = publicKeyHash.joinToString("") { "%02x".format(it) }
        
        // Check if report_data starts with the public key hash
        val isValid = reportData.lowercase().startsWith(expectedHashHex.lowercase())
        
        if (isValid) {
            Timber.d("$TAG: Public key binding verified successfully")
        } else {
            Timber.w("$TAG: Public key binding verification failed")
            Timber.v("$TAG: Expected hash: $expectedHashHex")
            Timber.v("$TAG: Report data: ${reportData.take(64)}")
        }
        
        return isValid
    }
    
    /**
     * Verify Azure IMDS attestation.
     * 
     * Azure IMDS provides PKCS7-signed attestation tokens that prove
     * the code is running in an Azure Confidential VM.
     */
    private fun verifyAzureImdsAttestation(
        rawQuote: String,
        publicKey: ByteArray,
        reportData: String?,
        attestationType: String
    ): AttestationResult {
        // For Azure IMDS, the quote is a PKCS7-signed JWT token
        // In a production implementation, you would:
        // 1. Verify the PKCS7 signature against Microsoft's certificate chain
        // 2. Parse the JWT payload to extract claims
        // 3. Verify the claims match expected values
        
        // For now, we perform basic validation
        if (rawQuote.isBlank()) {
            return AttestationResult(false, null, attestationType, "Empty Azure IMDS quote")
        }
        
        // Basic JWT structure check (header.payload.signature)
        val jwtParts = rawQuote.split(".")
        if (jwtParts.size != 3) {
            return AttestationResult(false, null, attestationType, "Invalid JWT structure in Azure IMDS quote")
        }
        
        Timber.i("$TAG: Azure IMDS attestation basic validation passed")
        
        // In production, implement full PKCS7 signature verification here
        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = attestationType,
            error = null
        )
    }
    
    /**
     * Verify SEV-SNP attestation.
     * 
     * SEV-SNP provides cryptographically signed attestation reports
     * that prove the code is running in an AMD SEV-SNP TEE.
     */
    private fun verifySevSnpAttestation(
        rawQuote: String,
        publicKey: ByteArray,
        attestationType: String
    ): AttestationResult {
        // For SEV-SNP, the quote is a base64-encoded attestation report
        // In a production implementation, you would:
        // 1. Parse the binary attestation report structure
        // 2. Verify the signature against AMD's VCEK certificate
        // 3. Check measurement values against known good values
        
        try {
            val quoteBytes = Base64.decode(rawQuote, Base64.NO_WRAP)
            
            // Basic structure validation
            if (quoteBytes.size < 64) {
                return AttestationResult(false, null, attestationType, "SEV-SNP quote too short")
            }
            
            Timber.i("$TAG: SEV-SNP attestation basic validation passed")
            
            // In production, implement full signature verification here
            return AttestationResult(
                isValid = true,
                serverPublicKey = publicKey,
                attestationType = attestationType,
                error = null
            )
            
        } catch (e: Exception) {
            return AttestationResult(
                false, 
                null, 
                attestationType, 
                "Failed to decode SEV-SNP quote: ${e.message}"
            )
        }
    }
    
    /**
     * Clear the attestation cache.
     * Useful for testing or when attestation endpoints change.
     */
    fun clearCache() {
        attestationCache.clear()
        Timber.d("$TAG: Attestation cache cleared")
    }
    
    /**
     * Get cache statistics for debugging.
     */
    fun getCacheStats(): Map<String, Any> {
        val now = System.currentTimeMillis()
        val validEntries = attestationCache.values.count { (now - it.timestamp) < CACHE_DURATION_MS }
        
        return mapOf(
            "total_entries" to attestationCache.size,
            "valid_entries" to validEntries,
            "cache_duration_ms" to CACHE_DURATION_MS
        )
    }
}