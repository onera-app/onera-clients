package chat.onera.mobile.domain.model

import android.net.Uri

/**
 * Represents a file attachment for a chat message.
 */
data class Attachment(
    val id: String,
    val uri: Uri,
    val type: AttachmentType,
    val fileName: String,
    val mimeType: String,
    val size: Long = 0
)

enum class AttachmentType {
    IMAGE,
    FILE
}
