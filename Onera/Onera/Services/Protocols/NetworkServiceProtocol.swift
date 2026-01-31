//
//  NetworkServiceProtocol.swift
//  Onera
//
//  Protocol for network operations
//

import Foundation

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol: Sendable {
    
    /// Makes a tRPC mutation call (POST with input)
    func call<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output
    
    /// Makes a tRPC query call with no input (GET)
    func call<Output: Decodable>(
        procedure: String,
        token: String?
    ) async throws -> Output
    
    /// Makes a tRPC query call with input (GET with query params)
    func query<Input: Encodable, Output: Decodable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output
}

// MARK: - API Endpoints

enum APIEndpoint {
    
    // MARK: - Key Shares (Queries use GET, Mutations use POST)
    
    enum KeyShares {
        // Queries (GET)
        static let check = "keyShares.check"
        static let get = "keyShares.get"
        static let hasPasswordEncryption = "keyShares.hasPasswordEncryption"
        static let getPasswordEncryption = "keyShares.getPasswordEncryption"
        
        // Mutations (POST)
        static let create = "keyShares.create"
        static let updateAuthShare = "keyShares.updateAuthShare"
        static let updateRecoveryShare = "keyShares.updateRecoveryShare"
        static let setPasswordEncryption = "keyShares.setPasswordEncryption"
        static let removePasswordEncryption = "keyShares.removePasswordEncryption"
        static let delete = "keyShares.delete"
    }
    
    // MARK: - Devices (Queries use GET, Mutations use POST)
    
    enum Devices {
        // Queries (GET)
        static let list = "devices.list"
        static let getSecret = "devices.getDeviceSecret"
        
        // Mutations (POST)
        static let register = "devices.register"
        static let updateLastSeen = "devices.updateLastSeen"
        static let revoke = "devices.revoke"
        static let delete = "devices.delete"
    }
    
    // MARK: - Chats
    
    enum Chats {
        // Queries (GET)
        static let list = "chats.list"
        static let get = "chats.get"
        
        // Mutations (POST)
        static let create = "chats.create"
        static let update = "chats.update"
        static let delete = "chats.remove"
    }
    
    // MARK: - Credentials
    
    enum Credentials {
        // Queries (GET)
        static let list = "credentials.list"
        
        // Mutations (POST)
        static let create = "credentials.create"
        static let update = "credentials.update"
        static let remove = "credentials.remove"
    }
    
    // MARK: - Notes
    
    enum Notes {
        // Queries (GET)
        static let list = "notes.list"
        static let get = "notes.get"
        
        // Mutations (POST)
        static let create = "notes.create"
        static let update = "notes.update"
        static let delete = "notes.remove"
    }
    
    // MARK: - Folders
    
    enum Folders {
        // Queries (GET)
        static let list = "folders.list"
        static let get = "folders.get"
        
        // Mutations (POST)
        static let create = "folders.create"
        static let update = "folders.update"
        static let delete = "folders.remove"
    }
    
    // MARK: - Prompts
    
    enum Prompts {
        // Queries (GET)
        static let list = "prompts.list"
        static let get = "prompts.get"
        
        // Mutations (POST)
        static let create = "prompts.create"
        static let update = "prompts.update"
        static let delete = "prompts.remove"
    }
    
    // MARK: - WebAuthn (Passkeys)
    
    enum WebAuthn {
        // Queries (GET)
        static let hasPasskeys = "webauthn.hasPasskeys"
        static let list = "webauthn.list"
        
        // Mutations (POST)
        static let generateRegistrationOptions = "webauthn.generateRegistrationOptions"
        static let verifyRegistration = "webauthn.verifyRegistration"
        static let generateAuthenticationOptions = "webauthn.generateAuthenticationOptions"
        static let verifyAuthentication = "webauthn.verifyAuthentication"
        static let rename = "webauthn.rename"
        static let delete = "webauthn.delete"
    }
}
