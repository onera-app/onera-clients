package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ChatCompletionRequest(
    @SerialName("chat_id")
    val chatId: String,
    val messages: List<MessageDto>,
    val stream: Boolean = true
)

@Serializable
data class MessageDto(
    val role: String,
    val content: String
)

@Serializable
data class ChatCompletionResponse(
    val id: String,
    val choices: List<ChoiceDto>,
    val usage: UsageDto? = null
)

@Serializable
data class ChoiceDto(
    val index: Int,
    val message: MessageDto,
    @SerialName("finish_reason")
    val finishReason: String?
)

@Serializable
data class UsageDto(
    @SerialName("prompt_tokens")
    val promptTokens: Int,
    @SerialName("completion_tokens")
    val completionTokens: Int,
    @SerialName("total_tokens")
    val totalTokens: Int
)

// Streaming response
@Serializable
data class StreamChunk(
    val id: String,
    val choices: List<StreamChoiceDto>
)

@Serializable
data class StreamChoiceDto(
    val index: Int,
    val delta: DeltaDto,
    @SerialName("finish_reason")
    val finishReason: String?
)

@Serializable
data class DeltaDto(
    val role: String? = null,
    val content: String? = null
)
