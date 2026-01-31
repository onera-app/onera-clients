package chat.onera.mobile.presentation.features.main.handlers

import android.content.Context
import android.net.Uri
import android.util.Base64
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.domain.model.Attachment
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject

/**
 * Processor for handling file attachments.
 * Encapsulates attachment conversion and processing logic.
 */
class AttachmentProcessor @Inject constructor(
    @ApplicationContext private val context: Context
) {
    /**
     * Convert an attachment URI to ImageData (base64) for LLM API.
     * 
     * @param attachment The attachment to convert
     * @return ImageData containing base64 encoded image, or null if conversion fails
     */
    suspend fun convertToImageData(attachment: Attachment): ImageData? {
        return withContext(Dispatchers.IO) {
            try {
                if (attachment.uri == Uri.EMPTY) return@withContext null
                
                context.contentResolver.openInputStream(attachment.uri)?.use { inputStream ->
                    val bytes = inputStream.readBytes()
                    val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                    ImageData(
                        base64Data = base64,
                        mimeType = attachment.mimeType
                    )
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to convert attachment: ${attachment.fileName}")
                null
            }
        }
    }

    /**
     * Convert multiple attachments to ImageData list.
     * 
     * @param attachments List of attachments to convert
     * @return List of successfully converted ImageData
     */
    suspend fun convertAllToImageData(attachments: List<Attachment>): List<ImageData> {
        return attachments.mapNotNull { attachment ->
            convertToImageData(attachment)
        }
    }

    /**
     * Check if the attachment is an image based on MIME type.
     */
    fun isImage(attachment: Attachment): Boolean {
        return attachment.mimeType.startsWith("image/")
    }

    /**
     * Get the file size of an attachment in bytes.
     * Returns null if size cannot be determined.
     */
    suspend fun getFileSize(attachment: Attachment): Long? {
        return withContext(Dispatchers.IO) {
            try {
                if (attachment.uri == Uri.EMPTY) return@withContext null
                
                context.contentResolver.openInputStream(attachment.uri)?.use { inputStream ->
                    inputStream.available().toLong()
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to get file size: ${attachment.fileName}")
                null
            }
        }
    }

    companion object {
        // Maximum file size for attachments (10MB)
        const val MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024L
        
        // Supported image MIME types
        val SUPPORTED_IMAGE_TYPES = setOf(
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp"
        )
    }
}
