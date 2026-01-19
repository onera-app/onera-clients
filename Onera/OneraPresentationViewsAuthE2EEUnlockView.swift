//
//  E2EEUnlockView.swift
//  Onera
//
//  Enter recovery phrase to unlock E2EE
//

import SwiftUI

struct E2EEUnlockView: View {
    
    @Bindable var viewModel: E2EEUnlockViewModel
    @FocusState private var focusedWordIndex: Int?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    inputModeToggle
                    
                    if viewModel.showPasteField {
                        pasteFieldView
                    } else {
                        wordGridView
                    }
                    
                    unlockButton
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            
            Text("Enter Recovery Phrase")
                .font(.title2.bold())
            
            Text("Enter your 24-word recovery phrase to unlock your encrypted data on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
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
                } else {
                    Text("Unlock")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
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
        )
    )
}
