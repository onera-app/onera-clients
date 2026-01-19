//
//  E2EESetupView.swift
//  Onera
//
//  E2EE setup and recovery phrase display
//

import SwiftUI

struct E2EESetupView: View {
    
    @Bindable var viewModel: E2EESetupViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingView
                    
                case .showingPhrase(let phrase):
                    recoveryPhraseView(phrase: phrase)
                    
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Secure Your Account")
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
                    viewModel.completeSetup()
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
