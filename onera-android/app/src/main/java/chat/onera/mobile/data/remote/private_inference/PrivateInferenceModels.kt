package chat.onera.mobile.data.remote.private_inference

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Prefix for private model IDs
 */
const val PRIVATE_MODEL_PREFIX = "private:"

/**
 * Check if a model ID is a private inference model
 */
fun isPrivateModel(modelId: String): Boolean = modelId.startsWith(PRIVATE_MODEL_PREFIX)

/**
 * Parse a private model ID to get the actual model name
 */
fun parsePrivateModelId(modelId: String): String = 
    modelId.removePrefix(PRIVATE_MODEL_PREFIX)

// ============================================================================
// Enclave Configuration
// ============================================================================

/**
 * Configuration for connecting to a private inference enclave
 */
data class EnclaveConfig(
    val id: String,
    val name: String,
    val endpoint: String,          // HTTP endpoint for REST calls
    val wsEndpoint: String,        // WebSocket endpoint for streaming
    val attestationEndpoint: String,
    val allowUnverified: Boolean = false,  // Development only
    val expectedMeasurements: ExpectedMeasurements? = null
)

/**
 * Expected TEE measurements for attestation verification
 */
data class ExpectedMeasurements(
    val measurement: String? = null,
    val hostData: String? = null
)

// ============================================================================
// API Request/Response Models
// ============================================================================

/**
 * Request to get an enclave assignment from the server
 */
@Serializable
data class RequestEnclaveInput(
    @SerialName("modelId")
    val modelId: String,
    val tier: String = "shared",  // "shared" or "dedicated"
    @SerialName("sessionId")
    val sessionId: String
)

/**
 * Response from requesting an enclave
 */
@Serializable
data class RequestEnclaveResponse(
    @SerialName("assignmentId")
    val assignmentId: String,
    val enclave: EnclaveInfo,
    @SerialName("wsEndpoint")
    val wsEndpoint: String,
    @SerialName("attestationEndpoint")
    val attestationEndpoint: String
)

@Serializable
data class EnclaveInfo(
    val id: String,
    val host: String,
    val port: Int
)

/**
 * Request to release an enclave assignment
 */
@Serializable
data class ReleaseEnclaveInput(
    @SerialName("assignmentId")
    val assignmentId: String
)

/**
 * Private model info from server
 */
@Serializable
data class PrivateModelInfo(
    val id: String,
    val name: String,
    @SerialName("enclaveId")
    val enclaveId: String,
    @SerialName("maxContextLength")
    val maxContextLength: Int? = null,
    val capabilities: List<String>? = null
)

// ============================================================================
// Streaming Events
// ============================================================================

/**
 * Events emitted during private inference streaming
 */
sealed interface PrivateInferenceEvent {
    /** Text content delta */
    data class TextDelta(val text: String) : PrivateInferenceEvent
    
    /** Stream finished */
    data class Finish(
        val reason: String,
        val promptTokens: Int = 0,
        val completionTokens: Int = 0
    ) : PrivateInferenceEvent
    
    /** Error occurred */
    data class Error(val message: String, val cause: Throwable? = null) : PrivateInferenceEvent
}

// ============================================================================
// Attestation
// ============================================================================

/**
 * Result of attestation verification
 */
data class AttestationResult(
    val isValid: Boolean,
    val serverPublicKey: ByteArray? = null,
    val attestationType: String = "unknown",
    val error: String? = null
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

// ============================================================================
// Errors
// ============================================================================

/**
 * Exceptions specific to private inference
 */
sealed class PrivateInferenceException(
    message: String,
    cause: Throwable? = null
) : Exception(message, cause) {
    
    class AttestationFailed(details: String) : 
        PrivateInferenceException("Attestation verification failed: $details")
    
    class ConnectionTimeout : 
        PrivateInferenceException("Connection timeout")
    
    class ConnectionClosed : 
        PrivateInferenceException("Connection closed")
    
    class NotConnected : 
        PrivateInferenceException("Not connected to inference endpoint")
    
    class HandshakeFailed(details: String) : 
        PrivateInferenceException("Noise handshake failed: $details")
    
    class EncryptionFailed : 
        PrivateInferenceException("Failed to encrypt message")
    
    class DecryptionFailed : 
        PrivateInferenceException("Failed to decrypt message")
}
