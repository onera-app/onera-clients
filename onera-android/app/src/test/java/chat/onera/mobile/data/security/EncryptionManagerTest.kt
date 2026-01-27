package chat.onera.mobile.data.security

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class EncryptionManagerTest {
    
    private lateinit var encryptionManager: EncryptionManager
    
    @Before
    fun setup() {
        encryptionManager = EncryptionManager()
    }
    
    @Test
    fun `generateChatKey generates 32 byte key`() {
        val key = encryptionManager.generateChatKey()
        assertEquals(32, key.size)
    }
    
    @Test
    fun `generateChatKey generates unique keys`() {
        val key1 = encryptionManager.generateChatKey()
        val key2 = encryptionManager.generateChatKey()
        assertFalse(key1.contentEquals(key2))
    }
    
    @Test
    fun `generateRandomBytes generates correct length`() {
        val bytes = encryptionManager.generateRandomBytes(16)
        assertEquals(16, bytes.size)
    }
    
    @Test
    fun `encrypt and decrypt roundtrip with ByteArray key`() {
        val key = encryptionManager.generateChatKey()
        val plaintext = "Hello, World!"
        
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key)
        val decrypted = encryptionManager.decryptToStringWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertEquals(plaintext, decrypted)
    }
    
    @Test
    fun `encrypt and decrypt roundtrip for server`() {
        // Note: This test uses Base64 which requires Android runtime
        // Testing in integration tests instead
        // For unit tests, we test the core encryption/decryption without Base64
        val key = encryptionManager.generateChatKey()
        val plaintext = "Test message for server"
        
        // Test the underlying encryption without Base64
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key)
        val decrypted = encryptionManager.decryptToStringWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertEquals(plaintext, decrypted)
    }
    
    @Test
    fun `encrypt produces different ciphertext each time due to random nonce`() {
        val key = encryptionManager.generateChatKey()
        val plaintext = "Same message"
        
        val encrypted1 = encryptionManager.encryptStringWithKey(plaintext, key)
        val encrypted2 = encryptionManager.encryptStringWithKey(plaintext, key)
        
        // Nonces should be different
        assertFalse(encrypted1.nonce.contentEquals(encrypted2.nonce))
        // Ciphertext should be different (due to different nonces)
        assertFalse(encrypted1.ciphertext.contentEquals(encrypted2.ciphertext))
    }
    
    @Test
    fun `decrypt with wrong key throws exception`() {
        val key1 = encryptionManager.generateChatKey()
        val key2 = encryptionManager.generateChatKey()
        val plaintext = "Secret message"
        
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key1)
        
        assertThrows(Exception::class.java) {
            encryptionManager.decryptToStringWithKey(
                encrypted.ciphertext,
                encrypted.nonce,
                key2
            )
        }
    }
    
    @Test
    fun `encrypt empty string works`() {
        val key = encryptionManager.generateChatKey()
        val plaintext = ""
        
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key)
        val decrypted = encryptionManager.decryptToStringWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertEquals(plaintext, decrypted)
    }
    
    @Test
    fun `encrypt long string works`() {
        val key = encryptionManager.generateChatKey()
        val plaintext = "A".repeat(10000)
        
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key)
        val decrypted = encryptionManager.decryptToStringWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertEquals(plaintext, decrypted)
    }
    
    @Test
    fun `encrypt unicode string works`() {
        val key = encryptionManager.generateChatKey()
        val plaintext = "Hello, 世界! 🌍 Привет!"
        
        val encrypted = encryptionManager.encryptStringWithKey(plaintext, key)
        val decrypted = encryptionManager.decryptToStringWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertEquals(plaintext, decrypted)
    }
    
    @Test
    fun `bytes roundtrip`() {
        // Test bytes encryption/decryption without Base64 (which requires Android)
        val key = encryptionManager.generateChatKey()
        val data = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
        
        val encrypted = encryptionManager.encryptWithKey(data, key)
        val decrypted = encryptionManager.decryptWithKey(
            encrypted.ciphertext,
            encrypted.nonce,
            key
        )
        
        assertArrayEquals(data, decrypted)
    }
}
