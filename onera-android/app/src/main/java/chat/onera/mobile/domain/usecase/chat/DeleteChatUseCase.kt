package chat.onera.mobile.domain.usecase.chat

import chat.onera.mobile.domain.repository.ChatRepository
import javax.inject.Inject

class DeleteChatUseCase @Inject constructor(
    private val chatRepository: ChatRepository
) {
    suspend operator fun invoke(chatId: String) {
        chatRepository.deleteChat(chatId)
    }
}
