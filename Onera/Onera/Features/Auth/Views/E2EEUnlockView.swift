//
//  E2EEUnlockView.swift
//  Onera
//
//  Native iOS unlock view for E2EE
//  Enter recovery phrase, password, or use passkey to unlock
//

import SwiftUI

enum UnlockMethod {
    case options
    case passkey
    case password
    case recovery
}

struct E2EEUnlockView: View {
    
    @Bindable var viewModel: E2EEUnlockViewModel
    @Bindable var passwordViewModel: PasswordUnlockViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var currentMethod: UnlockMethod = .options
    @State private var hasPassword = false
    @State private var isCheckingUnlockMethods = true
    
    @Environment(\.theme) private var theme
    @FocusState private var focusedWordIndex: Int?
    @FocusState private var passwordFieldFocused: Bool
    
    private let onSignOut: (() -> Void)?
    
    @State private var showingSignOutConfirmation = false
    
    /// iPad uses constrained width
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    /// Max width for content on iPad
    private let iPadMaxWidth: CGFloat = 500
    
    /// Simplified initializer - services are obtained from the viewModel
    /// This eliminates the redundant parameter passing pattern
    init(
        viewModel: E2EEUnlockViewModel,
        onComplete: @escaping () -> Void,
        onSignOut: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onSignOut = onSignOut
        // Create password ViewModel using services from the main viewModel
        self.passwordViewModel = PasswordUnlockViewModel(
            authService: viewModel.authService,
            e2eeService: viewModel.e2eeService,
            onComplete: onComplete
        )
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isCheckingUnlockMethods || viewModel.isCheckingPasskey {
                    loadingView
                } else if viewModel.isUnlockingWithPasskey {
                    passkeyUnlockingView
                } else {
                    switch currentMethod {
                    case .options:
                        unlockOptionsView
                    case .passkey:
                        passkeyUnlockView
                    case .password:
                        passwordUnlockView
                    case .recovery:
                        recoveryPhraseView
                    }
                }
            }
            // iPad: Constrain content width and center
            .frame(maxWidth: isRegularWidth ? iPadMaxWidth : .infinity)
            .frame(maxWidth: .infinity)
            .navigationTitle("Unlock")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .interactiveDismissDisabled()
        .task {
            await checkUnlockMethods()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Error", isPresented: $passwordViewModel.showError) {
            Button("OK") { passwordViewModel.clearError() }
        } message: {
            if let error = passwordViewModel.error {
                Text(error)
            }
        }
    }
    
    // MARK: - Check Unlock Methods
    
    private func checkUnlockMethods() async {
        isCheckingUnlockMethods = true
        
        do {
            let token = try await viewModel.authService.getToken()
            hasPassword = try await viewModel.e2eeService.hasPasswordEncryption(token: token)
        } catch {
            hasPassword = false
        }
        
        isCheckingUnlockMethods = false
        
        await viewModel.checkAndAutoUnlockWithPasskey()
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private var passkeyUnlockingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.badge.key.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            
            ProgressView()
            
            Text("Authenticating with passkey...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Unlock Options View
    
    private var unlockOptionsView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Unlock your encrypted data to continue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                if viewModel.canUsePasskey {
                    Button {
                        Task { await viewModel.unlockWithPasskey() }
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
                                        .background(.blue)
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
                    .disabled(viewModel.isUnlockingWithPasskey)
                }
                
                if hasPassword {
                    Button {
                        currentMethod = .password
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
                                Text("Use your encryption password")
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
                    currentMethod = .recovery
                } label: {
                    HStack {
                        Image(systemName: "rectangle.grid.3x2")
                            .font(.title2)
                            .foregroundStyle(.purple)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery Phrase")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.primary)
                            Text("Enter your 24-word phrase")
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
                                Text("Sign out and use a different account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account")
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
                    Text("Are you sure you want to sign out? You'll need to sign in again to access your encrypted data.")
                }
            }
        }
    }
    
    // MARK: - Passkey Unlock View
    
    private var passkeyUnlockView: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Use Face ID or Touch ID to unlock your encrypted data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                Button {
                    Task { await viewModel.unlockWithPasskey() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isUnlockingWithPasskey {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Unlocking...")
                        } else {
                            Text("Unlock with Passkey")
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isUnlockingWithPasskey)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    currentMethod = .options
                }
            }
        }
    }
    
    // MARK: - Password Unlock View
    
    private var passwordUnlockView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    
                    Text("Enter your encryption password to unlock.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                HStack {
                    if passwordViewModel.showPassword {
                        TextField("Password", text: $passwordViewModel.password)
                    } else {
                        SecureField("Password", text: $passwordViewModel.password)
                    }
                    
                    Button {
                        passwordViewModel.togglePasswordVisibility()
                    } label: {
                        Image(systemName: passwordViewModel.showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .focused($passwordFieldFocused)
            } header: {
                Text("Encryption Password")
            }
            
            Section {
                Button {
                    Task { await passwordViewModel.unlock() }
                } label: {
                    HStack {
                        Spacer()
                        if passwordViewModel.isUnlocking {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Unlocking...")
                        } else {
                            Text("Unlock")
                        }
                        Spacer()
                    }
                }
                .disabled(!passwordViewModel.canUnlock)
            }
        }
        .onAppear {
            passwordFieldFocused = true
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    currentMethod = .options
                    passwordViewModel.clearPassword()
                }
            }
        }
    }
    
    // MARK: - Recovery Phrase View
    
    private var recoveryPhraseView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.grid.3x2")
                        .font(.largeTitle)
                        .foregroundStyle(.purple)
                    
                    Text("Enter your 24-word recovery phrase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 16, trailing: 0))
            }
            
            Section {
                Button {
                    viewModel.toggleInputMode()
                } label: {
                    Label(
                        viewModel.showPasteField ? "Enter words individually" : "Paste full phrase",
                        systemImage: viewModel.showPasteField ? "keyboard" : "doc.on.clipboard"
                    )
                }
            }
            
            if viewModel.showPasteField {
                Section {
                    TextEditor(text: $viewModel.pastedPhrase)
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .onChange(of: viewModel.pastedPhrase) { _, newValue in
                            viewModel.parsePhrase(newValue)
                        }
                } header: {
                    Text("Paste Recovery Phrase")
                }
            } else {
                Section {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(0..<Configuration.Mnemonic.wordCount, id: \.self) { index in
                            wordInputField(index: index)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                } header: {
                    Text("Recovery Words")
                }
            }
            
            Section {
                Button {
                    Task { await viewModel.unlock() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isUnlocking {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Unlocking...")
                        } else {
                            Text("Unlock")
                        }
                        Spacer()
                    }
                }
                .disabled(!viewModel.canUnlock)
            }
        }
        .toolbar {
            if hasPassword || viewModel.canUsePasskey {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        currentMethod = .options
                    }
                }
            }
        }
    }
    
    private func wordInputField(index: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            TextField("", text: $viewModel.words[index])
                .font(.footnote.monospaced())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .focused($focusedWordIndex, equals: index)
                #if os(iOS)
                .submitLabel(index < Configuration.Mnemonic.wordCount - 1 ? .next : .done)
                #endif
                .onSubmit {
                    if index < Configuration.Mnemonic.wordCount - 1 {
                        focusedWordIndex = index + 1
                    } else {
                        focusedWordIndex = nil
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

#if DEBUG
#Preview {
    E2EEUnlockView(
        viewModel: E2EEUnlockViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            onComplete: {}
        ),
        onComplete: {}
    )
}
#endif