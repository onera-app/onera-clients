package chat.onera.mobile.domain.model

data class Folder(
    val id: String,
    val name: String,
    val parentId: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val chatCount: Int = 0,
    val noteCount: Int = 0,
    val createdAt: Long,
    val updatedAt: Long
)
