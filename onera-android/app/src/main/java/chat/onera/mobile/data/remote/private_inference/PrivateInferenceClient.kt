package chat.onera.mobile.data.remote.private_inference

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import okio.ByteString.Companion.toByteString
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * WebSocket client for encrypted communication with TEE inference endpoints.
 * 
 * Handles:
 * - Attestation verification to obtain server's public key
 * - Noise Protocol NK handshake for establishing encrypted channel
 * - Streaming encrypted inference requests/responses
 * 
 * Matches the iOS/web implementation for compatibility.
 */
@Singleton
class PrivateInferenceClient @Inject constructor() {
    
    companion object {
        private const val TAG = "PrivateInferenceClient"
        private const val CONNECT_TIMEOUT_MS = 30_000L
    }
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    private val attestationVerifier = AttestationVerifier()
    
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()
    
    // Connection state
    private var webSocket: WebSocket? = null
    private var noiseSession: NoiseSession? = null
    
    @Volatile
    var isConnected: Boolean = false
        private set
    
    @Volatile
    var isClosed: Boolean = false
        private set
    
    // Message handling
    private var messageChannel = Channel<ByteArray>(Channel.UNLIMITED)
    private val isCancelled = AtomicBoolean(false)
    
    /**
     * Connect to a TEE endpoint with attestation verification and Noise handshake
     */
    suspend fun connect(
        wsEndpoint: String,
        attestationEndpoint: String,
        expectedMeasurements: ExpectedMeasurements? = null
    ) = withContext(Dispatchers.IO) {
        isClosed = false
        isCancelled.set(false)
        if (messageChannel.isClosedForReceive || messageChannel.isClosedForSend) {
            messageChannel = Channel(Channel.UNLIMITED)
        }

        Log.i(TAG, "Connecting to private inference endpoint: $wsEndpoint")
        
        // Step 1: Verify attestation and get server public key
        val attestationResult = attestationVerifier.verify(
            attestationEndpoint,
            expectedMeasurements
        )
        
        if (!attestationResult.isValid || attestationResult.serverPublicKey == null) {
            throw PrivateInferenceException.AttestationFailed(
                attestationResult.error ?: "Unknown error"
            )
        }
        
        Log.i(TAG, "Attestation verified successfully (${attestationResult.attestationType})")
        
        // Step 2: Establish WebSocket connection
        establishWebSocketConnection(wsEndpoint)
        
        // Step 3: Perform Noise Protocol handshake
        val handshakeResult = withTimeout(CONNECT_TIMEOUT_MS) {
            NoiseProtocol.performNKHandshake(
                serverPublicKey = attestationResult.serverPublicKey,
                sendMessage = { message -> sendWebSocketMessage(message) },
                receiveMessage = { receiveWebSocketMessage() }
            )
        }
        
        // Step 4: Initialize Noise session
        noiseSession = NoiseSession(
            sendingKey = handshakeResult.sendingKey,
            receivingKey = handshakeResult.receivingKey
        )
        
        Log.i(TAG, "Private inference client connected and encrypted")
    }
    
    /**
     * Send a request and stream encrypted responses
     */
    fun sendAndStream(request: ByteArray): Flow<ByteArray> = callbackFlow {
        val session = noiseSession
            ?: throw PrivateInferenceException.NotConnected()
        
        if (session.isClosed) {
            throw PrivateInferenceException.ConnectionClosed()
        }
        
        isCancelled.set(false)
        
        // Encrypt and send request
        val encryptedRequest = session.encrypt(request)
        sendWebSocketMessage(encryptedRequest)
        Log.d(TAG, "Sent encrypted request (${request.size} bytes)")
        
        // Stream responses
        while (isConnected && !isCancelled.get()) {
            try {
                val encryptedResponse = receiveWebSocketMessage()
                
                // Empty message signals end of stream
                if (encryptedResponse.isEmpty()) {
                    Log.d(TAG, "Received end-of-stream signal")
                    break
                }
                
                val decryptedResponse = session.decrypt(encryptedResponse)
                trySend(decryptedResponse)
                
            } catch (e: Exception) {
                if (!isCancelled.get()) {
                    Log.e(TAG, "Error receiving response: ${e.message}", e)
                    throw e
                }
                break
            }
        }
        
        awaitClose {
            Log.d(TAG, "Stream closed")
        }
    }.flowOn(Dispatchers.IO)
    
