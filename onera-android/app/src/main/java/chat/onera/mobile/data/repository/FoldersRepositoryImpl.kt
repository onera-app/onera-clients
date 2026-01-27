package chat.onera.mobile.data.repository

import android.util.Log
import chat.onera.mobile.data.remote.dto.*
import chat.onera.mobile.data.remote.trpc.FoldersProcedures
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.security.EncryptionManager
import chat.onera.mobile.domain.model.Folder
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.domain.repository.FoldersRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Folders Repository implementation - matches iOS FolderRepository.swift
 * 
 * Server-first approach (matching iOS):
 * - All create/update/delete operations call server FIRST
 * - Local state only updated AFTER server confirms success
 * - Throws exceptions on failure (caller handles UI feedback)
 * - No local-first creates or pending sync mechanisms
 */
@Singleton
class FoldersRepositoryImpl @Inject constructor(
    private val trpcClient: TRPCClient,
    private val encryptionManager: EncryptionManager,
    private val e2eeRepository: E2EERepository
) : FoldersRepository {
    
    companion object {
        private const val TAG = "FoldersRepository"
    }
    
    private val foldersFlow = MutableStateFlow<List<Folder>>(emptyList())

    override fun observeFolders(): Flow<List<Folder>> = foldersFlow.asStateFlow()

    override suspend fun getFolders(): List<Folder> = foldersFlow.value

    override suspend fun getFolder(folderId: String): Folder? {
        // Check local cache first
        foldersFlow.value.find { it.id == folderId }?.let { return it }
        
        // Try to fetch from server
        return fetchFolderFromServer(folderId)
    }

    /**
     * Create a folder - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun createFolder(name: String, parentId: String?): String {
        Log.d(TAG, "Creating folder...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot create folder")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt folder name
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(name, masterKey)
        
        val request = FolderCreateRequest(
            encryptedName = encryptedName,
            nameNonce = nameNonce,
            parentId = parentId
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<FolderCreateRequest, FolderCreateResponse>(
            FoldersProcedures.CREATE,
            request
        )
        val response = result.getOrThrow()
        Log.d(TAG, "Folder created on server: ${response.id}")
        
        // Only update local state AFTER server success
        val folder = Folder(
            id = response.id,
            name = name,
            parentId = parentId,
            createdAt = System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis()
        )
        foldersFlow.value = foldersFlow.value + folder
        
        return response.id
    }

    /**
     * Update a folder - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun updateFolder(folder: Folder) {
        Log.d(TAG, "Updating folder ${folder.id}...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            throw IllegalStateException("E2EE session locked - cannot update folder")
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Encrypt folder name
        val (encryptedName, nameNonce) = encryptionManager.encryptSecretBoxString(folder.name, masterKey)
        
        val request = FolderUpdateRequest(
            folderId = folder.id,
            encryptedName = encryptedName,
            nameNonce = nameNonce,
            parentId = folder.parentId
        )
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<FolderUpdateRequest, FolderUpdateResponse>(
            FoldersProcedures.UPDATE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Folder updated on server: ${folder.id}")
        
        // Only update local state AFTER server success
        val updatedFolder = folder.copy(updatedAt = System.currentTimeMillis())
        foldersFlow.value = foldersFlow.value.map { 
            if (it.id == folder.id) updatedFolder else it 
        }
    }

    /**
     * Delete a folder - Server First (matching iOS)
     * Calls server first, throws on failure, only updates local state after server success.
     */
    override suspend fun deleteFolder(folderId: String) {
        Log.d(TAG, "Deleting folder $folderId...")
        
        val request = FolderDeleteRequest(folderId = folderId)
        
        // Call server FIRST - throws on failure
        val result = trpcClient.mutation<FolderDeleteRequest, FolderDeleteResponse>(
            FoldersProcedures.REMOVE,
            request
        )
        result.getOrThrow()
        Log.d(TAG, "Folder deleted from server: $folderId")
        
        // Only update local state AFTER server success
        foldersFlow.value = foldersFlow.value.filter { it.id != folderId }
    }

    /**
     * Refresh folders from server.
     * Fetches all folders from server and updates local state.
     */
    override suspend fun refreshFolders() {
        Log.d(TAG, "Refreshing folders from server...")
        
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot decrypt folders")
            return
        }
        
        val masterKey = e2eeRepository.getMasterKey()
        
        // Fetch from server
        val result = trpcClient.query<Unit, List<EncryptedFolderResponse>>(
            FoldersProcedures.LIST,
            Unit
        )
        
        val encryptedFolders = result.getOrThrow()
        Log.d(TAG, "Received ${encryptedFolders.size} encrypted folders from server")
        
        // Decrypt and update local state
        val decryptedFolders = encryptedFolders.mapNotNull { encrypted ->
            try {
                decryptFolder(encrypted, masterKey)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to decrypt folder ${encrypted.id}", e)
                null
            }
        }
        
        foldersFlow.value = decryptedFolders
        Log.d(TAG, "Decrypted ${decryptedFolders.size} folders")
    }
    
    // ===== Private Helpers =====
    
    private suspend fun fetchFolderFromServer(folderId: String): Folder? {
        if (!e2eeRepository.isSessionUnlocked()) {
            Log.w(TAG, "E2EE session locked, cannot fetch folder")
            return null
        }
        
        try {
            val masterKey = e2eeRepository.getMasterKey()
            val request = FolderGetRequest(folderId = folderId)
            
            val result = trpcClient.query<FolderGetRequest, EncryptedFolderResponse>(
                FoldersProcedures.GET,
                request
            )
            
            return result.fold(
                onSuccess = { encrypted ->
                    val folder = decryptFolder(encrypted, masterKey)
                    // Add to cache
                    if (folder != null) {
                        foldersFlow.value = foldersFlow.value.filter { it.id != folderId } + folder
                    }
                    folder
                },
                onFailure = { e ->
                    Log.e(TAG, "Failed to fetch folder from server", e)
                    null
                }
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching folder", e)
            return null
        }
    }
    
    private fun decryptFolder(encrypted: EncryptedFolderResponse, masterKey: ByteArray): Folder? {
        return try {
            val name = if (encrypted.encryptedName != null && encrypted.nameNonce != null) {
                encryptionManager.decryptSecretBoxString(
                    encrypted.encryptedName,
                    encrypted.nameNonce,
                    masterKey
                )
            } else {
                "Encrypted Folder"
            }
            
            Folder(
                id = encrypted.id,
                name = name,
                parentId = encrypted.parentId,
                color = null,
                icon = null,
                createdAt = encrypted.createdAt,
                updatedAt = encrypted.updatedAt
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to decrypt folder", e)
            null
        }
    }
}
