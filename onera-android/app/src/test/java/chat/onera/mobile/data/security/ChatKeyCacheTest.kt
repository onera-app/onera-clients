package chat.onera.mobile.data.security

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class ChatKeyCacheTest {
    
    private lateinit var cache: ChatKeyCache
    
    @Before
    fun setup() {
        cache = ChatKeyCache()
    }
    
    @Test
    fun `set and get returns correct key`() {
        val chatId = "chat-123"
        val key = byteArrayOf(1, 2, 3, 4, 5)
        
        cache.set(chatId, key)
        val retrieved = cache.get(chatId)
        
        assertArrayEquals(key, retrieved)
    }
    
    @Test
    fun `get returns null for non-existent key`() {
        val result = cache.get("non-existent")
        assertNull(result)
    }
    
    @Test
    fun `remove removes key`() {
        val chatId = "chat-123"
        val key = byteArrayOf(1, 2, 3)
        
        cache.set(chatId, key)
        assertNotNull(cache.get(chatId))
        
        cache.remove(chatId)
        assertNull(cache.get(chatId))
    }
    
    @Test
    fun `clear removes all keys`() {
        cache.set("chat-1", byteArrayOf(1))
        cache.set("chat-2", byteArrayOf(2))
        cache.set("chat-3", byteArrayOf(3))
        
        assertEquals(3, cache.size())
        
        cache.clear()
        
        assertEquals(0, cache.size())
        assertNull(cache.get("chat-1"))
        assertNull(cache.get("chat-2"))
        assertNull(cache.get("chat-3"))
    }
    
    @Test
    fun `size returns correct count`() {
        assertEquals(0, cache.size())
        
        cache.set("chat-1", byteArrayOf(1))
        assertEquals(1, cache.size())
        
        cache.set("chat-2", byteArrayOf(2))
        assertEquals(2, cache.size())
        
        cache.remove("chat-1")
        assertEquals(1, cache.size())
    }
    
    @Test
    fun `contains returns true for existing key`() {
        val chatId = "chat-123"
        cache.set(chatId, byteArrayOf(1, 2, 3))
        
        assertTrue(cache.contains(chatId))
    }
    
    @Test
    fun `contains returns false for non-existent key`() {
        assertFalse(cache.contains("non-existent"))
    }
    
    @Test
    fun `set overwrites existing key`() {
        val chatId = "chat-123"
        val key1 = byteArrayOf(1, 2, 3)
        val key2 = byteArrayOf(4, 5, 6)
        
        cache.set(chatId, key1)
        cache.set(chatId, key2)
        
        val retrieved = cache.get(chatId)
        assertArrayEquals(key2, retrieved)
        assertEquals(1, cache.size())
    }
    
    @Test
    fun `get returns copy not reference`() {
        val chatId = "chat-123"
        val key = byteArrayOf(1, 2, 3)
        
        cache.set(chatId, key)
        val retrieved = cache.get(chatId)!!
        
        // Modify the retrieved array
        retrieved[0] = 99
        
        // Original cached value should be unchanged
        val retrievedAgain = cache.get(chatId)!!
        assertEquals(1.toByte(), retrievedAgain[0])
    }
    
    @Test
    fun `set stores copy not reference`() {
        val chatId = "chat-123"
        val key = byteArrayOf(1, 2, 3)
        
        cache.set(chatId, key)
        
        // Modify the original array
        key[0] = 99
        
        // Cached value should be unchanged
        val retrieved = cache.get(chatId)!!
        assertEquals(1.toByte(), retrieved[0])
    }
    
    @Test
    fun `multiple chats can be cached`() {
        val keys = mapOf(
            "chat-1" to byteArrayOf(1, 1, 1),
            "chat-2" to byteArrayOf(2, 2, 2),
            "chat-3" to byteArrayOf(3, 3, 3)
        )
        
        keys.forEach { (id, key) ->
            cache.set(id, key)
        }
        
        keys.forEach { (id, expectedKey) ->
            val retrieved = cache.get(id)
            assertArrayEquals(expectedKey, retrieved)
        }
    }
    
    @Test
    fun `evictExpired does not affect fresh entries`() {
        cache.set("chat-1", byteArrayOf(1))
        cache.set("chat-2", byteArrayOf(2))
        
        cache.evictExpired()
        
        // Fresh entries should still be present
        assertEquals(2, cache.size())
        assertNotNull(cache.get("chat-1"))
        assertNotNull(cache.get("chat-2"))
    }
}
