package chat.onera.mobile.domain.usecase.chat

import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class GetMessagesUseCase @Inject constructor(
    private val chatRepository: ChatRepository
) {
    operator fun invoke(chatId: String): Flow<List<Message>> {
        return chatRepository.observeMessages(chatId)
    }
}
