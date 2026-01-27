package chat.onera.mobile.data.remote.llm

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Request Models
// ============================================================================

/**
 * OpenAI-compatible chat completion request
 */
@Serializable
data class ChatCompletionRequest(
    val model: String,
    val messages: List<ChatMessage>,
    val stream: Boolean = true,
    @SerialName("max_tokens")
    val maxTokens: Int? = null,
    val temperature: Double? = null,
    @SerialName("top_p")
    val topP: Double? = null,
    @SerialName("frequency_penalty")
    val frequencyPenalty: Double? = null,
    @SerialName("presence_penalty")
    val presencePenalty: Double? = null,
    @SerialName("stop")
    val stop: List<String>? = null
)

/**
 * Chat message in OpenAI format
 */
@Serializable
data class ChatMessage(
    val role: String,
    val content: String
) {
    companion object {
        const val ROLE_SYSTEM = "system"
        const val ROLE_USER = "user"
        const val ROLE_ASSISTANT = "assistant"
        
        fun system(content: String) = ChatMessage(ROLE_SYSTEM, content)
        fun user(content: String) = ChatMessage(ROLE_USER, content)
        fun assistant(content: String) = ChatMessage(ROLE_ASSISTANT, content)
    }
}

// ============================================================================
// Multimodal Message Models (Vision API)
// ============================================================================

/**
 * Image data for multimodal messages
 */
data class ImageData(
    val base64Data: String,
    val mimeType: String
)

/**
 * Content part for multimodal messages
 */
@Serializable
data class TextContentPart(
    val type: String = "text",
    val text: String
)

@Serializable
data class ImageContentPart(
    val type: String = "image_url",
    @SerialName("image_url")
    val imageUrl: ImageUrlDetail
)

@Serializable
data class ImageUrlDetail(
    val url: String
)

/**
 * Chat message with multimodal content (for vision)
 */
@Serializable
data class MultimodalChatMessage(
    val role: String,
    val content: kotlinx.serialization.json.JsonArray
)

// ============================================================================
// Response Models (Non-streaming)
// ============================================================================

/**
 * OpenAI-compatible chat completion response
 */
@Serializable
data class ChatCompletionResponse(
    val id: String,
    val `object`: String? = null,
    val created: Long? = null,
    val model: String? = null,
    val choices: List<Choice>,
    val usage: Usage? = null
)

@Serializable
data class Choice(
    val index: Int,
    val message: ChatMessage? = null,
    @SerialName("finish_reason")
    val finishReason: String? = null
)

@Serializable
data class Usage(
    @SerialName("prompt_tokens")
    val promptTokens: Int,
    @SerialName("completion_tokens")
    val completionTokens: Int,
    @SerialName("total_tokens")
    val totalTokens: Int
)

// ============================================================================
// Streaming Response Models
// ============================================================================

/**
 * SSE streaming chunk for chat completions
 */
@Serializable
data class StreamChunk(
    val id: String? = null,
    val `object`: String? = null,
    val created: Long? = null,
    val model: String? = null,
    val choices: List<StreamChoice> = emptyList()
)

@Serializable
data class StreamChoice(
    val index: Int = 0,
    val delta: Delta? = null,
    @SerialName("finish_reason")
    val finishReason: String? = null
)

@Serializable
data class Delta(
    val role: String? = null,
    val content: String? = null,
    @SerialName("reasoning_content")
    val reasoningContent: String? = null
)

// ============================================================================
// Models Listing Response
// ============================================================================

/**
 * Response from /models endpoint
 */
@Serializable
data class ModelsResponse(
    val `object`: String? = null,
    val data: List<ModelInfo> = emptyList()
)

@Serializable
data class ModelInfo(
    val id: String,
    val `object`: String? = null,
    val created: Long? = null,
    @SerialName("owned_by")
    val ownedBy: String? = null
)

// ============================================================================
// Credential Models
// ============================================================================

/**
 * Decrypted credential ready for API calls
 */
data class DecryptedCredential(
    val id: String,
    val provider: LLMProvider,
    val apiKey: String,
    val name: String,
    val baseUrl: String? = null,
    val orgId: String? = null
) {
    /**
     * Get the effective base URL (custom or provider default)
     */
    val effectiveBaseUrl: String
        get() = baseUrl?.takeIf { it.isNotBlank() } ?: provider.defaultBaseUrl
}

// ============================================================================
// Stream Events
// ============================================================================

/**
 * Events emitted during streaming
 */
sealed interface StreamEvent {
    /** Text content delta */
    data class Text(val content: String) : StreamEvent
    
    /** Reasoning/thinking content delta (for models like DeepSeek R1) */
    data class Reasoning(val content: String) : StreamEvent
    
    /** Tool call event */
    data class ToolCall(val name: String, val arguments: String) : StreamEvent
    
    /** Stream completed successfully */
    data object Done : StreamEvent
    
    /** Error occurred during streaming */
    data class Error(val message: String, val cause: Throwable? = null) : StreamEvent
}

// ============================================================================
// Error Models
// ============================================================================

/**
 * Error response from LLM APIs
 */
@Serializable
data class LLMErrorResponse(
    val error: LLMErrorDetail? = null
)

@Serializable
data class LLMErrorDetail(
    val message: String? = null,
    val type: String? = null,
    val code: String? = null
)

/**
 * LLM-specific exceptions
 */
sealed class LLMException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class AuthenticationFailed(message: String = "Authentication failed") : LLMException(message)
    class RateLimited(val retryAfter: Long? = null) : LLMException("Rate limited${retryAfter?.let { ", retry after ${it}s" } ?: ""}")
    class InvalidRequest(message: String) : LLMException(message)
    class ModelNotFound(model: String) : LLMException("Model not found: $model")
    class NetworkError(message: String, cause: Throwable? = null) : LLMException(message, cause)
    class StreamingError(message: String, cause: Throwable? = null) : LLMException(message, cause)
    class ProviderError(message: String) : LLMException(message)
}
