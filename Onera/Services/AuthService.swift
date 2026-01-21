//
//  AuthService.swift
//  Onera
//
//  Clerk authentication service implementation
//

import Foundation
import Observation
import Clerk
import AuthenticationServices

@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    
    // MARK: - State
    
    private(set) var isAuthenticated = false
    private(set) var currentUser: User?
    
    // MARK: - Private
    
    private let networkService: NetworkServiceProtocol
    
    // MARK: - Initialization
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        
        // Check for existing session on init
        Task {
            await updateSessionState()
        }
    }
    
    // MARK: - Token
    
    func getToken() async throws -> String {
        guard let session = Clerk.shared.session else {
            throw AuthError.notAuthenticated
        }
        
        do {
            let token = try await session.getToken()
            guard let jwt = token?.jwt else {
                throw AuthError.tokenRefreshFailed
            }
            return jwt
        } catch {
            throw AuthError.tokenRefreshFailed
        }
    }
    
    // MARK: - OAuth Sign In
    
    func signInWithApple() async throws {
        // Apple native sign-in is triggered from the view with SignInWithAppleButton
        // The view calls authenticateWithApple(idToken:) after getting the credential
        throw AuthError.oauthFailed(provider: "Apple")
    }
    
    /// Authenticate with Apple using the ID token from ASAuthorizationAppleIDCredential
    func authenticateWithApple(idToken: String) async throws {
        do {
            let result = try await SignIn.authenticateWithIdToken(
                provider: .apple,
                idToken: idToken
            )
            
            try await handleTransferFlowResult(result, provider: "Apple")
        } catch let authError as AuthError {
            throw authError
        } catch {
            throw AuthError.oauthFailed(provider: "Apple")
        }
    }
    
    func signInWithGoogle() async throws {
        // Check if user is already signed in with a valid session
        if let session = Clerk.shared.session {
            // Verify the session is actually valid by attempting to get a token
            do {
                _ = try await session.getToken()
                await updateSessionState()
                return
            } catch {
                // Session exists but token is invalid - sign out and proceed with fresh sign-in
                try? await Clerk.shared.signOut()
            }
        }
        
        do {
            // This starts the OAuth redirect flow
            // The actual authentication completes when the app receives the callback
            let result = try await SignIn.authenticateWithRedirect(
                strategy: .oauth(provider: .google)
            )
            
            // If we get here, the OAuth completed (user came back from browser)
            try await handleTransferFlowResult(result, provider: "Google")
        } catch let authError as AuthError {
            throw authError
        } catch {
            print("[AuthService] Google sign-in error: \(error)")
            print("[AuthService] Error type: \(type(of: error))")
            if let clerkError = error as? ClerkClientError {
                print("[AuthService] Clerk error: \(clerkError)")
            }
            throw AuthError.oauthFailed(provider: "Google")
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await Clerk.shared.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
        
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - OAuth Callback
    
    func handleOAuthCallback(url: URL) async throws {
        // Clerk SDK handles OAuth callbacks automatically
        // Wait a moment for session to be established
        try await Task.sleep(for: .milliseconds(1000))
        await updateSessionState()
        
        if !isAuthenticated {
            throw AuthError.oauthFailed(provider: "OAuth")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleTransferFlowResult(_ result: TransferFlowResult, provider: String) async throws {
        switch result {
        case .signIn(let signIn):
            if signIn.status == .complete {
                await updateSessionState()
                if !isAuthenticated {
                    throw AuthError.oauthFailed(provider: provider)
                }
            } else {
                throw AuthError.oauthFailed(provider: provider)
            }
        case .signUp(let signUp):
            if signUp.status == .complete {
                await updateSessionState()
                if !isAuthenticated {
                    throw AuthError.oauthFailed(provider: provider)
                }
            } else {
                throw AuthError.oauthFailed(provider: provider)
            }
        }
    }
    
    private func updateSessionState() async {
        if let session = Clerk.shared.session,
           let clerkUser = session.user {
            // Map Clerk's User to our app's User model
            currentUser = User(
                id: clerkUser.id,
                email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                imageURL: URL(string: clerkUser.imageUrl ?? ""),
                createdAt: clerkUser.createdAt ?? Date()
            )
            isAuthenticated = true
        } else {
            currentUser = nil
            isAuthenticated = false
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockAuthService: AuthServiceProtocol {
    
    var isAuthenticated = false
    var currentUser: User?
    var shouldFail = false
    var mockToken = "mock_token"
    
    func getToken() async throws -> String {
        if shouldFail { throw AuthError.notAuthenticated }
        return mockToken
    }
    
    func signInWithApple() async throws {
        if shouldFail { throw AuthError.oauthFailed(provider: "Apple") }
        // Simulate delay
        try await Task.sleep(for: .milliseconds(500))
        currentUser = .mock()
        isAuthenticated = true
    }
    
    func signInWithGoogle() async throws {
        if shouldFail { throw AuthError.oauthFailed(provider: "Google") }
        // Simulate delay
        try await Task.sleep(for: .milliseconds(500))
        currentUser = .mock()
        isAuthenticated = true
    }
    
    func signOut() async {
        currentUser = nil
        isAuthenticated = false
    }
    
    func handleOAuthCallback(url: URL) async throws {}
}
#endif
