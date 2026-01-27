package chat.onera.mobile.domain.usecase.chat

import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.E2EERepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

class SendMessageUseCase @Inject constructor(
    private val chatRepository: ChatRepository,
    private val e2eeRepository: E2EERepository
) {
    /**
     * Send a message and stream the LLM response.
     * 
     * Note: Messages are stored locally in plaintext and encrypted with per-chat keys
     * when synced to the server. This approach matches iOS and web implementations.
     * The LLM processes plaintext - encryption is for server-side storage only.
     */
    operator fun invoke(chatId: String, content: String, model: String = "gpt-4o"): Flow<String> {
        // Messages are processed locally, encryption happens in ChatRepository when syncing
        return chatRepository.sendMessageStream(chatId, content, model)
    }
}
