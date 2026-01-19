//
//  AuthenticationView.swift
//  Onera
//
//  Sign in / Sign up view
//

import SwiftUI

struct AuthenticationView: View {
    
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password, confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerView
                    formView
                    dividerView
                    oauthButtonsView
                    toggleModeButton
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
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
        .padding(.top, 32)
    }
    
    private var formView: some View {
        VStack(spacing: 16) {
            // Email
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Password
            SecureField("Password", text: $viewModel.password)
                .textContentType(viewModel.isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(viewModel.isSignUp ? .next : .go)
                .onSubmit {
                    if viewModel.isSignUp {
                        focusedField = .confirmPassword
                    } else {
                        Task { await viewModel.submit() }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Confirm Password (Sign Up only)
            if viewModel.isSignUp {
                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit { Task { await viewModel.submit() } }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Submit Button
            Button {
                Task { await viewModel.submit() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSubmit)
        }
    }
    
    private var dividerView: some View {
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
    }
    
    private var oauthButtonsView: some View {
        HStack(spacing: 16) {
            Button {
                Task { await viewModel.signInWithApple() }
            } label: {
                Label("Apple", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            
            Button {
                Task { await viewModel.signInWithGoogle() }
            } label: {
                Label("Google", systemImage: "g.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
        }
    }
    
    private var toggleModeButton: some View {
        Button {
            withAnimation { viewModel.toggleAuthMode() }
        } label: {
            if viewModel.isSignUp {
                Text("Already have an account? **Sign In**")
            } else {
                Text("Don't have an account? **Sign Up**")
            }
        }
        .font(.callout)
        .padding(.top)
    }
}

#Preview("Sign In") {
    AuthenticationView(
        viewModel: AuthViewModel(
            authService: MockAuthService(),
            onSuccess: {}
        )
    )
}

#Preview("Sign Up") {
    let viewModel = AuthViewModel(
        authService: MockAuthService(),
        onSuccess: {}
    )
    viewModel.isSignUp = true
    return AuthenticationView(viewModel: viewModel)
}
