//
//  NoiseProtocol.swift
//  Onera
//
//  Noise Protocol NK handshake implementation matching Web exactly
//  Protocol: Noise_NK_25519_ChaChaPoly_SHA256
//

import Foundation
import CryptoKit
import os.log

// MARK: - Noise Protocol Constants

private enum NoiseConstants {
    static let dhLen = 32        // X25519 key length
    static let hashLen = 32      // SHA-256 output
    static let keyLen = 32       // ChaCha20-Poly1305 key length
    static let nonceLen = 12     // ChaCha20-Poly1305 nonce length
    static let protocolName = "Noise_NK_25519_ChaChaPoly_SHA256"
}

// MARK: - Cipher State

/// Cipher state for transport encryption after handshake
struct CipherState: Sendable {
    var key: Data
    var nonce: UInt64
    
    init(key: Data, nonce: UInt64 = 0) {
        self.key = key
        self.nonce = nonce
    }
}

// MARK: - Handshake Result

/// Result of successful Noise NK handshake containing cipher states for bidirectional communication
struct HandshakeResult: Sendable {
    let sendCipher: CipherState
    let recvCipher: CipherState
}

// MARK: - Noise Session

/// High-level Noise session for encrypted communication
actor NoiseSession: Sendable {
    private var sendCipher: CipherState?
    private var recvCipher: CipherState?
    private var _isClosed = false
    private let logger = Logger(subsystem: "chat.onera", category: "NoiseProtocol")
    
    /// Whether the session is closed and cannot be reused
    var isClosed: Bool {
        _isClosed
    }
    
    /// Initializes session with handshake result
    func initialize(with result: HandshakeResult) {
        self.sendCipher = result.sendCipher
        self.recvCipher = result.recvCipher
        self._isClosed = false
        logger.info("Noise session initialized")
    }
    
    /// Encrypts a message for sending
    func encrypt(_ plaintext: Data) throws -> Data {
        guard !_isClosed else {
            throw NoiseError.sessionClosed
        }
        guard var cipher = sendCipher else {
            throw NoiseError.sessionNotInitialized
        }
        
        let ciphertext = try NoiseProtocol.encryptMessage(cipher: &cipher, plaintext: plaintext)
        sendCipher = cipher
        return ciphertext
    }
    
    /// Decrypts a received message
    func decrypt(_ ciphertext: Data) throws -> Data {
        guard !_isClosed else {
            throw NoiseError.sessionClosed
        }
        guard var cipher = recvCipher else {
            throw NoiseError.sessionNotInitialized
        }
        
        let plaintext = try NoiseProtocol.decryptMessage(cipher: &cipher, ciphertext: ciphertext)
        recvCipher = cipher
        return plaintext
    }
    
    /// Clears session state
    func close() {
        _isClosed = true
        sendCipher = nil
        recvCipher = nil
        logger.info("Noise session closed")
    }
}

// MARK: - Noise Protocol Implementation

enum NoiseProtocol {
    
    private static let logger = Logger(subsystem: "chat.onera", category: "NoiseProtocol")
    
    // MARK: - NK Handshake
    
