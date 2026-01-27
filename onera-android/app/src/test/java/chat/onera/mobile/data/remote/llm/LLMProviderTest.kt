package chat.onera.mobile.data.remote.llm

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for LLMProvider configuration
 */
class LLMProviderTest {
    
    @Test
    fun `OPENAI has correct default base URL`() {
        assertEquals("https://api.openai.com/v1", LLMProvider.OPENAI.defaultBaseUrl)
    }
    
    @Test
    fun `GROQ has correct default base URL`() {
        assertEquals("https://api.groq.com/openai/v1", LLMProvider.GROQ.defaultBaseUrl)
    }
    
    @Test
    fun `ANTHROPIC has correct default base URL`() {
        assertEquals("https://api.anthropic.com/v1", LLMProvider.ANTHROPIC.defaultBaseUrl)
    }
    
    @Test
    fun `GOOGLE has correct default base URL`() {
        assertEquals("https://generativelanguage.googleapis.com/v1beta", LLMProvider.GOOGLE.defaultBaseUrl)
    }
    
    @Test
    fun `MISTRAL has correct default base URL`() {
        assertEquals("https://api.mistral.ai/v1", LLMProvider.MISTRAL.defaultBaseUrl)
    }
    
    @Test
    fun `DEEPSEEK has correct default base URL`() {
        assertEquals("https://api.deepseek.com/v1", LLMProvider.DEEPSEEK.defaultBaseUrl)
    }
    
    @Test
    fun `OPENROUTER has correct default base URL`() {
        assertEquals("https://openrouter.ai/api/v1", LLMProvider.OPENROUTER.defaultBaseUrl)
    }
    
    @Test
    fun `OLLAMA has correct default base URL`() {
        assertEquals("http://localhost:11434/v1", LLMProvider.OLLAMA.defaultBaseUrl)
    }
    
    @Test
    fun `LMSTUDIO has correct default base URL`() {
        assertEquals("http://localhost:1234/v1", LLMProvider.LMSTUDIO.defaultBaseUrl)
    }
    
    // Auth type tests
    
    @Test
    fun `OPENAI uses Bearer auth`() {
        assertEquals(AuthType.BEARER, LLMProvider.OPENAI.authType)
    }
    
    @Test
    fun `GROQ uses Bearer auth`() {
        assertEquals(AuthType.BEARER, LLMProvider.GROQ.authType)
    }
    
    @Test
    fun `ANTHROPIC uses Anthropic auth`() {
        assertEquals(AuthType.ANTHROPIC, LLMProvider.ANTHROPIC.authType)
    }
    
    @Test
    fun `GOOGLE uses API key auth`() {
        assertEquals(AuthType.GOOGLE_API_KEY, LLMProvider.GOOGLE.authType)
    }
    
    @Test
    fun `OLLAMA uses no auth`() {
        assertEquals(AuthType.NONE, LLMProvider.OLLAMA.authType)
    }
    
    @Test
    fun `LMSTUDIO uses no auth`() {
        assertEquals(AuthType.NONE, LLMProvider.LMSTUDIO.authType)
    }
    
    // Chat URL tests
    
    @Test
    fun `getChatUrl returns correct URL for OpenAI provider`() {
        val url = LLMProvider.OPENAI.getChatUrl()
        assertEquals("https://api.openai.com/v1/chat/completions", url)
    }
    
    @Test
    fun `getChatUrl returns correct URL for Groq provider`() {
        val url = LLMProvider.GROQ.getChatUrl()
        assertEquals("https://api.groq.com/openai/v1/chat/completions", url)
    }
    
    @Test
    fun `getChatUrl with custom base URL overrides default`() {
        val url = LLMProvider.OPENAI.getChatUrl("https://custom.api.com/v1")
        assertEquals("https://custom.api.com/v1/chat/completions", url)
    }
    
    @Test
    fun `getChatUrl removes trailing slash from base URL`() {
        val url = LLMProvider.OPENAI.getChatUrl("https://custom.api.com/v1/")
        assertEquals("https://custom.api.com/v1/chat/completions", url)
    }
    
    @Test
    fun `ANTHROPIC uses messages endpoint`() {
        val url = LLMProvider.ANTHROPIC.getChatUrl()
        assertEquals("https://api.anthropic.com/v1/messages", url)
    }
    
    // Models URL tests
    
    @Test
    fun `getModelsUrl returns correct URL for OpenAI provider`() {
        val url = LLMProvider.OPENAI.getModelsUrl()
        assertEquals("https://api.openai.com/v1/models", url)
    }
    
    @Test
    fun `getModelsUrl with custom base URL overrides default`() {
        val url = LLMProvider.GROQ.getModelsUrl("https://custom.api.com/v1")
        assertEquals("https://custom.api.com/v1/models", url)
    }
    
    // Provider lookup tests
    
    @Test
    fun `fromName finds provider by name case insensitive`() {
        assertEquals(LLMProvider.OPENAI, LLMProvider.fromName("openai"))
        assertEquals(LLMProvider.OPENAI, LLMProvider.fromName("OPENAI"))
        assertEquals(LLMProvider.OPENAI, LLMProvider.fromName("OpenAI"))
    }
    
    @Test
    fun `fromName finds provider by display name`() {
        assertEquals(LLMProvider.OPENAI, LLMProvider.fromName("OpenAI"))
        assertEquals(LLMProvider.GROQ, LLMProvider.fromName("Groq"))
        assertEquals(LLMProvider.LMSTUDIO, LLMProvider.fromName("LM Studio"))
    }
    
    @Test
    fun `fromName returns null for unknown provider`() {
        assertNull(LLMProvider.fromName("unknown"))
        assertNull(LLMProvider.fromName(""))
    }
    
    // OpenAI compatible tests
    
    @Test
    fun `isOpenAICompatible returns true for OpenAI protocol providers`() {
        assertTrue(LLMProvider.OPENAI.isOpenAICompatible)
        assertTrue(LLMProvider.GROQ.isOpenAICompatible)
        assertTrue(LLMProvider.MISTRAL.isOpenAICompatible)
        assertTrue(LLMProvider.DEEPSEEK.isOpenAICompatible)
        assertTrue(LLMProvider.OPENROUTER.isOpenAICompatible)
    }
    
    @Test
    fun `isOpenAICompatible returns false for non-OpenAI protocol providers`() {
        assertFalse(LLMProvider.ANTHROPIC.isOpenAICompatible)
        assertFalse(LLMProvider.GOOGLE.isOpenAICompatible)
    }
}
