package chat.onera.mobile.data.remote.private_inference

import android.util.Log
import chat.onera.mobile.data.remote.trpc.EnclavesProcedures
import chat.onera.mobile.data.remote.trpc.PrivateModelDto
import chat.onera.mobile.data.remote.trpc.PrivateModelsListOutput
import chat.onera.mobile.data.remote.trpc.ReleaseEnclaveInput
import chat.onera.mobile.data.remote.trpc.RequestEnclaveInput
import chat.onera.mobile.data.remote.trpc.RequestEnclaveOutput
import chat.onera.mobile.data.remote.trpc.TRPCClient
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for managing private inference enclave requests via tRPC.
 * 
 * Handles:
 * - Listing available private models
 * - Requesting enclave assignments
 * - Releasing enclave assignments
 */
@Singleton
class EnclaveService @Inject constructor(
    private val trpcClient: TRPCClient
) {
    companion object {
        private const val TAG = "EnclaveService"
        
        /** Cache TTL for model list: 5 minutes */
        private const val MODEL_CACHE_TTL_MS = 5 * 60 * 1000L
    }
    
    // Model list cache
    private var modelCache: List<PrivateModelDto>? = null
    private var modelCacheFetchedAt: Long = 0
    
    // Active assignments
    private val activeAssignments = mutableMapOf<String, String>() // modelId -> assignmentId
    
    /**
     * Get available private models
     */
    suspend fun listModels(forceRefresh: Boolean = false): List<PrivateModelDto> {
        val now = System.currentTimeMillis()
        
        // Return cached if fresh
        if (!forceRefresh && modelCache != null && now - modelCacheFetchedAt < MODEL_CACHE_TTL_MS) {
            return modelCache!!
        }
        
        return try {
            val result = trpcClient.query<Unit, PrivateModelsListOutput>(
                EnclavesProcedures.LIST_MODELS,
                Unit
            )
            
            result.getOrNull()?.models?.also {
                modelCache = it
                modelCacheFetchedAt = now
                Log.d(TAG, "Fetched ${it.size} private models")
            } ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to list models: ${e.message}", e)
            modelCache ?: emptyList()
        }
    }
    
    /**
     * Request an enclave for a specific model
     */
    suspend fun requestEnclave(
        modelId: String,
        sessionId: String = UUID.randomUUID().toString()
    ): EnclaveConfig? {
        Log.d(TAG, "Requesting enclave for model: $modelId")
        
        val input = RequestEnclaveInput(
            modelId = parsePrivateModelId(modelId),
            tier = "shared",
            sessionId = sessionId
        )
        
        return try {
            val result = trpcClient.mutation<RequestEnclaveInput, RequestEnclaveOutput>(
                EnclavesProcedures.REQUEST,
                input
            )
            
            val response = result.getOrNull() ?: run {
                Log.e(TAG, "Failed to request enclave: ${result.exceptionOrNull()?.message}")
                return null
            }
            
            // Track the assignment
            activeAssignments[modelId] = response.assignmentId
            Log.d(TAG, "Enclave assigned: ${response.assignmentId}")
            
            EnclaveConfig(
                id = response.enclave.id,
                name = modelId,
                endpoint = "https://${response.enclave.host}:${response.enclave.port}",
                wsEndpoint = response.wsEndpoint,
                attestationEndpoint = response.attestationEndpoint,
                allowUnverified = response.allowUnverified
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request enclave: ${e.message}", e)
            null
        }
    }
    
    /**
     * Release an enclave assignment
     */
    suspend fun releaseEnclave(modelId: String) {
        val assignmentId = activeAssignments.remove(modelId) ?: return
        
        Log.d(TAG, "Releasing enclave assignment: $assignmentId")
        
        try {
            trpcClient.mutation<ReleaseEnclaveInput, Unit>(
                EnclavesProcedures.RELEASE,
                ReleaseEnclaveInput(assignmentId)
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to release enclave (may already be released): ${e.message}")
        }
    }
    
    /**
     * Release all active enclave assignments
     */
    suspend fun releaseAll() {
        val assignments = activeAssignments.keys.toList()
        assignments.forEach { modelId ->
            releaseEnclave(modelId)
        }
    }
    
    /**
     * Check if there's an active assignment for a model
     */
    fun hasActiveAssignment(modelId: String): Boolean {
        return activeAssignments.containsKey(modelId)
    }
}
