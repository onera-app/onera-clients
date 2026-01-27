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
    
    @State private var currentMethod: UnlockMethod = .options
    @State private var hasPassword = false
    @State private var isCheckingUnlockMethods = true
    
    @FocusState private var focusedWordIndex: Int?
    @FocusState private var passwordFieldFocused: Bool
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    
    init(
        viewModel: E2EEUnlockViewModel,
        authService: AuthServiceProtocol,
        e2eeService: E2EEServiceProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.authService = authService
        self.e2eeService = e2eeService
        self.passwordViewModel = PasswordUnlockViewModel(
            authService: authService,
            e2eeService: e2eeService,
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
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
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
            let token = try await authService.getToken()
            hasPassword = try await e2eeService.hasPasswordEncryption(token: token)
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
                .font(.system(size: 64))
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
                        .font(.system(size: 56))
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
                                        .foregroundStyle(Color(.label))
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
                                    .foregroundStyle(Color(.label))
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
                                .foregroundStyle(Color(.label))
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
        }
    }
    
    // MARK: - Passkey Unlock View
    
    private var passkeyUnlockView: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 64))
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
            ToolbarItem(placement: .navigationBarLeading) {
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
                        .font(.system(size: 56))
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
            ToolbarItem(placement: .navigationBarLeading) {
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
                        .font(.system(size: 56))
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
                ToolbarItem(placement: .navigationBarLeading) {
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
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedWordIndex, equals: index)
                .submitLabel(index < Configuration.Mnemonic.wordCount - 1 ? .next : .done)
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
        .background(Color(.tertiarySystemGroupedBackground))
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
        authService: MockAuthService(),
        e2eeService: MockE2EEService(),
        onComplete: {}
    )
}
#endif