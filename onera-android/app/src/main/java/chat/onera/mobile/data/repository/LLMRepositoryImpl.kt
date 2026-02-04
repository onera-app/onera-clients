package chat.onera.mobile.data.repository

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import chat.onera.mobile.data.remote.llm.ChatMessage
import chat.onera.mobile.data.remote.llm.DecryptedCredential
import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.data.remote.llm.LLMClient
import chat.onera.mobile.data.remote.llm.LLMException
import chat.onera.mobile.data.remote.llm.LLMProvider
import chat.onera.mobile.data.remote.llm.ModelInfo
import chat.onera.mobile.data.remote.llm.StreamEvent
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.domain.repository.StoredCredential
import dagger.Lazy
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation of LLMRepository that manages encrypted credentials
 * and coordinates with LLMClient for API calls.
 */
@Singleton
class LLMRepositoryImpl @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val llmClient: LLMClient,
    private val credentialRepositoryLazy: Lazy<CredentialRepository>
) : LLMRepository {
    
    // Use lazy to avoid circular dependency
    private val credentialRepository: CredentialRepository
        get() = credentialRepositoryLazy.get()
    
    companion object {
        private const val TAG = "LLMRepository"
        private const val PREFS_NAME = "llm_credentials"
        private const val KEY_CREDENTIALS = "credentials"
        
        /** Model cache TTL: 5 minutes (matches web implementation) */
        private const val MODEL_CACHE_TTL_MS = 5 * 60 * 1000L
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    // Model cache keyed by credential ID
    private data class ModelCacheEntry(
        val models: List<ModelInfo>,
        val fetchedAt: Long
    )
    private val modelCache = mutableMapOf<String, ModelCacheEntry>()
    
    // Lazy-init encrypted prefs to avoid blocking main thread
    private val encryptedPrefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        
        EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
    
    // In-memory cache of credentials
    private var credentialsCache: MutableList<EncryptedCredentialData>? = null
    
    override fun streamChat(
        credentialId: String,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String?,
        maxTokens: Int,
        images: List<ImageData>
    ): Flow<StreamEvent> = flow {
        val credential = getDecryptedCredential(credentialId)
            ?: throw LLMException.AuthenticationFailed("Credential not found: $credentialId")
        
        llmClient.streamChat(credential, messages, model, systemPrompt, maxTokens, images)
            .collect { emit(it) }
    }
    
    override suspend fun chat(
        credentialId: String,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String?,
        maxTokens: Int
    ): String {
        val credential = getDecryptedCredential(credentialId)
            ?: throw LLMException.AuthenticationFailed("Credential not found: $credentialId")
        
        return llmClient.chat(credential, messages, model, systemPrompt, maxTokens)
    }
    
    override suspend fun fetchModels(credentialId: String): List<ModelInfo> {
        // Check cache first
        val now = System.currentTimeMillis()
        modelCache[credentialId]?.let { cached ->
            if (now - cached.fetchedAt < MODEL_CACHE_TTL_MS) {
                return cached.models
            }
        }
        
        val credential = getDecryptedCredential(credentialId)
            ?: throw LLMException.AuthenticationFailed("Credential not found: $credentialId")
        
        return try {
            val models = llmClient.fetchModels(credential)
            // Cache the results
            modelCache[credentialId] = ModelCacheEntry(models, now)
            models
        } catch (e: Exception) {
            // On error, return stale cache if available (better UX)
            modelCache[credentialId]?.models ?: throw e
        }
    }
    
    /** Invalidate model cache for a specific credential or all credentials */
    fun invalidateModelCache(credentialId: String? = null) {
        if (credentialId != null) {
            modelCache.remove(credentialId)
        } else {
            modelCache.clear()
        }
    }
    
    override fun cancelStream() {
        llmClient.cancelStream()
    }
    
    override suspend fun getCredentials(): List<StoredCredential> {
        return loadCredentials().map { it.toStoredCredential() }
    }
    
    override suspend fun addCredential(
        provider: String,
        name: String,
        apiKey: String,
        baseUrl: String?
    ): String {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        
        val credentialData = EncryptedCredentialData(
            id = id,
            provider = provider.lowercase(),
            name = name.ifBlank { LLMProvider.fromName(provider)?.displayName ?: provider },
            apiKey = apiKey,
            baseUrl = baseUrl,
            createdAt = now
        )
        
        val credentials = loadCredentials().toMutableList()
        credentials.add(credentialData)
        saveCredentials(credentials)
        
        Log.d(TAG, "Added credential: $id for provider: $provider")
        return id
    }
    
    override suspend fun deleteCredential(credentialId: String) {
        val credentials = loadCredentials().toMutableList()
        credentials.removeAll { it.id == credentialId }
        saveCredentials(credentials)
        Log.d(TAG, "Deleted credential: $credentialId")
    }
    
    override suspend fun validateCredential(credentialId: String): Boolean {
        return try {
            val models = fetchModels(credentialId)
            models.isNotEmpty()
        } catch (e: Exception) {
            Log.w(TAG, "Credential validation failed: ${e.message}")
            false
        }
    }
    
    // ========================================================================
    // Internal Methods
    // ========================================================================
    
    /**
     * Get a decrypted credential by ID for making API calls.
     * First checks server-synced credentials, then falls back to local storage.
     */
    private fun getDecryptedCredential(credentialId: String): DecryptedCredential? {
        // First try server-synced credentials
        val serverCred = runBlocking { 
            try {
                credentialRepository.getCredential(credentialId)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to get credential from server: ${e.message}")
                null
            }
        }
        
        if (serverCred != null) {
            val provider = LLMProvider.fromName(serverCred.provider.name) ?: LLMProvider.CUSTOM
            return DecryptedCredential(
                id = serverCred.id,
                provider = provider,
                apiKey = serverCred.apiKey,
                name = serverCred.name,
                baseUrl = serverCred.baseUrl
            )
        }
        
        // Fall back to local storage
        val data = loadCredentials().find { it.id == credentialId } ?: return null
        val provider = LLMProvider.fromName(data.provider) ?: LLMProvider.CUSTOM
        
        return DecryptedCredential(
            id = data.id,
            provider = provider,
            apiKey = data.apiKey,
            name = data.name,
            baseUrl = data.baseUrl
        )
    }
    
    /**
     * Get a decrypted credential by provider for quick access.
     */
    fun getDecryptedCredentialByProvider(provider: LLMProvider): DecryptedCredential? {
        // Try server-synced credentials first
        val serverCreds = runBlocking { 
            try {
                credentialRepository.getCredentialsForProvider(
                    chat.onera.mobile.domain.model.LLMProvider.fromString(provider.name)
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to get credentials by provider: ${e.message}")
                emptyList()
            }
        }
        
        if (serverCreds.isNotEmpty()) {
            val cred = serverCreds.first()
            return DecryptedCredential(
                id = cred.id,
                provider = provider,
                apiKey = cred.apiKey,
                name = cred.name,
                baseUrl = cred.baseUrl
            )
        }
        
        // Fall back to local storage
        val data = loadCredentials().find { 
            it.provider.equals(provider.name, ignoreCase = true) 
        } ?: return null
        
        return DecryptedCredential(
            id = data.id,
            provider = provider,
            apiKey = data.apiKey,
            name = data.name,
            baseUrl = data.baseUrl
        )
    }
    
    /**
     * Get the first available credential (for testing).
     */
    fun getFirstCredential(): DecryptedCredential? {
        // Try server-synced credentials first  
        val serverCreds = runBlocking {
            try {
                credentialRepository.getCredentials()
            } catch (e: Exception) {
                Log.w(TAG, "Failed to get credentials: ${e.message}")
                emptyList()
            }
        }
        
        if (serverCreds.isNotEmpty()) {
            val cred = serverCreds.first()
            val provider = LLMProvider.fromName(cred.provider.name) ?: LLMProvider.CUSTOM
            return DecryptedCredential(
                id = cred.id,
                provider = provider,
                apiKey = cred.apiKey,
                name = cred.name,
                baseUrl = cred.baseUrl
            )
        }
        
        // Fall back to local storage
        val data = loadCredentials().firstOrNull() ?: return null
        val provider = LLMProvider.fromName(data.provider) ?: LLMProvider.CUSTOM
        
        return DecryptedCredential(
            id = data.id,
            provider = provider,
            apiKey = data.apiKey,
            name = data.name,
            baseUrl = data.baseUrl
        )
    }
    
    private fun loadCredentials(): List<EncryptedCredentialData> {
        credentialsCache?.let { return it }
        
        val jsonString = encryptedPrefs.getString(KEY_CREDENTIALS, null)
        
        val credentials = if (jsonString != null) {
            try {
                json.decodeFromString<List<EncryptedCredentialData>>(jsonString).toMutableList()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load credentials", e)
                mutableListOf()
            }
        } else {
            mutableListOf()
        }
        
        credentialsCache = credentials
        return credentials
    }
    
    private fun saveCredentials(credentials: List<EncryptedCredentialData>) {
        val jsonString = json.encodeToString(credentials)
        encryptedPrefs.edit()
            .putString(KEY_CREDENTIALS, jsonString)
            .apply()
        credentialsCache = credentials.toMutableList()
    }
    
    /**
     * Internal data class for storing credentials.
     * API key is stored encrypted via EncryptedSharedPreferences.
     */
    @Serializable
    private data class EncryptedCredentialData(
        val id: String,
        val provider: String,
        val name: String,
        val apiKey: String,
        val baseUrl: String? = null,
        val createdAt: Long
    ) {
        fun toStoredCredential() = StoredCredential(
            id = id,
            provider = provider,
            name = name,
            maskedKey = maskApiKey(apiKey),
            baseUrl = baseUrl,
            createdAt = createdAt
        )
        
        private fun maskApiKey(key: String): String {
            return if (key.length > 8) {
                "${key.take(4)}...${key.takeLast(4)}"
            } else {
                "••••••••"
            }
        }
    }
}
