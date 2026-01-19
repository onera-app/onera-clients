//
//  CryptoError.swift
//  Onera
//
//  Crypto-related errors (no sensitive details exposed)
//

import Foundation

enum CryptoError: LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case shareReconstructionFailed
    case invalidKeyLength
    case invalidNonce
    case keychainOperationFailed
    case mnemonicGenerationFailed
    case mnemonicValidationFailed
    case keyDerivationFailed
    case deviceFingerprintFailed
    case shareXOROperationFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .shareReconstructionFailed:
            return "Failed to reconstruct encryption key"
        case .invalidKeyLength:
            return "Invalid key length"
        case .invalidNonce:
            return "Invalid nonce"
        case .keychainOperationFailed:
            return "Secure storage operation failed"
        case .mnemonicGenerationFailed:
            return "Failed to generate recovery phrase"
        case .mnemonicValidationFailed:
            return "Invalid recovery phrase"
        case .keyDerivationFailed:
            return "Key derivation failed"
        case .deviceFingerprintFailed:
            return "Failed to create device fingerprint"
        case .shareXOROperationFailed:
            return "Key share operation failed"
        }
    }
}

enum AuthError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case signInFailed
    case signUpFailed
    case oauthCallbackFailed
    case sessionExpired
    case deviceRegistrationFailed
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication required"
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .signInFailed:
            return "Sign in failed"
        case .signUpFailed:
            return "Sign up failed"
        case .oauthCallbackFailed:
            return "OAuth authentication failed"
        case .sessionExpired:
            return "Your session has expired"
        case .deviceRegistrationFailed:
            return "Device registration failed"
        case .invalidCredentials:
            return "Invalid credentials"
        }
    }
}

enum APIError: LocalizedError {
    case networkError(underlying: Error)
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingFailed
    case encodingFailed
    case unauthorized
    case notFound
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let statusCode):
            return "Server error (\(statusCode))"
        case .decodingFailed:
            return "Failed to process server response"
        case .encodingFailed:
            return "Failed to prepare request"
        case .unauthorized:
            return "Unauthorized access"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        }
    }
}
