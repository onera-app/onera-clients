//
//  Errors.swift
//  Onera
//
//  Domain-specific error types
//

import Foundation

// MARK: - Authentication Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case tokenRefreshFailed
    case signInFailed(underlying: Error? = nil)
    case signUpFailed(underlying: Error? = nil)
    case oauthFailed(provider: String)
    case invalidCredentials
    case accountNotFound
    case emailNotVerified
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in"
        case .tokenExpired:
            return "Your session has expired"
        case .tokenRefreshFailed:
            return "Failed to refresh session"
        case .signInFailed:
            return "Sign in failed. Please try again."
        case .signUpFailed:
            return "Sign up failed. Please try again."
        case .oauthFailed(let provider):
            return "Failed to sign in with \(provider)"
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountNotFound:
            return "Account not found"
        case .emailNotVerified:
            return "Please verify your email address"
        }
    }
}

// MARK: - Cryptographic Errors

enum CryptoError: LocalizedError {
    case randomGenerationFailed
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKeyLength(expected: Int, actual: Int)
    case invalidNonceLength
    case shareReconstructionFailed
    case xorOperationFailed
    case mnemonicGenerationFailed
    case mnemonicValidationFailed
    case keypairGenerationFailed
    case passwordDerivationFailed
    case incorrectPassword
    
    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed:
            return "Failed to generate secure random data"
        case .keyDerivationFailed:
            return "Key derivation failed"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .invalidKeyLength:
            return "Invalid key length"
        case .invalidNonceLength:
            return "Invalid nonce length"
        case .shareReconstructionFailed:
            return "Failed to reconstruct encryption key"
        case .xorOperationFailed:
            return "Key share operation failed"
        case .mnemonicGenerationFailed:
            return "Failed to generate recovery phrase"
        case .mnemonicValidationFailed:
            return "Invalid recovery phrase"
        case .keypairGenerationFailed:
            return "Failed to generate key pair"
        case .passwordDerivationFailed:
            return "Failed to derive key from password"
        case .incorrectPassword:
            return "Incorrect password"
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case readFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case itemNotFound
    case unexpectedData
    case accessControlFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save to secure storage"
        case .readFailed:
            return "Failed to read from secure storage"
        case .deleteFailed:
            return "Failed to delete from secure storage"
        case .itemNotFound:
            return "Item not found in secure storage"
        case .unexpectedData:
            return "Unexpected data format in secure storage"
        case .accessControlFailed:
            return "Access control configuration failed"
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case noConnection
    case timeout
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL"
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let message):
            return message ?? "HTTP error \(code)"
        case .decodingFailed:
            return "Failed to process response"
        case .encodingFailed:
            return "Failed to prepare request"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError(let code):
            return "Server error (\(code))"
        case .cancelled:
            return "Request was cancelled"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited:
            return true
        default:
            return false
        }
    }
}

// MARK: - E2EE Errors

enum E2EEError: LocalizedError {
    case notSetup
    case setupFailed(underlying: Error)
    case unlockFailed
    case deviceShareNotFound
    case deviceRegistrationFailed
    case keySharesFetchFailed
    case recoveryRequired
    case sessionLocked
    case passwordNotSetup
    case passwordSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .notSetup:
            return "End-to-end encryption not set up"
        case .setupFailed:
            return "Failed to set up encryption"
        case .unlockFailed:
            return "Failed to unlock encryption"
        case .deviceShareNotFound:
            return "Device credentials not found"
        case .deviceRegistrationFailed:
            return "Device registration failed"
        case .keySharesFetchFailed:
            return "Failed to fetch encryption keys"
        case .recoveryRequired:
            return "Recovery phrase required"
        case .sessionLocked:
            return "Session is locked"
        case .passwordNotSetup:
            return "Password encryption not set up for this account"
        case .passwordSetupFailed:
            return "Failed to set up password encryption"
        }
    }
}

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case chatNotFound
    case createFailed
    case updateFailed
    case deleteFailed
    case encryptionFailed
    case decryptionFailed
    case invalidChatKey
    case missingEncryptionKey
    case streamingFailed(underlying: Error?)
    
    var errorDescription: String? {
        switch self {
        case .chatNotFound:
            return "Chat not found"
        case .createFailed:
            return "Failed to create chat"
        case .updateFailed:
            return "Failed to update chat"
        case .deleteFailed:
            return "Failed to delete chat"
        case .encryptionFailed:
            return "Failed to encrypt message"
        case .decryptionFailed:
            return "Failed to decrypt message"
        case .invalidChatKey:
            return "Invalid chat encryption key"
        case .missingEncryptionKey:
            return "Chat encryption key not found"
        case .streamingFailed:
            return "Failed to stream response"
        }
    }
}
