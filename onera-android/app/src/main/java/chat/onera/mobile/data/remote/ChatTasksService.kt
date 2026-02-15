package chat.onera.mobile.data.remote

import chat.onera.mobile.data.remote.llm.ChatMessage
import chat.onera.mobile.data.remote.llm.DecryptedCredential
import chat.onera.mobile.data.remote.llm.LLMClient
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatTasksService @Inject constructor(
    private val llmClient: LLMClient
) {
    /**
     * Generate follow-up questions based on recent conversation.
     * Uses the same LLM provider to generate contextual follow-ups.
     */
    suspend fun generateFollowUps(
        recentMessages: List<ChatMessage>,
        credential: DecryptedCredential,
        model: String,
        count: Int = 3
    ): List<String> {
        if (recentMessages.isEmpty()) return emptyList()

        return try {
            // Take last 6 messages for context
            val contextMessages = recentMessages.takeLast(6)

            val systemPrompt = """You are a helpful assistant that generates follow-up questions.
Based on the conversation below, suggest exactly $count follow-up questions the user might want to ask.
Return ONLY a JSON object in this format: {"follow_ups": ["Question 1?", "Question 2?", "Question 3?"]}
Keep questions concise (under 80 characters), diverse, and directly relevant to the conversation."""

            val messages = contextMessages + ChatMessage.user(
                "Based on our conversation, suggest $count follow-up questions I might want to ask."
            )

            val response = llmClient.chat(
                credential = credential,
                messages = messages,
                model = model,
                systemPrompt = systemPrompt,
                maxTokens = 300
            )

            extractFollowUps(response, count)
        } catch (e: Exception) {
            Timber.w(e, "Failed to generate follow-ups")
            emptyList()
        }
    }

    private fun extractFollowUps(response: String, count: Int): List<String> {
        // Try JSON parsing first
        try {
            val jsonMatch = Regex("\\{[^}]*\"follow_ups\"\\s*:\\s*\\[([^\\]]+)]").find(response)
            if (jsonMatch != null) {
                val arrayContent = jsonMatch.groupValues[1]
                val items = Regex("\"([^\"]+)\"").findAll(arrayContent)
                    .map { it.groupValues[1].trim() }
                    .filter { it.endsWith("?") || it.length > 10 }
                    .take(count)
                    .toList()
                if (items.isNotEmpty()) return items
            }
        } catch (e: Exception) {
            Timber.d("JSON parsing failed, trying fallback")
        }

        // Fallback: extract lines ending with ?
        return response.lines()
            .map { it.trim().removePrefix("-").removePrefix("*").trim() }
            .filter { it.endsWith("?") && it.length > 10 }
            .map { it.removePrefix("\"").removeSuffix("\"").trim() }
            .take(count)
    }
}
