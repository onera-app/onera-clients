package chat.onera.mobile.presentation.features.chat.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.PromptSummary
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessageInputBar(
    value: String,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
    isStreaming: Boolean,
    onStopStreaming: () -> Unit,
    isEncrypted: Boolean,
    modifier: Modifier = Modifier,
    onAttachmentClick: (() -> Unit)? = null,
    isRecording: Boolean = false,
    onStartRecording: (() -> Unit)? = null,
    onStopRecording: (() -> Unit)? = null,
    isSending: Boolean = false,
    promptSummaries: List<PromptSummary> = emptyList(),
    onFetchPromptContent: (suspend (PromptSummary) -> String?)? = null
) {
    val focusRequester = remember { FocusRequester() }
    val hasText = value.isNotBlank()
    val coroutineScope = rememberCoroutineScope()
    
    // @mention state
    var showMentionPopup by remember { mutableStateOf(false) }
    var mentionQuery by remember { mutableStateOf("") }
    var mentionStartIndex by remember { mutableIntStateOf(-1) }
    
    // Variable fill-in bottom sheet state
    var showVariableSheet by remember { mutableStateOf(false) }
    var pendingPromptContent by remember { mutableStateOf<String?>(null) }
    var pendingPromptVariables by remember { mutableStateOf<List<String>>(emptyList()) }
    var variableValues by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var pendingMentionRange by remember { mutableStateOf(IntRange.EMPTY) }
    
    // Detect @ character in input changes
    val handleValueChange: (String) -> Unit = { newValue ->
        onValueChange(newValue)
        
        // Find cursor position by comparing old and new values
        // Detect if user just typed '@'
        if (newValue.length > value.length) {
            val insertedChar = newValue.getOrNull(newValue.length - 1)
            if (insertedChar == '@' && promptSummaries.isNotEmpty()) {
                showMentionPopup = true
                mentionStartIndex = newValue.length - 1
                mentionQuery = ""
            } else if (showMentionPopup && mentionStartIndex >= 0) {
                // Update the query as user types after @
                val afterAt = newValue.substring(mentionStartIndex + 1)
                if (afterAt.contains(' ') || afterAt.contains('\n')) {
                    // Space or newline typed — dismiss popup
                    showMentionPopup = false
                    mentionStartIndex = -1
                    mentionQuery = ""
                } else {
                    mentionQuery = afterAt
                }
            }
        } else if (showMentionPopup && mentionStartIndex >= 0) {
            // User deleted characters
            if (newValue.length <= mentionStartIndex) {
                // Deleted past the @ character
                showMentionPopup = false
                mentionStartIndex = -1
                mentionQuery = ""
            } else {
                mentionQuery = newValue.substring(mentionStartIndex + 1)
            }
        }
    }
    
    // Filter prompts by mention query
    val filteredPrompts = remember(mentionQuery, promptSummaries) {
        if (mentionQuery.isBlank()) {
            promptSummaries
        } else {
            promptSummaries.filter {
                it.name.contains(mentionQuery, ignoreCase = true)
            }
        }
    }
    
    // Dismiss popup if no matches
    LaunchedEffect(filteredPrompts) {
        if (filteredPrompts.isEmpty() && mentionQuery.isNotBlank()) {
            showMentionPopup = false
        }
    }

    Column(modifier = modifier) {
        // @mention popup — shown above the input bar
        AnimatedVisibility(
            visible = showMentionPopup && filteredPrompts.isNotEmpty(),
            enter = fadeIn(tween(150)) + slideInVertically(
                animationSpec = tween(150),
                initialOffsetY = { it / 2 }
            ),
            exit = fadeOut(tween(100)) + slideOutVertically(
                animationSpec = tween(100),
                targetOffsetY = { it / 2 }
            )
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 200.dp)
                    .padding(bottom = 4.dp)
                    .shadow(4.dp, RoundedCornerShape(12.dp)),
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                tonalElevation = 2.dp
            ) {
                LazyColumn(
                    modifier = Modifier.padding(vertical = 4.dp)
                ) {
                    items(
                        items = filteredPrompts,
                        key = { it.id }
                    ) { prompt ->
                        PromptMentionItem(
                            prompt = prompt,
                            onClick = {
                                coroutineScope.launch {
                                    handlePromptSelection(
                                        prompt = prompt,
                                        currentValue = value,
                                        mentionStartIndex = mentionStartIndex,
                                        onFetchPromptContent = onFetchPromptContent,
                                        onDirectInsert = { newText ->
                                            onValueChange(newText)
                                        },
                                        onShowVariableSheet = { content, variables, range ->
                                            pendingPromptContent = content
                                            pendingPromptVariables = variables
                                            pendingMentionRange = range
                                            variableValues = variables.associateWith { "" }
                                            showVariableSheet = true
                                        }
                                    )
                                }
                                showMentionPopup = false
                                mentionStartIndex = -1
                                mentionQuery = ""
                            }
                        )
                    }
                }
            }
        }
        
        // Main input row
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Attachment button
            IconButton(
                onClick = {
                    android.util.Log.d("MessageInputBar", "Attachment button clicked, callback is ${if (onAttachmentClick != null) "NOT null" else "null"}")
                    onAttachmentClick?.invoke()
                },
                modifier = Modifier
                    .padding(bottom = 4.dp)
                    .size(40.dp)
            ) {
                Icon(
                    imageVector = Icons.Outlined.Add,
                    contentDescription = "Attach",
                    modifier = Modifier.size(24.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            // Input surface with text field and send button
            Surface(
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(24.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                tonalElevation = 0.dp
            ) {
                Row(
                    modifier = Modifier.padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    // Text input
                    BasicTextField(
                        value = value,
                        onValueChange = handleValueChange,
                        modifier = Modifier
                            .weight(1f)
                            .defaultMinSize(minHeight = 40.dp)
                            .focusRequester(focusRequester)
                            .padding(vertical = 10.dp),
                        textStyle = MaterialTheme.typography.bodyLarge.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        keyboardOptions = KeyboardOptions(
                            imeAction = ImeAction.Default
                        ),
                        decorationBox = { innerTextField ->
                            Box(
                                modifier = Modifier.fillMaxWidth(),
                                contentAlignment = Alignment.CenterStart
                            ) {
                                if (value.isEmpty()) {
                                    Text(
                                        text = "Ask anything",
                                        style = MaterialTheme.typography.bodyLarge,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                innerTextField()
                            }
                        }
                    )
                    
                    // Send, stop, or microphone button
                    when {
                        isStreaming -> {
                            FilledIconButton(
                                onClick = onStopStreaming,
                                modifier = Modifier.size(40.dp),
                                colors = IconButtonDefaults.filledIconButtonColors(
                                    containerColor = MaterialTheme.colorScheme.error,
                                    contentColor = MaterialTheme.colorScheme.onError
                                )
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Stop,
                                    contentDescription = "Stop",
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        hasText -> {
                            FilledIconButton(
                                onClick = onSend,
                                enabled = !isSending,
                                modifier = Modifier.size(40.dp),
                                colors = IconButtonDefaults.filledIconButtonColors(
                                    containerColor = MaterialTheme.colorScheme.primary,
                                    contentColor = MaterialTheme.colorScheme.onPrimary
                                )
                            ) {
                                if (isSending) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(20.dp),
                                        strokeWidth = 2.dp,
                                        color = MaterialTheme.colorScheme.onPrimary
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.ArrowUpward,
                                        contentDescription = "Send",
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                        }
                        isRecording -> {
                            FilledIconButton(
                                onClick = { onStopRecording?.invoke() },
                                modifier = Modifier.size(40.dp),
                                colors = IconButtonDefaults.filledIconButtonColors(
                                    containerColor = MaterialTheme.colorScheme.error,
                                    contentColor = MaterialTheme.colorScheme.onError
                                )
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Stop,
                                    contentDescription = "Stop recording",
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        else -> {
                            IconButton(
                                onClick = { onStartRecording?.invoke() },
                                modifier = Modifier.size(40.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Outlined.Mic,
                                    contentDescription = "Voice input",
                                    modifier = Modifier.size(22.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Variable fill-in bottom sheet
    if (showVariableSheet && pendingPromptContent != null) {
        ModalBottomSheet(
            onDismissRequest = {
                showVariableSheet = false
                pendingPromptContent = null
                pendingPromptVariables = emptyList()
                variableValues = emptyMap()
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            PromptVariableSheet(
                variables = pendingPromptVariables,
                values = variableValues,
                onValueChange = { variable, newVal ->
                    variableValues = variableValues + (variable to newVal)
                },
                onInsert = {
                    var resolved = pendingPromptContent ?: ""
                    for ((key, v) in variableValues) {
                        resolved = resolved.replace(
                            Regex("\\{\\{\\s*${Regex.escape(key)}\\s*\\}\\}"),
                            v
                        )
                    }
                    // Replace the @mention range with resolved content
                    val before = value.substring(0, pendingMentionRange.first.coerceAtLeast(0))
                    val after = if (pendingMentionRange.last < value.length) {
                        value.substring(pendingMentionRange.last + 1)
                    } else ""
                    onValueChange(before + resolved + after)
                    
                    showVariableSheet = false
                    pendingPromptContent = null
                    pendingPromptVariables = emptyList()
                    variableValues = emptyMap()
                },
                onCancel = {
                    showVariableSheet = false
                    pendingPromptContent = null
                    pendingPromptVariables = emptyList()
                    variableValues = emptyMap()
                }
            )
        }
    }
}

/**
 * A single prompt item in the @mention dropdown.
 */
@Composable
private fun PromptMentionItem(
    prompt: PromptSummary,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Icon
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.TextSnippet,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = prompt.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (prompt.description.isNotBlank()) {
                Text(
                    text = prompt.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * Bottom sheet content for filling in prompt template variables.
 */
@Composable
private fun PromptVariableSheet(
    variables: List<String>,
    values: Map<String, String>,
    onValueChange: (variable: String, value: String) -> Unit,
    onInsert: () -> Unit,
    onCancel: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Fill in variables",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
        
        Text(
            text = "This prompt has variables that need values.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        variables.forEach { variable ->
            OutlinedTextField(
                value = values[variable] ?: "",
                onValueChange = { onValueChange(variable, it) },
                label = { Text(variable.replace('_', ' ').replaceFirstChar { it.uppercase() }) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )
        }
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.End)
        ) {
            TextButton(onClick = onCancel) {
                Text("Cancel")
            }
            Button(
                onClick = onInsert,
                enabled = values.values.all { it.isNotBlank() }
            ) {
                Text("Insert")
            }
        }
    }
}

/**
 * Handle prompt selection from the @mention popup.
 * Fetches full content, checks for variables, and either inserts directly or shows the variable sheet.
 */
private suspend fun handlePromptSelection(
    prompt: PromptSummary,
    currentValue: String,
    mentionStartIndex: Int,
    onFetchPromptContent: (suspend (PromptSummary) -> String?)?,
    onDirectInsert: (String) -> Unit,
    onShowVariableSheet: (content: String, variables: List<String>, mentionRange: IntRange) -> Unit
) {
    val content = onFetchPromptContent?.invoke(prompt) ?: return
    
    // Calculate the range to replace: from @ to end of current mention query
    val mentionEnd = currentValue.length
    val range = mentionStartIndex until mentionEnd
    
    // Check for {{variables}}
    val variablePattern = Regex("\\{\\{\\s*(\\w+)\\s*\\}\\}")
    val variables = variablePattern.findAll(content)
        .map { it.groupValues[1] }
        .distinct()
        .toList()
    
    if (variables.isEmpty()) {
        // No variables — insert directly, replacing the @mention text
        val before = currentValue.substring(0, mentionStartIndex.coerceAtLeast(0))
        val after = if (mentionEnd < currentValue.length) {
            currentValue.substring(mentionEnd)
        } else ""
        onDirectInsert(before + content + after)
    } else {
        // Has variables — show the bottom sheet
        onShowVariableSheet(content, variables, range)
    }
}
