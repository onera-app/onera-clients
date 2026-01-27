package chat.onera.mobile.data.remote.websocket

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WebSocketService @Inject constructor() {
    
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    
    private val json = Json { 
        ignoreUnknownKeys = true
        encodeDefaults = true 
    }
    
    private val httpClient = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .build()
    
    private var webSocket: WebSocket? = null
    private var baseUrl = "wss://api.onera.chat/ws"
    private var authToken: String? = null
    
    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()
    
    private val _messages = MutableSharedFlow<WebSocketMessage>(
        replay = 0,
        extraBufferCapacity = 100,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val messages: SharedFlow<WebSocketMessage> = _messages.asSharedFlow()
    
    private var reconnectAttempt = 0
    private val maxReconnectAttempts = 5
    private val reconnectDelayMs = 1000L
    
    fun setBaseUrl(url: String) {
        baseUrl = url
    }
    
    fun setAuthToken(token: String?) {
        authToken = token
        // Reconnect if already connected
        if (webSocket != null && token != null) {
            disconnect()
            connect()
        }
    }
    
    fun connect() {
        if (_connectionState.value == ConnectionState.Connecting || 
            _connectionState.value == ConnectionState.Connected) {
            return
        }
        
        _connectionState.value = ConnectionState.Connecting
        
        val urlWithAuth = buildString {
            append(baseUrl)
            authToken?.let { token ->
                append("?token=$token")
            }
        }
        
        val request = Request.Builder()
            .url(urlWithAuth)
            .build()
        
        webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                _connectionState.value = ConnectionState.Connected
                reconnectAttempt = 0
            }
            
            override fun onMessage(webSocket: WebSocket, text: String) {
                scope.launch {
                    try {
                        val message = json.decodeFromString<WebSocketMessage>(text)
                        _messages.emit(message)
                    } catch (e: Exception) {
                        // Try as raw text message
                        _messages.emit(WebSocketMessage(type = "raw", data = text))
                    }
                }
            }
            
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }
            
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                _connectionState.value = ConnectionState.Disconnected
            }
            
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                _connectionState.value = ConnectionState.Error(t.message ?: "WebSocket error")
                scheduleReconnect()
            }
        })
    }
    
    fun disconnect() {
        webSocket?.close(1000, "Client disconnect")
        webSocket = null
        _connectionState.value = ConnectionState.Disconnected
    }
    
    fun send(message: WebSocketMessage) {
        if (_connectionState.value != ConnectionState.Connected) {
            return
        }
        
        try {
            val messageJson = json.encodeToString(message)
            webSocket?.send(messageJson)
        } catch (e: Exception) {
            // Handle serialization error
        }
    }
    
    private fun scheduleReconnect() {
        if (reconnectAttempt >= maxReconnectAttempts) {
            return
        }
        
        reconnectAttempt++
        
        scope.launch {
            delay(reconnectDelayMs * reconnectAttempt)
            connect()
        }
    }
    
    fun cleanup() {
        disconnect()
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
    }
}

sealed class ConnectionState {
    data object Disconnected : ConnectionState()
    data object Connecting : ConnectionState()
    data object Connected : ConnectionState()
    data class Error(val message: String) : ConnectionState()
}

@Serializable
data class WebSocketMessage(
    val type: String,
    val data: String? = null,
    val chatId: String? = null,
    val messageId: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

// Specific message types
@Serializable
data class ChatStreamChunk(
    val content: String,
    val isComplete: Boolean = false
)

@Serializable
data class ChatSyncEvent(
    val chatId: String,
    val action: String, // "created", "updated", "deleted"
    val timestamp: Long
)

@Serializable
data class TypingIndicator(
    val chatId: String,
    val userId: String,
    val isTyping: Boolean
)
