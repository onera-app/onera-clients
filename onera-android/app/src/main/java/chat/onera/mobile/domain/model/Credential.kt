package chat.onera.mobile.domain.model

/**
 * Domain model for an API credential.
 */
data class Credential(
    val id: String,
    val provider: LLMProvider,
    val name: String,
    val apiKey: String,
    val baseUrl: String? = null,
    val orgId: String? = null,
    val createdAt: Long = System.currentTimeMillis()
) {
    /**
     * Get the effective base URL for API calls.
     */
    val effectiveBaseUrl: String
        get() = baseUrl ?: provider.defaultBaseUrl
    
    /**
     * Get a masked version of the API key for display.
     */
    val maskedApiKey: String
        get() = if (apiKey.length > 8) {
            "${apiKey.take(4)}...${apiKey.takeLast(4)}"
        } else {
            "****"
        }
}

/**
 * LLM Provider types.
 */
enum class LLMProvider(val displayName: String, val defaultBaseUrl: String) {
    OPENAI("OpenAI", "https://api.openai.com/v1"),
    ANTHROPIC("Anthropic", "https://api.anthropic.com"),
    GOOGLE("Google AI", "https://generativelanguage.googleapis.com"),
    GROQ("Groq", "https://api.groq.com/openai/v1"),
    TOGETHER("Together AI", "https://api.together.xyz/v1"),
    OPENROUTER("OpenRouter", "https://openrouter.ai/api/v1"),
    OLLAMA("Ollama", "http://localhost:11434/v1"),
    CUSTOM("Custom", "");
    
    companion object {
        fun fromString(value: String): LLMProvider {
            return entries.find { 
                it.name.equals(value, ignoreCase = true) ||
                it.displayName.equals(value, ignoreCase = true)
            } ?: CUSTOM
        }
    }
}
