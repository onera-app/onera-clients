//
//  RecoveryPhraseEntryView.swift
//  Onera
//
//  Enter recovery phrase to unlock E2EE
//

import SwiftUI

struct RecoveryPhraseEntryView: View {
    @State private var e2eeManager = E2EEManager.shared
    @State private var words: [String] = Array(repeating: "", count: 24)
    @State private var pastedPhrase = ""
    @State private var showPasteField = false
    @State private var isUnlocking = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var focusedIndex: Int?
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
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
                    
                    // Paste option
                    Button {
                        showPasteField.toggle()
                    } label: {
                        Label(
                            showPasteField ? "Enter words individually" : "Paste full phrase",
                            systemImage: showPasteField ? "keyboard" : "doc.on.clipboard"
                        )
                    }
                    .font(.callout)
                    
                    if showPasteField {
                        pasteFieldView
                    } else {
                        wordGridView
                    }
                    
                    // Unlock button
                    Button {
                        Task {
                            await unlock()
                        }
                    } label: {
                        if isUnlocking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Unlock")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isUnlocking || !isValid)
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled()
    }
    
    private var pasteFieldView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your recovery phrase:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $pastedPhrase)
                .font(.body.monospaced())
                .frame(height: 120)
                .padding(8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: pastedPhrase) { _, newValue in
                    parsePhrase(newValue)
                }
        }
    }
    
    private var wordGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(0..<24, id: \.self) { index in
                HStack(spacing: 4) {
                    Text("\(index + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    TextField("", text: $words[index])
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedIndex, equals: index)
                        .submitLabel(index < 23 ? .next : .done)
                        .onSubmit {
                            if index < 23 {
                                focusedIndex = index + 1
                            } else {
                                focusedIndex = nil
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var isValid: Bool {
        let phrase = currentPhrase
        let wordCount = phrase.split(separator: " ").count
        return wordCount == 24
    }
    
    private var currentPhrase: String {
        if showPasteField && !pastedPhrase.isEmpty {
            return pastedPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func parsePhrase(_ text: String) {
        let parsed = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        for (index, word) in parsed.prefix(24).enumerated() {
            words[index] = word
        }
    }
    
    private func unlock() async {
        isUnlocking = true
        
        defer { isUnlocking = false }
        
        do {
            let token = try await AuthenticationManager.shared.getToken()
            try await e2eeManager.unlockWithRecoveryPhrase(mnemonic: currentPhrase, token: token)
            onComplete()
        } catch {
            errorMessage = "Invalid recovery phrase. Please check and try again."
            showError = true
        }
    }
}

#Preview {
    RecoveryPhraseEntryView {
        print("Complete")
    }
}
