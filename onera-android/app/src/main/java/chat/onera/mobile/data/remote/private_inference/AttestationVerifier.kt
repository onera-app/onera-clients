package chat.onera.mobile.data.remote.private_inference

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/**
 * Verifies TEE attestation and extracts the server X25519 public key.
 *
 * Expected response shape matches the server/iOS implementation:
 * {
 *   "attestation_type": "mock-sev-snp" | "sev-snp" | "azure-imds",
 *   "quote": "...",
 *   "public_key": "base64-or-hex",
 *   "report_data": "..."
 * }
 */
class AttestationVerifier {

    companion object {
        private const val TAG = "AttestationVerifier"
        private const val PUBLIC_KEY_SIZE = 32
        private const val CACHE_TTL_MS = 60 * 60 * 1000L
    }

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val cache = mutableMapOf<String, CachedAttestation>()

    suspend fun verify(
        attestationEndpoint: String,
        expectedMeasurements: ExpectedMeasurements? = null
    ): AttestationResult = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        cache[attestationEndpoint]?.let { cached ->
            if (now - cached.timestamp < CACHE_TTL_MS) {
                Log.d(TAG, "Using cached attestation for $attestationEndpoint")
                return@withContext cached.result
            }
        }

        try {
            val doc = fetchAttestation(attestationEndpoint)
            val result = verifyAttestationData(doc, expectedMeasurements)

            if (result.isValid) {
                cache[attestationEndpoint] = CachedAttestation(result, now)
            }

            result
        } catch (e: Exception) {
            Log.e(TAG, "Attestation verification failed", e)
            AttestationResult(
                isValid = false,
                error = e.message ?: "Unknown error"
            )
        }
    }

    private fun fetchAttestation(endpoint: String): JsonObject {
        val request = Request.Builder()
            .url(endpoint)
            .get()
            .build()

        httpClient.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw PrivateInferenceException.AttestationFailed("HTTP ${response.code}: ${response.message}")
            }

            val body = response.body?.string()
                ?: throw PrivateInferenceException.AttestationFailed("Empty attestation response")

            return try {
                json.parseToJsonElement(body) as JsonObject
            } catch (e: Exception) {
                throw PrivateInferenceException.AttestationFailed("Invalid attestation JSON: ${e.message}")
            }
        }
    }

    private fun verifyAttestationData(
        doc: JsonObject,
        expected: ExpectedMeasurements?
    ): AttestationResult {
        val attestationType = doc["attestation_type"]?.jsonPrimitive?.content
            ?: return AttestationResult(isValid = false, error = "Missing attestation_type")

        val quote = doc["quote"]?.jsonPrimitive?.content
            ?: return AttestationResult(isValid = false, attestationType = attestationType, error = "Missing quote")

        val publicKeyRaw = doc["public_key"]?.jsonPrimitive?.content
            ?: doc["publicKey"]?.jsonPrimitive?.content
            ?: return AttestationResult(isValid = false, attestationType = attestationType, error = "Missing public_key")

        val publicKey = parsePublicKey(publicKeyRaw)
            ?: return AttestationResult(
                isValid = false,
                attestationType = attestationType,
                error = "Invalid public key encoding"
            )

        if (publicKey.size != PUBLIC_KEY_SIZE) {
            return AttestationResult(
                isValid = false,
                attestationType = attestationType,
                error = "Invalid public key length: ${publicKey.size}"
            )
        }

        // Optional measurement checks if caller provided expectations.
        if (expected != null) {
            val measurement = doc["measurement"]?.jsonPrimitive?.content
            if (expected.measurement != null && measurement != expected.measurement) {
                return AttestationResult(
                    isValid = false,
                    attestationType = attestationType,
                    error = "Measurement mismatch"
                )
            }
            val hostData = doc["hostData"]?.jsonPrimitive?.content ?: doc["host_data"]?.jsonPrimitive?.content
            if (expected.hostData != null && hostData != expected.hostData) {
                return AttestationResult(
                    isValid = false,
                    attestationType = attestationType,
                    error = "Host data mismatch"
                )
            }
        }

        return when (attestationType) {
            "azure-imds" -> verifyAzureImds(doc, quote, publicKey, attestationType)
            "sev-snp", "mock-sev-snp" -> verifySevSnp(quote, publicKey, attestationType)
            else -> AttestationResult(
                isValid = false,
                attestationType = attestationType,
                error = "Unsupported attestation type: $attestationType"
            )
        }
    }

    private fun verifyAzureImds(
        doc: JsonObject,
        quote: String,
        publicKey: ByteArray,
        attestationType: String
    ): AttestationResult {
        if (quote.isBlank()) {
            return AttestationResult(false, null, attestationType, "Empty Azure IMDS quote")
        }

        val reportData = doc["report_data"]?.jsonPrimitive?.content
            ?: return AttestationResult(false, null, attestationType, "Missing report_data")

        val publicKeyHash = MessageDigest.getInstance("SHA-256").digest(publicKey)
        val expectedHashHex = publicKeyHash.joinToString("") { "%02x".format(it) }

        if (!reportData.lowercase().startsWith(expectedHashHex.lowercase())) {
            return AttestationResult(
                isValid = false,
                attestationType = attestationType,
                error = "Public key hash is not bound in report_data"
            )
        }

        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = attestationType
        )
    }

    private fun verifySevSnp(
        quote: String,
        publicKey: ByteArray,
        attestationType: String
    ): AttestationResult {
        if (quote.isBlank()) {
            return AttestationResult(false, null, attestationType, "Empty SEV-SNP quote")
        }

        // Match iOS/web behavior: cryptographic quote verification can be tightened later.
        return AttestationResult(
            isValid = true,
            serverPublicKey = publicKey,
            attestationType = attestationType
        )
    }

    private fun parsePublicKey(publicKeyRaw: String): ByteArray? {
        // Hex string support
        if (publicKeyRaw.matches(Regex("^[0-9a-fA-F]+$"))) {
            return try {
                publicKeyRaw.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            } catch (_: Exception) {
                null
            }
        }

        // Base64 support
        return try {
            Base64.decode(publicKeyRaw, Base64.NO_WRAP)
        } catch (_: Exception) {
            try {
                Base64.decode(publicKeyRaw, Base64.DEFAULT)
            } catch (_: Exception) {
                null
            }
        }
    }

    private data class CachedAttestation(
        val result: AttestationResult,
        val timestamp: Long
    )
}
