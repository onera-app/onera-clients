package chat.onera.mobile.presentation.features.main.model

import chat.onera.mobile.presentation.features.main.ModelProvider

data class ChatSummary(
    val id: String,
    val title: String,
    val lastMessage: String?,
    val updatedAt: Long,
    val isEncrypted: Boolean = true,
    val folderId: String? = null
)

enum class ChatGroup(val displayName: String) {
    TODAY("Today"),
    YESTERDAY("Yesterday"),
    PREVIOUS_7_DAYS("Previous 7 Days"),
    PREVIOUS_30_DAYS("Previous 30 Days"),
    OLDER("Older")
}

data class ModelOption(
    val id: String,
    val displayName: String,
    val provider: ModelProvider,
    val credentialId: String? = null
) {
    /**
     * Get the combined ID for API calls (credentialId:modelName)
     */
    val apiModelId: String
        get() = if (credentialId != null) "$credentialId:$id" else id
}
