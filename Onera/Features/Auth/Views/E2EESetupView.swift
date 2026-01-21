//
//  E2EESetupView.swift
//  Onera
//
//  E2EE setup with recovery phrase display and optional password/passkey setup
//

import SwiftUI

struct E2EESetupView: View {
    
    @Bindable var viewModel: E2EESetupViewModel
    @FocusState private var passwordFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                    
                case .showingPhrase(let phrase):
                    recoveryPhraseView(phrase: phrase)
                    
                case .confirmPhrase:
                    confirmPhraseView
                    
                case .unlockMethodOptions:
                    unlockMethodOptionsView
                    
                case .settingPasskey:
                    passkeySetupView
                    
                case .settingPassword:
                    passwordSetupView
                    
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.canComplete {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.confirmSaved()
                        }
                    }
                }
            }
            .confirmationDialog(
                "Confirm",
                isPresented: $viewModel.showConfirmation,
                titleVisibility: .visible
            ) {
                Button("I've Saved It", role: .destructive) {
                    viewModel.proceedToUnlockMethod()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Make sure you've saved your recovery phrase in a secure location. You won't be able to recover your encrypted data without it.")
            }
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
                Text(error)
            }
        }
    }
    
    private var navigationTitle: String {
        switch viewModel.state {
        case .loading, .showingPhrase, .confirmPhrase:
            return "Secure Your Account"
        case .unlockMethodOptions, .settingPasskey, .settingPassword:
            return "Quick Unlock"
        case .error:
            return "Setup Error"
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
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
    
    private func recoveryPhraseView(phrase: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("Save Your Recovery Phrase")
                        .font(.title2.bold())
                    
                    Text("This is the only way to recover your encrypted data if you lose access to your devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Recovery phrase grid
                RecoveryPhraseGrid(phrase: phrase)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Copy button
                Button {
                    copyToClipboard(phrase)
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Warning
                WarningBanner(
                    text: "Write down this phrase and store it somewhere safe. Never share it with anyone. Anyone with this phrase can access your encrypted data."
                )
                
                // Confirmation toggle
                Toggle(isOn: $viewModel.hasSavedPhrase) {
                    Text("I have saved my recovery phrase securely")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
    
    private var confirmPhraseView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("Recovery Phrase Saved")
                .font(.title2.bold())
            
            Text("Great! Your recovery phrase has been saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                viewModel.proceedToUnlockMethod()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.systemGray))
            .foregroundStyle(.white)
            .controlSize(.large)
        }
        .padding()
    }
    
    // MARK: - Unlock Method Options
    
    private var unlockMethodOptionsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    
                    Text("Set Up Quick Unlock")
                        .font(.title2.bold())
                    
                    Text("Choose how you want to unlock your encrypted data. Your recovery phrase always works as a backup.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Options
                VStack(spacing: 16) {
                    // Passkey option (recommended, if supported)
                    if viewModel.passkeySupported {
                        optionButton(
                            icon: "person.badge.key.fill",
                            title: "Passkey (Recommended)",
                            description: "Use Face ID or Touch ID. Fast and secure.",
                            badge: "Recommended"
                        ) {
                            viewModel.selectPasskeySetup()
                        }
                    }
                    
                    // Password option
                    optionButton(
                        icon: "key.fill",
                        title: "Set Encryption Password",
                        description: "Set a password to unlock your data. Works on any device."
                    ) {
                        viewModel.selectPasswordSetup()
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button {
                    viewModel.skipPasswordSetup()
                } label: {
                    HStack {
                        Text("Skip for now")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text("You can always set this up later in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: - Passkey Setup
    
    private var passkeySetupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Only show back button if there are other options (passkey not supported or we came from options)
                if !viewModel.passkeySupported {
                    Button {
                        viewModel.backToOptions()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back to options")
                        }
                    }
                    .font(.callout)
                    .disabled(viewModel.isSettingUpPasskey)
                }
                
                Spacer()
                    .frame(height: viewModel.passkeySupported ? 40 : 20)
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    
                    Text("Add a Passkey")
                        .font(.title2.bold())
                    
                    Text("Passkeys are the easiest and most secure way to unlock your data. Your passkey stays on your device and uses Face ID or Touch ID.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    passkeyBenefitRow(
                        icon: "faceid",
                        text: "Unlock with Face ID or Touch ID"
                    )
                    passkeyBenefitRow(
                        icon: "shield.checkered",
                        text: "Phishing resistant - can't be stolen"
                    )
                    passkeyBenefitRow(
                        icon: "iphone",
                        text: "Stays on your device"
                    )
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                    .frame(height: 20)
                
                // Create passkey button
                Button {
                    Task { await viewModel.setupPasskey() }
                } label: {
                    Group {
                        if viewModel.isSettingUpPasskey {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Creating passkey...")
                            }
                        } else {
                            Text("Create Passkey")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(viewModel.isSettingUpPasskey)
                
                // Show skip option when passkey supported (user can set up later)
                if viewModel.passkeySupported {
                    Button {
                        viewModel.skipPasswordSetup()
                    } label: {
                        Text("Skip for now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSettingUpPasskey)
                }
                
                Text("You can always add more unlock methods in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    private func passkeyBenefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func optionButton(
        icon: String,
        title: String,
        description: String,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(.tint.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Password Setup
    
    private var passwordSetupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Back button
                Button {
                    viewModel.backToOptions()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to options")
                    }
                }
                .font(.callout)
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    
                    Text("Set Encryption Password")
                        .font(.title2.bold())
                    
                    Text("This password will unlock your encrypted data. Choose something strong and memorable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Password fields
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            if viewModel.showPassword {
                                TextField("Enter a strong password", text: $viewModel.password)
                            } else {
                                SecureField("Enter a strong password", text: $viewModel.password)
                            }
                            
                            Button {
                                viewModel.togglePasswordVisibility()
                            } label: {
                                Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($passwordFieldFocused)
                        
                        if !viewModel.passwordLengthValid {
                            Text("Password must be at least 8 characters")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if viewModel.showPassword {
                            TextField("Confirm your password", text: $viewModel.confirmPassword)
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            SecureField("Confirm your password", text: $viewModel.confirmPassword)
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        if !viewModel.passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Text("This is separate from your account password. Use at least 8 characters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    Task { await viewModel.setupPassword() }
                } label: {
                    Group {
                        if viewModel.isSettingUpPassword {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Set Password")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(.systemGray))
                .foregroundStyle(.white)
                .controlSize(.large)
                .disabled(!viewModel.canSetupPassword)
            }
            .padding()
        }
        .onAppear {
            passwordFieldFocused = true
        }
    }
    
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
            .tint(Color(.systemGray))
            .foregroundStyle(.white)
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        
        // Clear clipboard after 60 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if UIPasteboard.general.string == text {
                UIPasteboard.general.string = ""
            }
        }
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
            spacing: 12
        ) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack {
                    Text("\(index + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    
                    Text(word)
                        .font(.body.monospaced())
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Warning Banner

struct WarningBanner: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    E2EESetupView(
        viewModel: E2EESetupViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            onComplete: {}
        )
    )
}
