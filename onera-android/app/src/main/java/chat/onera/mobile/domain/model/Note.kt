package chat.onera.mobile.domain.model

data class Note(
    val id: String,
    val title: String,
    val content: String,
    val folderId: String? = null,
    val isPinned: Boolean = false,
    val isEncrypted: Boolean = true,
    val createdAt: Long,
    val updatedAt: Long
)
