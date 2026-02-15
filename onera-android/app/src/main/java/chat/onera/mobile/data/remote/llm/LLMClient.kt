package chat.onera.mobile.data.remote.llm

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.BufferedReader
import java.io.IOException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Unified LLM client that supports streaming chat completions from multiple providers.
 * 
 * Uses OkHttp for HTTP requests with manual SSE parsing for streaming responses.
 * Supports OpenAI, Anthropic, Google, Groq, Mistral, DeepSeek, and other providers.
 */
@Singleton
class LLMClient @Inject constructor() {
    
    companion object {
        private const val TAG = "LLMClient"
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        private const val ANTHROPIC_VERSION = "2023-06-01"
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        isLenient = true
    }
    
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS) // Longer timeout for streaming
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    // Track active call for cancellation
    private var activeCall: Call? = null
    private val isCancelled = AtomicBoolean(false)
    
    /**
     * Stream chat completions from an LLM provider.
     * 
     * @param credential The decrypted credential with API key
     * @param messages The conversation messages
     * @param model The model to use
     * @param systemPrompt Optional system prompt
     * @param maxTokens Maximum tokens to generate
     * @param images Optional list of images to include in the last user message
     * @return Flow of streaming events
     */
    fun streamChat(
        credential: DecryptedCredential,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String? = null,
        maxTokens: Int = 4096,
        images: List<ImageData> = emptyList()
    ): Flow<StreamEvent> = callbackFlow {
        Log.d(TAG, "Starting stream chat with ${credential.provider} model: $model, images: ${images.size}")
        isCancelled.set(false)
        
        // Build the full message list with system prompt
        val fullMessages = buildList {
            systemPrompt?.let { add(ChatMessage.system(it)) }
            addAll(messages)
        }
        
        // Build provider-specific request
        val request = when (credential.provider) {
            LLMProvider.ANTHROPIC -> buildAnthropicRequest(credential, fullMessages, model, maxTokens, images)
            LLMProvider.GOOGLE -> buildGoogleRequest(credential, fullMessages, model, maxTokens, images)
            else -> buildOpenAIRequest(credential, fullMessages, model, maxTokens, images)
        }
        
        Log.d(TAG, "Request URL: ${request.url}")
        
        val call = httpClient.newCall(request)
        activeCall = call
        
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                if (!isCancelled.get()) {
                    Log.e(TAG, "Request failed: ${e.message}", e)
                    trySend(StreamEvent.Error(e.message ?: "Network error", e))
                }
                close()
            }
            
            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    val error = parseErrorResponse(response)
                    trySend(StreamEvent.Error(error.message ?: "API error"))
                    close()
                    return
                }
                
                try {
                    response.body?.let { body ->
                        val reader = body.source().inputStream().bufferedReader()
                        parseSSEStream(reader, credential.provider) { event ->
                            if (!isCancelled.get() && isActive) {
                                trySend(event)
                            }
                        }
                        reader.close()
                    }
                    
                    if (!isCancelled.get()) {
                        trySend(StreamEvent.Done)
                    }
                } catch (e: Exception) {
                    if (!isCancelled.get()) {
                        Log.e(TAG, "Error reading stream: ${e.message}", e)
                        trySend(StreamEvent.Error(e.message ?: "Stream error", e))
                    }
                } finally {
                    close()
                }
            }
        })
        
        awaitClose {
            Log.d(TAG, "Closing stream connection")
            isCancelled.set(true)
            activeCall?.cancel()
            activeCall = null
        }
    }.flowOn(Dispatchers.IO)
    
    /**
     * Parse SSE stream manually from a BufferedReader
     */
    private fun parseSSEStream(
        reader: BufferedReader,
        provider: LLMProvider,
        onEvent: (StreamEvent) -> Unit
    ) {
        var line: String?
        
        while (reader.readLine().also { line = it } != null) {
            if (isCancelled.get()) break
            
            val currentLine = line ?: continue
            
            // SSE format: "data: {json}" or "data: [DONE]"
            if (currentLine.startsWith("data: ")) {
                val data = currentLine.removePrefix("data: ").trim()
                
                if (data == "[DONE]") {
                    Log.d(TAG, "Received [DONE]")
                    break
                }
                
                if (data.isNotEmpty()) {
                    try {
                        val event = parseStreamChunk(data, provider)
                        if (event != null) {
                            onEvent(event)
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to parse chunk: $data", e)
                    }
                }
            }
            // Ignore other lines (empty lines, event: lines, etc.)
        }
    }
    
    /**
     * Cancel any active streaming request
     */
    fun cancelStream() {
        isCancelled.set(true)
        activeCall?.cancel()
        activeCall = null
    }
    
    /**
     * Fetch available models for a credential
     */
    suspend fun fetchModels(credential: DecryptedCredential): List<ModelInfo> = withContext(Dispatchers.IO) {
        Log.d(TAG, "Fetching models for ${credential.provider}")
        
        val url = credential.provider.getModelsUrl(credential.baseUrl)
        
        val requestBuilder = Request.Builder()
            .url(url)
            .get()
        
        // Add auth headers
        addAuthHeaders(requestBuilder, credential)
        
        val request = requestBuilder.build()
        
        suspendCancellableCoroutine { continuation ->
            val call = httpClient.newCall(request)
            
            continuation.invokeOnCancellation {
                call.cancel()
            }
            
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    continuation.resumeWithException(LLMException.NetworkError(e.message ?: "Network error", e))
                }
                
                override fun onResponse(call: Call, response: Response) {
                    try {
                        if (!response.isSuccessful) {
                            val error = parseErrorResponse(response)
                            continuation.resumeWithException(error)
                            return
                        }
                        
                        val body = response.body?.string() ?: ""
                        val models = parseModelsResponse(body, credential.provider)
                        continuation.resume(models)
                    } catch (e: Exception) {
                        continuation.resumeWithException(e)
                    }
                }
            })
        }
    }
    
    /**
     * Non-streaming chat completion (for simple use cases)
     */
    suspend fun chat(
        credential: DecryptedCredential,
        messages: List<ChatMessage>,
        model: String,
        systemPrompt: String? = null,
        maxTokens: Int = 4096
    ): String = withContext(Dispatchers.IO) {
        val fullMessages = buildList {
            systemPrompt?.let { add(ChatMessage.system(it)) }
            addAll(messages)
        }
        
        val chatRequest = ChatCompletionRequest(
            model = model,
            messages = fullMessages,
            stream = false,
            maxTokens = maxTokens
        )
        
        val url = credential.provider.getChatUrl(credential.baseUrl, model)
        
        val requestBuilder = Request.Builder()
            .url(url)
            .post(json.encodeToString(chatRequest).toRequestBody(JSON_MEDIA_TYPE))
        
        addAuthHeaders(requestBuilder, credential)
        
        val request = requestBuilder.build()
        
        suspendCancellableCoroutine { continuation ->
            val call = httpClient.newCall(request)
            
            continuation.invokeOnCancellation {
                call.cancel()
            }
            
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    continuation.resumeWithException(LLMException.NetworkError(e.message ?: "Network error", e))
                }
                
                override fun onResponse(call: Call, response: Response) {
                    try {
                        if (!response.isSuccessful) {
                            val error = parseErrorResponse(response)
                            continuation.resumeWithException(error)
                            return
                        }
                        
                        val body = response.body?.string() ?: ""
                        val chatResponse = json.decodeFromString<ChatCompletionResponse>(body)
                        val content = chatResponse.choices.firstOrNull()?.message?.content ?: ""
                        continuation.resume(content)
                    } catch (e: Exception) {
                        continuation.resumeWithException(e)
                    }
                }
            })
        }
    }
    
    // ========================================================================
    // Request Building
    // ========================================================================
    
    private fun buildOpenAIRequest(
        credential: DecryptedCredential,
        messages: List<ChatMessage>,
        model: String,
        maxTokens: Int,
        images: List<ImageData> = emptyList()
    ): Request {
        val url = credential.provider.getChatUrl(credential.baseUrl)
        
        val requestBody = if (images.isEmpty()) {
            // Standard text-only request
            val chatRequest = ChatCompletionRequest(
                model = model,
                messages = messages,
                stream = true,
                maxTokens = maxTokens
            )
            json.encodeToString(chatRequest)
        } else {
            // Multimodal request with images - build using JsonObject for proper serialization
            val jsonMessages = buildJsonArray {
                messages.forEachIndexed { index, msg ->
                    if (index == messages.lastIndex && msg.role == ChatMessage.ROLE_USER) {
                        // Convert last user message to multimodal format with images
                        add(buildJsonObject {
                            put("role", msg.role)
                            put("content", buildJsonArray {
                                // Add text content
                                add(buildJsonObject {
                                    put("type", "text")
                                    put("text", msg.content)
                                })
                                // Add image content
                                images.forEach { img ->
                                    add(buildJsonObject {
                                        put("type", "image_url")
                                        put("image_url", buildJsonObject {
                                            put("url", "data:${img.mimeType};base64,${img.base64Data}")
                                        })
                                    })
                                }
                            })
                        })
                    } else {
                        // Standard text message
                        add(buildJsonObject {
                            put("role", msg.role)
                            put("content", msg.content)
                        })
                    }
                }
            }
            
            val requestJson = buildJsonObject {
                put("model", model)
                put("messages", jsonMessages)
                put("stream", true)
                put("max_tokens", maxTokens)
            }
            requestJson.toString()
        }
        
        Log.d(TAG, "Request body length: ${requestBody.length}")
        
        val requestBuilder = Request.Builder()
            .url(url)
            .post(requestBody.toRequestBody(JSON_MEDIA_TYPE))
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
        
        addAuthHeaders(requestBuilder, credential)
        
        return requestBuilder.build()
    }
    
    private fun buildAnthropicRequest(
        credential: DecryptedCredential,
        messages: List<ChatMessage>,
        model: String,
        maxTokens: Int,
        images: List<ImageData> = emptyList()
    ): Request {
        // Anthropic uses a different format - convert messages
        // System message goes to a separate field
        val systemMessage = messages.find { it.role == ChatMessage.ROLE_SYSTEM }?.content
        val chatMessages = messages.filter { it.role != ChatMessage.ROLE_SYSTEM }
        
        val requestBody = if (images.isEmpty()) {
            val anthropicRequest = buildMap {
                put("model", model)
                put("max_tokens", maxTokens)
                put("stream", true)
                put("messages", chatMessages.map { mapOf("role" to it.role, "content" to it.content) })
                systemMessage?.let { put("system", it) }
            }
            json.encodeToString(anthropicRequest)
        } else {
            // Multimodal request with images
            val jsonMessages = buildJsonArray {
                chatMessages.forEachIndexed { index, msg ->
                    if (index == chatMessages.lastIndex && msg.role == ChatMessage.ROLE_USER) {
                        // Convert last user message to multimodal format
                        add(buildJsonObject {
                            put("role", msg.role)
                            put("content", buildJsonArray {
                                // Add image content first
                                images.forEach { img ->
                                    add(buildJsonObject {
                                        put("type", "image")
                                        put("source", buildJsonObject {
                                            put("type", "base64")
                                            put("media_type", img.mimeType)
                                            put("data", img.base64Data)
                                        })
                                    })
                                }
                                // Add text content
                                add(buildJsonObject {
                                    put("type", "text")
                                    put("text", msg.content)
                                })
                            })
                        })
                    } else {
                        add(buildJsonObject {
                            put("role", msg.role)
                            put("content", msg.content)
                        })
                    }
                }
            }
            
            val requestJson = buildJsonObject {
                put("model", model)
                put("max_tokens", maxTokens)
                put("stream", true)
                put("messages", jsonMessages)
                systemMessage?.let { put("system", it) }
            }
            requestJson.toString()
        }
        
        val url = credential.provider.getChatUrl(credential.baseUrl)
        
        return Request.Builder()
            .url(url)
            .post(requestBody.toRequestBody(JSON_MEDIA_TYPE))
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
            .header("x-api-key", credential.apiKey)
            .header("anthropic-version", ANTHROPIC_VERSION)
            .header("anthropic-dangerous-direct-browser-access", "true")
            .build()
    }
    
    private fun buildGoogleRequest(
        credential: DecryptedCredential,
        messages: List<ChatMessage>,
        model: String,
        maxTokens: Int,
        images: List<ImageData> = emptyList()
    ): Request {
        // Google Gemini uses a different format
        val chatMessages = messages.filter { it.role != ChatMessage.ROLE_SYSTEM }
        
        val contents = if (images.isEmpty()) {
            // Standard text-only contents
            chatMessages.map { msg ->
                mapOf(
                    "role" to if (msg.role == ChatMessage.ROLE_USER) "user" else "model",
                    "parts" to listOf(mapOf("text" to msg.content))
                )
            }
        } else {
            // Multimodal contents with images on last user message
            chatMessages.mapIndexed { index, msg ->
                val role = if (msg.role == ChatMessage.ROLE_USER) "user" else "model"
                if (index == chatMessages.lastIndex && msg.role == ChatMessage.ROLE_USER) {
                    // Build multimodal parts: images first, then text
                    val parts = buildList {
                        images.forEach { img ->
                            add(mapOf(
                                "inline_data" to mapOf(
                                    "mime_type" to img.mimeType,
                                    "data" to img.base64Data
                                )
                            ))
                        }
                        add(mapOf("text" to msg.content))
                    }
                    mapOf("role" to role, "parts" to parts)
                } else {
                    mapOf(
                        "role" to role,
                        "parts" to listOf(mapOf("text" to msg.content))
                    )
                }
            }
        }
        
        val systemInstruction = messages.find { it.role == ChatMessage.ROLE_SYSTEM }?.let {
            mapOf("parts" to listOf(mapOf("text" to it.content)))
        }
        
        val googleRequest = buildMap {
            put("contents", contents)
            systemInstruction?.let { put("systemInstruction", it) }
            put("generationConfig", mapOf("maxOutputTokens" to maxTokens))
        }
        
        val baseUrl = credential.baseUrl ?: credential.provider.defaultBaseUrl
        val url = "$baseUrl/models/$model:streamGenerateContent?key=${credential.apiKey}&alt=sse"
        
        return Request.Builder()
            .url(url)
            .post(json.encodeToString(googleRequest).toRequestBody(JSON_MEDIA_TYPE))
            .header("Accept", "text/event-stream")
            .build()
    }
    
    private fun addAuthHeaders(builder: Request.Builder, credential: DecryptedCredential) {
        when (credential.provider.authType) {
            AuthType.BEARER -> {
                builder.header("Authorization", "Bearer ${credential.apiKey}")
                credential.orgId?.let { 
                    builder.header("OpenAI-Organization", it)
                }
            }
            AuthType.ANTHROPIC -> {
                builder.header("x-api-key", credential.apiKey)
                builder.header("anthropic-version", ANTHROPIC_VERSION)
            }
            AuthType.GOOGLE_API_KEY -> {
                // API key added as query parameter in URL
            }
            AuthType.NONE -> {
                // No auth needed
            }
        }
    }
    
    // ========================================================================
    // Response Parsing
    // ========================================================================
    
    private fun parseStreamChunk(data: String, provider: LLMProvider): StreamEvent? {
        return when (provider) {
            LLMProvider.ANTHROPIC -> parseAnthropicChunk(data)
            LLMProvider.GOOGLE -> parseGoogleChunk(data)
            else -> parseOpenAIChunk(data)
        }
    }
    
    private fun parseOpenAIChunk(data: String): StreamEvent? {
        val chunk = json.decodeFromString<StreamChunk>(data)
        val delta = chunk.choices.firstOrNull()?.delta ?: return null
        
        return when {
            delta.reasoningContent != null -> StreamEvent.Reasoning(delta.reasoningContent)
            delta.content != null -> StreamEvent.Text(delta.content)
            else -> null
        }
    }
    
    // Accumulator for tool call arguments across deltas
    private val toolCallArgsAccumulator = StringBuilder()
    private var currentToolCallName: String? = null
    
    private fun parseAnthropicChunk(data: String): StreamEvent? {
        // Anthropic has different event types
        val eventData = json.decodeFromString<JsonObject>(data)
        val type = (eventData["type"] as? JsonPrimitive)?.content ?: return null
        
        return when (type) {
            "content_block_start" -> {
                val contentBlock = eventData["content_block"] as? JsonObject ?: return null
                val blockType = (contentBlock["type"] as? JsonPrimitive)?.content ?: return null
                
                when (blockType) {
                    "thinking" -> StreamEvent.Reasoning("")
                    "tool_use" -> {
                        val name = (contentBlock["name"] as? JsonPrimitive)?.content ?: ""
                        currentToolCallName = name
                        toolCallArgsAccumulator.clear()
                        StreamEvent.ToolCall(name, "")
                    }
                    else -> null
                }
            }
            "content_block_delta" -> {
                val delta = eventData["delta"] as? JsonObject ?: return null
                val deltaType = (delta["type"] as? JsonPrimitive)?.content ?: return null
                
                when (deltaType) {
                    "text_delta" -> {
                        val text = (delta["text"] as? JsonPrimitive)?.content ?: return null
                        StreamEvent.Text(text)
                    }
                    "thinking_delta" -> {
                        val thinking = (delta["thinking"] as? JsonPrimitive)?.content ?: return null
                        StreamEvent.Reasoning(thinking)
                    }
                    "input_json_delta" -> {
                        val partialJson = (delta["partial_json"] as? JsonPrimitive)?.content ?: return null
                        toolCallArgsAccumulator.append(partialJson)
                        // Emit accumulated args so far
                        StreamEvent.ToolCall(currentToolCallName ?: "", toolCallArgsAccumulator.toString())
                    }
                    else -> null
                }
            }
            "content_block_stop" -> {
                // Reset tool call state when block ends
                currentToolCallName = null
                toolCallArgsAccumulator.clear()
                null
            }
            "message_stop" -> StreamEvent.Done
            else -> null
        }
    }
    
    private fun parseGoogleChunk(data: String): StreamEvent? {
        val eventData = json.decodeFromString<Map<String, Any?>>(data)
        
        @Suppress("UNCHECKED_CAST")
        val candidates = eventData["candidates"] as? List<Map<String, Any?>> ?: return null
        val content = candidates.firstOrNull()?.get("content") as? Map<String, Any?> ?: return null
        val parts = content["parts"] as? List<Map<String, Any?>> ?: return null
        val text = parts.firstOrNull()?.get("text") as? String ?: return null
        
        return StreamEvent.Text(text)
    }
    
    private fun parseModelsResponse(body: String, provider: LLMProvider): List<ModelInfo> {
        return when (provider) {
            LLMProvider.OLLAMA -> {
                // Ollama uses /api/tags with different format
                val data = json.decodeFromString<Map<String, Any?>>(body)
                @Suppress("UNCHECKED_CAST")
                val models = data["models"] as? List<Map<String, Any?>> ?: return emptyList()
                models.mapNotNull { model ->
                    val name = model["name"] as? String ?: return@mapNotNull null
                    ModelInfo(id = name)
                }
            }
            LLMProvider.GOOGLE -> {
                val data = json.decodeFromString<Map<String, Any?>>(body)
                @Suppress("UNCHECKED_CAST")
                val models = data["models"] as? List<Map<String, Any?>> ?: return emptyList()
                models.mapNotNull { model ->
                    val name = model["name"] as? String ?: return@mapNotNull null
                    val modelId = name.removePrefix("models/")
                    ModelInfo(id = modelId)
                }
            }
            else -> {
                val response = json.decodeFromString<ModelsResponse>(body)
                response.data
            }
        }
    }
    
    private fun parseErrorResponse(response: Response): LLMException {
        val code = response.code
        val body = response.body?.string() ?: ""
        
        return when (code) {
            401, 403 -> LLMException.AuthenticationFailed()
            429 -> {
                val retryAfter = response.header("Retry-After")?.toLongOrNull()
                LLMException.RateLimited(retryAfter)
            }
            404 -> LLMException.ModelNotFound("Model not found")
            else -> {
                try {
                    val errorResponse = json.decodeFromString<LLMErrorResponse>(body)
                    LLMException.ProviderError(errorResponse.error?.message ?: "Unknown error: $code")
                } catch (e: Exception) {
                    LLMException.ProviderError("Error $code: $body")
                }
            }
        }
    }
}