    /// Performs Noise NK handshake as initiator (client)
    /// NK pattern: Client knows server's static public key (from attestation)
    ///
    /// - Parameters:
    ///   - serverPublicKey: Base64-encoded X25519 public key from attestation
    ///   - send: Callback to send handshake message to server
    ///   - receive: Callback to receive handshake message from server
    /// - Returns: Cipher states for encrypted transport
    /// - Throws: NoiseError if handshake fails
    static func performNKHandshake(
        serverPublicKey: Data,
        send: (Data) async throws -> Void,
        receive: () async throws -> Data
    ) async throws -> HandshakeResult {
        
        logger.info("Starting Noise NK handshake")
        
        // Validate server public key
        guard serverPublicKey.count == NoiseConstants.dhLen else {
            throw NoiseError.invalidPublicKey
        }
        
        // Initialize symmetric state
        var ss = initializeSymmetric(protocolName: NoiseConstants.protocolName)
        
        // MixHash with empty prologue
        mixHash(&ss, Data())
        
        // Pre-message pattern: <- s
        // Mix server's static public key into handshake hash
        mixHash(&ss, serverPublicKey)
        
        // Generate ephemeral keypair
        let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralPrivateKey.publicKey
        let e = ephemeralPublicKey.rawRepresentation
        
        // Message 1: -> e, es
        // Send ephemeral public key
        mixHash(&ss, e)
        
        // Perform DH: es = DH(e, rs)
        let serverPublicKeyObj = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverPublicKey)
        let es = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: serverPublicKeyObj)
        mixKey(&ss, es.withUnsafeBytes { Data($0) })
        
        // Encrypt empty payload (NK has no payload in first message)
        let payload1 = try encryptAndHash(&ss, Data())
        
        // Build message 1: e || encrypted_payload
        var message1 = Data()
        message1.append(e)
        message1.append(payload1)
        
        try await send(message1)
        logger.debug("Sent handshake message 1 (\(message1.count) bytes)")
        
        // Message 2: <- e, ee
        let message2 = try await receive()
        logger.debug("Received handshake message 2 (\(message2.count) bytes)")
        
        guard message2.count >= NoiseConstants.dhLen else {
            throw NoiseError.invalidHandshakeMessage("Message 2 too short: \(message2.count) bytes")
        }
        
        // Extract server's ephemeral public key
        let re = message2.prefix(NoiseConstants.dhLen)
        mixHash(&ss, Data(re))
        
        // Perform DH: ee = DH(e, re)
        let serverEphemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(re))
        let ee = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: serverEphemeralKey)
        mixKey(&ss, ee.withUnsafeBytes { Data($0) })
        
        // Decrypt payload (may be empty)
        let encryptedPayload2 = message2.dropFirst(NoiseConstants.dhLen)
        if !encryptedPayload2.isEmpty {
            _ = try decryptAndHash(&ss, Data(encryptedPayload2))
        }
        
        // Split into transport cipher states
        // Initiator sends with first key, receives with second
        let (c1, c2) = split(ss)
        
        logger.info("Noise NK handshake completed successfully")
        
        return HandshakeResult(
            sendCipher: c1,
            recvCipher: c2
        )
    }
    
    // MARK: - Transport Encryption
    
    /// Encrypts a message using the transport cipher state
    /// The nonce is automatically incremented after each encryption
    nonisolated static func encryptMessage(cipher: inout CipherState, plaintext: Data) throws -> Data {
        // Create nonce from counter (12 bytes, counter at offset 4, little-endian)
        var nonce = Data(count: NoiseConstants.nonceLen)
        nonce.withUnsafeMutableBytes { bytes in
            let uint64Ptr = bytes.bindMemory(to: UInt64.self)
            uint64Ptr[0] = 0 // First 8 bytes are zero
            // Counter at offset 4 (overlapping with first 8 bytes)
            let counterPtr = bytes.baseAddress!.advanced(by: 4).bindMemory(to: UInt64.self, capacity: 1)
            counterPtr.pointee = cipher.nonce.littleEndian
        }
        
        // Encrypt with ChaCha20-Poly1305 (no additional data for transport)
        let sealedBox = try ChaChaPoly.seal(plaintext, using: SymmetricKey(data: cipher.key), nonce: try ChaChaPoly.Nonce(data: nonce))
        
        cipher.nonce += 1
        
        return sealedBox.combined
    }
    
    /// Decrypts a message using the transport cipher state
    /// The nonce is automatically incremented after each decryption
    nonisolated static func decryptMessage(cipher: inout CipherState, ciphertext: Data) throws -> Data {
        // Create nonce from counter (12 bytes, counter at offset 4, little-endian)
        var nonce = Data(count: NoiseConstants.nonceLen)
        nonce.withUnsafeMutableBytes { bytes in
            let uint64Ptr = bytes.bindMemory(to: UInt64.self)
            uint64Ptr[0] = 0 // First 8 bytes are zero
            // Counter at offset 4 (overlapping with first 8 bytes)
            let counterPtr = bytes.baseAddress!.advanced(by: 4).bindMemory(to: UInt64.self, capacity: 1)
            counterPtr.pointee = cipher.nonce.littleEndian
        }
        
        // Decrypt with ChaCha20-Poly1305
        let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
        let plaintext = try ChaChaPoly.open(sealedBox, using: SymmetricKey(data: cipher.key))
        
        cipher.nonce += 1
        
        return plaintext
    }
}

// MARK: - Private Symmetric State Implementation

private struct SymmetricState {
    var h: Data          // Handshake hash
    var ck: Data         // Chaining key
    var hasKey: Bool
    var k: Data          // Cipher key (if hasKey)
    var n: UInt64        // Nonce counter
}

// MARK: - Private Helper Functions

private func initializeSymmetric(protocolName: String) -> SymmetricState {
    let nameBytes = Data(protocolName.utf8)
    
    let h: Data
    if nameBytes.count <= NoiseConstants.hashLen {
        var paddedName = Data(count: NoiseConstants.hashLen)
        paddedName.replaceSubrange(0..<nameBytes.count, with: nameBytes)
        h = paddedName
    } else {
        h = Data(SHA256.hash(data: nameBytes))
    }
    
    return SymmetricState(
        h: h,
        ck: h, // Copy h to ck
        hasKey: false,
        k: Data(count: NoiseConstants.keyLen),
        n: 0
    )
}

