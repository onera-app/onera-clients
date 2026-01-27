package chat.onera.mobile.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * DTOs for encrypted chat synchronization with the server.
 * Matches the iOS and web implementations for E2EE chat storage.
 * 
 * Note: Server chats.list returns a direct array, not wrapped in an object.
 */

// ===== Chat List =====

/**
 * Encrypted chat summary returned by server.
 * Server returns List<EncryptedChatSummary> directly from chats.list
 */
@Serializable
data class EncryptedChatSummary(
    val id: String,
    val userId: String,
    val isEncrypted: Boolean,
    val encryptedChatKey: String,
    val chatKeyNonce: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val folderId: String? = null,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Get Single Chat =====

@Serializable
data class ChatGetRequest(
    val chatId: String
)

@Serializable
data class ChatGetResponse(
    val id: String,
    val userId: String,
    val isEncrypted: Boolean,
    val encryptedChatKey: String,
    val chatKeyNonce: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedChat: String,
    val chatNonce: String,
    val folderId: String? = null,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Create Chat =====

@Serializable
data class ChatCreateRequest(
    val encryptedChatKey: String,
    val chatKeyNonce: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedChat: String,
    val chatNonce: String,
    val folderId: String? = null
)

/**
 * Server returns full chat object on create.
 * We use the same structure as ChatGetResponse.
 */
@Serializable
data class ChatCreateResponse(
    val id: String,
    val userId: String,
    val isEncrypted: Boolean,
    val encryptedChatKey: String,
    val chatKeyNonce: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedChat: String,
    val chatNonce: String,
    val folderId: String? = null,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Update Chat =====

@Serializable
data class ChatUpdateRequest(
    val chatId: String,
    val encryptedTitle: String? = null,
    val titleNonce: String? = null,
    val encryptedChat: String? = null,
    val chatNonce: String? = null,
    val folderId: String? = null,
    val pinned: Boolean? = null,
    val archived: Boolean? = null
)

/**
 * Server returns full chat object on update.
 */
@Serializable
data class ChatUpdateResponse(
    val id: String,
    val userId: String,
    val isEncrypted: Boolean,
    val encryptedChatKey: String,
    val chatKeyNonce: String,
    val encryptedTitle: String,
    val titleNonce: String,
    val encryptedChat: String,
    val chatNonce: String,
    val folderId: String? = null,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

// ===== Remove Chat =====

@Serializable
data class ChatRemoveRequest(
    val chatId: String
)

@Serializable
data class ChatRemoveResponse(
    val success: Boolean
)

// ===== Chat Data (for encryption/decryption) =====

/**
 * Container for chat messages that gets encrypted/decrypted.
 * This matches the web/iOS structure.
 */
@Serializable
data class ChatData(
    val messages: List<ChatMessageDto>
)

@Serializable
data class ChatMessageDto(
    val id: String,
    val role: String,  // "user", "assistant", "system"
    val content: String,
    val model: String? = null,
    val reasoningContent: String? = null,
    val parentMessageId: String? = null,
    val branchIndex: Int = 0,
    val siblingCount: Int = 1,
    val createdAt: Long
)

// ===== Encryption Result =====

/**
 * Result of encryption operation containing ciphertext and nonce.
 */
data class EncryptedData(
    val ciphertext: ByteArray,
    val nonce: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as EncryptedData
        if (!ciphertext.contentEquals(other.ciphertext)) return false
        if (!nonce.contentEquals(other.nonce)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = ciphertext.contentHashCode()
        result = 31 * result + nonce.contentHashCode()
        return result
    }
}
