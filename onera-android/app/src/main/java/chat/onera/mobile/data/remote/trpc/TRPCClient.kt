package chat.onera.mobile.data.remote.trpc

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import chat.onera.mobile.BuildConfig
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TRPCClient @Inject constructor(
    val authTokenProvider: AuthTokenProvider
) {
    val json = Json { 
        ignoreUnknownKeys = true 
        encodeDefaults = true
        explicitNulls = false  // Don't include null values in JSON (server expects omitted, not null)
    }
    
    val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    var baseUrl = "${BuildConfig.API_BASE_URL.trimEnd('/')}/trpc"
        private set
    
    fun setBaseUrl(url: String) {
        baseUrl = url
    }
    
    /**
     * Execute a tRPC query
     */
    suspend inline fun <reified I, reified O> query(
        procedure: String,
        input: I
    ): Result<O> = withContext(Dispatchers.IO) {
        try {
            // Handle Unit input specially - use empty object
            val inputJson = if (input is Unit) "{}" else json.encodeToString(input)
            val url = "$baseUrl/$procedure?input=$inputJson"
            
            // Get token BEFORE building request (properly handle suspend function)
            val token = authTokenProvider.getToken()
            
            val requestBuilder = Request.Builder()
                .url(url)
                .get()
            
            if (token != null) {
                requestBuilder.addHeader("Authorization", "Bearer $token")
                Log.d("TRPCClient", "query $procedure with auth token (${token.length} chars)")
            } else {
                Log.w("TRPCClient", "query $procedure WITHOUT auth token!")
            }
            
            val request = requestBuilder.build()
            
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.e("TRPCClient", "query $procedure failed: ${response.code} ${response.message}")
                    return@withContext Result.failure(TRPCException(response.code, response.message))
                }
                
                val body = response.body?.string() ?: return@withContext Result.failure(TRPCException(-1, "Empty response"))
                val result = json.decodeFromString<TRPCResponse<O>>(body)
                
                when {
                    result.result?.data != null -> Result.success(result.result.data)
                    result.error != null -> Result.failure(TRPCException(-1, result.error.message))
                    else -> Result.failure(TRPCException(-1, "Unknown error"))
                }
            }
        } catch (e: Exception) {
            Log.e("TRPCClient", "query $procedure exception: ${e.message}", e)
            Result.failure(e)
        }
    }
    
    /**
     * Execute a tRPC mutation
     */
    suspend inline fun <reified I, reified O> mutation(
        procedure: String,
        input: I
    ): Result<O> = withContext(Dispatchers.IO) {
        try {
            // Handle Unit input specially - use empty object
            val inputJson = if (input is Unit) "{}" else json.encodeToString(input)
            val url = "$baseUrl/$procedure"
            
            // Get token BEFORE building request (properly handle suspend function)
            val token = authTokenProvider.getToken()
            
            val requestBuilder = Request.Builder()
                .url(url)
                .post(inputJson.toRequestBody("application/json".toMediaType()))
            
            if (token != null) {
                requestBuilder.addHeader("Authorization", "Bearer $token")
                Log.d("TRPCClient", "mutation $procedure with auth token (${token.length} chars)")
            } else {
                Log.w("TRPCClient", "mutation $procedure WITHOUT auth token!")
            }
            
            val request = requestBuilder.build()
            
            Log.d("TRPCClient", "mutation $procedure with input: $inputJson")
            
            httpClient.newCall(request).execute().use { response ->
                val body = response.body?.string()
                
                if (!response.isSuccessful) {
                    Log.e("TRPCClient", "mutation $procedure failed: ${response.code} ${response.message}")
                    Log.e("TRPCClient", "Response body: $body")
                    return@withContext Result.failure(TRPCException(response.code, body ?: response.message))
                }
                
                if (body == null) {
                    return@withContext Result.failure(TRPCException(-1, "Empty response"))
                }
                
                val result = json.decodeFromString<TRPCResponse<O>>(body)
                
                when {
                    result.result?.data != null -> Result.success(result.result.data)
                    result.error != null -> {
                        Log.e("TRPCClient", "mutation $procedure error: ${result.error.message}")
                        Result.failure(TRPCException(-1, result.error.message))
                    }
                    else -> Result.failure(TRPCException(-1, "Unknown error"))
                }
            }
        } catch (e: Exception) {
            Log.e("TRPCClient", "mutation $procedure exception: ${e.message}", e)
            Result.failure(e)
        }
    }
}

interface AuthTokenProvider {
    suspend fun getToken(): String?
}

@Serializable
data class TRPCResponse<T>(
    val result: TRPCResult<T>? = null,
    val error: TRPCError? = null
)

@Serializable
data class TRPCResult<T>(
    val data: T
)

@Serializable
data class TRPCError(
    val message: String,
    val code: String? = null
)

class TRPCException(
    val code: Int,
    override val message: String
) : Exception(message)
