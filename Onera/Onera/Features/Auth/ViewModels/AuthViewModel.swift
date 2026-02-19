//
//  AuthViewModel.swift
//  Onera
//
//  Authentication view model - OAuth only
//

import Foundation
import Observation
import AuthenticationServices
import CryptoKit

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
    
    /// Nonce for Apple Sign In
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
        // Generate raw nonce and send SHA-256 hash to Apple
        // The raw nonce is later sent to Supabase for verification
        appleNonce = UUID().uuidString
        request.nonce = sha256(_ : appleNonce)
    }
    
    /// SHA-256 hash a string and return hex-encoded result
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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
            
            // Apple only provides fullName on first authorization — capture it now
            let fullName = credential.fullName
            let firstName = fullName?.givenName
            let lastName = fullName?.familyName
            
            // Authenticate with Supabase using the Apple ID token and raw nonce
            try await authService.authenticateWithApple(
                idToken: idToken,
                nonce: appleNonce,
                firstName: firstName,
                lastName: lastName
            )
            
            await onSuccess()
        } catch let authError as AuthError {
            self.error = authError
        } catch let asError as ASAuthorizationError where asError.code == .canceled {
            self.error = .oauthCancelled(provider: "Apple")
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
