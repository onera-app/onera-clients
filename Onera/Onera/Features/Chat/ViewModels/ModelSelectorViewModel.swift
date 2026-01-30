//
//  ModelSelectorViewModel.swift
//  Onera
//
//  ViewModel for model selection
//

import Foundation
import Observation

@MainActor
@Observable
final class ModelSelectorViewModel {
    
    // MARK: - State
    
    private(set) var models: [ModelOption] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var selectedModel: ModelOption? {
        didSet {
            if let model = selectedModel {
                // Persist the selection
                UserDefaults.standard.set(model.id, forKey: "selectedModelId")
            }
        }
    }
    
    /// Models grouped by provider
    var groupedModels: [(provider: LLMProvider, models: [ModelOption])] {
        let grouped = Dictionary(grouping: models) { $0.provider }
        return LLMProvider.allCases.compactMap { provider in
            guard let providerModels = grouped[provider], !providerModels.isEmpty else { return nil }
            return (provider: provider, models: providerModels)
        }
    }
    
    /// Whether any models are available
    var hasModels: Bool {
        !models.isEmpty
    }
    
    // MARK: - Dependencies
    
    private let credentialService: CredentialServiceProtocol
    private let llmService: LLMServiceProtocol
    
    // MARK: - Initialization
    
    init(
        credentialService: CredentialServiceProtocol,
        llmService: LLMServiceProtocol
    ) {
        self.credentialService = credentialService
        self.llmService = llmService
        
        // Restore last selected model
        if let savedModelId = UserDefaults.standard.string(forKey: "selectedModelId") {
            // Will be resolved after models are fetched
            Task {
                await fetchModels()
                selectedModel = models.first { $0.id == savedModelId }
            }
        }
    }
    
    // MARK: - Actions
    
    func fetchModels() async {
        guard !credentialService.credentials.isEmpty else {
            models = []
            return
        }
        
        isLoading = true
        error = nil
        
        var allModels: [ModelOption] = []
        
        // Fetch models from all credentials in parallel
        await withTaskGroup(of: [ModelOption].self) { group in
            for credential in credentialService.credentials {
                group.addTask { [llmService] in
                    do {
                        return try await llmService.fetchModels(credential: credential)
                    } catch {
                        print("Failed to fetch models for \(credential.name): \(error)")
                        return []
                    }
                }
            }
            
            for await credentialModels in group {
                allModels.append(contentsOf: credentialModels)
            }
        }
        
        models = allModels.sorted { $0.name < $1.name }
        isLoading = false
        
        // Select first model if none selected
        if selectedModel == nil, let firstModel = models.first {
            selectedModel = firstModel
        }
        
        // Re-validate selected model
        if let selected = selectedModel, !models.contains(where: { $0.id == selected.id }) {
            selectedModel = models.first
        }
    }
    
    func selectModel(_ model: ModelOption) {
        selectedModel = model
    }
    
    func getCredentialForSelectedModel() -> DecryptedCredential? {
        guard let model = selectedModel else { return nil }
        return credentialService.getCredential(byId: model.credentialId)
    }
}
