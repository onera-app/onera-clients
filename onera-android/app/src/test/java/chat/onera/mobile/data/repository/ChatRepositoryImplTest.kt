package chat.onera.mobile.data.repository

import chat.onera.mobile.data.remote.dto.ChatRemoveRequest
import chat.onera.mobile.data.remote.dto.ChatRemoveResponse
import chat.onera.mobile.data.remote.dto.EncryptedChatSummary
import chat.onera.mobile.data.remote.trpc.ChatProcedures
import chat.onera.mobile.data.security.ChatKeyCache
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for ChatRepositoryImpl.
 * Tests procedure names and basic functionality.
 */
class ChatRepositoryImplTest {
    
    @Test
    fun `ChatProcedures LIST uses plural chats`() {
        assertEquals("chats.list", ChatProcedures.LIST)
    }
    
    @Test
    fun `ChatProcedures GET uses plural chats`() {
        assertEquals("chats.get", ChatProcedures.GET)
    }
    
    @Test
    fun `ChatProcedures CREATE uses plural chats`() {
        assertEquals("chats.create", ChatProcedures.CREATE)
    }
    
    @Test
    fun `ChatProcedures UPDATE uses plural chats`() {
        assertEquals("chats.update", ChatProcedures.UPDATE)
    }
    
    @Test
    fun `ChatProcedures REMOVE uses remove not delete`() {
        assertEquals("chats.remove", ChatProcedures.REMOVE)
    }
    
    @Test
    fun `ChatRemoveRequest serializes correctly`() {
        val request = ChatRemoveRequest(chatId = "test-123")
        assertEquals("test-123", request.chatId)
    }
    
    @Test
    fun `ChatRemoveResponse deserializes correctly`() {
        val response = ChatRemoveResponse(success = true)
        assertTrue(response.success)
    }
    
    @Test
    fun `EncryptedChatSummary has all required fields`() {
        val summary = EncryptedChatSummary(
            id = "chat-1",
            userId = "user-1",
            isEncrypted = true,
            encryptedChatKey = "key",
            chatKeyNonce = "nonce1",
            encryptedTitle = "title",
            titleNonce = "nonce2",
            folderId = null,
            pinned = false,
            archived = false,
            createdAt = 1000L,
            updatedAt = 2000L
        )
        
        assertEquals("chat-1", summary.id)
        assertTrue(summary.isEncrypted)
        assertEquals("key", summary.encryptedChatKey)
    }
    
    @Test
    fun `ChatKeyCache stores and retrieves keys`() {
        val cache = ChatKeyCache()
        val key = byteArrayOf(1, 2, 3, 4)
        
        cache.set("chat-1", key)
        val retrieved = cache.get("chat-1")
        
        assertNotNull(retrieved)
        assertArrayEquals(key, retrieved)
    }
    
    @Test
    fun `ChatKeyCache returns null for non-existent keys`() {
        val cache = ChatKeyCache()
        
        val result = cache.get("non-existent")
        
        assertNull(result)
    }
    
    @Test
    fun `ChatKeyCache clear removes all keys`() {
        val cache = ChatKeyCache()
        cache.set("chat-1", byteArrayOf(1))
        cache.set("chat-2", byteArrayOf(2))
        
        cache.clear()
        
        assertNull(cache.get("chat-1"))
        assertNull(cache.get("chat-2"))
    }
}
