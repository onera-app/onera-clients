package chat.onera.mobile.domain.model

data class Chat(
    val id: String,
    val title: String,
    val messages: List<Message> = emptyList(),
    val lastMessage: String?,
    val folderId: String? = null,
    val pinned: Boolean = false,
    val archived: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long,
    val isEncrypted: Boolean = true,
    /**
     * Per-chat encryption key (in memory only, never persisted).
     * This key is used to encrypt/decrypt the chat content.
     * It's encrypted with the master key before being sent to the server.
     */
    val encryptionKey: ByteArray? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        
        other as Chat
        
        if (id != other.id) return false
        if (title != other.title) return false
        if (messages != other.messages) return false
        if (lastMessage != other.lastMessage) return false
        if (folderId != other.folderId) return false
        if (pinned != other.pinned) return false
        if (archived != other.archived) return false
        if (createdAt != other.createdAt) return false
        if (updatedAt != other.updatedAt) return false
        if (isEncrypted != other.isEncrypted) return false
        if (encryptionKey != null) {
            if (other.encryptionKey == null) return false
            if (!encryptionKey.contentEquals(other.encryptionKey)) return false
        } else if (other.encryptionKey != null) return false
        
        return true
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + title.hashCode()
        result = 31 * result + messages.hashCode()
        result = 31 * result + (lastMessage?.hashCode() ?: 0)
        result = 31 * result + (folderId?.hashCode() ?: 0)
        result = 31 * result + pinned.hashCode()
        result = 31 * result + archived.hashCode()
        result = 31 * result + createdAt.hashCode()
        result = 31 * result + updatedAt.hashCode()
        result = 31 * result + isEncrypted.hashCode()
        result = 31 * result + (encryptionKey?.contentHashCode() ?: 0)
        return result
    }
}
