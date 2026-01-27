package chat.onera.mobile.presentation.features.main

import chat.onera.mobile.presentation.base.UiEffect

sealed interface MainEffect : UiEffect {
    data class ShowError(val message: String) : MainEffect
    data class CopyToClipboard(val content: String) : MainEffect
    data object ScrollToBottom : MainEffect
    data object SignOutComplete : MainEffect
}
