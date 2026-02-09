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
            print("[AuthService] No Clerk session found")
            throw AuthError.notAuthenticated
        }
        
        print("[AuthService] Session found, user ID: \(session.user?.id ?? "nil")")
        
        do {
            let token = try await session.getToken()
            guard let jwt = token?.jwt else {
                print("[AuthService] Token object returned but JWT is nil")
                throw AuthError.tokenRefreshFailed
            }
            
            // Debug: Print token prefix (first 50 chars) to verify format
            let tokenPrefix = String(jwt.prefix(50))
            print("[AuthService] Token obtained: \(tokenPrefix)...")
            print("[AuthService] Token length: \(jwt.count)")
            
            return jwt
        } catch {
            print("[AuthService] getToken error: \(error)")
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
            print("[AuthService] Starting Google OAuth redirect flow...")
            // This starts the OAuth redirect flow
            // The actual authentication completes when the app receives the callback
            let result = try await SignIn.authenticateWithRedirect(
                strategy: .oauth(provider: .google)
            )
            
            print("[AuthService] OAuth redirect completed, handling result...")
            // If we get here, the OAuth completed (user came back from browser)
            try await handleTransferFlowResult(result, provider: "Google")
        } catch let authError as AuthError {
            print("[AuthService] AuthError: \(authError)")
            throw authError
        } catch {
            print("[AuthService] Google sign-in error: \(error)")
            
            // Detect user cancellation from ASWebAuthenticationSession (error code 1)
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
                && nsError.code == 1 {
                throw AuthError.oauthCancelled(provider: "Google")
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
        
        // Sync sign-out state to Apple Watch
        #if os(iOS)
        await iOSWatchConnectivityManager.shared.syncToWatch()
        #endif
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
        let wasAuthenticated = isAuthenticated
        
        if let session = Clerk.shared.session,
           let clerkUser = session.user {
            // Map Clerk's User to our app's User model
            currentUser = User(
                id: clerkUser.id,
                email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                imageURL: URL(string: clerkUser.imageUrl),
                createdAt: clerkUser.createdAt
            )
            isAuthenticated = true
        } else {
            currentUser = nil
            isAuthenticated = false
        }
        
        // Sync auth state to Apple Watch when authentication changes
        #if os(iOS)
        if wasAuthenticated != isAuthenticated {
            await iOSWatchConnectivityManager.shared.syncToWatch()
        }
        #endif
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
