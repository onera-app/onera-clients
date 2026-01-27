package chat.onera.mobile.presentation.features.notes.model

data class NoteSummary(
    val id: String,
    val title: String,
    val preview: String,
    val folder: String?,
    val isPinned: Boolean,
    val isEncrypted: Boolean,
    val updatedAt: Long
)

enum class NoteGroup(val displayName: String) {
    PINNED("Pinned"),
    TODAY("Today"),
    YESTERDAY("Yesterday"),
    PREVIOUS_7_DAYS("Previous 7 Days"),
    PREVIOUS_30_DAYS("Previous 30 Days"),
    OLDER("Older")
}
