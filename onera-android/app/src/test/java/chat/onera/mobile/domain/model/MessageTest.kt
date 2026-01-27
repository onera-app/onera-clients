package chat.onera.mobile.domain.model

import org.junit.Assert.*
import org.junit.Test

class MessageTest {

    @Test
    fun `message should have default edited false`() {
        val message = Message(
            id = "1",
            chatId = "chat-1",
            role = MessageRole.USER,
            content = "Hello",
            createdAt = System.currentTimeMillis()
        )
        
        assertFalse(message.edited)
        assertNull(message.editedAt)
    }

    @Test
    fun `message copy should preserve edited state`() {
        val message = Message(
            id = "1",
            chatId = "chat-1",
            role = MessageRole.USER,
            content = "Hello",
            createdAt = System.currentTimeMillis(),
            edited = true,
            editedAt = System.currentTimeMillis()
        )
        
        val copied = message.copy(content = "Updated content")
        
        assertTrue(copied.edited)
        assertNotNull(copied.editedAt)
        assertEquals("Updated content", copied.content)
    }

    @Test
    fun `message roles should be distinguishable`() {
        val userMessage = Message(
            id = "1",
            chatId = "chat-1",
            role = MessageRole.USER,
            content = "User message",
            createdAt = System.currentTimeMillis()
        )
        
        val assistantMessage = Message(
            id = "2",
            chatId = "chat-1",
            role = MessageRole.ASSISTANT,
            content = "Assistant message",
            createdAt = System.currentTimeMillis()
        )
        
        assertEquals(MessageRole.USER, userMessage.role)
        assertEquals(MessageRole.ASSISTANT, assistantMessage.role)
        assertNotEquals(userMessage.role, assistantMessage.role)
    }

    @Test
    fun `system message should have system role`() {
        val systemMessage = Message(
            id = "1",
            chatId = "chat-1",
            role = MessageRole.SYSTEM,
            content = "System prompt",
            createdAt = System.currentTimeMillis()
        )
        
        assertEquals(MessageRole.SYSTEM, systemMessage.role)
    }
}
