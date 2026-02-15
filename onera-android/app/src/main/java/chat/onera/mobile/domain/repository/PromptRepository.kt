package chat.onera.mobile.domain.repository

import chat.onera.mobile.domain.model.Prompt
import kotlinx.coroutines.flow.Flow

interface PromptRepository {
    fun observePrompts(): Flow<List<Prompt>>
    suspend fun getPrompts(): List<Prompt>
    suspend fun getPrompt(promptId: String): Prompt?
    suspend fun createPrompt(name: String, description: String, content: String): String
    suspend fun updatePrompt(prompt: Prompt)
    suspend fun deletePrompt(promptId: String)
    suspend fun refreshPrompts()
}
