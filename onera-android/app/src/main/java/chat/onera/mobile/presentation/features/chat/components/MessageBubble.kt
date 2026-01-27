package chat.onera.mobile.presentation.features.chat.components

import android.net.Uri
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.VolumeUp
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import android.content.ClipData
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import kotlinx.coroutines.launch
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole
import chat.onera.mobile.presentation.components.MarkdownText
import coil.compose.AsyncImage
import coil.request.ImageRequest

@Composable
fun MessageBubble(
    message: Message,
    onCopy: () -> Unit,
    onRegenerate: (() -> Unit)?,
    onEdit: ((newContent: String, regenerate: Boolean) -> Unit)?,
    onSpeak: ((String) -> Unit)? = null,
    onStopSpeaking: (() -> Unit)? = null,
    isSpeakingThisMessage: Boolean = false,
    onNavigateToPreviousBranch: (() -> Unit)? = null,
    onNavigateToNextBranch: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val isUser = message.role == MessageRole.USER
    
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        if (isUser) {
            // User message - right-aligned bubble with edit support
            UserMessageBubble(
                content = message.content,
                imageUris = message.imageUris,
                isEdited = message.edited,
                onEdit = onEdit,
                modifier = Modifier.widthIn(max = 280.dp)
            )
        } else {
            // Assistant message - full width markdown
            AssistantMessageBubble(
                content = message.content,
                reasoningContent = message.reasoningContent,
                onCopy = onCopy,
                onRegenerate = onRegenerate,
                onSpeak = onSpeak,
                onStopSpeaking = onStopSpeaking,
                isSpeaking = isSpeakingThisMessage,
                branchIndex = message.branchIndex,
                siblingCount = message.siblingCount,
                onPreviousBranch = onNavigateToPreviousBranch,
                onNextBranch = onNavigateToNextBranch
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun UserMessageBubble(
    content: String,
    imageUris: List<String>,
    isEdited: Boolean,
    onEdit: ((newContent: String, regenerate: Boolean) -> Unit)?,
    modifier: Modifier = Modifier
) {
    var isEditing by remember { mutableStateOf(false) }
    var editText by remember { mutableStateOf(content) }
    var showContextMenu by remember { mutableStateOf(false) }
    val hapticFeedback = LocalHapticFeedback.current
    val focusRequester = remember { FocusRequester() }
    val context = LocalContext.current
    
    // Reset edit text when content changes (e.g., after save)
    LaunchedEffect(content) {
        editText = content
    }
    
    // Request focus when entering edit mode
    LaunchedEffect(isEditing) {
        if (isEditing) {
            focusRequester.requestFocus()
        }
    }
    
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Display attached images
        if (imageUris.isNotEmpty()) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                reverseLayout = true // Right align images
            ) {
                items(imageUris) { uriString ->
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant
                    ) {
                        AsyncImage(
                            model = ImageRequest.Builder(context)
                                .data(Uri.parse(uriString))
                                .crossfade(true)
                                .build(),
                            contentDescription = "Attached image",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(120.dp)
                                .clip(RoundedCornerShape(12.dp))
                        )
                    }
                }
            }
        }
        
        if (isEditing) {
            // Edit mode
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                tonalElevation = 2.dp
            ) {
                Column(
                    modifier = Modifier.padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Edit TextField
                    BasicTextField(
                        value = editText,
                        onValueChange = { editText = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focusRequester),
                        textStyle = MaterialTheme.typography.bodyLarge.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        decorationBox = { innerTextField ->
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .defaultMinSize(minHeight = 40.dp)
                            ) {
                                innerTextField()
                            }
                        }
                    )
                    
                    // Action buttons row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Cancel button
                        TextButton(
                            onClick = {
                                editText = content
                                isEditing = false
                            }
                        ) {
                            Text(
                                text = "Cancel",
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        
                        Spacer(modifier = Modifier.width(8.dp))
                        
                        // Save button (edit without regenerate)
                        TextButton(
                            onClick = {
                                val trimmed = editText.trim()
                                if (trimmed.isNotBlank() && trimmed != content) {
                                    onEdit?.invoke(trimmed, false)
                                }
                                isEditing = false
                            },
                            enabled = editText.trim().isNotBlank()
                        ) {
                            Text(
                                text = "Save",
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                        
                        Spacer(modifier = Modifier.width(8.dp))
                        
                        // Send button (edit and regenerate)
                        Button(
                            onClick = {
                                val trimmed = editText.trim()
                                if (trimmed.isNotBlank()) {
                                    onEdit?.invoke(trimmed, true)
                                }
                                isEditing = false
                            },
                            enabled = editText.trim().isNotBlank(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary
                            )
                        ) {
                            Text("Send")
                        }
                    }
                }
            }
        } else {
            // Normal display mode with context menu
            Box {
                Surface(
                    modifier = Modifier
                        .combinedClickable(
                            onClick = { },
                            onLongClick = {
                                if (onEdit != null) {
                                    hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                                    showContextMenu = true
                                }
                            }
                        ),
                    shape = RoundedCornerShape(20.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Text(
                        text = content,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                    )
                }
                
                // Context menu dropdown
                DropdownMenu(
                    expanded = showContextMenu,
                    onDismissRequest = { showContextMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Edit") },
                        onClick = {
                            showContextMenu = false
                            isEditing = true
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Outlined.Edit,
                                contentDescription = null
                            )
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Copy") },
                        onClick = {
                            showContextMenu = false
                            // Copy to clipboard would be handled here
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Outlined.ContentCopy,
                                contentDescription = null
                            )
                        }
                    )
                }
            }
            
            // Edited indicator
            if (isEdited) {
                Text(
                    text = "Edited",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp, end = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun AssistantMessageBubble(
    content: String,
    reasoningContent: String?,
    onCopy: () -> Unit,
    onRegenerate: (() -> Unit)?,
    onSpeak: ((String) -> Unit)? = null,
    onStopSpeaking: (() -> Unit)? = null,
    isSpeaking: Boolean = false,
    branchIndex: Int = 0,
    siblingCount: Int = 1,
    onPreviousBranch: (() -> Unit)? = null,
    onNextBranch: (() -> Unit)? = null
) {
    var showReasoning by remember { mutableStateOf(false) }
    var copiedFeedback by remember { mutableStateOf(false) }
    val hapticFeedback = LocalHapticFeedback.current
    val clipboard = LocalClipboard.current
    val coroutineScope = rememberCoroutineScope()
    
    LaunchedEffect(copiedFeedback) {
        if (copiedFeedback) {
            kotlinx.coroutines.delay(2000)
            copiedFeedback = false
        }
    }
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Reasoning indicator (if present)
        if (reasoningContent != null) {
            ReasoningIndicator(
                isExpanded = showReasoning,
                onClick = { showReasoning = !showReasoning }
            )
            
            if (showReasoning) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = reasoningContent,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }
        
        // Message content with code block copy support
        MarkdownText(
            markdown = content,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            onCopyCode = { code ->
                coroutineScope.launch {
                    clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("code", code)))
                }
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
            }
        )
        
        // Action buttons row with branch navigation
        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            // Branch navigation (if multiple branches exist)
            if (siblingCount > 1 && onPreviousBranch != null && onNextBranch != null) {
                BranchNavigationRow(
                    currentIndex = branchIndex,
                    totalCount = siblingCount,
                    onPrevious = onPreviousBranch,
                    onNext = onNextBranch
                )
                
                Spacer(modifier = Modifier.weight(1f))
            }
            // Copy button
            IconButton(
                onClick = {
                    onCopy()
                    copiedFeedback = true
                },
                modifier = Modifier.size(32.dp)
            ) {
                if (copiedFeedback) {
                    Text(
                        text = "Copied!",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary
                    )
                } else {
                    Icon(
                        imageVector = Icons.Outlined.ContentCopy,
                        contentDescription = "Copy",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            // Regenerate button
            if (onRegenerate != null) {
                IconButton(
                    onClick = onRegenerate,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Refresh,
                        contentDescription = "Regenerate",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            // Read aloud / Stop button
            IconButton(
                onClick = {
                    hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                    if (isSpeaking) {
                        onStopSpeaking?.invoke()
                    } else {
                        onSpeak?.invoke(content)
                    }
                },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Outlined.VolumeUp,
                    contentDescription = if (isSpeaking) "Stop Reading" else "Read Aloud",
                    modifier = Modifier.size(16.dp),
                    tint = if (isSpeaking) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ReasoningIndicator(
    isExpanded: Boolean,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = if (isExpanded) "Hide thinking" else "Show thinking",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
