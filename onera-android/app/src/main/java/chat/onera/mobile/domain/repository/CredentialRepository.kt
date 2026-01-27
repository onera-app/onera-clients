package chat.onera.mobile.domain.repository

import chat.onera.mobile.domain.model.Credential
import chat.onera.mobile.domain.model.LLMProvider
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for managing encrypted API credentials.
 */
interface CredentialRepository {
    
    /** Observe all credentials */
    fun observeCredentials(): Flow<List<Credential>>
    
    /** Get all credentials */
    suspend fun getCredentials(): List<Credential>
    
    /** Get a credential by ID */
    suspend fun getCredential(id: String): Credential?
    
    /** Get credentials for a specific provider */
    suspend fun getCredentialsForProvider(provider: LLMProvider): List<Credential>
    
    /** Refresh credentials from server */
    suspend fun refreshCredentials()
    
    /** Create a new credential */
    suspend fun createCredential(
        provider: LLMProvider,
        name: String,
        apiKey: String,
        baseUrl: String? = null,
        orgId: String? = null
    ): String
    
    /** Update an existing credential */
    suspend fun updateCredential(credential: Credential)
    
    /** Delete a credential */
    suspend fun deleteCredential(id: String)
    
    /** Clear local credentials cache */
    fun clearCredentials()
}
