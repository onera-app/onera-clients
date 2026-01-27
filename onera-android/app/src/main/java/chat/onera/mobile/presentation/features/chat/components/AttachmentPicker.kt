package chat.onera.mobile.presentation.features.chat.components

import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.domain.model.AttachmentType
import java.util.UUID

private const val TAG = "AttachmentPicker"

/**
 * Bottom sheet for selecting attachments using Android's modern APIs:
 * - PickVisualMedia for photo picker (Android 13+)
 * - TakePicturePreview for camera capture
 * - OpenDocument for file picker
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttachmentPickerSheet(
    onAttachmentSelected: (Attachment) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState()
    
    // Photo picker launcher (Android 13+ photo picker)
    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri: Uri? ->
        Log.d(TAG, "Photo picker result: $uri")
        uri?.let {
            val attachment = createAttachmentFromUri(context, it, AttachmentType.IMAGE)
            Log.d(TAG, "Created attachment: ${attachment.fileName}, type: ${attachment.mimeType}")
            onAttachmentSelected(attachment)
        }
        onDismiss()
    }
    
    // Camera capture launcher
    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        Log.d(TAG, "Camera result: bitmap is ${if (bitmap != null) "not null" else "null"}")
        bitmap?.let {
            // For camera captures, we create a temporary URI
            // In a real app, you'd save the bitmap to a file and use that URI
            val attachment = Attachment(
                id = UUID.randomUUID().toString(),
                uri = Uri.EMPTY, // Would be the saved file URI
                type = AttachmentType.IMAGE,
                fileName = "photo_${System.currentTimeMillis()}.jpg",
                mimeType = "image/jpeg"
            )
            Log.d(TAG, "Created camera attachment: ${attachment.fileName}")
            onAttachmentSelected(attachment)
        }
        onDismiss()
    }
    
    // Document picker launcher
    val documentPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        Log.d(TAG, "Document picker result: $uri")
        uri?.let {
            val attachment = createAttachmentFromUri(context, it, AttachmentType.FILE)
            Log.d(TAG, "Created document attachment: ${attachment.fileName}, type: ${attachment.mimeType}")
            onAttachmentSelected(attachment)
        }
        onDismiss()
    }
    
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
        tonalElevation = 0.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 32.dp)
        ) {
            Text(
                text = "Add Attachment",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp)
            )
            
            // Photo Library option
            AttachmentOption(
                icon = Icons.Outlined.PhotoLibrary,
                title = "Photo Library",
                subtitle = "Choose from your photos",
                onClick = {
                    photoPickerLauncher.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                }
            )
            
            // Camera option
            AttachmentOption(
                icon = Icons.Outlined.CameraAlt,
                title = "Take Photo",
                subtitle = "Use your camera",
                onClick = {
                    cameraLauncher.launch(null)
                }
            )
            
            // File option
            AttachmentOption(
                icon = Icons.Outlined.Description,
                title = "Choose File",
                subtitle = "PDF, documents, and more",
                onClick = {
                    documentPickerLauncher.launch(
                        arrayOf(
                            "application/pdf",
                            "text/*",
                            "application/json",
                            "image/*"
                        )
                    )
                }
            )
        }
    }
}

@Composable
private fun AttachmentOption(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceContainerLow
    ) {
        ListItem(
            headlineContent = { 
                Text(
                    text = title,
                    color = MaterialTheme.colorScheme.onSurface
                ) 
            },
            supportingContent = { 
                Text(
                    text = subtitle,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                ) 
            },
            leadingContent = {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
            colors = ListItemDefaults.colors(
                containerColor = MaterialTheme.colorScheme.surfaceContainerLow
            )
        )
    }
}

private fun createAttachmentFromUri(
    context: android.content.Context,
    uri: Uri,
    type: AttachmentType
): Attachment {
    val contentResolver = context.contentResolver
    val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
    
    // Get file name from cursor
    var fileName = "attachment_${System.currentTimeMillis()}"
    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) {
            val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0) {
                fileName = cursor.getString(nameIndex)
            }
        }
    }
    
    // Get file size
    var size = 0L
    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
        if (cursor.moveToFirst()) {
            val sizeIndex = cursor.getColumnIndex(android.provider.OpenableColumns.SIZE)
            if (sizeIndex >= 0) {
                size = cursor.getLong(sizeIndex)
            }
        }
    }
    
    return Attachment(
        id = UUID.randomUUID().toString(),
        uri = uri,
        type = if (mimeType.startsWith("image/")) AttachmentType.IMAGE else type,
        fileName = fileName,
        mimeType = mimeType,
        size = size
    )
}
