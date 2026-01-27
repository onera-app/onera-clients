package chat.onera.mobile.data.remote.llm

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for LLM request/response models and SSE parsing
 */
class LLMModelsTest {
    
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        isLenient = true
    }
    
    // ========================================================================
    // ChatMessage Tests
    // ========================================================================
    
    @Test
    fun `ChatMessage system creates system message`() {
        val message = ChatMessage.system("You are helpful")
        assertEquals(ChatMessage.ROLE_SYSTEM, message.role)
        assertEquals("You are helpful", message.content)
    }
    
    @Test
    fun `ChatMessage user creates user message`() {
        val message = ChatMessage.user("Hello")
        assertEquals(ChatMessage.ROLE_USER, message.role)
        assertEquals("Hello", message.content)
    }
    
    @Test
    fun `ChatMessage assistant creates assistant message`() {
        val message = ChatMessage.assistant("Hi there!")
        assertEquals(ChatMessage.ROLE_ASSISTANT, message.role)
        assertEquals("Hi there!", message.content)
    }
    
    // ========================================================================
    // ChatCompletionRequest Tests
    // ========================================================================
    
    @Test
    fun `ChatCompletionRequest serializes correctly`() {
        val request = ChatCompletionRequest(
            model = "gpt-4o",
            messages = listOf(
                ChatMessage.user("Hello")
            ),
            stream = true,
            maxTokens = 1000
        )
        
        val jsonString = json.encodeToString(ChatCompletionRequest.serializer(), request)
        
        assertTrue(jsonString.contains("\"model\":\"gpt-4o\""))
        assertTrue(jsonString.contains("\"stream\":true"))
        assertTrue(jsonString.contains("\"max_tokens\":1000"))
        assertTrue(jsonString.contains("\"role\":\"user\""))
    }
    
    @Test
    fun `ChatCompletionRequest defaults stream to true`() {
        val request = ChatCompletionRequest(
            model = "test",
            messages = emptyList()
        )
        assertTrue(request.stream)
    }
    
    // ========================================================================
    // StreamChunk Parsing Tests
    // ========================================================================
    
    @Test
    fun `StreamChunk parses OpenAI format correctly`() {
        val chunkJson = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion.chunk",
            "created": 1694268190,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "delta": {
                    "content": "Hello"
                },
                "finish_reason": null
            }]
        }
        """.trimIndent()
        
        val chunk = json.decodeFromString<StreamChunk>(chunkJson)
        
        assertEquals("chatcmpl-123", chunk.id)
        assertEquals("gpt-4o", chunk.model)
        assertEquals(1, chunk.choices.size)
        assertEquals("Hello", chunk.choices[0].delta?.content)
        assertNull(chunk.choices[0].finishReason)
    }
    
    @Test
    fun `StreamChunk parses chunk with finish_reason`() {
        val chunkJson = """
        {
            "id": "chatcmpl-123",
            "choices": [{
                "index": 0,
                "delta": {},
                "finish_reason": "stop"
            }]
        }
        """.trimIndent()
        
        val chunk = json.decodeFromString<StreamChunk>(chunkJson)
        
        assertEquals("stop", chunk.choices[0].finishReason)
        assertNull(chunk.choices[0].delta?.content)
    }
    
    @Test
    fun `StreamChunk parses chunk with reasoning content`() {
        val chunkJson = """
        {
            "id": "chatcmpl-123",
            "choices": [{
                "index": 0,
                "delta": {
                    "reasoning_content": "Let me think..."
                }
            }]
        }
        """.trimIndent()
        
        val chunk = json.decodeFromString<StreamChunk>(chunkJson)
        
        assertEquals("Let me think...", chunk.choices[0].delta?.reasoningContent)
    }
    
    @Test
    fun `StreamChunk handles empty choices gracefully`() {
        val chunkJson = """
        {
            "id": "chatcmpl-123",
            "choices": []
        }
        """.trimIndent()
        
        val chunk = json.decodeFromString<StreamChunk>(chunkJson)
        
        assertTrue(chunk.choices.isEmpty())
    }
    
    // ========================================================================
    // ChatCompletionResponse Tests
    // ========================================================================
    
    @Test
    fun `ChatCompletionResponse parses non-streaming response`() {
        val responseJson = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1694268190,
            "model": "gpt-4o",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! How can I help you?"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }
        """.trimIndent()
        
        val response = json.decodeFromString<ChatCompletionResponse>(responseJson)
        
        assertEquals("chatcmpl-123", response.id)
        assertEquals("gpt-4o", response.model)
        assertEquals("Hello! How can I help you?", response.choices[0].message?.content)
        assertEquals("stop", response.choices[0].finishReason)
        assertEquals(30, response.usage?.totalTokens)
    }
    
    // ========================================================================
    // ModelsResponse Tests
    // ========================================================================
    
    @Test
    fun `ModelsResponse parses correctly`() {
        val modelsJson = """
        {
            "object": "list",
            "data": [
                {"id": "gpt-4o", "object": "model", "owned_by": "openai"},
                {"id": "gpt-4o-mini", "object": "model", "owned_by": "openai"}
            ]
        }
        """.trimIndent()
        
        val response = json.decodeFromString<ModelsResponse>(modelsJson)
        
        assertEquals(2, response.data.size)
        assertEquals("gpt-4o", response.data[0].id)
        assertEquals("gpt-4o-mini", response.data[1].id)
    }
    
    // ========================================================================
    // DecryptedCredential Tests
    // ========================================================================
    
    @Test
    fun `DecryptedCredential effectiveBaseUrl returns custom URL if provided`() {
        val credential = DecryptedCredential(
            id = "test-id",
            provider = LLMProvider.OPENAI,
            apiKey = "sk-test",
            name = "Test",
            baseUrl = "https://custom.api.com/v1"
        )
        
        assertEquals("https://custom.api.com/v1", credential.effectiveBaseUrl)
    }
    
    @Test
    fun `DecryptedCredential effectiveBaseUrl returns provider default if no custom URL`() {
        val credential = DecryptedCredential(
            id = "test-id",
            provider = LLMProvider.GROQ,
            apiKey = "gsk_test",
            name = "Test",
            baseUrl = null
        )
        
        assertEquals("https://api.groq.com/openai/v1", credential.effectiveBaseUrl)
    }
    
    @Test
    fun `DecryptedCredential effectiveBaseUrl returns provider default if custom URL is blank`() {
        val credential = DecryptedCredential(
            id = "test-id",
            provider = LLMProvider.OPENAI,
            apiKey = "sk-test",
            name = "Test",
            baseUrl = "   "
        )
        
        assertEquals("https://api.openai.com/v1", credential.effectiveBaseUrl)
    }
    
    // ========================================================================
    // StreamEvent Tests
    // ========================================================================
    
    @Test
    fun `StreamEvent Text contains content`() {
        val event = StreamEvent.Text("Hello")
        assertEquals("Hello", event.content)
    }
    
    @Test
    fun `StreamEvent Reasoning contains content`() {
        val event = StreamEvent.Reasoning("Let me think...")
        assertEquals("Let me think...", event.content)
    }
    
    @Test
    fun `StreamEvent Error contains message and cause`() {
        val cause = RuntimeException("test error")
        val event = StreamEvent.Error("Something went wrong", cause)
        assertEquals("Something went wrong", event.message)
        assertEquals(cause, event.cause)
    }
    
    // ========================================================================
    // LLMException Tests
    // ========================================================================
    
    @Test
    fun `LLMException AuthenticationFailed has correct message`() {
        val exception = LLMException.AuthenticationFailed()
        assertEquals("Authentication failed", exception.message)
    }
    
    @Test
    fun `LLMException RateLimited includes retry time`() {
        val exception = LLMException.RateLimited(60)
        assertTrue(exception.message!!.contains("60"))
    }
    
    @Test
    fun `LLMException ModelNotFound includes model name`() {
        val exception = LLMException.ModelNotFound("gpt-5")
        assertTrue(exception.message!!.contains("gpt-5"))
    }
    
    // ========================================================================
    // Error Response Parsing Tests
    // ========================================================================
    
    @Test
    fun `LLMErrorResponse parses error correctly`() {
        val errorJson = """
        {
            "error": {
                "message": "Invalid API key",
                "type": "authentication_error",
                "code": "invalid_api_key"
            }
        }
        """.trimIndent()
        
        val response = json.decodeFromString<LLMErrorResponse>(errorJson)
        
        assertEquals("Invalid API key", response.error?.message)
        assertEquals("authentication_error", response.error?.type)
        assertEquals("invalid_api_key", response.error?.code)
    }
}