private func mixHash(_ state: inout SymmetricState, _ data: Data) {
    var combined = state.h
    combined.append(data)
    state.h = Data(SHA256.hash(data: combined))
}

private func mixKey(_ state: inout SymmetricState, _ inputKeyMaterial: Data) {
    let (ck, tempK) = hkdf(chainingKey: state.ck, inputKeyMaterial: inputKeyMaterial, numOutputs: 2)
    state.ck = ck
    state.k = Data(tempK.prefix(NoiseConstants.keyLen))
    state.n = 0
    state.hasKey = true
}

private func encryptAndHash(_ state: inout SymmetricState, _ plaintext: Data) throws -> Data {
    if !state.hasKey {
        mixHash(&state, plaintext)
        return plaintext
    }
    
    // Create nonce from counter
    var nonce = Data(count: NoiseConstants.nonceLen)
    nonce.withUnsafeMutableBytes { bytes in
        let uint64Ptr = bytes.bindMemory(to: UInt64.self)
        uint64Ptr[0] = 0 // First 8 bytes are zero
        // Counter at offset 4 (overlapping with first 8 bytes)
        let counterPtr = bytes.baseAddress!.advanced(by: 4).bindMemory(to: UInt64.self, capacity: 1)
        counterPtr.pointee = state.n.littleEndian
    }
    
    // Encrypt with ChaCha20-Poly1305 using handshake hash as additional data
    let sealedBox = try ChaChaPoly.seal(
        plaintext,
        using: SymmetricKey(data: state.k),
        nonce: ChaChaPoly.Nonce(data: nonce),
        authenticating: state.h
    )
    
    let ciphertext = sealedBox.combined
    mixHash(&state, ciphertext)
    state.n += 1
    
    return ciphertext
}

private func decryptAndHash(_ state: inout SymmetricState, _ ciphertext: Data) throws -> Data {
    if !state.hasKey {
        mixHash(&state, ciphertext)
        return ciphertext
    }
    
    // Create nonce from counter
    var nonce = Data(count: NoiseConstants.nonceLen)
    nonce.withUnsafeMutableBytes { bytes in
        let uint64Ptr = bytes.bindMemory(to: UInt64.self)
        uint64Ptr[0] = 0 // First 8 bytes are zero
        // Counter at offset 4 (overlapping with first 8 bytes)
        let counterPtr = bytes.baseAddress!.advanced(by: 4).bindMemory(to: UInt64.self, capacity: 1)
        counterPtr.pointee = state.n.littleEndian
    }
    
    // Decrypt with ChaCha20-Poly1305 using handshake hash as additional data
    let sealedBox = try ChaChaPoly.SealedBox(combined: ciphertext)
    let plaintext = try ChaChaPoly.open(
        sealedBox,
        using: SymmetricKey(data: state.k),
        authenticating: state.h
    )
    
    mixHash(&state, ciphertext)
    state.n += 1
    
    return plaintext
}

private func split(_ state: SymmetricState) -> (CipherState, CipherState) {
    let (tempK1, tempK2) = hkdf(chainingKey: state.ck, inputKeyMaterial: Data(), numOutputs: 2)
    
    return (
        CipherState(key: Data(tempK1.prefix(NoiseConstants.keyLen)), nonce: 0),
        CipherState(key: Data(tempK2.prefix(NoiseConstants.keyLen)), nonce: 0)
    )
}

// MARK: - HKDF Implementation

private func hkdf(chainingKey: Data, inputKeyMaterial: Data, numOutputs: Int) -> (Data, Data) {
    // HKDF-Extract
    let tempKey = hmacSha256(key: chainingKey, data: inputKeyMaterial)
    
    // HKDF-Expand
    let output1 = hmacSha256(key: tempKey, data: Data([0x01]))
    var output2Data = output1
    output2Data.append(0x02)
    let output2 = hmacSha256(key: tempKey, data: output2Data)
    
    return (
        Data(output1.prefix(NoiseConstants.hashLen)),
        Data(output2.prefix(NoiseConstants.hashLen))
    )
}

private func hmacSha256(key: Data, data: Data) -> Data {
    let key = SymmetricKey(data: key)
    let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
    return Data(mac)
}

// MARK: - Errors

enum NoiseError: Error, LocalizedError {
    case invalidPublicKey
    case invalidHandshakeMessage(String)
    case encryptionFailed
    case decryptionFailed
    case sessionNotInitialized
    case sessionClosed
    case keyAgreementFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidHandshakeMessage(let details):
            return "Invalid handshake message: \(details)"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .sessionNotInitialized:
            return "Noise session not initialized"
        case .sessionClosed:
            return "Noise session is closed"
        case .keyAgreementFailed:
            return "Key agreement failed"
        }
    }
}