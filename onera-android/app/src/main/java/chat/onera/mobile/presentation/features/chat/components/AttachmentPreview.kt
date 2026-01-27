package chat.onera.mobile.presentation.features.chat.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.domain.model.AttachmentType
import coil.compose.AsyncImage
import coil.request.ImageRequest

/**
 * Horizontal row of attachment previews shown above the message input.
 */
@Composable
fun AttachmentPreviewRow(
    attachments: List<Attachment>,
    onRemove: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (attachments.isEmpty()) return
    
    LazyRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 16.dp)
    ) {
        items(
            items = attachments,
            key = { it.id }
        ) { attachment ->
            AttachmentPreviewItem(
                attachment = attachment,
                onRemove = { onRemove(attachment.id) }
            )
        }
    }
}

@Composable
private fun AttachmentPreviewItem(
    attachment: Attachment,
    onRemove: () -> Unit
) {
    Box(
        modifier = Modifier.size(72.dp)
    ) {
        when (attachment.type) {
            AttachmentType.IMAGE -> {
                ImagePreview(
                    attachment = attachment,
                    modifier = Modifier.fillMaxSize()
                )
            }
            AttachmentType.FILE -> {
                FilePreview(
                    attachment = attachment,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
        
        // Remove button
        IconButton(
            onClick = onRemove,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 4.dp, y = (-4).dp)
                .size(20.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surface)
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Remove attachment",
                modifier = Modifier.size(12.dp),
                tint = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun ImagePreview(
    attachment: Attachment,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        AsyncImage(
            model = ImageRequest.Builder(context)
                .data(attachment.uri)
                .crossfade(true)
                .build(),
            contentDescription = attachment.fileName,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
private fun FilePreview(
    attachment: Attachment,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Outlined.Description,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            
            Text(
                text = attachment.fileName.take(10) + if (attachment.fileName.length > 10) "..." else "",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1
            )
        }
    }
}
