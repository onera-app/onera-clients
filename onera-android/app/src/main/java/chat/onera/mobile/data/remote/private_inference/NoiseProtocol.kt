package chat.onera.mobile.data.remote.private_inference

import android.util.Log
import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.SodiumAndroid
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Noise NK handshake + transport encryption implementation.
 *
 * Matches server/web/iOS protocol:
 * Noise_NK_25519_ChaChaPoly_SHA256
 */
object NoiseProtocol {

    private const val TAG = "NoiseProtocol"

    // Noise protocol identifiers
    private const val PROTOCOL_NAME = "Noise_NK_25519_ChaChaPoly_SHA256"

    // Key sizes
    private const val KEY_SIZE = 32
    private const val DH_SIZE = 32
    private const val HASH_SIZE = 32
    private const val NONCE_SIZE = 12
    private const val AEAD_TAG_SIZE = 16

    private val sodium: LazySodiumAndroid by lazy {
        LazySodiumAndroid(SodiumAndroid())
    }

    suspend fun performNKHandshake(
        serverPublicKey: ByteArray,
        sendMessage: suspend (ByteArray) -> Unit,
        receiveMessage: suspend () -> ByteArray
    ): HandshakeResult {
        if (serverPublicKey.size != DH_SIZE) {
            throw PrivateInferenceException.HandshakeFailed("Invalid server public key length: ${serverPublicKey.size}")
        }

        Log.d(TAG, "Starting NK handshake")

        // Initialize symmetric state
        val ss = initializeSymmetric(PROTOCOL_NAME)
        mixHash(ss, ByteArray(0))            // empty prologue
        mixHash(ss, serverPublicKey)         // <- s (pre-message)

        // Generate ephemeral keypair
        val ephemeral = sodium.cryptoBoxKeypair()
        val e = ephemeral.publicKey.asBytes
        val ePrivate = ephemeral.secretKey.asBytes

        try {
            // -> e, es
            mixHash(ss, e)
            val es = scalarMult(ePrivate, serverPublicKey)
            mixKey(ss, es)

            // NK message 1 includes encrypted empty payload (16-byte tag)
            val payload1 = encryptAndHash(ss, ByteArray(0))
            val message1 = ByteArray(DH_SIZE + payload1.size)
            System.arraycopy(e, 0, message1, 0, DH_SIZE)
            System.arraycopy(payload1, 0, message1, DH_SIZE, payload1.size)

            sendMessage(message1)

            // <- e, ee
            val message2 = receiveMessage()
            if (message2.size < DH_SIZE) {
                throw PrivateInferenceException.HandshakeFailed(
                    "Invalid handshake message 2 length: ${message2.size}"
                )
            }

            val re = message2.copyOfRange(0, DH_SIZE)
            mixHash(ss, re)

            val ee = scalarMult(ePrivate, re)
            mixKey(ss, ee)

            val encryptedPayload2 = message2.copyOfRange(DH_SIZE, message2.size)
            if (encryptedPayload2.isNotEmpty()) {
                decryptAndHash(ss, encryptedPayload2)
            }

            val (sendingKey, receivingKey) = split(ss)
            Log.d(TAG, "NK handshake completed")

            return HandshakeResult(
                sendingKey = sendingKey,
                receivingKey = receivingKey,
                hash = ss.h
            )
        } finally {
            ePrivate.fill(0)
        }
    }

    private fun scalarMult(privateKey: ByteArray, publicKey: ByteArray): ByteArray {
        val out = ByteArray(DH_SIZE)
        val ok = sodium.cryptoScalarMult(out, privateKey, publicKey)
        if (!ok) {
            throw PrivateInferenceException.HandshakeFailed("X25519 key exchange failed")
        }
        return out
    }

    private data class SymmetricState(
        var h: ByteArray,
        var ck: ByteArray,
        var hasKey: Boolean,
        var k: ByteArray,
        var n: Long
    )

    private fun initializeSymmetric(protocolName: String): SymmetricState {
        val nameBytes = protocolName.toByteArray(Charsets.UTF_8)
        val h = if (nameBytes.size <= HASH_SIZE) {
            ByteArray(HASH_SIZE).also { out ->
                System.arraycopy(nameBytes, 0, out, 0, nameBytes.size)
            }
        } else {
            sha256(nameBytes)
        }

        return SymmetricState(
            h = h,
            ck = h.copyOf(),
            hasKey = false,
            k = ByteArray(KEY_SIZE),
            n = 0L
        )
    }

    private fun mixHash(state: SymmetricState, data: ByteArray) {
        val input = ByteArray(state.h.size + data.size)
        System.arraycopy(state.h, 0, input, 0, state.h.size)
        System.arraycopy(data, 0, input, state.h.size, data.size)
        state.h = sha256(input)
    }

    private fun mixKey(state: SymmetricState, inputKeyMaterial: ByteArray) {
        val (ck, tempK) = hkdf(state.ck, inputKeyMaterial)
        state.ck = ck
        state.k = tempK
        state.n = 0L
        state.hasKey = true
    }

    private fun split(state: SymmetricState): Pair<ByteArray, ByteArray> {
        return hkdf(state.ck, ByteArray(0))
    }

    private fun encryptAndHash(state: SymmetricState, plaintext: ByteArray): ByteArray {
        if (!state.hasKey) {
            mixHash(state, plaintext)
            return plaintext
        }

        val nonce = createNonce(state.n)
        val ciphertext = aeadEncrypt(
            plaintext = plaintext,
            additionalData = state.h,
            nonce = nonce,
            key = state.k
        )
        mixHash(state, ciphertext)
        state.n++
        return ciphertext
    }

