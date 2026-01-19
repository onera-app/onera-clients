//
//  AuthenticationManager.swift
//  Onera
//
//  Clerk authentication integration
//
//  IMPORTANT: Add Clerk iOS SDK via SPM: https://github.com/clerk/clerk-ios
//

import Foundation
import SwiftUI
// import ClerkSDK  // Uncomment after adding Clerk package

/// Manages Clerk authentication
@MainActor
@Observable
final class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    // MARK: - State
    
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var currentUser: User?
    private(set) var error: AuthError?
    
    // Clerk session token
    private var sessionToken: String?
    
    private init() {
        // TODO: Initialize Clerk SDK
        // Clerk.configure(publishableKey: Configuration.clerkPublishableKey)
        
        Task {
            await checkExistingSession()
        }
    }
    
    // MARK: - Token Access
    
    /// Gets the current JWT token for API requests
    func getToken() async throws -> String {
        // TODO: Get token from Clerk SDK
        // guard let session = Clerk.shared.session else {
        //     throw AuthError.notAuthenticated
        // }
        // return try await session.getToken()
        
        guard let token = sessionToken else {
            throw AuthError.notAuthenticated
        }
        return token
    }
    
    // MARK: - Sign In
    
    /// Signs in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // TODO: Implement with Clerk SDK
            // let signIn = try await Clerk.shared.signIn.create(
            //     strategy: .password(email: email, password: password)
            // )
            // sessionToken = try await signIn.createdSession?.getToken()
            
            // Placeholder for development
            sessionToken = "dev_token_\(UUID().uuidString)"
            currentUser = User(id: UUID().uuidString, email: email)
            isAuthenticated = true
        } catch {
            self.error = .signInFailed
            throw AuthError.signInFailed
        }
    }
    
    /// Signs in with Apple
    func signInWithApple() async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // TODO: Implement with Clerk SDK
            // let signIn = try await Clerk.shared.signIn.create(
            //     strategy: .oauth(provider: .apple)
            // )
            
            throw AuthError.signInFailed // Placeholder
        } catch {
            self.error = .signInFailed
            throw AuthError.signInFailed
        }
    }
    
    /// Signs in with Google
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // TODO: Implement with Clerk SDK
            // let signIn = try await Clerk.shared.signIn.create(
            //     strategy: .oauth(provider: .google)
            // )
            
            throw AuthError.signInFailed // Placeholder
        } catch {
            self.error = .signInFailed
            throw AuthError.signInFailed
        }
    }
    
    // MARK: - Sign Up
    
    /// Signs up with email and password
    func signUp(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            // TODO: Implement with Clerk SDK
            // let signUp = try await Clerk.shared.signUp.create(
            //     emailAddress: email,
            //     password: password
            // )
            // try await signUp.prepareEmailAddressVerification()
            
            // Placeholder for development
            sessionToken = "dev_token_\(UUID().uuidString)"
            currentUser = User(id: UUID().uuidString, email: email)
            isAuthenticated = true
        } catch {
            self.error = .signUpFailed
            throw AuthError.signUpFailed
        }
    }
    
    // MARK: - Sign Out
    
    /// Signs out the current user
    func signOut() async {
        // TODO: Implement with Clerk SDK
        // try? await Clerk.shared.signOut()
        
        sessionToken = nil
        currentUser = nil
        isAuthenticated = false
        
        // Lock the secure session
        await SecureSession.shared.lock()
        
        // Clear device share if desired (optional - keeping allows faster re-login)
        // KeychainManager.shared.clearAll()
    }
    
    // MARK: - Session Check
    
    private func checkExistingSession() async {
        // TODO: Check for existing Clerk session
        // if let session = Clerk.shared.session {
        //     sessionToken = try? await session.getToken()
        //     currentUser = session.user.map { User(from: $0) }
        //     isAuthenticated = sessionToken != nil
        // }
    }
    
    // MARK: - OAuth Callback Handler
    
    /// Handles OAuth callback URLs
    func handleOAuthCallback(url: URL) async throws {
        // TODO: Implement with Clerk SDK
        // try await Clerk.shared.handleOAuthCallback(url: url)
    }
}

// MARK: - User Model

struct User: Identifiable, Equatable {
    let id: String
    let email: String
    var firstName: String?
    var lastName: String?
    var imageURL: URL?
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        }
        return email
    }
}
