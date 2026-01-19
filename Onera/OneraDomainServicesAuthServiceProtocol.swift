//
//  AuthServiceProtocol.swift
//  Onera
//
//  Protocol for authentication operations
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
    
    // MARK: - Sign In
    
    /// Signs in with email and password
    func signIn(email: String, password: String) async throws
    
    /// Signs in with Apple
    func signInWithApple() async throws
    
    /// Signs in with Google
    func signInWithGoogle() async throws
    
    // MARK: - Sign Up
    
    /// Signs up with email and password
    func signUp(email: String, password: String) async throws
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    func signOut() async
    
    // MARK: - OAuth
    
    /// Handles OAuth callback URL
    func handleOAuthCallback(url: URL) async throws
}
