package chat.onera.mobile.data.security

import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

/**
 * LRU cache with TTL for per-chat encryption keys.
 * Matches the iOS ChatKeyCache implementation.
 * 
 * Thread-safe implementation using ConcurrentHashMap.
 */
@Singleton
class ChatKeyCache @Inject constructor() {
    
    companion object {
        private const val DEFAULT_MAX_SIZE = 100
        private const val DEFAULT_TTL_SECONDS = 600L // 10 minutes
    }
    
    private data class CacheEntry(
        val key: ByteArray,
        val timestamp: Long
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false
            other as CacheEntry
            if (!key.contentEquals(other.key)) return false
            if (timestamp != other.timestamp) return false
            return true
        }

        override fun hashCode(): Int {
            var result = key.contentHashCode()
            result = 31 * result + timestamp.hashCode()
            return result
        }
    }
    
    private val cache = ConcurrentHashMap<String, CacheEntry>()
    private val maxSize: Int = DEFAULT_MAX_SIZE
    private val ttlMillis: Long = DEFAULT_TTL_SECONDS * 1000
    
    /**
     * Get a cached chat key by chat ID.
     * Returns null if not found or expired.
     */
    fun get(chatId: String): ByteArray? {
        val entry = cache[chatId] ?: return null
        
        // Check TTL
        if (System.currentTimeMillis() - entry.timestamp > ttlMillis) {
            cache.remove(chatId)
            return null
        }
        
        return entry.key.copyOf() // Return a copy to prevent modification
    }
    
    /**
     * Store a chat key in the cache.
     */
    fun set(chatId: String, key: ByteArray) {
        // Evict oldest entries if at capacity
        evictIfNeeded()
        
        cache[chatId] = CacheEntry(
            key = key.copyOf(), // Store a copy
            timestamp = System.currentTimeMillis()
        )
    }
    
    /**
     * Remove a specific chat key from the cache.
     */
    fun remove(chatId: String) {
        cache.remove(chatId)
    }
    
    /**
     * Clear all cached keys.
     * Call this on session lock or sign out.
     */
    fun clear() {
        cache.clear()
    }
    
    /**
     * Get the current number of cached entries.
     */
    fun size(): Int = cache.size
    
    /**
     * Check if a chat key is cached (and not expired).
     */
    fun contains(chatId: String): Boolean = get(chatId) != null
    
    /**
     * Evict expired entries and oldest entries if over capacity.
     */
    private fun evictIfNeeded() {
        val now = System.currentTimeMillis()
        
        // First, remove expired entries
        val expiredKeys = cache.entries
            .filter { now - it.value.timestamp > ttlMillis }
            .map { it.key }
        
        expiredKeys.forEach { cache.remove(it) }
        
        // Then, remove oldest entries if still over capacity
        while (cache.size >= maxSize) {
            val oldest = cache.entries
                .minByOrNull { it.value.timestamp }
                ?.key
            
            if (oldest != null) {
                cache.remove(oldest)
            } else {
                break
            }
        }
    }
    
    /**
     * Remove all expired entries.
     * Can be called periodically for cleanup.
     */
    fun evictExpired() {
        val now = System.currentTimeMillis()
        val expiredKeys = cache.entries
            .filter { now - it.value.timestamp > ttlMillis }
            .map { it.key }
        
        expiredKeys.forEach { cache.remove(it) }
    }
}
