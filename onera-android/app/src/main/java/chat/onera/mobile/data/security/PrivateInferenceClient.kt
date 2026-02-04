package chat.onera.mobile.data.security

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Private Inference Client for encrypted TEE communication.
 * 
 * Provides WebSocket-based communication with TEE endpoints using:
 * - Attestation verification to ensure TEE authenticity
 * - Noise Protocol NK handshake for end-to-end encryption
 * - Streaming inference responses with proper flow control
 * - Connection lifecycle management with cleanup
 */
@Singleton
class PrivateInferenceClient @Inject constructor(
    private val okHttpClient: OkHttpClient,
    private val attestationVerifier: AttestationVerifier,
    private val noiseProtocol: NoiseProtocol
) {
    companion object {
        private const val TAG = "PrivateInferenceClient"
        private const val CONNECTION_TIMEOUT_MS = 30_000L
        private const val PING_INTERVAL_MS = 30_000L
    }
    
    private val connectionMutex = Mutex()
    private var webSocket: WebSocket? = null
    private var handshakeResult: NoiseProtocol.HandshakeResult? = null
    private var isConnected = false
    private var _isClosed = false
    
    /** Whether the client is closed and cannot be reused */
    val isClosed: Boolean get() = _isClosed
    
    // Message handling
    private val messageChannel = Channel<ByteArray>(Channel.UNLIMITED)
    private val handshakeChannel = Channel<ByteArray>(Channel.RENDEZVOUS)
    
    /**
     * Connect to a TEE endpoint with attestation verification and Noise handshake.
     * 
     * @param endpoint WebSocket URL (wss://...)
     * @param attestationEndpoint HTTP URL for attestation verification
     * @throws SecurityException if attestation fails or connection cannot be established
     */
    suspend fun connect(endpoint: String, attestationEndpoint: String) = connectionMutex.withLock {
        if (isConnected) {
            Timber.w("$TAG: Already connected, closing existing connection")
            closeInternal()
        }
        
        // Reset closed state for new connection
        _isClosed = false
        
        Timber.i("$TAG: Connecting to TEE endpoint: $endpoint")
        
        try {
            // Step 1: Verify attestation and get server public key
            val attestationResult = attestationVerifier.verify(attestationEndpoint)
            
            if (!attestationResult.isValid) {
                throw SecurityException("Attestation verification failed: ${attestationResult.error}")
            }
            
            val serverPublicKey = attestationResult.serverPublicKey
                ?: throw SecurityException("No server public key in attestation")
            
            Timber.i("$TAG: Attestation verified for ${attestationResult.attestationType}")
            
            // Step 2: Establish WebSocket connection
            val webSocket = establishWebSocketConnection(endpoint)
            this.webSocket = webSocket
            
            // Step 3: Perform Noise Protocol handshake
            val handshakeResult = performNoiseHandshake(serverPublicKey)
            this.handshakeResult = handshakeResult
            
            isConnected = true
            Timber.i("$TAG: Successfully connected and established secure channel")
            
        } catch (e: Exception) {
            Timber.e("$TAG: Connection failed", e)
            closeInternal()
            throw e
        }
    }
    
    /**
     * Send a request and stream the encrypted responses.
     * 
     * @param request Raw request data to encrypt and send
     * @return Flow of decrypted response chunks
     * @throws IllegalStateException if not connected
     * @throws SecurityException if encryption/decryption fails
     */
    fun sendAndStream(request: ByteArray): Flow<ByteArray> = flow {
        if (_isClosed) {
            throw IllegalStateException("Client is closed")
        }
        
        if (!isConnected) {
            throw IllegalStateException("Not connected to TEE endpoint")
        }
        
        val webSocket = this@PrivateInferenceClient.webSocket
            ?: throw IllegalStateException("WebSocket not available")
        
        val handshakeResult = this@PrivateInferenceClient.handshakeResult
            ?: throw IllegalStateException("Handshake not completed")
        
        try {
            // Encrypt and send request
            val encryptedRequest = noiseProtocol.encryptMessage(handshakeResult.sendCipher, request)
            val success = webSocket.send(ByteString.of(*encryptedRequest))
            
            if (!success) {
                throw SecurityException("Failed to send encrypted request")
            }
            
            Timber.d("$TAG: Sent encrypted request (${request.size} -> ${encryptedRequest.size} bytes)")
            
            // Stream responses until connection closes or empty message received
            while (isConnected) {
                val encryptedResponse = messageChannel.receive()
                
                // Empty message signals end of stream
                if (encryptedResponse.isEmpty()) {
                    Timber.d("$TAG: Received end-of-stream signal")
                    break
                }
                
                // Decrypt and emit response
                val decryptedResponse = noiseProtocol.decryptMessage(handshakeResult.recvCipher, encryptedResponse)
                Timber.v("$TAG: Decrypted response (${encryptedResponse.size} -> ${decryptedResponse.size} bytes)")
                
                emit(decryptedResponse)
            }
            
        } catch (e: Exception) {
            Timber.e("$TAG: Streaming failed", e)
            throw e
        }
    }
    
    /**
     * Close the connection and clean up resources.
     */
    fun close() {
        connectionMutex.tryLock()
        try {
            closeInternal()
        } finally {
            connectionMutex.unlock()
        }
    }
    
    /**
     * Check if currently connected to a TEE endpoint.
     */
    fun isConnected(): Boolean = isConnected
    
    // ===== Private Implementation =====
    
    /**
     * Establish WebSocket connection with proper configuration.
     */
    private suspend fun establishWebSocketConnection(endpoint: String): WebSocket {
        return suspendCancellableCoroutine { continuation ->
            val request = Request.Builder()
                .url(endpoint)
                .build()
            
            val listener = object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Timber.d("$TAG: WebSocket connection opened")
                    continuation.resume(webSocket)
                }
                
                override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                    // During handshake, route to handshake channel
                    if (handshakeResult == null) {
                        handshakeChannel.trySend(bytes.toByteArray())
                    } else {
                        // During normal operation, route to message channel
                        messageChannel.trySend(bytes.toByteArray())
                    }
                }
                
                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    Timber.d("$TAG: WebSocket closing: $code - $reason")
                    isConnected = false
                    messageChannel.trySend(ByteArray(0)) // Signal end of stream
                }
                
                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    Timber.d("$TAG: WebSocket closed: $code - $reason")
                    isConnected = false
                }
                
                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Timber.e("$TAG: WebSocket failure", t)
                    isConnected = false
                    
                    if (continuation.isActive) {
                        continuation.resumeWithException(
                            SecurityException("WebSocket connection failed", t)
                        )
                    }
                }
            }
            
            val webSocket = okHttpClient.newBuilder()
                .connectTimeout(CONNECTION_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                .pingInterval(PING_INTERVAL_MS, TimeUnit.MILLISECONDS)
                .build()
                .newWebSocket(request, listener)
            
            continuation.invokeOnCancellation {
                webSocket.close(1000, "Cancelled")
            }
        }
    }
    
    /**
     * Perform Noise Protocol NK handshake over WebSocket.
     */
    private suspend fun performNoiseHandshake(serverPublicKey: ByteArray): NoiseProtocol.HandshakeResult {
        val webSocket = this.webSocket ?: throw IllegalStateException("WebSocket not available")
        
        return noiseProtocol.performNKHandshake(
            serverPublicKey = serverPublicKey,
            send = { message ->
                val success = webSocket.send(ByteString.of(*message))
                if (!success) {
                    throw SecurityException("Failed to send handshake message")
                }
                Timber.d("$TAG: Sent handshake message (${message.size} bytes)")
            },
            receive = {
                val message = handshakeChannel.receive()
                Timber.d("$TAG: Received handshake message (${message.size} bytes)")
                message
            }
        )
    }
    
    /**
     * Internal cleanup without mutex (called from within mutex).
     */
    private fun closeInternal() {
        isConnected = false
        _isClosed = true
        
        webSocket?.let { ws ->
            try {
                ws.close(1000, "Client closing")
            } catch (e: Exception) {
                Timber.w("$TAG: Error closing WebSocket", e)
            }
        }
        webSocket = null
        
        // Clear cipher states securely
        handshakeResult?.let { result ->
            // Note: In a production implementation, you would securely zero the cipher keys
            // For now, just clear the reference
        }
        handshakeResult = null
        
        // Clear message channels
        messageChannel.close()
        handshakeChannel.close()
        
        Timber.d("$TAG: Connection closed and resources cleaned up")
    }
    
    /**
     * Get connection statistics for debugging.
     */
    fun getConnectionStats(): Map<String, Any> {
        return mapOf(
            "is_connected" to isConnected,
            "has_websocket" to (webSocket != null),
            "has_handshake" to (handshakeResult != null),
            "message_queue_size" to 0 // Simplified for now
        )
    }
}