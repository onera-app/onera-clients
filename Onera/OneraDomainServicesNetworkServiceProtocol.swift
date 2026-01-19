//
//  NetworkServiceProtocol.swift
//  Onera
//
//  Protocol for network operations
//

import Foundation

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol: Sendable {
    
    /// Makes a tRPC procedure call
    func call<Input: Encodable & Sendable, Output: Decodable & Sendable>(
        procedure: String,
        input: Input,
        token: String?
    ) async throws -> Output
    
    /// Makes a tRPC procedure call with no input
    func call<Output: Decodable & Sendable>(
        procedure: String,
        token: String?
    ) async throws -> Output
}

// MARK: - API Endpoints

enum APIEndpoint {
    
    // MARK: - Key Shares
    
    enum KeyShares {
        static let check = "keyShares.check"
        static let get = "keyShares.get"
        static let create = "keyShares.create"
    }
    
    // MARK: - Devices
    
    enum Devices {
        static let register = "devices.register"
        static let getSecret = "devices.getDeviceSecret"
    }
    
    // MARK: - Chats
    
    enum Chats {
        static let list = "chats.list"
        static let get = "chats.get"
        static let create = "chats.create"
        static let update = "chats.update"
        static let delete = "chats.delete"
    }
}
