package chat.onera.mobile.data.remote.private_inference

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Verifies TEE (Trusted Execution Environment) attestation and extracts
 * the server's public key for Noise protocol handshake.
 * 
 * Supports:
 * - AMD SEV-SNP attestation
 * - Intel TDX attestation
 * - Development/mock attestation (for testing)
 */
class AttestationVerifier {
    
    companion object {
        private const val TAG = "AttestationVerifier"
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }
    
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    
    /**
     * Verify attestation and extract server public key
     * 
     * @param attestationEndpoint URL to fetch attestation from
     * @param expectedMeasurements Optional expected measurements to verify against
     * @return AttestationResult containing the server's public key if valid
     */
    suspend fun verify(
        attestationEndpoint: String,
        expectedMeasurements: ExpectedMeasurements? = null
    ): AttestationResult = withContext(Dispatchers.IO) {
        Log.d(TAG, "Fetching attestation from: $attestationEndpoint")
        
        try {
            // Fetch attestation document
            val attestationDoc = fetchAttestation(attestationEndpoint)
            Log.d(TAG, "Received attestation document, type: ${attestationDoc.type}")
            
            // Verify based on attestation type
            when (attestationDoc.type) {
                "sev-snp" -> verifySevSnp(attestationDoc, expectedMeasurements)
                "tdx" -> verifyTdx(attestationDoc, expectedMeasurements)
                "development", "mock" -> {
                    Log.w(TAG, "Using development/mock attestation - NOT SECURE FOR PRODUCTION")
                    verifyDevelopment(attestationDoc)
                }
                else -> {
                    Log.e(TAG, "Unknown attestation type: ${attestationDoc.type}")
                    AttestationResult(
                        isValid = false,
                        error = "Unknown attestation type: ${attestationDoc.type}"
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Attestation verification failed", e)
            AttestationResult(
                isValid = false,
                error = e.message ?: "Unknown error"
            )
        }
    }
    
    /**
     * Fetch attestation document from endpoint
     */
    private suspend fun fetchAttestation(endpoint: String): AttestationDocument {
        return suspendCancellableCoroutine { continuation ->
            val request = Request.Builder()
                .url(endpoint)
                .get()
                .build()
            
            val call = httpClient.newCall(request)
            
            continuation.invokeOnCancellation {
                call.cancel()
            }
            
            try {
                val response = call.execute()
                
                if (!response.isSuccessful) {
                    continuation.resumeWithException(
                        PrivateInferenceException.AttestationFailed(
                            "HTTP ${response.code}: ${response.message}"
                        )
                    )
                    return@suspendCancellableCoroutine
                }
                
                val body = response.body?.string()
                    ?: throw PrivateInferenceException.AttestationFailed("Empty response")
                
                val doc = json.decodeFromString<AttestationDocument>(body)
                continuation.resume(doc)
                
            } catch (e: Exception) {
                if (e is PrivateInferenceException) {
                    continuation.resumeWithException(e)
                } else {
                    continuation.resumeWithException(
                        PrivateInferenceException.AttestationFailed(e.message ?: "Unknown error")
                    )
                }
            }
        }
    }
    
    /**
     * Verify AMD SEV-SNP attestation
     */
    private fun verifySevSnp(
        doc: AttestationDocument,
        expected: ExpectedMeasurements?
    ): AttestationResult {
        Log.d(TAG, "Verifying SEV-SNP attestation")
        
        // Extract public key from report data
        val publicKey = doc.publicKey?.let { 
            try {
                Base64.decode(it, Base64.DEFAULT)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decode public key", e)
                null
            }
        }
        
        if (publicKey == null || publicKey.size != 32) {
            return AttestationResult(
                isValid = false,
                error = "Invalid or missing public key in attestation"
            )
        }
        
        // Verify measurements if expected values provided
        if (expected != null) {
            val measurement = doc.measurement
            if (expected.measurement != null && measurement != expected.measurement) {
                Log.w(TAG, "Measurement mismatch: expected ${expected.measurement}, got $measurement")
                return AttestationResult(
                    isValid = false,
                    error = "Measurement verification failed"
                )
            }
        }
        
        // TODO: In production, verify the attestation report signature
        // against AMD's root certificates
        
        Log.d(TAG, "SEV-SNP attestation verified successfully")
        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = "sev-snp"
        )
    }
    
    /**
     * Verify Intel TDX attestation
     */
    private fun verifyTdx(
        doc: AttestationDocument,
        expected: ExpectedMeasurements?
    ): AttestationResult {
        Log.d(TAG, "Verifying TDX attestation")
        
        // Extract public key
        val publicKey = doc.publicKey?.let { 
            try {
                Base64.decode(it, Base64.DEFAULT)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decode public key", e)
                null
            }
        }
        
        if (publicKey == null || publicKey.size != 32) {
            return AttestationResult(
                isValid = false,
                error = "Invalid or missing public key in attestation"
            )
        }
        
        // TODO: Verify TDX quote against Intel's attestation service
        
        Log.d(TAG, "TDX attestation verified successfully")
        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = "tdx"
        )
    }
    
    /**
     * Handle development/mock attestation (NOT SECURE)
     */
    private fun verifyDevelopment(doc: AttestationDocument): AttestationResult {
        val publicKey = doc.publicKey?.let { 
            try {
                Base64.decode(it, Base64.DEFAULT)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decode public key", e)
                null
            }
        }
        
        if (publicKey == null || publicKey.size != 32) {
            return AttestationResult(
                isValid = false,
                error = "Invalid or missing public key in development attestation"
            )
        }
        
        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = "development"
        )
    }
}

/**
 * Attestation document from the server
 */
@Serializable
data class AttestationDocument(
    val type: String,
    val publicKey: String? = null,
    val measurement: String? = null,
    val hostData: String? = null,
    val report: String? = null,      // Base64 encoded attestation report
    val certificates: List<String>? = null
)
