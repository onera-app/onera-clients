package chat.onera.mobile.data.repository

import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.PromptsProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.domain.model.Prompt
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.domain.repository.PromptRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Prompt Repository implementation - matches iOS PromptRepository.swift
 * 
 * Server-first approach (matching iOS):
 * - All create/update/delete operations call server FIRST
 * - Local state only updated AFTER server confirms success
 * - Throws exceptions on failure (caller handles UI feedback)
 * - No local-first creates or pending sync mechanisms
 */
@Singleton
class PromptRepositoryImpl @Inject constructor(
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager,
    private val e2eeRepository: E2EERepository
) : PromptRepository {

    companion object {
        private const val TAG = "PromptRepository"
    }

    private val promptsFlow = MutableStateFlow<List<Prompt>>(emptyList())

    override fun observePrompts(): Flow<List<Prompt>> = promptsFlow.asStateFlow()

    override suspend fun getPrompts(): List<Prompt> = promptsFlow.value

    override suspend fun getPrompt(promptId: String): Prompt? {
        // First check local cache
        val cachedPrompt = promptsFlow.value.find { it.id == promptId }

        // If found in cache and has content, return it
        if (cachedPrompt != null && cachedPrompt.content.isNotEmpty()) {
            return cachedPrompt
        }

        // Fetch full prompt from server (to get content)
        return fetchPromptFromServer(promptId)
    }

    /**
     * Create a prompt - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun createPrompt(name: String, description: String, content: String): String {
        Log.d(TAG, "Creating prompt...")

        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot create prompt")
        }

        val masterKey = e2eeRepository.getMasterKey()

        // Encrypt prompt data
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(name, masterKey)
        val (encryptedContent, contentNonce) = encryptionManager.encryptSecretBoxString(content, masterKey)

        // Encrypt description if non-empty
        var encryptedDescription: String? = null
        var descriptionNonce: String? = null
        if (description.isNotEmpty()) {
            val (encDesc, descNonce) = encryptionManager.encryptSecretBoxString(description, masterKey)
            encryptedDescription = encDesc
            descriptionNonce = descNonce
        }

        val request = PromptCreateRequest(
            encryptedName = encryptedName,
            nameNonce = nameNonce,
            encryptedDescription = encryptedDescription,
            descriptionNonce = descriptionNonce,
            encryptedContent = encryptedContent,
            contentNonce = contentNonce
        )

        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<PromptCreateRequest, PromptCreateResponse>(
            PromptsProcedures.CREATE,
            request
        )
        val response = result.getOrThrow()
        Log.d(TAG, "Prompt created on server: ${response.id}")

        // Only update local state AFTER server success
        val prompt = Prompt(
            id = response.id,
            name = name,
            description = description,
            content = content,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        promptsFlow.value = promptsFlow.value + prompt

        return response.id
    }

    /**
     * Update a prompt - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun updatePrompt(prompt: Prompt) {
        Log.d(TAG, "Updating prompt ${prompt.id}...")

        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot update prompt")
        }

        val masterKey = e2eeRepository.getMasterKey()

        // Encrypt prompt data
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(prompt.name, masterKey)
        val (encryptedContent, contentNonce) = encryptionManager.encryptSecretBoxString(prompt.content, masterKey)

        // Encrypt description if non-empty
        var encryptedDescription: String? = null
        var descriptionNonce: String? = null
        if (prompt.description.isNotEmpty()) {
            val (encDesc, descNonce) = encryptionManager.encryptSecretBoxString(prompt.description, masterKey)
            encryptedDescription = encDesc
            descriptionNonce = descNonce
        }

        val request = PromptUpdateRequest(
            promptId = prompt.id,
            encryptedName = encryptedName,
            nameNonce = nameNonce,
            encryptedDescription = encryptedDescription,
            descriptionNonce = descriptionNonce,
            encryptedContent = encryptedContent,
            contentNonce = contentNonce
        )

        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<PromptUpdateRequest, PromptUpdateResponse>(
            PromptsProcedures.UPDATE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Prompt updated on server: ${prompt.id}")

        // Only update local state AFTER server success
        val updatedPrompt = prompt.copy(updatedAt = System.currentTimeMillis())
        promptsFlow.value = promptsFlow.value.map {
            if (it.id == prompt.id) updatedPrompt else it
        }
    }

    /**
     * Delete a prompt - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun deletePrompt(promptId: String) {
        Log.d(TAG, "Deleting prompt $promptId...")

        val request = PromptDeleteRequest(promptId = promptId)

        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<PromptDeleteRequest, PromptDeleteResponse>(
            PromptsProcedures.REMOVE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Prompt deleted from server: $promptId")

        // Only update local state AFTER server success
        promptsFlow.value = promptsFlow.value.filter { it.id != promptId }
    }

    /**
     * Refresh prompts from server.
     * Fetches all prompts from server and updates local state.
     */
    override suspend fun refreshPrompts() {
        Log.d(TAG, "Refreshing prompts from server...")

        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot decrypt prompts")
            return
        }

        val masterKey = e2eeRepository.getMasterKey()

        // Fetch from server
        val result = trpcClient.query<Unit, List<EncryptedPromptResponse>>(
            PromptsProcedures.LIST,
            Unit
        )

        val encryptedPrompts = result.getOrThrow()
        Log.d(TAG, "Received ${encryptedPrompts.size} encrypted prompts from server")

        // Decrypt and update local state
        val decryptedPrompts = encryptedPrompts.mapNotNull { encrypted ->
            try {
                decryptPrompt(encrypted, masterKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decrypt prompt ${encrypted.id}", e)
                null
            }
        }

        promptsFlow.value = decryptedPrompts
        Log.d(TAG, "Decrypted ${decryptedPrompts.size} prompts")
    }

    // ===== Private Helpers =====

    private suspend fun fetchPromptFromServer(promptId: String): Prompt? {
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot fetch prompt")
            return null
        }

        try {
            val masterKey = e2eeRepository.getMasterKey()
            val request = PromptGetRequest(promptId = promptId)

            val result = trpcClient.query<PromptGetRequest, EncryptedPromptResponse>(
                PromptsProcedures.GET,
                request
            )

            return result.fold(
                onSuccess = { encrypted ->
                    val prompt = decryptPrompt(encrypted, masterKey)
                    // Update cache
                    if (prompt != null) {
                        promptsFlow.value = promptsFlow.value.filter { it.id != promptId } + prompt
                    }
                    prompt
                },
                onFailure = { e ->
                    Log.e(TAG, "Failed to fetch prompt from server", e)
                    null
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching prompt", e)
            return null
        }
    }

    private fun decryptPrompt(encrypted: EncryptedPromptResponse, masterKey: ByteArray): Prompt? {
        return try {
            val name = encryptionManager.decryptSecretBoxString(
                encrypted.encryptedName,
                encrypted.nameNonce,
                masterKey
            )

            // Decrypt description if present
            val description = if (encrypted.encryptedDescription != null && encrypted.descriptionNonce != null) {
                try {
                    encryptionManager.decryptSecretBoxString(
                        encrypted.encryptedDescription,
                        encrypted.descriptionNonce,
                        masterKey
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to decrypt prompt description", e)
                    ""
                }
            } else {
                ""
            }

            val content = encryptionManager.decryptSecretBoxString(
                encrypted.encryptedContent,
                encrypted.contentNonce,
                masterKey
            )

            Prompt(
                id = encrypted.id,
                name = name,
                description = description,
                content = content,
                createdAt = encrypted.createdAt,
                updatedAt = encrypted.updatedAt
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decrypt prompt ${encrypted.id}", e)
            null
        }
    }
}