    /**
     * Stream chat completion through encrypted channel
     */
    fun streamChat(
        config: EnclaveConfig,
        modelId: String,
        messages: List<Map<String, Any>>,
        temperature: Double = 0.7,
        maxTokens: Int = 4096
    ): Flow<PrivateInferenceEvent> = callbackFlow {
        try {
            // Connect if not already connected
            if (!isConnected || isClosed) {
                connect(
                    wsEndpoint = config.wsEndpoint,
                    attestationEndpoint = config.attestationEndpoint,
                    expectedMeasurements = config.expectedMeasurements
                )
            }
            
            // Build request
            val request = mapOf(
                "model" to modelId,
                "messages" to messages,
                "stream" to true,
                "temperature" to temperature,
                "max_tokens" to maxTokens
            )
            
            val requestJson = json.encodeToString(request)
            val requestBytes = requestJson.toByteArray(Charsets.UTF_8)
            
            Log.d(TAG, "Sending chat request for model: $modelId")
            
            // Stream responses
            sendAndStream(requestBytes).collect { chunk ->
                val chunkStr = chunk.toString(Charsets.UTF_8)
                
                try {
                    val jsonObj = json.parseToJsonElement(chunkStr).jsonObject
                    val event = parseStreamChunk(jsonObj)
                    if (event != null) {
                        trySend(event)
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse chunk: $chunkStr", e)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Private inference error: ${e.message}", e)
            trySend(PrivateInferenceEvent.Error(e.message ?: "Unknown error", e))
        }
        
        awaitClose {
            Log.d(TAG, "Chat stream closed")
        }
    }.flowOn(Dispatchers.IO)
    
    /**
     * Parse a streaming response chunk
     */
    private fun parseStreamChunk(json: JsonObject): PrivateInferenceEvent? {
        // Handle streaming text-delta format
        val type = json["type"]?.jsonPrimitive?.content
        
        return when (type) {
            "text-delta" -> {
                val text = json["text"]?.jsonPrimitive?.content ?: return null
                PrivateInferenceEvent.TextDelta(text)
            }
            "finish" -> {
                val finishReason =
                    json["finish_reason"]?.jsonPrimitive?.content
                        ?: json["finishReason"]?.jsonPrimitive?.content
                        ?: "stop"
                val usage = json["usage"]?.jsonObject
                PrivateInferenceEvent.Finish(
                    reason = finishReason,
                    promptTokens = usage?.get("promptTokens")?.jsonPrimitive?.content?.toIntOrNull()
                        ?: usage?.get("prompt_tokens")?.jsonPrimitive?.content?.toIntOrNull()
                        ?: 0,
                    completionTokens = usage?.get("completionTokens")?.jsonPrimitive?.content?.toIntOrNull()
                        ?: usage?.get("completion_tokens")?.jsonPrimitive?.content?.toIntOrNull()
                        ?: 0
                )
            }
            "error" -> {
                val message = json["message"]?.jsonPrimitive?.content ?: "Unknown private inference error"
                PrivateInferenceEvent.Error(message)
            }
            else -> {
                // Try to handle single response format
                val content = json["content"]?.jsonPrimitive?.content
                if (content != null) {
                    PrivateInferenceEvent.TextDelta(content)
                } else {
                    null
                }
            }
        }
    }
    
    /**
     * Close the connection
     */
    fun close() {
        Log.i(TAG, "Closing private inference client")
        
        isClosed = true
        isConnected = false
        isCancelled.set(true)
        
        webSocket?.close(1000, "Client closed")
        webSocket = null
        
        noiseSession?.close()
        noiseSession = null
        
        messageChannel.close()
        messageChannel = Channel(Channel.UNLIMITED)
    }
    
    // ========================================================================
    // WebSocket Implementation
    // ========================================================================
    
    private suspend fun establishWebSocketConnection(endpoint: String) {
        suspendCancellableCoroutine { continuation ->
            val request = Request.Builder()
                .url(endpoint)
                .build()
            
            webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "WebSocket opened")
                    isConnected = true
                    if (continuation.isActive) {
                        continuation.resume(Unit)
                    }
                }
                
                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    Log.d(TAG, "Received binary message: ${bytes.size} bytes")
                    messageChannel.trySend(bytes.toByteArray())
                }
                
                override fun onMessage(webSocket: WebSocket, text: String) {
                    Log.d(TAG, "Received text message: ${text.length} chars")
                    messageChannel.trySend(text.toByteArray(Charsets.UTF_8))
                }
                
                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closing: $code $reason")
                    webSocket.close(code, reason)
                }
                
                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closed: $code $reason")
                    isConnected = false
                    messageChannel.trySend(ByteArray(0))
                }
                
                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.e(TAG, "WebSocket failure: ${t.message}", t)
                    isConnected = false
                    messageChannel.trySend(ByteArray(0))
                    if (continuation.isActive) {
                        continuation.resumeWithException(
                            PrivateInferenceException.ConnectionTimeout()
                        )
                    }
                }
            })
            
            continuation.invokeOnCancellation {
                webSocket?.cancel()
            }
        }
    }
    
    private suspend fun sendWebSocketMessage(data: ByteArray) {
        val ws = webSocket ?: throw PrivateInferenceException.NotConnected()
        ws.send(data.toByteString())
    }
    
    private suspend fun receiveWebSocketMessage(): ByteArray {
        return messageChannel.receive()
    }
}
