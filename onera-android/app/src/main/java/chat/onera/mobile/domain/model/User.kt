package chat.onera.mobile.domain.model

data class User(
    val id: String,
    val email: String,
    val displayName: String?,
    val avatarUrl: String?,
    val imageUrl: String? = avatarUrl,
    val hasE2EEKeys: Boolean = false
)
