package chat.onera.mobile.data.remote.llm

/**
 * LLM Provider configuration for OpenAI-compatible API endpoints.
 * 
 * Most providers support the OpenAI chat completions protocol, with some
 * variations in authentication and endpoint structure.
 */
enum class LLMProvider(
    val displayName: String,
    val defaultBaseUrl: String,
    val chatEndpoint: String = "/chat/completions",
    val modelsEndpoint: String = "/models",
    val authType: AuthType = AuthType.BEARER
) {
    OPENAI(
        displayName = "OpenAI",
        defaultBaseUrl = "https://api.openai.com/v1"
    ),
    
    ANTHROPIC(
        displayName = "Anthropic",
        defaultBaseUrl = "https://api.anthropic.com/v1",
        chatEndpoint = "/messages",
        authType = AuthType.ANTHROPIC
    ),
    
    GOOGLE(
        displayName = "Google",
        defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta",
        chatEndpoint = "/models/{model}:generateContent",
        modelsEndpoint = "/models",
        authType = AuthType.GOOGLE_API_KEY
    ),
    
    XAI(
        displayName = "xAI",
        defaultBaseUrl = "https://api.x.ai/v1"
    ),
    
    GROQ(
        displayName = "Groq",
        defaultBaseUrl = "https://api.groq.com/openai/v1"
    ),
    
    MISTRAL(
        displayName = "Mistral",
        defaultBaseUrl = "https://api.mistral.ai/v1"
    ),
    
    DEEPSEEK(
        displayName = "DeepSeek",
        defaultBaseUrl = "https://api.deepseek.com/v1"
    ),
    
    OPENROUTER(
        displayName = "OpenRouter",
        defaultBaseUrl = "https://openrouter.ai/api/v1"
    ),
    
    TOGETHER(
        displayName = "Together",
        defaultBaseUrl = "https://api.together.xyz/v1"
    ),
    
    FIREWORKS(
        displayName = "Fireworks",
        defaultBaseUrl = "https://api.fireworks.ai/inference/v1"
    ),
    
    OLLAMA(
        displayName = "Ollama",
        defaultBaseUrl = "http://localhost:11434/v1",
        authType = AuthType.NONE
    ),
    
    LMSTUDIO(
        displayName = "LM Studio",
        defaultBaseUrl = "http://localhost:1234/v1",
        authType = AuthType.NONE
    ),
    
    CUSTOM(
        displayName = "Custom",
        defaultBaseUrl = ""
    ),
    
    PRIVATE(
        displayName = "Private (E2EE)",
        defaultBaseUrl = "",
        authType = AuthType.NONE  // Uses Noise Protocol instead
    );
    
    /**
     * Get the full chat completions URL for this provider
     */
    fun getChatUrl(baseUrl: String? = null, model: String? = null): String {
        val base = (baseUrl ?: defaultBaseUrl).trimEnd('/')
        return when (this) {
            GOOGLE -> {
                // Google uses model in the URL path
                "$base${chatEndpoint.replace("{model}", model ?: "gemini-pro")}"
            }
            else -> "$base$chatEndpoint"
        }
    }
    
    /**
     * Get the models listing URL for this provider
     */
    fun getModelsUrl(baseUrl: String? = null): String {
        val base = (baseUrl ?: defaultBaseUrl).trimEnd('/')
        return "$base$modelsEndpoint"
    }
    
    companion object {
        /**
         * Find provider by name (case-insensitive)
         */
        fun fromName(name: String): LLMProvider? {
            return entries.find { 
                it.name.equals(name, ignoreCase = true) ||
                it.displayName.equals(name, ignoreCase = true)
            }
        }
    }
}

/**
 * Authentication type for LLM providers
 */
enum class AuthType {
    /** Standard Bearer token in Authorization header */
    BEARER,
    
    /** Anthropic uses x-api-key header with anthropic-version */
    ANTHROPIC,
    
    /** Google uses API key as query parameter */
    GOOGLE_API_KEY,
    
    /** No authentication required (local providers) */
    NONE
}

/**
 * Extension to check if a provider uses OpenAI-compatible protocol
 */
val LLMProvider.isOpenAICompatible: Boolean
    get() = this != LLMProvider.ANTHROPIC && this != LLMProvider.GOOGLE
