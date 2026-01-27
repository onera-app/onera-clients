package chat.onera.mobile.data.remote.trpc

import kotlinx.serialization.Serializable

// Chat procedures - matches server tRPC router (plural "chats")
object ChatProcedures {
    const val LIST = "chats.list"
    const val GET = "chats.get"
    const val CREATE = "chats.create"
    const val UPDATE = "chats.update"
    const val REMOVE = "chats.remove"  // Server uses "remove" not "delete"
}

// Notes procedures - matches server tRPC router
object NotesProcedures {
    const val LIST = "notes.list"
    const val GET = "notes.get"
    const val CREATE = "notes.create"
    const val UPDATE = "notes.update"
    const val REMOVE = "notes.remove"  // Server uses "remove" not "delete"
}

// Folders procedures - matches server tRPC router
object FoldersProcedures {
    const val LIST = "folders.list"
    const val GET = "folders.get"
    const val CREATE = "folders.create"
    const val UPDATE = "folders.update"
    const val REMOVE = "folders.remove"  // Server uses "remove" not "delete"
}

// User procedures
object UserProcedures {
    const val ME = "user.me"
    const val UPDATE_PROFILE = "user.updateProfile"
    const val DELETE_ACCOUNT = "user.deleteAccount"
}

// KeyShares procedures - matches iOS APIEndpoint.KeyShares
object KeySharesProcedures {
    const val CHECK = "keyShares.check"
    const val GET = "keyShares.get"
    const val CREATE = "keyShares.create"
    const val UPDATE_AUTH_SHARE = "keyShares.updateAuthShare"
    const val UPDATE_RECOVERY_SHARE = "keyShares.updateRecoveryShare"
    const val HAS_PASSWORD = "keyShares.hasPasswordEncryption"
    const val GET_PASSWORD = "keyShares.getPasswordEncryption"
    const val SET_PASSWORD = "keyShares.setPasswordEncryption"
    const val REMOVE_PASSWORD = "keyShares.removePasswordEncryption"
    const val DELETE = "keyShares.delete"
    const val RESET_ENCRYPTION = "keyShares.resetEncryption"
}

// Devices procedures - matches iOS APIEndpoint.Devices
object DevicesProcedures {
    const val LIST = "devices.list"
    const val GET_SECRET = "devices.getDeviceSecret"
    const val REGISTER = "devices.register"
    const val UPDATE_LAST_SEEN = "devices.updateLastSeen"
    const val REVOKE = "devices.revoke"
    const val DELETE = "devices.delete"
}

// WebAuthn (Passkeys) procedures - matches iOS APIEndpoint.WebAuthn
object WebAuthnProcedures {
    const val HAS_PASSKEYS = "webauthn.hasPasskeys"
    const val LIST = "webauthn.list"
    const val GENERATE_REGISTRATION = "webauthn.generateRegistrationOptions"
    const val VERIFY_REGISTRATION = "webauthn.verifyRegistration"
    const val GENERATE_AUTH = "webauthn.generateAuthenticationOptions"
    const val VERIFY_AUTH = "webauthn.verifyAuthentication"
    const val RENAME = "webauthn.rename"
    const val DELETE = "webauthn.delete"
}

// Credentials procedures - matches server tRPC router
object CredentialsProcedures {
    const val LIST = "credentials.list"
    const val GET = "credentials.get"
    const val CREATE = "credentials.create"
    const val UPDATE = "credentials.update"
    const val REMOVE = "credentials.remove"  // Server uses "remove" not "delete"
}

// Input/Output DTOs
@Serializable
data class PaginationInput(
    val cursor: String? = null,
    val limit: Int = 50
)

@Serializable
data class ChatListInput(
    val folderId: String? = null,
    val pagination: PaginationInput = PaginationInput()
)

@Serializable
data class ChatListOutput(
    val chats: List<ChatDto>,
    val nextCursor: String? = null
)

@Serializable
data class ChatDto(
    val id: String,
    val title: String,
    val lastMessage: String? = null,
    val folderId: String? = null,
    val createdAt: Long,
    val updatedAt: Long
)

@Serializable
data class CreateChatInput(
    val title: String,
    val folderId: String? = null
)

@Serializable
data class UpdateChatInput(
    val id: String,
    val title: String? = null,
    val folderId: String? = null
)

@Serializable
data class SendMessageInput(
    val chatId: String,
    val content: String,
    val model: String,
    val encryptedContent: String? = null
)

@Serializable
data class MessageDto(
    val id: String,
    val chatId: String,
    val role: String,
    val content: String,
    val model: String? = null,
    val reasoningContent: String? = null,
    val createdAt: Long
)

@Serializable
data class MessagesListOutput(
    val messages: List<MessageDto>,
    val nextCursor: String? = null
)

@Serializable
data class NoteDto(
    val id: String,
    val title: String,
    val content: String,
    val folderId: String? = null,
    val isPinned: Boolean = false,
    val createdAt: Long,
    val updatedAt: Long
)

@Serializable
data class NotesListOutput(
    val notes: List<NoteDto>,
    val nextCursor: String? = null
)

@Serializable
data class CreateNoteInput(
    val title: String,
    val content: String,
    val folderId: String? = null
)

@Serializable
data class UpdateNoteInput(
    val id: String,
    val title: String? = null,
    val content: String? = null,
    val folderId: String? = null,
    val isPinned: Boolean? = null
)

@Serializable
data class FolderDto(
    val id: String,
    val name: String,
    val parentId: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val chatCount: Int = 0,
    val noteCount: Int = 0,
    val createdAt: Long,
    val updatedAt: Long
)

@Serializable
data class FoldersListOutput(
    val folders: List<FolderDto>
)

@Serializable
data class CreateFolderInput(
    val name: String,
    val parentId: String? = null,
    val color: String? = null,
    val icon: String? = null
)

@Serializable
data class UpdateFolderInput(
    val id: String,
    val name: String? = null,
    val parentId: String? = null,
    val color: String? = null,
    val icon: String? = null
)

@Serializable
data class UserDto(
    val id: String,
    val email: String,
    val displayName: String? = null,
    val avatarUrl: String? = null,
    val hasE2EEKeys: Boolean = false,
    val createdAt: Long
)

@Serializable
data class UpdateProfileInput(
    val displayName: String? = null,
    val avatarUrl: String? = null
)

@Serializable
data class KeyShareDto(
    val deviceId: String,
    val encryptedShare: String,
    val shareIndex: Int,
    val totalShares: Int,
    val createdAt: Long
)

@Serializable
data class StoreKeyShareInput(
    val deviceId: String,
    val encryptedShare: String,
    val shareIndex: Int,
    val totalShares: Int
)

@Serializable
data class DeviceDto(
    val id: String,
    val name: String,
    val platform: String,
    val lastActive: Long,
    val createdAt: Long
)

@Serializable
data class RegisterDeviceInput(
    val name: String,
    val platform: String,
    val publicKey: String
)

@Serializable
data class CredentialDto(
    val id: String,
    val provider: String,
    val name: String,
    val maskedKey: String,
    val createdAt: Long
)

@Serializable
data class CreateCredentialInput(
    val provider: String,
    val name: String,
    val encryptedApiKey: String
)

@Serializable
data class IdInput(
    val id: String
)

@Serializable
data class EmptyInput(
    val placeholder: String = ""
)
