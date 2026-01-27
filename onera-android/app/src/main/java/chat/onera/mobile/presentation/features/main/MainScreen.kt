package chat.onera.mobile.presentation.features.main

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.presentation.features.chat.ChatContent
import chat.onera.mobile.presentation.features.main.components.SidebarDrawerContent
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun MainScreen(
    viewModel: MainViewModel = hiltViewModel(),
    refreshOnStart: Boolean = false,
    onNavigateToSettings: () -> Unit,
    onNavigateToNotes: () -> Unit,
    onSignOut: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val density = LocalDensity.current
    val configuration = LocalConfiguration.current
    
    // Keyboard and focus management
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    
    // Trigger refresh after E2EE unlock
    LaunchedEffect(refreshOnStart) {
        if (refreshOnStart) {
            android.util.Log.d("MainScreen", "Triggering data refresh after E2EE unlock")
            viewModel.sendIntent(MainIntent.OnE2EEUnlocked)
        }
    }
    
    // Handle one-time effects
    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is MainEffect.SignOutComplete -> onSignOut()
                is MainEffect.ShowError -> { /* Handle error toast/snackbar */ }
                is MainEffect.CopyToClipboard -> { /* Handle clipboard */ }
                is MainEffect.ScrollToBottom -> { /* Handle scroll */ }
            }
        }
    }
    
    // Drawer dimensions
    val screenWidthPx = with(density) { configuration.screenWidthDp.dp.toPx() }
    val drawerWidthPx = screenWidthPx * 0.80f
    val minDragThresholdPx = with(density) { 10.dp.toPx() } // Minimum drag to recognize as swipe
    
    // Drawer state
    var isDrawerOpen by remember { mutableStateOf(false) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    var isDragging by remember { mutableStateOf(false) }
    var totalDragDistance by remember { mutableFloatStateOf(0f) }
    var isHorizontalSwipe by remember { mutableStateOf<Boolean?>(null) }
    
    // Dismiss keyboard when drawer opens
    LaunchedEffect(isDrawerOpen) {
        if (isDrawerOpen) {
            keyboardController?.hide()
            focusManager.clearFocus()
        }
    }
    
    // Calculate current offset
    val baseOffset = if (isDrawerOpen) drawerWidthPx else 0f
    val currentOffset = (baseOffset + dragOffset).coerceIn(0f, drawerWidthPx)
    
    // Animated offset when not dragging
    val animatedOffset by animateFloatAsState(
        targetValue = if (isDragging) currentOffset else if (isDrawerOpen) drawerWidthPx else 0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "drawerOffset"
    )
    
    // Use animated offset when not dragging
    val displayOffset = if (isDragging) currentOffset else animatedOffset
    
    // Overlay opacity based on offset
    val overlayOpacity = (displayOffset / drawerWidthPx) * 0.3f
    
    // Sidebar offset - starts off-screen to the left
    val sidebarOffset = -drawerWidthPx * (1 - displayOffset / drawerWidthPx)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Sidebar drawer
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .width(with(density) { drawerWidthPx.toDp() })
                .offset { IntOffset(sidebarOffset.roundToInt(), 0) }
                .pointerInput(Unit) {
                    detectHorizontalDragGestures(
                        onDragStart = { 
                            isDragging = true
                            totalDragDistance = 0f
                            isHorizontalSwipe = null
                        },
                        onDragEnd = {
                            isDragging = false
                            val velocity = dragOffset
                            // Flick gesture - velocity determines outcome
                            if (velocity < -500) {
                                isDrawerOpen = false
                            } else {
                                // Snap based on position
                                isDrawerOpen = currentOffset > drawerWidthPx * 0.3f
                            }
                            dragOffset = 0f
                            totalDragDistance = 0f
                            isHorizontalSwipe = null
                        },
                        onDragCancel = {
                            isDragging = false
                            dragOffset = 0f
                            totalDragDistance = 0f
                            isHorizontalSwipe = null
                        },
                        onHorizontalDrag = { _, dragAmount ->
                            if (isDrawerOpen && dragAmount < 0) {
                                dragOffset = (dragOffset + dragAmount).coerceIn(-drawerWidthPx, 0f)
                            }
                        }
                    )
                }
        ) {
            SidebarDrawerContent(
                chats = state.chats,
                groupedChats = state.groupedChats,
                selectedChatId = state.selectedChatId,
                isLoading = state.isLoadingChats,
                user = state.currentUser,
                searchQuery = state.searchQuery,
                onSearchQueryChange = { viewModel.sendIntent(MainIntent.UpdateSearchQuery(it)) },
                onSelectChat = { chatId ->
                    viewModel.sendIntent(MainIntent.SelectChat(chatId))
                    isDrawerOpen = false
                },
                onNewChat = {
                    viewModel.sendIntent(MainIntent.CreateNewChat)
                    isDrawerOpen = false
                },
                onDeleteChat = { chatId ->
                    viewModel.sendIntent(MainIntent.DeleteChat(chatId))
                },
                onOpenSettings = {
                    isDrawerOpen = false
                    onNavigateToSettings()
                },
                onOpenNotes = {
                    isDrawerOpen = false
                    onNavigateToNotes()
                },
                onRefresh = { viewModel.sendIntent(MainIntent.RefreshChats) }
            )
        }
        
        // Main content with slide effect
        Box(
            modifier = Modifier
                .fillMaxSize()
                .offset { IntOffset(displayOffset.roundToInt(), 0) }
                // Full-screen swipe gesture when drawer is closed
                .then(
                    if (!isDrawerOpen) {
                        Modifier.pointerInput(Unit) {
                            detectHorizontalDragGestures(
                                onDragStart = { 
                                    totalDragDistance = 0f
                                    isHorizontalSwipe = null
                                },
                                onDragEnd = {
                                    if (isDragging) {
                                        isDragging = false
                                        val velocity = dragOffset
                                        // Flick gesture - lower threshold for easier opening
                                        if (velocity > 300) {
                                            isDrawerOpen = true
                                        } else {
                                            // Snap based on position
                                            isDrawerOpen = currentOffset > drawerWidthPx * 0.25f
                                        }
                                        dragOffset = 0f
                                    }
                                    totalDragDistance = 0f
                                    isHorizontalSwipe = null
                                },
                                onDragCancel = {
                                    isDragging = false
                                    dragOffset = 0f
                                    totalDragDistance = 0f
                                    isHorizontalSwipe = null
                                },
                                onHorizontalDrag = { change, dragAmount ->
                                    // Only allow right swipe (positive dragAmount) to open drawer
                                    if (dragAmount > 0) {
                                        val horizontalDelta = abs(change.positionChange().x)
                                        val verticalDelta = abs(change.positionChange().y)
                                        
                                        // Determine swipe direction on first significant movement
                                        if (isHorizontalSwipe == null && (horizontalDelta > 5 || verticalDelta > 5)) {
                                            isHorizontalSwipe = horizontalDelta > verticalDelta
                                        }
                                        
                                        // Only track horizontal swipes
                                        if (isHorizontalSwipe == true) {
                                            totalDragDistance += dragAmount
                                            
                                            // Start tracking drawer after minimum threshold
                                            if (totalDragDistance > minDragThresholdPx) {
                                                if (!isDragging) {
                                                    isDragging = true
                                                }
                                                change.consume()
                                                dragOffset = (dragOffset + dragAmount).coerceIn(0f, drawerWidthPx)
                                            }
                                        }
                                    }
                                }
                            )
                        }
                    } else {
                        Modifier
                    }
                )
        ) {
            // Chat content with keyboard dismiss callback
            ChatContent(
                chatState = state.chatState,
                onMenuTap = { isDrawerOpen = true },
                onNewConversation = { viewModel.sendIntent(MainIntent.CreateNewChat) },
                onSendMessage = { viewModel.sendIntent(MainIntent.SendMessage(it)) },
                onUpdateInput = { viewModel.sendIntent(MainIntent.UpdateChatInput(it)) },
                onStopStreaming = { viewModel.sendIntent(MainIntent.StopStreaming) },
                onRegenerateResponse = { viewModel.sendIntent(MainIntent.RegenerateResponse(it)) },
                onCopyMessage = { viewModel.sendIntent(MainIntent.CopyMessage(it)) },
                onSelectModel = { viewModel.sendIntent(MainIntent.SelectModel(it)) },
                onEditMessage = { messageId, newContent, regenerate ->
                    viewModel.sendIntent(MainIntent.EditMessage(messageId, newContent, regenerate))
                },
                onStartRecording = { viewModel.sendIntent(MainIntent.StartRecording) },
                onStopRecording = { viewModel.sendIntent(MainIntent.StopRecording) },
                onSpeakMessage = { text, messageId ->
                    viewModel.sendIntent(MainIntent.SpeakMessage(text, messageId))
                },
                onStopSpeaking = { viewModel.sendIntent(MainIntent.StopSpeaking) },
                onAddAttachment = { viewModel.sendIntent(MainIntent.AddAttachment(it)) },
                onRemoveAttachment = { viewModel.sendIntent(MainIntent.RemoveAttachment(it)) },
                onNavigateToPreviousBranch = { viewModel.sendIntent(MainIntent.NavigateToPreviousBranch(it)) },
                onNavigateToNextBranch = { viewModel.sendIntent(MainIntent.NavigateToNextBranch(it)) }
            )
            
            // Dimmed overlay when drawer is open - allows swipe to close
            if (displayOffset > 0) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .alpha(overlayOpacity / 0.3f)
                        .background(Color.Black.copy(alpha = 0.3f))
                        .pointerInput(Unit) {
                            detectHorizontalDragGestures(
                                onDragStart = { 
                                    isDragging = true
                                    totalDragDistance = 0f
                                },
                                onDragEnd = {
                                    isDragging = false
                                    val velocity = dragOffset
                                    if (velocity < -300) {
                                        isDrawerOpen = false
                                    } else {
                                        isDrawerOpen = currentOffset > drawerWidthPx * 0.5f
                                    }
                                    dragOffset = 0f
                                    totalDragDistance = 0f
                                },
                                onDragCancel = {
                                    isDragging = false
                                    dragOffset = 0f
                                    totalDragDistance = 0f
                                },
                                onHorizontalDrag = { change, dragAmount ->
                                    // Allow both left and right swipe on overlay
                                    change.consume()
                                    dragOffset = (dragOffset + dragAmount).coerceIn(-drawerWidthPx, 0f)
                                }
                            )
                        }
                        .pointerInput(Unit) {
                            // Tap to close
                            awaitPointerEventScope {
                                while (true) {
                                    val event = awaitPointerEvent()
                                    if (event.changes.any { it.pressed }) {
                                        val change = event.changes.first()
                                        if (!isDragging) {
                                            change.consume()
                                            isDrawerOpen = false
                                        }
                                    }
                                }
                            }
                        }
                )
            }
        }
    }
}
