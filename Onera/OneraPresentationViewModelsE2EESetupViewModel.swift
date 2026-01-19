//
//  E2EESetupViewModel.swift
//  Onera
//
//  E2EE setup view model
//

import Foundation
import Observation

@MainActor
@Observable
final class E2EESetupViewModel {
    
    // MARK: - State
    
    enum SetupState: Equatable {
        case loading
        case showingPhrase(String)
        case error(String)
    }
    
    private(set) var state: SetupState = .loading
    var hasSavedPhrase = false
    var showConfirmation = false
    
    var canComplete: Bool {
        if case .showingPhrase = state {
            return hasSavedPhrase
        }
        return false
    }
    
    var recoveryPhrase: String? {
        if case .showingPhrase(let phrase) = state {
            return phrase
        }
        return nil
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
    
    func startSetup() async {
        state = .loading
        
        do {
            let token = try await authService.getToken()
            let mnemonic = try await e2eeService.setupNewUser(token: token)
            state = .showingPhrase(mnemonic)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func confirmSaved() {
        showConfirmation = true
    }
    
    func completeSetup() {
        onComplete()
    }
    
    func retry() async {
        await startSetup()
    }
}
