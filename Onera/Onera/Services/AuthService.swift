//
//  AuthService.swift
//  Onera
//
//  Supabase authentication service implementation
//

import Foundation
import Observation
import Supabase
import Auth
import AuthenticationServices

@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    
    // MARK: - State
    
    private(set) var isAuthenticated = false
    private(set) var currentUser: User?
    private(set) var isReady = false
    
    // MARK: - Private
    
    private let networkService: NetworkServiceProtocol
    private nonisolated(unsafe) var authStateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        
        // Listen for auth state changes from Supabase
        authStateTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                
                let wasAuthenticated = self.isAuthenticated
                
                if let session {
                    self.currentUser = Self.mapUser(from: session)
                    self.isAuthenticated = true
                } else {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
                
                // Mark ready after the initial event
                if !self.isReady {
                    self.isReady = true
                }
                
                print("[AuthService] Auth state change: \(event), authenticated: \(self.isAuthenticated)")
                
                // Sync auth state to Apple Watch when authentication changes
                #if os(iOS)
                if wasAuthenticated != self.isAuthenticated {
                    await iOSWatchConnectivityManager.shared.syncToWatch()
                }
                #endif
            }
        }
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Token
    
    func getToken() async throws -> String {
        guard let session = try? await supabase.auth.session else {
            print("[AuthService] No Supabase session found")
            throw AuthError.notAuthenticated
        }
        
        let token = session.accessToken
        let tokenPrefix = String(token.prefix(50))
        print("[AuthService] Token obtained: \(tokenPrefix)...")
        print("[AuthService] Token length: \(token.count)")
        
        return token
    }
    
    // MARK: - OAuth Sign In
    
    /// Authenticate with Apple using the ID token from ASAuthorizationAppleIDCredential
    func authenticateWithApple(idToken: String, nonce: String, firstName: String?, lastName: String?) async throws {
        do {
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            
            // Session update will come through authStateChanges
            // Wait for the state to propagate
            try await waitForAuthentication()
            
            // Apple only provides the user's name on first sign-in.
            // Persist it to Supabase user metadata so it's available on future sessions.
            if let firstName, !firstName.isEmpty {
                var metadata: [String: AnyJSON] = [
                    "first_name": .string(firstName)
                ]
                if let lastName, !lastName.isEmpty {
                    metadata["last_name"] = .string(lastName)
                }
                try? await supabase.auth.update(user: UserAttributes(data: metadata))
            }
        } catch let authError as AuthError {
            throw authError
        } catch {
            print("[AuthService] Apple sign-in error: \(error)")
            throw AuthError.oauthFailed(provider: "Apple")
        }
    }
    
    func signInWithGoogle() async throws {
        // Check if user already has a valid session
        if let session = try? await supabase.auth.session {
            // Session exists and is valid (Supabase auto-refreshes)
            if !session.isExpired {
                await updateSessionState()
                return
            }
        }
        
        do {
            print("[AuthService] Starting Google OAuth flow...")
            
            // Use the app's bundle identifier as the redirect URL scheme
            let bundleId = Bundle.main.bundleIdentifier ?? "chat.onera.staging"
            let redirectURL = URL(string: "\(bundleId)://auth/callback")!
            
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: redirectURL
            )
            
            print("[AuthService] Google OAuth flow completed")
            
            // Wait for auth state change to propagate
            try? await waitForAuthentication(timeout: .seconds(10))
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
            try await supabase.auth.signOut()
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
        // Supabase SDK processes the callback URL and exchanges the code for a session
        try await supabase.auth.handle(url)
        
        // Wait for authStateChanges to propagate
        try await waitForAuthentication(timeout: .seconds(10))
    }
    
    // MARK: - Private Methods
    
    /// Polls for authentication state with exponential backoff instead of a fixed sleep.
    /// Returns once authenticated or throws after timeout.
    private func waitForAuthentication(timeout: Duration = .seconds(5)) async throws {
        let start = ContinuousClock.now
        var delay: Duration = .milliseconds(100)
        
        while ContinuousClock.now - start < timeout {
            if isAuthenticated { return }
            try await Task.sleep(for: delay)
            // Exponential backoff: 100ms, 200ms, 400ms, 800ms...
            delay = min(delay * 2, .seconds(1))
        }
        
        if !isAuthenticated {
            throw AuthError.oauthFailed(provider: "Apple")
        }
    }
    
    private func updateSessionState() async {
        let wasAuthenticated = isAuthenticated
        
        if let session = try? await supabase.auth.session {
            currentUser = Self.mapUser(from: session)
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
    
    /// Map a Supabase session to our app's User model
    private static func mapUser(from session: Session) -> User {
        let supaUser = session.user
        let metadata = supaUser.userMetadata
        
        let email = supaUser.email ?? ""
        let firstName = metadata["first_name"]?.stringValue
            ?? metadata["name"]?.stringValue?.components(separatedBy: " ").first
        let lastName = metadata["last_name"]?.stringValue
            ?? metadata["name"]?.stringValue?.components(separatedBy: " ").dropFirst().joined(separator: " ")
        
        let imageURLString = metadata["avatar_url"]?.stringValue
            ?? metadata["picture"]?.stringValue
        
        return User(
            id: supaUser.id.uuidString,
            email: email,
            firstName: firstName,
            lastName: lastName?.isEmpty == true ? nil : lastName,
            imageURL: imageURLString.flatMap { URL(string: $0) },
            createdAt: supaUser.createdAt
        )
    }
}

// MARK: - AnyJSON String Helper

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockAuthService: AuthServiceProtocol {
    
    var isAuthenticated = false
    var currentUser: User?
    var isReady = true
    var shouldFail = false
    var mockToken = "mock_token"
    
    func getToken() async throws -> String {
        if shouldFail { throw AuthError.notAuthenticated }
        return mockToken
    }
    
    func authenticateWithApple(idToken: String, nonce: String, firstName: String?, lastName: String?) async throws {
        if shouldFail { throw AuthError.oauthFailed(provider: "Apple") }
        try await Task.sleep(for: .milliseconds(500))
        currentUser = .mock()
        isAuthenticated = true
    }
    
    func signInWithGoogle() async throws {
        if shouldFail { throw AuthError.oauthFailed(provider: "Google") }
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
