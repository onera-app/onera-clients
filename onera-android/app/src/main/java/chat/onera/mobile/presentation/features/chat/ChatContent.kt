package chat.onera.mobile.presentation.features.chat

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.domain.model.PromptSummary
import chat.onera.mobile.presentation.features.chat.components.AttachmentPickerSheet
import chat.onera.mobile.presentation.features.chat.components.AttachmentPreviewRow
import chat.onera.mobile.presentation.features.chat.components.MessageBubble
import chat.onera.mobile.presentation.features.chat.components.MessageInputBar
import chat.onera.mobile.presentation.features.chat.components.ModelSelector
import chat.onera.mobile.presentation.features.chat.components.RecordingIndicator
import chat.onera.mobile.presentation.features.chat.components.StreamingMessageBubble
import chat.onera.mobile.presentation.features.chat.components.TTSPlayerOverlay
import chat.onera.mobile.presentation.components.ArtifactExtractor
import chat.onera.mobile.presentation.components.ArtifactsPanel
import chat.onera.mobile.presentation.components.FollowUpChips
import chat.onera.mobile.presentation.features.main.ChatState
import chat.onera.mobile.presentation.features.main.model.ModelOption

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatContent(
    chatState: ChatState,
    onMenuTap: () -> Unit,
    onNewConversation: () -> Unit,
    onSendMessage: (String) -> Unit,
    onUpdateInput: (String) -> Unit,
    onStopStreaming: () -> Unit,
    onRegenerateResponse: (String) -> Unit,
    onCopyMessage: (String) -> Unit,
    onSelectModel: (ModelOption) -> Unit,
    onEditMessage: (messageId: String, newContent: String, regenerate: Boolean) -> Unit,
    onStartRecording: () -> Unit = {},
    onStopRecording: () -> Unit = {},
    onSpeakMessage: (text: String, messageId: String) -> Unit = { _, _ -> },
    onStopSpeaking: () -> Unit = {},
    onAddAttachment: (Attachment) -> Unit = {},
    onRemoveAttachment: (String) -> Unit = {},
    onNavigateToPreviousBranch: (String) -> Unit = {},
    onNavigateToNextBranch: (String) -> Unit = {},
    onSelectFollowUp: (String) -> Unit = {},
    onToggleArtifactsPanel: () -> Unit = {},
    promptSummaries: List<PromptSummary> = emptyList(),
    onFetchPromptContent: (suspend (PromptSummary) -> String?)? = null
) {
    val context = LocalContext.current
    val listState = rememberLazyListState()
    var showModelSelector by remember { mutableStateOf(false) }
    var showAttachmentPicker by remember { mutableStateOf(false) }
    
    // Compute artifacts lazily from messages
    val artifacts = remember(chatState.messages) {
        ArtifactExtractor.extractArtifacts(chatState.messages)
    }
    
    // Microphone permission handling
    var hasMicPermission by remember {
        mutableStateOf(
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        )
    }
    
    val micPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasMicPermission = isGranted
        if (isGranted) {
            // Permission granted, start recording
            onStartRecording()
        }
    }
    
    // Callback to handle recording with permission check
    val handleStartRecording = {
        if (hasMicPermission) {
            onStartRecording()
        } else {
            // Request permission - recording will start in the callback if granted
            micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }
    
    // Keyboard and focus management
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    
    // Create nested scroll connection to dismiss keyboard on scroll down
    val nestedScrollConnection = remember {
        object : NestedScrollConnection {
            override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                // Dismiss keyboard when scrolling down (positive y means scrolling down/pulling content up)
                if (available.y < -10) { // Threshold to prevent accidental dismissal
                    keyboardController?.hide()
                    focusManager.clearFocus()
                }
                return Offset.Zero // Don't consume any scroll
            }
        }
    }
    
    // Scroll to bottom when new messages arrive
    LaunchedEffect(chatState.messages.size, chatState.streamingMessage) {
        if (chatState.messages.isNotEmpty() || chatState.streamingMessage.isNotEmpty()) {
            listState.animateScrollToItem(
                index = (chatState.messages.size + if (chatState.isStreaming) 1 else 0).coerceAtLeast(0)
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .imePadding() // Handle keyboard appearing
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    navigationIcon = {
                        IconButton(onClick = onMenuTap) {
                            Icon(
                                imageVector = Icons.Default.Menu,
                                contentDescription = "Menu"
                            )
                        }
                    },
                    title = {
                        Box(
                            modifier = Modifier.fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            ModelSelectorButton(
                                selectedModel = chatState.selectedModel,
                                onClick = { showModelSelector = true }
                            )
                        }
                    },
                    actions = {
                        // Artifacts button - only visible when code blocks exist
                        if (artifacts.isNotEmpty()) {
                            IconButton(onClick = onToggleArtifactsPanel) {
                                BadgedBox(
                                    badge = {
                                        Badge(
                                            containerColor = MaterialTheme.colorScheme.primary
                                        ) {
                                            Text(
                                                text = "${artifacts.size}",
                                                style = MaterialTheme.typography.labelSmall
                                            )
                                        }
                                    }
                                ) {
                                    Icon(
                                        imageVector = Icons.Outlined.Code,
                                        contentDescription = "Artifacts"
                                    )
                                }
                            }
                        }
                        IconButton(onClick = onNewConversation) {
                            Icon(
                                imageVector = Icons.Outlined.Edit,
                                contentDescription = "New Conversation"
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.background
                    )
                )
            },
            containerColor = MaterialTheme.colorScheme.background
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    // Add tap-to-dismiss keyboard on the content area
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null // No ripple effect
                    ) {
                        keyboardController?.hide()
                        focusManager.clearFocus()
                    }
            ) {
                // Messages list with nested scroll for keyboard dismissal
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .weight(1f)
                        .nestedScroll(nestedScrollConnection),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Empty state
                    if (chatState.messages.isEmpty() && !chatState.isStreaming) {
                        item {
                            EmptyChatState(
                                modifier = Modifier
                                    .fillParentMaxSize()
                                    .padding(horizontal = 24.dp)
                            )
                        }
                    }
                    
                    // Messages
                    items(
                        items = chatState.messages,
                        key = { it.id }
                    ) { message ->
                        MessageBubble(
                            message = message,
                            onCopy = { onCopyMessage(message.content) },
                            onRegenerate = if (message.role == chat.onera.mobile.domain.model.MessageRole.ASSISTANT) {
                                { onRegenerateResponse(message.id) }
                            } else null,
                            onEdit = if (message.role == chat.onera.mobile.domain.model.MessageRole.USER && !chatState.isStreaming) {
                                { newContent, regenerate ->
                                    onEditMessage(message.id, newContent, regenerate)
                                }
                            } else null,
                            onSpeak = if (message.role == chat.onera.mobile.domain.model.MessageRole.ASSISTANT) {
                                { text -> onSpeakMessage(text, message.id) }
                            } else null,
                            onStopSpeaking = onStopSpeaking,
                            isSpeakingThisMessage = chatState.speakingMessageId == message.id,
                            onNavigateToPreviousBranch = if (message.siblingCount > 1) {
                                { onNavigateToPreviousBranch(message.id) }
                            } else null,
                            onNavigateToNextBranch = if (message.siblingCount > 1) {
                                { onNavigateToNextBranch(message.id) }
                            } else null
                        )
                    }
                    
                    // Streaming message
                    if (chatState.isStreaming && chatState.streamingMessage.isNotEmpty()) {
                        item {
                            StreamingMessageBubble(
                                content = chatState.streamingMessage,
                                onStop = onStopStreaming
                            )
                        }
                    }
                }
                
                // Follow-up suggestion chips (shown after last assistant message)
                if (chatState.followUps.isNotEmpty() && !chatState.isStreaming) {
                    FollowUpChips(
                        followUps = chatState.followUps,
                        onSelectFollowUp = onSelectFollowUp,
                        modifier = Modifier.padding(bottom = 4.dp)
                    )
                }
                
                // Recording indicator (shown above input when recording)
                if (chatState.isRecording) {
                    RecordingIndicator(
                        onStop = onStopRecording,
                        transcribedText = chatState.transcribedText,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .padding(bottom = 8.dp)
                    )
                }
                
                // Attachment previews (shown above input when attachments exist)
                if (chatState.attachments.isNotEmpty()) {
                    AttachmentPreviewRow(
                        attachments = chatState.attachments,
                        onRemove = onRemoveAttachment,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }
                
                // Input bar
                MessageInputBar(
                    value = chatState.inputText,
                    onValueChange = onUpdateInput,
                    onSend = {
                        if (chatState.inputText.isNotBlank() || chatState.attachments.isNotEmpty()) {
                            onSendMessage(chatState.inputText)
                        }
                    },
                    isStreaming = chatState.isStreaming,
                    onStopStreaming = onStopStreaming,
                    isEncrypted = chatState.isEncrypted,
                    isRecording = chatState.isRecording,
                    onStartRecording = handleStartRecording,
                    onStopRecording = onStopRecording,
                    onAttachmentClick = { 
                        android.util.Log.d("ChatContent", "Attachment click - showing picker")
                        showAttachmentPicker = true 
                    },
                    isSending = chatState.isSending,
                    promptSummaries = promptSummaries,
                    onFetchPromptContent = onFetchPromptContent,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }
        }
        
        // TTS Player Overlay - shown at top when speaking
        TTSPlayerOverlay(
            isPlaying = chatState.isSpeaking,
            startTime = chatState.speakingStartTime,
            onStop = onStopSpeaking,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 64.dp) // Below the top app bar
        )
    }
    
    // Model selector overlay
    if (showModelSelector) {
        ModelSelector(
            models = chatState.availableModels,
            selectedModel = chatState.selectedModel,
            onSelectModel = { model ->
                onSelectModel(model)
                showModelSelector = false
            },
            onDismiss = { showModelSelector = false }
        )
    }
    
    // Attachment picker bottom sheet
    if (showAttachmentPicker) {
        AttachmentPickerSheet(
            onAttachmentSelected = { attachment ->
                onAddAttachment(attachment)
            },
            onDismiss = { showAttachmentPicker = false }
        )
    }
    
    // Artifacts panel bottom sheet
    if (chatState.showArtifactsPanel) {
        ArtifactsPanel(
            artifacts = artifacts,
            onDismiss = onToggleArtifactsPanel
        )
    }
}

@Composable
private fun ModelSelectorButton(
    selectedModel: ModelOption?,
    onClick: () -> Unit
) {
    TextButton(
        onClick = onClick,
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Text(
            text = selectedModel?.displayName ?: "Select Model",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.width(2.dp))
        Icon(
            imageVector = Icons.Default.KeyboardArrowDown,
            contentDescription = "Select model",
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun EmptyChatState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "How can I help you today?",
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurface
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Select a model above to get started",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
