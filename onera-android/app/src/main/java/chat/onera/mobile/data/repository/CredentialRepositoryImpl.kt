package chat.onera.mobile.data.repository

import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.CredentialsProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.domain.model.Credential
import chat.onera.mobile.domain.model.LLMProvider
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.E2EERepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Credential Repository implementation - matches iOS CredentialService.swift
 * Manages encrypted API credentials with E2EE.
 */
@Singleton
class CredentialRepositoryImpl @Inject constructor(
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager,
    private val e2eeRepository: E2EERepository
) : CredentialRepository {
    
    companion object {
        private const val TAG = "CredentialRepository"
    }
    
    private val json = Json { 
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    private val _credentials = MutableStateFlow<List<Credential>>(emptyList())
    private val _isLoading = MutableStateFlow(false)
    
    // ===== Public Interface =====
    
    override fun observeCredentials(): Flow<List<Credential>> = _credentials.asStateFlow()
    
    override suspend fun getCredentials(): List<Credential> = _credentials.value
    
    override suspend fun getCredential(id: String): Credential? {
        return _credentials.value.find { it.id == id }
    }
    
    override suspend fun getCredentialsForProvider(provider: LLMProvider): List<Credential> {
        return _credentials.value.filter { it.provider == provider }
    }
    
    override suspend fun refreshCredentials() {
        Log.d(TAG, "Refreshing credentials from server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot decrypt credentials")
            return
        }
        
        _isLoading.value = true
        
        try {
            val masterKey = e2eeRepository.getMasterKey()
            
            // Fetch encrypted credentials from server
            val result = trpcClient.query<Unit, List<EncryptedCredentialResponse>>(
                CredentialsProcedures.LIST,
                Unit
            )
            
            result.onSuccess { encryptedCredentials ->
                Log.d(TAG, "Received ${encryptedCredentials.size} encrypted credentials")
                
                val decrypted = encryptedCredentials.mapNotNull { encrypted ->
                    try {
                        decryptCredential(encrypted, masterKey)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to decrypt credential ${encrypted.id}", e)
                        null
                    }
                }
                
                _credentials.value = decrypted
                Log.d(TAG, "Decrypted ${decrypted.size} credentials")
            }.onFailure { e ->
                Log.e(TAG, "Failed to fetch credentials", e)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error refreshing credentials", e)
        } finally {
            _isLoading.value = false
        }
    }
    
    override suspend fun createCredential(
        provider: LLMProvider,
        name: String,
        apiKey: String,
        baseUrl: String?,
        orgId: String?
    ): String {
        Log.d(TAG, "Creating credential for $provider...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt credential data (API key, base URL, etc.) using XSalsa20-Poly1305
        val credentialData = CredentialData(
            apiKey = apiKey,
            baseUrl = baseUrl,
            orgId = orgId,
            config = null
        )
        val dataJson = json.encodeToString(credentialData)
        val (encryptedData, dataIv) = encryptionManager.encryptSecretBoxString(dataJson, masterKey)
        
        // Encrypt name using XSalsa20-Poly1305
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(name, masterKey)
        
        // Encrypt provider using XSalsa20-Poly1305
        val (encryptedProvider, providerNonce) = encryptionManager.encryptSecretBoxString(
            provider.name.lowercase(),
            masterKey
        )
        
        // Send to server
        val request = CreateEncryptedCredentialRequest(
            encryptedData = encryptedData,
            iv = dataIv,
            encryptedName = encryptedName,
            nameNonce = nameNonce,
            encryptedProvider = encryptedProvider,
            providerNonce = providerNonce
        )
        
        val result = trpcClient.mutation<CreateEncryptedCredentialRequest, CreateCredentialResponse>(
            CredentialsProcedures.CREATE,
            request
        )
        
        val response = result.getOrThrow()
        Log.d(TAG, "Created credential: ${response.id}")
        
        // Add to local list
        val newCredential = Credential(
            id = response.id,
            provider = provider,
            name = name,
            apiKey = apiKey,
            baseUrl = baseUrl,
            orgId = orgId,
            createdAt = System.currentTimeMillis()
        )
        _credentials.value = _credentials.value + newCredential
        
        return response.id
    }
    
    override suspend fun updateCredential(credential: Credential) {
        Log.d(TAG, "Updating credential ${credential.id}...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt credential data using XSalsa20-Poly1305
        val credentialData = CredentialData(
            apiKey = credential.apiKey,
            baseUrl = credential.baseUrl,
            orgId = credential.orgId,
            config = null
        )
        val dataJson = json.encodeToString(credentialData)
        val (encryptedData, dataIv) = encryptionManager.encryptSecretBoxString(dataJson, masterKey)
        
        // Encrypt name using XSalsa20-Poly1305
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(credential.name, masterKey)
        
        // Send to server
        val request = UpdateEncryptedCredentialRequest(
            credentialId = credential.id,
            encryptedData = encryptedData,
            iv = dataIv,
            encryptedName = encryptedName,
            nameNonce = nameNonce
        )
        
        val result = trpcClient.mutation<UpdateEncryptedCredentialRequest, UpdateCredentialResponse>(
            CredentialsProcedures.UPDATE,
            request
        )
        
        result.getOrThrow()
        Log.d(TAG, "Updated credential: ${credential.id}")
        
        // Update local list
        _credentials.value = _credentials.value.map { 
            if (it.id == credential.id) credential else it 
        }
    }
    
    override suspend fun deleteCredential(id: String) {
        Log.d(TAG, "Deleting credential $id...")
        
        val request = RemoveCredentialRequest(credentialId = id)
        val result = trpcClient.mutation<RemoveCredentialRequest, RemoveCredentialResponse>(
            CredentialsProcedures.REMOVE,
            request
        )
        
        result.getOrThrow()
        Log.d(TAG, "Deleted credential: $id")
        
        // Remove from local list
        _credentials.value = _credentials.value.filter { it.id != id }
    }
    
    override fun clearCredentials() {
        _credentials.value = emptyList()
    }
    
    // ===== Private Decryption =====
    
    private fun decryptCredential(
        encrypted: EncryptedCredentialResponse,
        masterKey: ByteArray
    ): Credential? {
        // Decrypt credential data (API key, base URL, etc.) using XSalsa20-Poly1305
        val dataJson = encryptionManager.decryptSecretBoxString(
            encrypted.encryptedData,
            encrypted.iv,
            masterKey
        )
        val credentialData = json.decodeFromString<CredentialData>(dataJson)
        
        // Decrypt name using XSalsa20-Poly1305
        val name = if (encrypted.encryptedName != null && encrypted.nameNonce != null) {
            try {
                encryptionManager.decryptSecretBoxString(
                    encrypted.encryptedName,
                    encrypted.nameNonce,
                    masterKey
                )
            } catch (e: Exception) {
                "Encrypted Credential"
            }
        } else {
            "Encrypted Credential"
        }
        
        // Decrypt provider using XSalsa20-Poly1305
        val providerString = if (encrypted.encryptedProvider != null && encrypted.providerNonce != null) {
            try {
                encryptionManager.decryptSecretBoxString(
                    encrypted.encryptedProvider,
                    encrypted.providerNonce,
                    masterKey
                )
            } catch (e: Exception) {
                "custom"
            }
        } else {
            "custom"
        }
        
        val provider = LLMProvider.fromString(providerString)
        
        return Credential(
            id = encrypted.id,
            provider = provider,
            name = name,
            apiKey = credentialData.apiKey,
            baseUrl = credentialData.baseUrl,
            orgId = credentialData.orgId,
            createdAt = encrypted.createdAt
        )
    }
}
