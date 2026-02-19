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
    
    /// Whether the auth service has completed its initial session check
    var isReady: Bool { get }
    
    // MARK: - Token
    
    /// Gets the current JWT token for API requests
    func getToken() async throws -> String
    
    // MARK: - OAuth Sign In
    
    /// Signs in with Apple using the ID token from ASAuthorizationAppleIDCredential
    /// - Parameters:
    ///   - firstName: Only provided by Apple on first authorization
    ///   - lastName: Only provided by Apple on first authorization
    func authenticateWithApple(idToken: String, nonce: String, firstName: String?, lastName: String?) async throws
    
    /// Signs in with Google
    func signInWithGoogle() async throws
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    func signOut() async
    
    // MARK: - OAuth Callback
    
    /// Handles OAuth callback URL
    func handleOAuthCallback(url: URL) async throws
}
