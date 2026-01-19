//
//  E2EESetupView.swift
//  Onera
//
//  E2EE setup and recovery phrase display
//

import SwiftUI

struct E2EESetupView: View {
    @State private var e2eeManager = E2EEManager.shared
    @State private var recoveryPhrase: String?
    @State private var hasSavedPhrase = false
    @State private var showConfirmation = false
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let phrase = recoveryPhrase {
                    recoveryPhraseView(phrase)
                } else {
                    setupProgressView
                }
            }
            .navigationTitle("Secure Your Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if recoveryPhrase != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showConfirmation = true
                        }
                        .disabled(!hasSavedPhrase)
                    }
                }
            }
            .alert("Confirm", isPresented: $showConfirmation) {
                Button("I've Saved It", role: .destructive) {
                    onComplete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Make sure you've saved your recovery phrase in a secure location. You won't be able to recover your encrypted data without it.")
            }
        }
        .interactiveDismissDisabled()
    }
    
    private var setupProgressView: some View {
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
        .task {
            await setupE2EE()
        }
    }
    
    private func recoveryPhraseView(_ phrase: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Warning header
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
                    UIPasteboard.general.string = phrase
                    // Clear clipboard after 60 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        if UIPasteboard.general.string == phrase {
                            UIPasteboard.general.string = ""
                        }
                    }
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                // Warning
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text("Write down this phrase and store it somewhere safe. Never share it with anyone. Anyone with this phrase can access your encrypted data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Confirmation toggle
                Toggle(isOn: $hasSavedPhrase) {
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
    
    private func setupE2EE() async {
        do {
            let token = try await AuthenticationManager.shared.getToken()
            let phrase = try await e2eeManager.setupNewUser(token: token)
            recoveryPhrase = phrase
        } catch {
            // Handle error - show alert
        }
    }
}

struct RecoveryPhraseGrid: View {
    let phrase: String
    
    private var words: [String] {
        phrase.split(separator: " ").map(String.init)
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
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

#Preview {
    E2EESetupView {
        print("Complete")
    }
}
