package chat.onera.mobile.domain.model

data class Message(
    val id: String,
    val chatId: String,
    val role: MessageRole,
    val content: String,
    val createdAt: Long,
    val isEncrypted: Boolean = true,
    val model: String? = null,
    val reasoningContent: String? = null,
    val edited: Boolean = false,
    val editedAt: Long? = null,
    // Branch navigation fields
    val parentMessageId: String? = null, // ID of the message this branches from (null for root/original)
    val branchIndex: Int = 0, // Index of this branch among siblings (0-indexed)
    val siblingCount: Int = 1, // Total number of siblings including this message
    // Attachments
    val imageUris: List<String> = emptyList() // URIs of attached images (local only, not synced)
)

enum class MessageRole {
    USER,
    ASSISTANT,
    SYSTEM
}
