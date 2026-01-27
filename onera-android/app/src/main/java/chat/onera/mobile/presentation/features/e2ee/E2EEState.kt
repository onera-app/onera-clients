package chat.onera.mobile.presentation.features.e2ee

import chat.onera.mobile.presentation.base.UiState

data class E2EESetupState(
    val step: E2EESetupStep = E2EESetupStep.INTRO,
    val isLoading: Boolean = false,
    val recoveryPhrase: List<String> = emptyList(),
    val verificationWords: List<IndexedWord> = emptyList(),
    val userInputWords: Map<Int, String> = emptyMap(),
    val isVerified: Boolean = false,
    val error: String? = null,
    // Passkey setup
    val isPasskeySupported: Boolean = false,
    val isRegisteringPasskey: Boolean = false,
    val passkeyRegistered: Boolean = false,
    // Password setup (alternative to passkey)
    val password: String = "",
    val confirmPassword: String = "",
    val showPassword: Boolean = false,
    val isSettingUpPassword: Boolean = false,
    val passwordSetUp: Boolean = false
) : UiState

/**
 * E2EE Setup steps - reordered to match web flow:
 * Passkey/Password setup BEFORE showing recovery phrase
 */
enum class E2EESetupStep {
    INTRO,
    GENERATING_KEYS,
    SETUP_PASSKEY,           // First try passkey (if supported)
    SETUP_PASSWORD,          // Fallback if passkey declined or unsupported
    SHOW_RECOVERY_PHRASE,    // Show recovery phrase AFTER unlock method is set
    VERIFY_RECOVERY_PHRASE,
    COMPLETE
}

data class IndexedWord(
    val index: Int,
    val word: String
)

/**
 * State for E2EE Unlock screen (returning users)
 */
data class E2EEUnlockState(
    val isCheckingMethods: Boolean = true,
    val isUnlocking: Boolean = false,
    val hasPasskey: Boolean = false, // True if passkeys exist (server or local)
    val hasLocalPasskey: Boolean = false, // True if local KEK exists (can biometric unlock)
    val hasPassword: Boolean = false,
    val hasMultipleOptions: Boolean = false,
    val password: String = "",
    val showPassword: Boolean = false,
    val recoveryWords: List<String> = List(24) { "" },
    val pastedPhrase: String = "",
    val showPasteField: Boolean = false,
    val error: String? = null,
    // Reset encryption state
    val isResetting: Boolean = false,
    val resetConfirmInput: String = "",
    val resetError: String? = null
) : UiState
