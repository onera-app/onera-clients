package chat.onera.mobile.presentation.components

import android.content.Intent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.NavigateBefore
import androidx.compose.material.icons.automirrored.filled.NavigateNext
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole

/**
 * Represents a code artifact extracted from chat messages.
 */
data class CodeArtifact(
    val id: String,
    val title: String,
    val content: String,
    val language: String?,
    val messageId: String
)

/**
 * Extracts code artifacts from assistant messages by scanning for markdown code blocks.
 */
object ArtifactExtractor {

    private val codeBlockPattern = Regex("```(\\w*)\\n?([\\s\\S]*?)```")

    fun extractArtifacts(messages: List<Message>): List<CodeArtifact> {
        val artifacts = mutableListOf<CodeArtifact>()
        var snippetCounter = 0

        messages
            .filter { it.role == MessageRole.ASSISTANT }
            .forEach { message ->
                codeBlockPattern.findAll(message.content).forEach { match ->
                    snippetCounter++
                    val language = match.groupValues[1].ifBlank { null }
                    val code = match.groupValues[2].trimEnd()

                    if (code.isNotBlank()) {
                        val title = buildTitle(language, code, snippetCounter)
                        artifacts.add(
                            CodeArtifact(
                                id = "${message.id}_snippet_$snippetCounter",
                                title = title,
                                content = code,
                                language = language,
                                messageId = message.id
                            )
                        )
                    }
                }
            }

        return artifacts
    }

    private fun buildTitle(language: String?, code: String, index: Int): String {
        if (language != null) {
            return "${language.replaceFirstChar { it.uppercase() }} snippet $index"
        }
        // Use first meaningful line, capped at 40 chars
        val firstLine = code.lines().firstOrNull { it.isNotBlank() }?.take(40) ?: "Snippet $index"
        return if (firstLine.length >= 40) "$firstLine..." else firstLine
    }
}

/**
 * Bottom sheet panel displaying extracted code artifacts with navigation.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ArtifactsPanel(
    artifacts: List<CodeArtifact>,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var currentIndex by remember { mutableIntStateOf(0) }
    val context = LocalContext.current

    // Clamp index if artifacts change
    val safeIndex = currentIndex.coerceIn(0, (artifacts.size - 1).coerceAtLeast(0))
    if (safeIndex != currentIndex) currentIndex = safeIndex

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        if (artifacts.isEmpty()) {
            // Empty state
            ArtifactsEmptyState(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(48.dp)
            )
        } else {
            val artifact = artifacts[safeIndex]

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp)
            ) {
                // Header: title, language badge, navigation
                ArtifactHeader(
                    artifact = artifact,
                    currentIndex = safeIndex,
                    totalCount = artifacts.size,
                    onPrevious = {
                        if (safeIndex > 0) currentIndex = safeIndex - 1
                    },
                    onNext = {
                        if (safeIndex < artifacts.size - 1) currentIndex = safeIndex + 1
                    },
                    onClose = onDismiss
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Code content
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = false)
                        .heightIn(min = 120.dp, max = 400.dp)
                        .padding(horizontal = 16.dp),
                    shape = MaterialTheme.shapes.medium,
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Box(
                        modifier = Modifier
                            .verticalScroll(rememberScrollState())
                            .horizontalScroll(rememberScrollState())
                            .padding(12.dp)
                    ) {
                        Text(
                            text = artifact.content,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                fontSize = 13.sp,
                                lineHeight = 20.sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Action bar: Copy + Share
                ArtifactActionBar(
                    onCopy = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("Code", artifact.content))
                        Toast.makeText(context, "Copied to clipboard", Toast.LENGTH_SHORT).show()
                    },
                    onShare = {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, artifact.content)
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "Share code")
                        context.startActivity(shareIntent)
                    },
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }
        }
    }
}

@Composable
private fun ArtifactHeader(
    artifact: CodeArtifact,
    currentIndex: Int,
    totalCount: Int,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onClose: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        // Top row: close button + counter
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Artifacts",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )

            if (totalCount > 1) {
                Text(
                    text = "${currentIndex + 1} / $totalCount",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            IconButton(onClick = onClose, modifier = Modifier.size(36.dp)) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Close",
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        // Title + language badge + navigation
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Language badge
            if (artifact.language != null) {
                Surface(
                    shape = MaterialTheme.shapes.small,
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = artifact.language.uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            // Title
            Text(
                text = artifact.title,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )

            // Prev/Next navigation
            if (totalCount > 1) {
                Row {
                    IconButton(
                        onClick = onPrevious,
                        enabled = currentIndex > 0,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.NavigateBefore,
                            contentDescription = "Previous",
                            modifier = Modifier.size(20.dp)
                        )
                    }
                    IconButton(
                        onClick = onNext,
                        enabled = currentIndex < totalCount - 1,
                        modifier = Modifier.size(32.dp)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.NavigateNext,
                            contentDescription = "Next",
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ArtifactActionBar(
    onCopy: () -> Unit,
    onShare: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        OutlinedButton(
            onClick = onCopy,
            modifier = Modifier.weight(1f)
        ) {
            Icon(
                imageVector = Icons.Outlined.ContentCopy,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("Copy")
        }

        OutlinedButton(
            onClick = onShare,
            modifier = Modifier.weight(1f)
        ) {
            Icon(
                imageVector = Icons.Outlined.Share,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text("Share")
        }
    }
}

@Composable
private fun ArtifactsEmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "No Artifacts",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Code blocks from the conversation will appear here",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
