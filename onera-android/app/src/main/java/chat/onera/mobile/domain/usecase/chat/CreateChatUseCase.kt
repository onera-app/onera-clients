package chat.onera.mobile.domain.usecase.chat

import chat.onera.mobile.domain.repository.ChatRepository
import javax.inject.Inject

class CreateChatUseCase @Inject constructor(
    private val chatRepository: ChatRepository
) {
    suspend operator fun invoke(title: String): String {
        return chatRepository.createChat(title)
    }
}
