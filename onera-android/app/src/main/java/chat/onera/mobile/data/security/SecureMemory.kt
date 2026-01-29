package chat.onera.mobile.data.security

import timber.log.Timber
import java.util.Arrays

/**
 * Utility class for secure memory handling.
 * Provides methods to safely clear sensitive data from memory.
 */
object SecureMemory {
    
    private const val TAG = "SecureMemory"
    
    /**
     * Securely zeros a byte array to prevent sensitive data from lingering in memory.
     * Uses Arrays.fill which should not be optimized away by the JVM.
     */
    fun zero(data: ByteArray?) {
        if (data == null) return
        Arrays.fill(data, 0.toByte())
    }
    
    /**
     * Securely zeros multiple byte arrays.
     */
    fun zero(vararg arrays: ByteArray?) {
        arrays.forEach { zero(it) }
    }
    
    /**
     * Securely zeros a char array (useful for passwords).
     */
    fun zero(data: CharArray?) {
        if (data == null) return
        Arrays.fill(data, '\u0000')
    }
    
    /**
     * Securely zeros an int array.
     */
    fun zero(data: IntArray?) {
        if (data == null) return
        Arrays.fill(data, 0)
    }
    
    /**
     * Execute a block with a temporary byte array that will be securely zeroed after use.
     * 
     * Usage:
     * ```
     * SecureMemory.withSecureBytes(32) { key ->
     *     // Use key here
     *     encryptWith(key)
     * } // key is automatically zeroed here
     * ```
     */
    inline fun <T> withSecureBytes(size: Int, block: (ByteArray) -> T): T {
        val data = ByteArray(size)
        return try {
            block(data)
        } finally {
            zero(data)
        }
    }
    
    /**
     * Execute a block with a cloned byte array that will be securely zeroed after use.
     * Original array is not modified.
     */
    inline fun <T> withSecureCopy(source: ByteArray, block: (ByteArray) -> T): T {
        val copy = source.copyOf()
        return try {
            block(copy)
        } finally {
            zero(copy)
        }
    }
    
    /**
     * Wrapper class for sensitive byte data that automatically zeros on close.
     */
    class SecureByteArray(size: Int) : AutoCloseable {
        val data: ByteArray = ByteArray(size)
        
        constructor(source: ByteArray) : this(source.size) {
            source.copyInto(data)
        }
        
        override fun close() {
            zero(data)
            Timber.v("$TAG: Securely zeroed ${data.size} bytes")
        }
    }
    
    /**
     * Create a SecureByteArray that will be automatically zeroed when the block completes.
     */
    inline fun <T> withSecureArray(size: Int, block: (SecureByteArray) -> T): T {
        return SecureByteArray(size).use(block)
    }
    
    /**
     * Compare two byte arrays in constant time to prevent timing attacks.
     * Returns true if arrays are equal, false otherwise.
     */
    fun constantTimeEquals(a: ByteArray, b: ByteArray): Boolean {
        if (a.size != b.size) return false
        
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].toInt() xor b[i].toInt())
        }
        return result == 0
    }
}

/**
 * Extension function for ByteArray to securely zero its contents.
 */
fun ByteArray.secureZero() {
    SecureMemory.zero(this)
}

/**
 * Extension function for CharArray to securely zero its contents.
 */
fun CharArray.secureZero() {
    SecureMemory.zero(this)
}
