//
//  AuthViewModel.swift
//  Onera
//
//  Authentication view model - OAuth only
//

import Foundation
import Observation
import AuthenticationServices

@MainActor
@Observable
final class AuthViewModel {
    
    // MARK: - State
    
    private(set) var isLoading = false
    private(set) var error: AuthError?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    /// Nonce for Apple Sign In (required by Clerk)
    private(set) var appleNonce: String = UUID().uuidString
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let onSuccess: () async -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        onSuccess: @escaping () async -> Void
    ) {
        self.authService = authService
        self.onSuccess = onSuccess
    }
    
    // MARK: - Apple Sign In
    
    /// Configure the Apple Sign In request
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.email, .fullName]
        appleNonce = UUID().uuidString
        request.nonce = appleNonce
    }
    
    /// Handle Apple Sign In completion
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil
        
        do {
            let authorization = try result.get()
            
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.oauthFailed(provider: "Apple")
            }
            
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw AuthError.oauthFailed(provider: "Apple")
            }
            
            // Authenticate with Clerk using the Apple ID token
            if let service = authService as? AuthService {
                try await service.authenticateWithApple(idToken: idToken)
            } else {
                // Mock service fallback for previews
                try await authService.signInWithApple()
            }
            
            await onSuccess()
        } catch let authError as AuthError {
            self.error = authError
        } catch {
            self.error = .oauthFailed(provider: "Apple")
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signInWithGoogle()
            await onSuccess()
        } catch let authError as AuthError {
            self.error = authError
        } catch {
            self.error = .oauthFailed(provider: "Google")
        }
        
        isLoading = false
    }
    
    func clearError() {
        error = nil
    }
}
