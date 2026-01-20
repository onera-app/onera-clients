//
//  AuthServiceProtocol.swift
//  Onera
//
//  Protocol for OAuth authentication operations
//

import Foundation

// MARK: - Auth Service Protocol

@MainActor
protocol AuthServiceProtocol: Sendable {
    
    // MARK: - State
    
    var isAuthenticated: Bool { get }
    var currentUser: User? { get }
    
    // MARK: - Token
    
    /// Gets the current JWT token for API requests
    func getToken() async throws -> String
    
    // MARK: - OAuth Sign In
    
    /// Signs in with Apple
    func signInWithApple() async throws
    
    /// Signs in with Google
    func signInWithGoogle() async throws
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    func signOut() async
    
    // MARK: - OAuth Callback
    
    /// Handles OAuth callback URL
    func handleOAuthCallback(url: URL) async throws
}
