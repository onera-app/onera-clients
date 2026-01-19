//
//  E2EEUnlockViewModel.swift
//  Onera
//
//  E2EE unlock/recovery view model
//

import Foundation
import Observation

@MainActor
@Observable
final class E2EEUnlockViewModel {
    
    // MARK: - State
    
    var words: [String] = Array(repeating: "", count: Configuration.Mnemonic.wordCount)
    var pastedPhrase = ""
    var showPasteField = false
    
    private(set) var isUnlocking = false
    private(set) var error: String?
    var showError: Bool {
        get { error != nil }
        set { if !newValue { error = nil } }
    }
    
    var currentPhrase: String {
        if showPasteField && !pastedPhrase.isEmpty {
            return pastedPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return words
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    var isValid: Bool {
        let wordCount = currentPhrase.split(separator: " ").count
        return wordCount == Configuration.Mnemonic.wordCount
    }
    
    var canUnlock: Bool {
        isValid && !isUnlocking
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let e2eeService: E2EEServiceProtocol
    private let onComplete: () -> Void
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        e2eeService: E2EEServiceProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.authService = authService
        self.e2eeService = e2eeService
        self.onComplete = onComplete
    }
    
    // MARK: - Actions
    
    func unlock() async {
        guard canUnlock else { return }
        
        isUnlocking = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            try await e2eeService.unlockWithRecoveryPhrase(
                mnemonic: currentPhrase,
                token: token
            )
            onComplete()
        } catch {
            self.error = "Invalid recovery phrase. Please check and try again."
        }
        
        isUnlocking = false
    }
    
    func parsePhrase(_ text: String) {
        let parsed = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        for (index, word) in parsed.prefix(Configuration.Mnemonic.wordCount).enumerated() {
            words[index] = word
        }
    }
    
    func toggleInputMode() {
        showPasteField.toggle()
    }
    
    func clearError() {
        error = nil
    }
}
