//
//  AuthenticationView.swift
//  Onera
//
//  Sign in / Sign up UI
//

import SwiftUI

struct AuthenticationView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    
                    Text("Onera")
                        .font(.largeTitle.bold())
                    
                    Text("End-to-End Encrypted Chat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 48)
                
                Spacer()
                
                // Auth form
                VStack(spacing: 16) {
                    // Email field
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Confirm password (sign up only)
                    if isSignUp {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Submit button
                    Button {
                        Task {
                            await authenticate()
                        }
                    } label: {
                        if authManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(authManager.isLoading || !isFormValid)
                }
                .padding(.horizontal)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                    
                    Text("or continue with")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
                .padding(.horizontal)
                
                // OAuth buttons
                HStack(spacing: 16) {
                    Button {
                        Task {
                            try? await authManager.signInWithApple()
                        }
                    } label: {
                        Label("Apple", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        Task {
                            try? await authManager.signInWithGoogle()
                        }
                    } label: {
                        Label("Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Toggle sign in / sign up
                Button {
                    withAnimation {
                        isSignUp.toggle()
                        confirmPassword = ""
                    }
                } label: {
                    if isSignUp {
                        Text("Already have an account? **Sign In**")
                    } else {
                        Text("Don't have an account? **Sign Up**")
                    }
                }
                .font(.callout)
                .padding(.bottom, 24)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 8
        
        if isSignUp {
            return emailValid && passwordValid && password == confirmPassword
        }
        
        return emailValid && passwordValid
    }
    
    private func authenticate() async {
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AuthenticationView()
}
