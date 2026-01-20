//
//  E2EEUnlockView.swift
//  Onera
//
//  Enter recovery phrase or password to unlock E2EE
//

import SwiftUI

enum UnlockMethod {
    case options
    case password
    case recovery
}

struct E2EEUnlockView: View {
    
    @Bindable var viewModel: E2EEUnlockViewModel
    @Bindable var passwordViewModel: PasswordUnlockViewModel
    
    @State private var currentMethod: UnlockMethod = .options
    @State private var hasPassword = false
    @State private var isCheckingPassword = true
    
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
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if isCheckingPassword {
                        loadingView
                    } else {
                        switch currentMethod {
                        case .options:
                            unlockOptionsView
                        case .password:
                            passwordUnlockView
                        case .recovery:
                            recoveryPhraseView
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .task {
            await checkPasswordEncryption()
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
    
    // MARK: - Check Password
    
    private func checkPasswordEncryption() async {
        isCheckingPassword = true
        do {
            let token = try await authService.getToken()
            hasPassword = try await e2eeService.hasPasswordEncryption(token: token)
        } catch {
            hasPassword = false
        }
        isCheckingPassword = false
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            
            Text("Unlock Encryption")
                .font(.title2.bold())
            
            Text(headerDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var headerDescription: String {
        switch currentMethod {
        case .options:
            if hasPassword {
                return "Use your password or recovery phrase to unlock your encrypted data."
            }
            return "Enter your recovery phrase to unlock your encrypted data."
        case .password:
            return "Enter your encryption password to unlock."
        case .recovery:
            return "Enter your 24-word recovery phrase."
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Options View
    
    private var unlockOptionsView: some View {
        VStack(spacing: 16) {
            if hasPassword {
                optionButton(
                    icon: "key.fill",
                    title: "Unlock with Password",
                    description: "Use your encryption password"
                ) {
                    currentMethod = .password
                }
            }
            
            optionButton(
                icon: "rectangle.grid.3x2",
                title: "Use Recovery Phrase",
                description: "Enter your 24-word phrase"
            ) {
                currentMethod = .recovery
            }
        }
    }
    
    private func optionButton(
        icon: String,
        title: String,
        description: String,
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
                    Text(title)
                        .font(.headline)
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
    
    // MARK: - Password Unlock View
    
    private var passwordUnlockView: some View {
        VStack(spacing: 20) {
            backButton
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Encryption Password")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    if passwordViewModel.showPassword {
                        TextField("Enter your password", text: $passwordViewModel.password)
                    } else {
                        SecureField("Enter your password", text: $passwordViewModel.password)
                    }
                    
                    Button {
                        passwordViewModel.togglePasswordVisibility()
                    } label: {
                        Image(systemName: passwordViewModel.showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($passwordFieldFocused)
            }
            
            Button {
                Task { await passwordViewModel.unlock() }
            } label: {
                Group {
                    if passwordViewModel.isUnlocking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Unlock")
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
            .disabled(!passwordViewModel.canUnlock)
        }
        .onAppear {
            passwordFieldFocused = true
        }
    }
    
    // MARK: - Recovery Phrase View
    
    private var recoveryPhraseView: some View {
        VStack(spacing: 20) {
            if hasPassword {
                backButton
            }
            
            inputModeToggle
            
            if viewModel.showPasteField {
                pasteFieldView
            } else {
                wordGridView
            }
            
            unlockButton
        }
    }
    
    private var backButton: some View {
        Button {
            currentMethod = .options
            passwordViewModel.clearPassword()
        } label: {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back to options")
            }
        }
        .font(.callout)
    }
    
    private var inputModeToggle: some View {
        Button {
            viewModel.toggleInputMode()
        } label: {
            Label(
                viewModel.showPasteField ? "Enter words individually" : "Paste full phrase",
                systemImage: viewModel.showPasteField ? "keyboard" : "doc.on.clipboard"
            )
        }
        .font(.callout)
    }
    
    private var pasteFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your recovery phrase:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $viewModel.pastedPhrase)
                .font(.body.monospaced())
                .frame(height: 120)
                .padding(8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: viewModel.pastedPhrase) { _, newValue in
                    viewModel.parsePhrase(newValue)
                }
        }
    }
    
    private var wordGridView: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            ForEach(0..<Configuration.Mnemonic.wordCount, id: \.self) { index in
                wordInputField(index: index)
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
                .font(.body.monospaced())
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
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var unlockButton: some View {
        Button {
            Task { await viewModel.unlock() }
        } label: {
            Group {
                if viewModel.isUnlocking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Unlock")
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
        .disabled(!viewModel.canUnlock)
        .padding(.top)
    }
}

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
