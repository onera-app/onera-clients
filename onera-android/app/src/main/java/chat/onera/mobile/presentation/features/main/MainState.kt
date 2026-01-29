package chat.onera.mobile.presentation.features.main

import chat.onera.mobile.domain.model.Attachment
import chat.onera.mobile.domain.model.Folder
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.presentation.base.UiState
import chat.onera.mobile.presentation.features.main.model.ChatGroup
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import chat.onera.mobile.presentation.features.main.model.ModelOption

data class MainState(
    // Sidebar state
    val chats: List<ChatSummary> = emptyList(),
    val groupedChats: List<Pair<ChatGroup, List<ChatSummary>>> = emptyList(),
    val isLoadingChats: Boolean = true,
    val searchQuery: String = "",
    val selectedChatId: String? = null,
    val currentUser: User? = null,
    
    // Folder state
    val folders: List<Folder> = emptyList(),
    val selectedFolderId: String? = null,
    val expandedFolderIds: Set<String> = emptySet(),
    val isLoadingFolders: Boolean = false,
    
    // Chat state
    val chatState: ChatState = ChatState()
) : UiState {
    
    /**
     * Get chats filtered by the selected folder.
     * If no folder is selected, returns all chats.
     */
    val filteredGroupedChats: List<Pair<ChatGroup, List<ChatSummary>>>
        get() = if (selectedFolderId == null) {
            groupedChats
        } else {
            groupedChats.mapNotNull { (group, chats) ->
                val filtered = chats.filter { it.folderId == selectedFolderId }
                if (filtered.isEmpty()) null else group to filtered
            }
        }
}

data class ChatState(
    val chatId: String? = null,
    val chatTitle: String = "New chat",
    // All messages including all branch variants
    val allMessages: List<Message> = emptyList(),
    // Map of parentMessageId to selected branchIndex (for switching between variants)
    val selectedBranches: Map<String, Int> = emptyMap(),
    val inputText: String = "",
    val isLoading: Boolean = false,
    val isSending: Boolean = false,
    val isStreaming: Boolean = false,
    val streamingMessage: String = "",
    val selectedModel: ModelOption? = null,
    val availableModels: List<ModelOption> = emptyList(),
    val isEncrypted: Boolean = true,
    val isRecording: Boolean = false,
    val transcribedText: String = "",
    // TTS state
    val isSpeaking: Boolean = false,
    val speakingMessageId: String? = null,
    val speakingStartTime: Long? = null,
    // Attachments
    val attachments: List<Attachment> = emptyList()
) {
    /**
     * Get the visible messages (only the selected branch for each message group).
     * Messages without siblings are always visible.
     * For messages with siblings, only the currently selected branch is visible.
     */
    val messages: List<Message>
        get() {
            // Group messages by their parentMessageId (null for root messages)
            val messagesByParent = allMessages.groupBy { it.parentMessageId }
            
            // Start with root messages (no parent) - these are always visible
            val rootMessages = messagesByParent[null] ?: emptyList()
            
            // Build visible message list
            val visibleMessages = mutableListOf<Message>()
            
            for (msg in rootMessages) {
                visibleMessages.add(msg)
            }
            
            // For each message group with a parent, select the appropriate branch
            for ((parentId, siblings) in messagesByParent) {
                if (parentId == null) continue // Already handled root messages
                
                val selectedIndex = selectedBranches[parentId] ?: 0
                val selectedMessage = siblings.find { it.branchIndex == selectedIndex }
                    ?: siblings.firstOrNull()
                
                if (selectedMessage != null) {
                    // Update sibling count on the selected message
                    val updatedMessage = selectedMessage.copy(siblingCount = siblings.size)
                    visibleMessages.add(updatedMessage)
                }
            }
            
            // Sort by creation time to maintain order
            return visibleMessages.sortedBy { it.createdAt }
        }
}
