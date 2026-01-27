package chat.onera.mobile.presentation.features.chat

import chat.onera.mobile.presentation.base.UiEffect

// Chat List Effects
sealed interface ChatListEffect : UiEffect {
    data class NavigateToChat(val chatId: String) : ChatListEffect
    data class ShowError(val message: String) : ChatListEffect
}

// Individual Chat Effects
sealed interface ChatEffect : UiEffect {
    data class ChatCreated(val chatId: String) : ChatEffect
    data object ScrollToBottom : ChatEffect
    data class ShowError(val message: String) : ChatEffect
    data class CopyToClipboard(val text: String) : ChatEffect
}
