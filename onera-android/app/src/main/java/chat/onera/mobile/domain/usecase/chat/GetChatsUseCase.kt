package chat.onera.mobile.domain.usecase.chat

import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class GetChatsUseCase @Inject constructor(
    private val chatRepository: ChatRepository
) {
    operator fun invoke(): Flow<List<Chat>> {
        return chatRepository.observeChats()
    }
}
