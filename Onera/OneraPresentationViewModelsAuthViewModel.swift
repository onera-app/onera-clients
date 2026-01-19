//
//  AuthViewModel.swift
//  Onera
//
//  Authentication view model
//

import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    
    // MARK: - State
    
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isSignUp = false
    
    private(set) var isLoading = false
    private(set) var error: AuthError?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    // MARK: - Validation
    
    var isEmailValid: Bool {
        email.isValidEmail
    }
    
    var isPasswordValid: Bool {
        password.count >= 8
    }
    
    var doPasswordsMatch: Bool {
        password == confirmPassword
    }
    
    var canSubmit: Bool {
        if isSignUp {
            return isEmailValid && isPasswordValid && doPasswordsMatch && !isLoading
        }
        return isEmailValid && isPasswordValid && !isLoading
    }
    
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
    
    // MARK: - Actions
    
    func submit() async {
        guard canSubmit else { return }
        
        isLoading = true
        error = nil
        
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
            await onSuccess()
        } catch let authError as AuthError {
            self.error = authError
        } catch {
            self.error = .signInFailed(underlying: error)
        }
        
        isLoading = false
    }
    
    func signInWithApple() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signInWithApple()
            await onSuccess()
        } catch let authError as AuthError {
            self.error = authError
        } catch {
            self.error = .oauthFailed(provider: "Apple")
        }
        
        isLoading = false
    }
    
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
    
    func toggleAuthMode() {
        isSignUp.toggle()
        confirmPassword = ""
        error = nil
    }
    
    func clearError() {
        error = nil
    }
}
