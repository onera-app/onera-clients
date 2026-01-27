package chat.onera.mobile.presentation.features.folders

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import chat.onera.mobile.domain.model.Folder

@Composable
fun FolderTreeView(
    folders: List<Folder>,
    selectedFolderId: String?,
    expandedFolderIds: Set<String>,
    onSelectFolder: (String?) -> Unit,
    onToggleExpand: (String) -> Unit,
    onCreateFolder: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    // Build tree structure
    val rootFolders = folders.filter { it.parentId == null }
    val childrenMap = folders.groupBy { it.parentId }
    
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        // "All" option
        FolderRow(
            name = "All Items",
            isSelected = selectedFolderId == null,
            isExpanded = false,
            hasChildren = false,
            depth = 0,
            onClick = { onSelectFolder(null) },
            onToggleExpand = {}
        )
        
        // Root folders
        rootFolders.forEach { folder ->
            FolderTreeItem(
                folder = folder,
                childrenMap = childrenMap,
                selectedFolderId = selectedFolderId,
                expandedFolderIds = expandedFolderIds,
                onSelectFolder = onSelectFolder,
                onToggleExpand = onToggleExpand,
                depth = 0
            )
        }
        
        // Create folder button
        TextButton(
            onClick = { onCreateFolder(null) },
            modifier = Modifier.padding(start = 8.dp, top = 8.dp)
        ) {
            Icon(
                imageVector = Icons.Outlined.Add,
                contentDescription = null,
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text("New Folder", style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun FolderTreeItem(
    folder: Folder,
    childrenMap: Map<String?, List<Folder>>,
    selectedFolderId: String?,
    expandedFolderIds: Set<String>,
    onSelectFolder: (String?) -> Unit,
    onToggleExpand: (String) -> Unit,
    depth: Int
) {
    val children = childrenMap[folder.id] ?: emptyList()
    val hasChildren = children.isNotEmpty()
    val isExpanded = expandedFolderIds.contains(folder.id)
    val isSelected = selectedFolderId == folder.id
    
    Column {
        FolderRow(
            name = folder.name,
            isSelected = isSelected,
            isExpanded = isExpanded,
            hasChildren = hasChildren,
            depth = depth,
            itemCount = folder.chatCount + folder.noteCount,
            onClick = { onSelectFolder(folder.id) },
            onToggleExpand = { onToggleExpand(folder.id) }
        )
        
        AnimatedVisibility(visible = isExpanded) {
            Column {
                children.forEach { child ->
                    FolderTreeItem(
                        folder = child,
                        childrenMap = childrenMap,
                        selectedFolderId = selectedFolderId,
                        expandedFolderIds = expandedFolderIds,
                        onSelectFolder = onSelectFolder,
                        onToggleExpand = onToggleExpand,
                        depth = depth + 1
                    )
                }
            }
        }
    }
}

@Composable
private fun FolderRow(
    name: String,
    isSelected: Boolean,
    isExpanded: Boolean,
    hasChildren: Boolean,
    depth: Int,
    itemCount: Int = 0,
    onClick: () -> Unit,
    onToggleExpand: () -> Unit
) {
    val chevronRotation by animateFloatAsState(
        targetValue = if (isExpanded) 90f else 0f,
        label = "chevronRotation"
    )
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = (depth * 16).dp)
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isSelected) MaterialTheme.colorScheme.surfaceVariant
                else MaterialTheme.colorScheme.surface
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Expand/collapse button (only if has children)
        if (hasChildren) {
            IconButton(
                onClick = onToggleExpand,
                modifier = Modifier.size(24.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = if (isExpanded) "Collapse" else "Expand",
                    modifier = Modifier
                        .size(16.dp)
                        .rotate(chevronRotation),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            Spacer(modifier = Modifier.size(24.dp))
        }
        
        // Folder icon
        Icon(
            imageVector = if (isExpanded) Icons.Default.FolderOpen else Icons.Default.Folder,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = if (isSelected) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            }
        )
        
        Spacer(modifier = Modifier.width(8.dp))
        
        // Folder name
        Text(
            text = name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (isSelected) FontWeight.Medium else FontWeight.Normal,
            modifier = Modifier.weight(1f)
        )
        
        // Item count badge
        if (itemCount > 0) {
            Text(
                text = itemCount.toString(),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
