package chat.onera.mobile.presentation.features.main.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons

import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.MoveToInbox
import androidx.compose.material.icons.outlined.NoteAlt
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.onera.mobile.domain.model.Folder
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import chat.onera.mobile.presentation.theme.EncryptionGreen
import coil.compose.AsyncImage

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SidebarDrawerContent(
    chats: List<ChatSummary>,
    groupedChats: List<Pair<ChatGroup, List<ChatSummary>>>,
    selectedChatId: String?,
    isLoading: Boolean,
    user: User?,
    searchQuery: String,
    // Folder state
    folders: List<Folder> = emptyList(),
    selectedFolderId: String? = null,
    expandedFolderIds: Set<String> = emptySet(),
    onSearchQueryChange: (String) -> Unit,
    onSelectChat: (String) -> Unit,
    onNewChat: () -> Unit,
    onDeleteChat: (String) -> Unit,
    onMoveChatToFolder: ((String, String?) -> Unit)? = null,
    onOpenSettings: () -> Unit,
    onOpenNotes: () -> Unit,
    onOpenPrompts: () -> Unit = {},
    onOpenSearch: () -> Unit = {},
    onRefresh: () -> Unit,
    // Folder callbacks
    onCreateFolder: ((String, String?) -> Unit)? = null,
    onSelectFolder: ((String?) -> Unit)? = null,
    onToggleFolderExpanded: ((String) -> Unit)? = null
) {
    var showFolders by remember { mutableStateOf(false) }
    var showMoveToFolderSheet by remember { mutableStateOf<ChatSummary?>(null) }
    var showCreateFolderDialog by remember { mutableStateOf(false) }
    var newFolderName by remember { mutableStateOf("") }
    
    // Filter chats based on search query
    val filteredGroupedChats = if (searchQuery.isBlank()) {
        groupedChats
    } else {
        groupedChats.mapNotNull { (group, groupChats) ->
            val filtered = groupChats.filter { 
                it.title.contains(searchQuery, ignoreCase = true) 
            }
            if (filtered.isEmpty()) null else group to filtered
        }
    }

    val statusBarPadding = WindowInsets.statusBars.asPaddingValues()
    val navigationBarPadding = WindowInsets.navigationBars.asPaddingValues()
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Search bar - with status bar padding
        SearchBar(
            query = searchQuery,
            onQueryChange = onSearchQueryChange,
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .padding(
                    top = statusBarPadding.calculateTopPadding() + 16.dp,
                    bottom = 12.dp
                )
        )
        
        // Scrollable content
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(bottom = 16.dp)
        ) {
            // Navigation items
            item {
                NavigationItems(
                    showFolders = showFolders,
                    folders = folders,
                    selectedFolderId = selectedFolderId,
                    expandedFolderIds = expandedFolderIds,
                    onToggleFolders = { showFolders = !showFolders },
                    onOpenNotes = onOpenNotes,
                    onOpenPrompts = onOpenPrompts,
                    onOpenSearch = onOpenSearch,
                    onSelectFolder = onSelectFolder,
                    onToggleFolderExpanded = onToggleFolderExpanded,
                    onCreateFolder = if (onCreateFolder != null) {
                        { showCreateFolderDialog = true }
                    } else null
                )
                
                Spacer(modifier = Modifier.height(24.dp))
            }
            
            // Chat history
            if (isLoading && chats.isEmpty()) {
                item {
                    LoadingState()
                }
            } else if (chats.isEmpty()) {
                item {
                    EmptyState()
                }
            } else {
                filteredGroupedChats.forEach { (group, groupChats) ->
                    item {
                        SectionHeader(title = group.displayName)
                    }
                    
                    items(
                        items = groupChats,
                        key = { it.id }
                    ) { chat ->
                        ChatHistoryRow(
                            chat = chat,
                            isSelected = selectedChatId == chat.id,
                            canMoveToFolder = onMoveChatToFolder != null && folders.isNotEmpty(),
                            onSelect = { onSelectChat(chat.id) },
                            onDelete = { onDeleteChat(chat.id) },
                            onMoveToFolder = { showMoveToFolderSheet = chat }
                        )
                    }
                }
            }
        }
        
        // Footer with user profile - with navigation bar padding
        FooterSection(
            user = user,
            onOpenSettings = onOpenSettings,
            bottomPadding = navigationBarPadding.calculateBottomPadding()
        )
    }
    
    // Folder picker bottom sheet for moving chat
    if (showMoveToFolderSheet != null) {
        val chatToMove = showMoveToFolderSheet!!
        AlertDialog(
            onDismissRequest = { showMoveToFolderSheet = null },
            title = { Text("Move to Folder") },
            text = {
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // No folder option
                    Surface(
                        onClick = {
                            onMoveChatToFolder?.invoke(chatToMove.id, null)
                            showMoveToFolderSheet = null
                        },
                        shape = RoundedCornerShape(8.dp),
                        color = if (chatToMove.folderId == null) {
                            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                        } else {
                            Color.Transparent
                        }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.FolderOff,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp)
                            )
                            Text("No Folder")
                            Spacer(modifier = Modifier.weight(1f))
                            if (chatToMove.folderId == null) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    }
                    
                    // Folder list
                    folders.filter { it.parentId == null }.forEach { folder ->
                        Surface(
                            onClick = {
                                onMoveChatToFolder?.invoke(chatToMove.id, folder.id)
                                showMoveToFolderSheet = null
                            },
                            shape = RoundedCornerShape(8.dp),
                            color = if (chatToMove.folderId == folder.id) {
                                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                            } else {
                                Color.Transparent
                            }
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Outlined.Folder,
                                    contentDescription = null,
                                    modifier = Modifier.size(20.dp)
                                )
                                Text(folder.name)
                                Spacer(modifier = Modifier.weight(1f))
                                if (chatToMove.folderId == folder.id) {
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showMoveToFolderSheet = null }) {
                    Text("Cancel")
                }
            }
        )
    }
    
    // Create folder dialog
    if (showCreateFolderDialog) {
        AlertDialog(
            onDismissRequest = { 
                showCreateFolderDialog = false
                newFolderName = ""
            },
            title = { Text("Create Folder") },
            text = {
                OutlinedTextField(
                    value = newFolderName,
                    onValueChange = { newFolderName = it },
                    label = { Text("Folder name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (newFolderName.isNotBlank()) {
                            onCreateFolder?.invoke(newFolderName.trim(), null)
                        }
                        showCreateFolderDialog = false
                        newFolderName = ""
                    },
                    enabled = newFolderName.isNotBlank()
                ) {
                    Text("Create")
                }
            },
            dismissButton = {
                TextButton(onClick = { 
                    showCreateFolderDialog = false
                    newFolderName = ""
                }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    // Search field only - no new chat button
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp),
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            Box(modifier = Modifier.weight(1f)) {
                if (query.isEmpty()) {
                    Text(
                        text = "Search",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                androidx.compose.foundation.text.BasicTextField(
                    value = query,
                    onValueChange = onQueryChange,
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = MaterialTheme.typography.bodyMedium.copy(
                        color = MaterialTheme.colorScheme.onSurface
                    ),
                    singleLine = true,
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(
                        MaterialTheme.colorScheme.primary
                    )
                )
            }
            
            if (query.isNotEmpty()) {
                IconButton(
                    onClick = { onQueryChange("") },
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Clear",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun NavigationItems(
    showFolders: Boolean,
    folders: List<Folder>,
    selectedFolderId: String?,
    expandedFolderIds: Set<String>,
    onToggleFolders: () -> Unit,
    onOpenNotes: () -> Unit,
    onOpenPrompts: () -> Unit = {},
    onOpenSearch: () -> Unit = {},
    onSelectFolder: ((String?) -> Unit)?,
    onToggleFolderExpanded: ((String) -> Unit)?,
    onCreateFolder: (() -> Unit)?
) {
    val chevronRotation by animateFloatAsState(
        targetValue = if (showFolders) 90f else 0f,
        label = "chevronRotation"
    )
    
    Column(
        modifier = Modifier.padding(horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        // Search
        NavigationItemRow(
            icon = Icons.Default.Search,
            title = "Search",
            onClick = onOpenSearch
        )
        
        // Notes
        NavigationItemRow(
            icon = Icons.Outlined.NoteAlt,
            title = "Notes",
            onClick = onOpenNotes
        )
        
        // Prompts
        NavigationItemRow(
            icon = Icons.Outlined.AutoAwesome,
            title = "Prompts",
            onClick = onOpenPrompts
        )
        
        // Folders (expandable)
        NavigationItemRow(
            icon = Icons.Outlined.Folder,
            title = "Folders",
            onClick = onToggleFolders,
            trailing = {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier
                        .size(16.dp)
                        .rotate(chevronRotation),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        )
        
        // Folder tree (when expanded)
        AnimatedVisibility(visible = showFolders) {
            Column(
                modifier = Modifier.padding(start = 24.dp, top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                // "All Chats" option to clear folder filter
                if (selectedFolderId != null) {
                    Surface(
                        onClick = { onSelectFolder?.invoke(null) },
                        shape = RoundedCornerShape(8.dp),
                        color = Color.Transparent
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                                Icon(
                                    imageVector = Icons.Default.Home,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            Text(
                                text = "All Chats",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                
                if (folders.isEmpty()) {
                    Text(
                        text = "No folders yet",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                    )
                } else {
                    // Display root folders (those with no parent)
                    folders.filter { it.parentId == null }.forEach { folder ->
                        FolderTreeItem(
                            folder = folder,
                            allFolders = folders,
                            isSelected = folder.id == selectedFolderId,
                            isExpanded = folder.id in expandedFolderIds,
                            depth = 0,
                            onSelect = { onSelectFolder?.invoke(folder.id) },
                            onToggleExpand = { onToggleFolderExpanded?.invoke(folder.id) }
                        )
                    }
                }
                
                // Create new folder button
                if (onCreateFolder != null) {
                    Surface(
                        onClick = onCreateFolder,
                        shape = RoundedCornerShape(8.dp),
                        color = Color.Transparent
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = "New Folder",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FolderTreeItem(
    folder: Folder,
    allFolders: List<Folder>,
    isSelected: Boolean,
    isExpanded: Boolean,
    depth: Int,
    onSelect: () -> Unit,
    onToggleExpand: () -> Unit
) {
    val children = allFolders.filter { it.parentId == folder.id }
    val hasChildren = children.isNotEmpty()
    
    Column {
        Surface(
            onClick = onSelect,
            shape = RoundedCornerShape(8.dp),
            color = if (isSelected) {
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
            } else {
                Color.Transparent
            }
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = (depth * 16).dp + 12.dp, end = 12.dp)
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (hasChildren) {
                    val rotation by animateFloatAsState(
                        targetValue = if (isExpanded) 90f else 0f,
                        label = "folderExpand"
                    )
                    IconButton(
                        onClick = onToggleExpand,
                        modifier = Modifier.size(16.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.ChevronRight,
                            contentDescription = if (isExpanded) "Collapse" else "Expand",
                            modifier = Modifier
                                .size(12.dp)
                                .rotate(rotation),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    Spacer(modifier = Modifier.size(16.dp))
                }
                
                Icon(
                    imageVector = if (isExpanded && hasChildren) Icons.Default.FolderOpen else Icons.Outlined.Folder,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Text(
                    text = folder.name,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        
        // Render children if expanded
        if (isExpanded && hasChildren) {
            children.forEach { child ->
                FolderTreeItem(
                    folder = child,
                    allFolders = allFolders,
                    isSelected = false, // Would need to pass selectedFolderId down
                    isExpanded = false, // Would need expandedFolderIds
                    depth = depth + 1,
                    onSelect = { /* Would need callback */ },
                    onToggleExpand = { /* Would need callback */ }
                )
            }
        }
    }
}

@Composable
private fun NavigationItemRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    onClick: () -> Unit,
    isSelected: Boolean = false,
    trailing: @Composable (() -> Unit)? = null
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = if (isSelected) {
            MaterialTheme.colorScheme.surfaceVariant
        } else {
            Color.Transparent
        }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = if (isSelected) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }
            )
            
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
                modifier = Modifier.weight(1f)
            )
            
            trailing?.invoke()
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
    )
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun ChatHistoryRow(
    chat: ChatSummary,
    isSelected: Boolean,
    canMoveToFolder: Boolean = false,
    onSelect: () -> Unit,
    onDelete: () -> Unit,
    onMoveToFolder: (() -> Unit)? = null
) {
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showContextMenu by remember { mutableStateOf(false) }
    val hapticFeedback = LocalHapticFeedback.current
    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { dismissValue ->
            if (dismissValue == SwipeToDismissBoxValue.EndToStart) {
                hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                showDeleteDialog = true
                false // Don't dismiss yet, show confirmation first
            } else {
                false
            }
        },
        positionalThreshold = { it * 0.4f }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            val color by animateColorAsState(
                targetValue = when (dismissState.targetValue) {
                    SwipeToDismissBoxValue.EndToStart -> MaterialTheme.colorScheme.errorContainer
                    else -> Color.Transparent
                },
                label = "swipeColor"
            )
            val scale by animateFloatAsState(
                targetValue = if (dismissState.targetValue == SwipeToDismissBoxValue.EndToStart) 1f else 0.8f,
                label = "iconScale"
            )
            
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 8.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(color)
                    .padding(horizontal = 20.dp),
                contentAlignment = Alignment.CenterEnd
            ) {
                Icon(
                    imageVector = Icons.Outlined.Delete,
                    contentDescription = "Delete",
                    modifier = Modifier.scale(scale),
                    tint = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        },
        content = {
            Box {
                Surface(
                    onClick = onSelect,
                    shape = RoundedCornerShape(12.dp),
                    color = if (isSelected) {
                        MaterialTheme.colorScheme.surfaceVariant
                    } else {
                        MaterialTheme.colorScheme.background
                    },
                    modifier = Modifier
                        .padding(horizontal = 8.dp)
                        .combinedClickable(
                            onClick = onSelect,
                            onLongClick = {
                                if (canMoveToFolder) {
                                    hapticFeedback.performHapticFeedback(HapticFeedbackType.LongPress)
                                    showContextMenu = true
                                }
                            }
                        )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = chat.title,
                            style = MaterialTheme.typography.bodyLarge,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                
                // Context menu for move to folder
                DropdownMenu(
                    expanded = showContextMenu,
                    onDismissRequest = { showContextMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { 
                            Text(if (chat.folderId == null) "Move to Folder" else "Change Folder")
                        },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Outlined.MoveToInbox,
                                contentDescription = null
                            )
                        },
                        onClick = {
                            showContextMenu = false
                            onMoveToFolder?.invoke()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Delete", color = MaterialTheme.colorScheme.error) },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Outlined.Delete,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error
                            )
                        },
                        onClick = {
                            showContextMenu = false
                            showDeleteDialog = true
                        }
                    )
                }
            }
        },
        enableDismissFromStartToEnd = false,
        enableDismissFromEndToStart = true
    )
    
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error
                )
            },
            title = { Text("Delete Chat") },
            text = { Text("Are you sure you want to delete this chat? This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDelete()
                        showDeleteDialog = false
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun LoadingState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        CircularProgressIndicator(modifier = Modifier.size(24.dp))
        Text(
            text = "Loading chats...",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun EmptyState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.ChatBubbleOutline,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Text(
            text = "No chats yet",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Text(
            text = "Start a new conversation",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun FooterSection(
    user: User?,
    onOpenSettings: () -> Unit,
    bottomPadding: androidx.compose.ui.unit.Dp = 0.dp
) {
    Surface(
        onClick = onOpenSettings,
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 16.dp + bottomPadding),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // User avatar
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center
            ) {
                if (user?.imageUrl != null) {
                    AsyncImage(
                        model = user.imageUrl,
                        contentDescription = "Profile",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        text = user?.displayName?.firstOrNull()?.uppercase() ?: "?",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            Text(
                text = user?.displayName ?: "Sign In",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
        }
    }
}