    private fun decryptAndHash(state: SymmetricState, ciphertext: ByteArray): ByteArray {
        if (!state.hasKey) {
            mixHash(state, ciphertext)
            return ciphertext
        }

        val nonce = createNonce(state.n)
        val plaintext = aeadDecrypt(
            ciphertext = ciphertext,
            additionalData = state.h,
            nonce = nonce,
            key = state.k
        )
        mixHash(state, ciphertext)
        state.n++
        return plaintext
    }

    private fun sha256(data: ByteArray): ByteArray {
        return MessageDigest.getInstance("SHA-256").digest(data)
    }

    private fun hkdf(chainingKey: ByteArray, inputKeyMaterial: ByteArray): Pair<ByteArray, ByteArray> {
        val tempKey = hmacSha256(chainingKey, inputKeyMaterial)
        val output1 = hmacSha256(tempKey, byteArrayOf(0x01))
        val output2 = hmacSha256(tempKey, output1 + byteArrayOf(0x02))
        return output1.copyOf(KEY_SIZE) to output2.copyOf(KEY_SIZE)
    }

    private fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(data)
    }

    private fun createNonce(counter: Long): ByteArray {
        val nonce = ByteArray(NONCE_SIZE)
        val buffer = ByteBuffer.wrap(nonce).order(ByteOrder.LITTLE_ENDIAN)
        buffer.position(4)
        buffer.putLong(counter)
        return nonce
    }

    private fun aeadEncrypt(
        plaintext: ByteArray,
        additionalData: ByteArray?,
        nonce: ByteArray,
        key: ByteArray
    ): ByteArray {
        val ad = additionalData ?: ByteArray(0)
        val out = ByteArray(plaintext.size + AEAD_TAG_SIZE)
        val outLen = longArrayOf(0L)
        val ok = sodium.cryptoAeadChaCha20Poly1305IetfEncrypt(
            out,
            outLen,
            plaintext,
            plaintext.size.toLong(),
            ad,
            ad.size.toLong(),
            null,
            nonce,
            key
        )
        if (!ok) {
            throw PrivateInferenceException.EncryptionFailed()
        }
        return out.copyOf(outLen[0].toInt())
    }

    private fun aeadDecrypt(
        ciphertext: ByteArray,
        additionalData: ByteArray?,
        nonce: ByteArray,
        key: ByteArray
    ): ByteArray {
        val ad = additionalData ?: ByteArray(0)
        val out = ByteArray((ciphertext.size - AEAD_TAG_SIZE).coerceAtLeast(0))
        val outLen = longArrayOf(0L)
        val ok = sodium.cryptoAeadChaCha20Poly1305IetfDecrypt(
            out,
            outLen,
            null,
            ciphertext,
            ciphertext.size.toLong(),
            ad,
            ad.size.toLong(),
            nonce,
            key
        )
        if (!ok) {
            throw PrivateInferenceException.DecryptionFailed()
        }
        return out.copyOf(outLen[0].toInt())
    }
}

data class HandshakeResult(
    val sendingKey: ByteArray,
    val receivingKey: ByteArray,
    val hash: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as HandshakeResult
        if (!sendingKey.contentEquals(other.sendingKey)) return false
        if (!receivingKey.contentEquals(other.receivingKey)) return false
        if (!hash.contentEquals(other.hash)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = sendingKey.contentHashCode()
        result = 31 * result + receivingKey.contentHashCode()
        result = 31 * result + hash.contentHashCode()
        return result
    }
}

class NoiseSession(
    private val sendingKey: ByteArray,
    private val receivingKey: ByteArray
) {
    private val sodium: LazySodiumAndroid = LazySodiumAndroid(SodiumAndroid())
    private var sendNonce: Long = 0L
    private var receiveNonce: Long = 0L

    @Volatile
    var isClosed: Boolean = false
        private set

    fun encrypt(plaintext: ByteArray): ByteArray {
        if (isClosed) throw PrivateInferenceException.ConnectionClosed()

        val nonce = createNonce(sendNonce++)
        val out = ByteArray(plaintext.size + AEAD_TAG_SIZE)
        val outLen = longArrayOf(0L)
        val ok = sodium.cryptoAeadChaCha20Poly1305IetfEncrypt(
            out,
            outLen,
            plaintext,
            plaintext.size.toLong(),
            ByteArray(0),
            0L,
            null,
            nonce,
            sendingKey
        )
        if (!ok) throw PrivateInferenceException.EncryptionFailed()
        return out.copyOf(outLen[0].toInt())
    }

    fun decrypt(ciphertext: ByteArray): ByteArray {
        if (isClosed) throw PrivateInferenceException.ConnectionClosed()

        val nonce = createNonce(receiveNonce++)
        val out = ByteArray((ciphertext.size - AEAD_TAG_SIZE).coerceAtLeast(0))
        val outLen = longArrayOf(0L)
        val ok = sodium.cryptoAeadChaCha20Poly1305IetfDecrypt(
            out,
            outLen,
            null,
            ciphertext,
            ciphertext.size.toLong(),
            ByteArray(0),
            0L,
            nonce,
            receivingKey
        )
        if (!ok) throw PrivateInferenceException.DecryptionFailed()
        return out.copyOf(outLen[0].toInt())
    }

    fun close() {
        isClosed = true
        sendingKey.fill(0)
        receivingKey.fill(0)
    }

    private fun createNonce(counter: Long): ByteArray {
        val nonce = ByteArray(NONCE_SIZE)
        val buffer = ByteBuffer.wrap(nonce).order(ByteOrder.LITTLE_ENDIAN)
        buffer.position(4)
        buffer.putLong(counter)
        return nonce
    }

    private companion object {
        private const val NONCE_SIZE = 12
        private const val AEAD_TAG_SIZE = 16
    }
}
