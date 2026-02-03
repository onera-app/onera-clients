//
//  SecureEnclaveServiceProtocol.swift
//  Onera
//
//  Protocol for Secure Enclave operations with hardware-backed key generation
//

import Foundation
import Security

/// Protocol for Secure Enclave operations providing hardware-backed cryptographic keys
/// when available, with software fallback for unsupported devices.
protocol SecureEnclaveServiceProtocol: Sendable {
    
    /// Indicates whether the current device supports hardware-backed keys
    /// Returns true if Secure Enclave is available and functional
    var isHardwareBacked: Bool { get }
    
    /// Generates a cryptographic key pair using the most secure method available
    /// - On supported devices: Uses Secure Enclave with P-256 (secp256r1)
    /// - On unsupported devices: Uses software Keychain with X25519
    /// - Returns: Tuple containing the public key data and private key reference
    /// - Throws: SecureEnclaveError if key generation fails
    func generateKeyPair() throws -> (publicKey: Data, privateKey: SecKey)
    
    /// Signs data using a private key
    /// - Parameters:
    ///   - data: The data to sign
    ///   - privateKey: The private key reference from generateKeyPair()
    /// - Returns: The signature data
    /// - Throws: SecureEnclaveError if signing fails
    func sign(data: Data, with privateKey: SecKey) throws -> Data
    
    /// Performs Elliptic Curve Diffie-Hellman key agreement
    /// - Parameters:
    ///   - privateKey: The local private key reference
    ///   - publicKey: The remote public key data
    /// - Returns: The shared secret data
    /// - Throws: SecureEnclaveError if key agreement fails
    func performKeyAgreement(privateKey: SecKey, publicKey: Data) throws -> Data
}

// MARK: - Errors

enum SecureEnclaveError: Error, LocalizedError {
    case notAvailable
    case keyGenerationFailed
    case signingFailed
    case keyAgreementFailed
    case invalidPublicKey
    case invalidPrivateKey
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Secure Enclave is not available on this device"
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key pair"
        case .signingFailed:
            return "Failed to sign data with private key"
        case .keyAgreementFailed:
            return "Failed to perform key agreement"
        case .invalidPublicKey:
            return "Invalid public key format"
        case .invalidPrivateKey:
            return "Invalid private key reference"
        case .unsupportedOperation:
            return "Operation not supported on this device"
        }
    }
}