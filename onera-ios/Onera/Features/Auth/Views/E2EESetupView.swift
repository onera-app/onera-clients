//
//  E2EESetupView.swift
//  Onera
//
//  E2EE setup with recovery phrase display and optional password/passkey setup
//  Native iOS design following Human Interface Guidelines
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct E2EESetupView: View {
    
    @Bindable var viewModel: E2EESetupViewModel
    @FocusState private var passwordFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// Callback for signing out
    var onSignOut: (() -> Void)?
    
    @State private var showingSignOutConfirmation = false
    
    /// iPad uses constrained width
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    /// Max width for content on iPad
    private let iPadMaxWidth: CGFloat = 500
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                    
                case .unlockMethodOptions:
                    unlockMethodOptionsView
                    
                case .settingPasskey:
                    passkeySetupView
                    
                case .settingPassword:
                    passwordSetupView
                    
                case .showingPhrase(let phrase):
                    recoveryPhraseView(phrase: phrase)
                    
                case .confirmPhrase:
                    confirmPhraseView
                    
                case .error(let message):
                    errorView(message: message)
                }
            }
            // iPad: Constrain content width and center
            .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
            .frame(maxWidth: .infinity)
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .interactiveDismissDisabled()
        .task {
            await viewModel.startSetup()
        }
        .alert("Error", isPresented: $viewModel.showPasswordError) {
            Button("OK") { viewModel.clearPasswordError() }
        } message: {
            if let error = viewModel.passwordError {
                Text(error)
            }
        }
        .alert("Error", isPresented: $viewModel.showPasskeyError) {
            Button("OK") { viewModel.clearPasskeyError() }
        } message: {
            if let error = viewModel.passkeyError {
                Text("Passkey authentication failed: \(error)")
            }
        }
    }
    
    private var navigationTitle: String {
        switch viewModel.state {
        case .loading:
            return "Setting Up"
        case .unlockMethodOptions, .settingPasskey, .settingPassword:
            return "Quick Unlock"
        case .showingPhrase, .confirmPhrase:
            return "Recovery Phrase"
        case .error:
            return "Error"
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 8)
            
            VStack(spacing: 8) {
                Text("Setting up encryption...")
                    .font(.headline)
                
                Text("Generating secure keys for your account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Unlock Method Options
    
    private var unlockMethodOptionsView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    
                    Text("Choose how you want to unlock your encrypted data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0))
            }
            
            Section {
                if viewModel.passkeySupported {
                    Button {
                        viewModel.selectPasskeySetup()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Passkey")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.primary)
                                    Text("Recommended")
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.green)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                Text("Use Face ID or Touch ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Button {
                    viewModel.selectPasswordSetup()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Password")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.primary)
                            Text("Works on any device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Unlock Method")
            }
            
            Section {
                Button("Skip for now") {
                    viewModel.skipPasswordSetup()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } footer: {
                Text("You can always set this up later in Settings. Your recovery phrase will still be shown.")
            }
            
            // Sign out section
            if onSignOut != nil {
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign Out")
                                    .font(.body.weight(.medium))
                                Text("Use a different account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account")
                }
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                onSignOut?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Passkey Setup
    
    private var passkeySetupView: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Add a Passkey")
                            .font(.title2.bold())
                        
                        Text("The easiest and most secure way to unlock your data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                Label {
                    Text("Unlock with Face ID or Touch ID")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "faceid")
                        .foregroundStyle(.blue)
                }
                
                Label {
                    Text("Phishing resistant")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.green)
                }
                
                Label {
                    Text("Stays on your device")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundStyle(.purple)
                }
            } header: {
                Text("Benefits")
            }
            
            Section {
                Button {
                    Task { await viewModel.setupPasskey() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSettingUpPasskey {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Creating...")
                        } else {
                            Text("Create Passkey")
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isSettingUpPasskey)
            }
            
            Section {
                Button("Skip for now") {
                    viewModel.skipPasswordSetup()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.secondary)
                .disabled(viewModel.isSettingUpPasskey)
            } footer: {
                Text("You can add a passkey later in Settings.")
            }
        }
        .toolbar {
            if !viewModel.passkeySupported {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        viewModel.backToOptions()
                    }
                    .disabled(viewModel.isSettingUpPasskey)
                }
            }
        }
    }
    
    // MARK: - Password Setup
    
    private var passwordSetupView: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Set Password")
                            .font(.title2.bold())
                        
                        Text("This password unlocks your encrypted data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                HStack {
                    if viewModel.showPassword {
                        TextField("Password", text: $viewModel.password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                    }
                    
                    Button {
                        viewModel.togglePasswordVisibility()
                    } label: {
                        Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .focused($passwordFieldFocused)
                
                if viewModel.showPassword {
                    TextField("Confirm Password", text: $viewModel.confirmPassword)
                } else {
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                }
            } header: {
                Text("Password")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if !viewModel.passwordLengthValid {
                        Label("At least 8 characters required", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    if !viewModel.passwordsMatch {
                        Label("Passwords do not match", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            
            Section {
                Button {
                    Task { await viewModel.setupPassword() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSettingUpPassword {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Setting up...")
                        } else {
                            Text("Set Password")
                        }
                        Spacer()
                    }
                }
                .disabled(!viewModel.canSetupPassword)
            }
        }
        .onAppear {
            passwordFieldFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    viewModel.backToOptions()
                }
            }
        }
    }
    
    // MARK: - Recovery Phrase View
    
    private func recoveryPhraseView(phrase: String) -> some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "lock.doc.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Recovery Phrase")
                            .font(.title2.bold())
                        
                        Text("Save these 24 words as backup. You'll need them if you lose access to your passkey or password.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                RecoveryPhraseGrid(phrase: phrase)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            } header: {
                HStack {
                    Text("Your Recovery Phrase")
                    Spacer()
                    Button {
                        copyToClipboard(phrase)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                }
            } footer: {
                Label("This phrase will be automatically cleared from clipboard after 60 seconds.", systemImage: "info.circle")
                    .font(.caption)
            }
            
            Section {
                Label {
                    Text("Copy to your password manager")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "key.viewfinder")
                        .foregroundStyle(.blue)
                }
                
                Label {
                    Text("Write it down and keep it safe")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Quick Save Options")
            }
            
            Section {
                Button("I've Saved My Recovery Phrase") {
                    viewModel.proceedAfterRecoveryPhrase()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Sign out section
            if onSignOut != nil {
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundStyle(.red)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign Out")
                                    .font(.body.weight(.medium))
                                Text("Use a different account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account")
                }
            }
        }
    }
    
    // MARK: - Confirm Phrase View
    
    private var confirmPhraseView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            
            VStack(spacing: 12) {
                Text("Recovery Phrase Saved")
                    .font(.title2.bold())
                
                Text("Great! Your recovery phrase has been saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Continue") {
                viewModel.proceedToUnlockMethod()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Setup Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Helpers
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if UIPasteboard.general.string == text {
                UIPasteboard.general.string = ""
            }
        }
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            // Auto-clear on macOS not possible without reading back
        }
        #endif
    }
}

// MARK: - Recovery Phrase Grid

struct RecoveryPhraseGrid: View {
    let phrase: String
    
    private var words: [String] {
        phrase.split(separator: " ").map(String.init)
    }
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 4) {
                    Text("\(index + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    Text(word)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Color.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(OneraColors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}

// MARK: - Warning Banner

struct WarningBanner: View {
    let text: String
    
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#if DEBUG
#Preview {
    E2EESetupView(
        viewModel: E2EESetupViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            onComplete: {}
        )
    )
}
#endif