//
//  PasskeyServiceProtocol.swift
//  Onera
//
//  Protocol for passkey (WebAuthn) operations
//

import Foundation

// MARK: - Passkey Service Protocol

protocol PasskeyServiceProtocol: Sendable {
    
    // MARK: - Support Check
    
    /// Checks if passkey is supported on this device (Face ID / Touch ID available)
    func isPasskeySupported() -> Bool
    
    // MARK: - Registration
    
    /// Registers a new passkey and encrypts the master key with a device-bound KEK
    /// - Parameters:
    ///   - masterKey: The master key to encrypt
    ///   - name: Optional name for the passkey
    ///   - token: Authentication token
    /// - Returns: The credential ID of the registered passkey
    func registerPasskey(masterKey: Data, name: String?, token: String) async throws -> String
    
    // MARK: - Authentication
    
    /// Authenticates with a passkey and returns the decrypted master key
    /// - Parameter token: Authentication token
    /// - Returns: The decrypted master key
    func authenticateWithPasskey(token: String) async throws -> Data
    
    // MARK: - Passkey Management
    
    /// Checks if user has any passkeys registered on server
    func hasPasskeys(token: String) async throws -> Bool
    
    /// Lists all registered passkeys for the current user
    func listPasskeys(token: String) async throws -> [WebAuthnPasskey]
    
    /// Renames a passkey
    func renamePasskey(credentialId: String, encryptedName: String, nameNonce: String, token: String) async throws
    
    /// Deletes a passkey
    func deletePasskey(credentialId: String, token: String) async throws
    
    /// Checks if this device has a passkey KEK stored locally
    func hasLocalPasskeyKEK() -> Bool
    
    /// Removes the local passkey KEK
    func removeLocalPasskeyKEK() throws
}

// MARK: - Passkey Error

enum PasskeyError: LocalizedError {
    case notSupported
    case cancelled
    case registrationFailed(String)
    case authenticationFailed(String)
    case kekGenerationFailed
    case kekNotFound
    case kekRetrievalFailed
    case serverError(String)
    case invalidResponse
    case biometricRequired
    case prfNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Passkey is not supported on this device"
        case .cancelled:
            return "Authentication was cancelled"
        case .registrationFailed(let message):
            return "Passkey registration failed: \(message)"
        case .authenticationFailed(let message):
            return "Passkey authentication failed: \(message)"
        case .kekGenerationFailed:
            return "Failed to generate encryption key"
        case .kekNotFound:
            return "Passkey key not found. Please set up passkey again."
        case .kekRetrievalFailed:
            return "Failed to retrieve passkey key. Please try again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        case .biometricRequired:
            return "Face ID or Touch ID is required"
        case .prfNotSupported:
            return "Your device does not support PRF extension. Please use a different authentication method."
        }
    }
}
