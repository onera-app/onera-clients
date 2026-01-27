package chat.onera.mobile.domain.repository

import chat.onera.mobile.data.remote.llm.ChatMessage
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.data.remote.llm.ModelInfo
import chat.onera.mobile.data.remote.llm.StreamEvent
import kotlinx.coroutines.flow.Flow

/**
 * Repository for LLM operations.
 * Coordinates credential management with LLM API calls.
 */
interface LLMRepository {
    
    /**
     * Stream a chat completion response.
     * 
     * @param credentialId The ID of the credential to use
     * @param messages The conversation messages
     * @param model The model name to use
     * @param systemPrompt Optional system prompt
     * @param maxTokens Maximum tokens to generate
     * @param images Optional list of images to include with the message
     * @return Flow of streaming events
     */
    fun streamChat(
        credentialId: String,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String? = null,
        maxTokens: Int = 4096,
        images: List<ImageData> = emptyList()
    ): Flow<StreamEvent>
    
    /**
     * Get a non-streaming chat completion.
     * 
     * @param credentialId The ID of the credential to use
     * @param messages The conversation messages
     * @param model The model name to use
     * @param systemPrompt Optional system prompt
     * @param maxTokens Maximum tokens to generate
     * @return The completion text
     */
    suspend fun chat(
        credentialId: String,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String? = null,
        maxTokens: Int = 4096
    ): String
    
    /**
     * Fetch available models for a credential.
     * 
     * @param credentialId The ID of the credential
     * @return List of available models
     */
    suspend fun fetchModels(credentialId: String): List<ModelInfo>
    
    /**
     * Cancel any active streaming request.
     */
    fun cancelStream()
    
    /**
     * Get all stored credentials (with masked keys).
     */
    suspend fun getCredentials(): List<StoredCredential>
    
    /**
     * Add a new credential.
     * 
     * @param provider The provider name (e.g., "openai", "groq")
     * @param name Display name for the credential
     * @param apiKey The API key
     * @param baseUrl Optional custom base URL
     * @return The ID of the created credential
     */
    suspend fun addCredential(
        provider: String,
        name: String,
        apiKey: String,
        baseUrl: String? = null
    ): String
    
    /**
     * Delete a credential.
     * 
     * @param credentialId The ID of the credential to delete
     */
    suspend fun deleteCredential(credentialId: String)
    
    /**
     * Validate a credential by making a test API call.
     * 
     * @param credentialId The ID of the credential to validate
     * @return true if the credential is valid
     */
    suspend fun validateCredential(credentialId: String): Boolean
}

/**
 * Stored credential with masked API key (for display purposes)
 */
data class StoredCredential(
    val id: String,
    val provider: String,
    val name: String,
    val maskedKey: String,
    val baseUrl: String? = null,
    val createdAt: Long
)
