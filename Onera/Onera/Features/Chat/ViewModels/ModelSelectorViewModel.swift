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
    private(set) var privateModels: [ModelOption] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    /// Current enclave assignment for private inference
    private(set) var currentEnclaveAssignment: EnclaveAssignment?
    
    var selectedModel: ModelOption? {
        didSet {
            if let model = selectedModel {
                UserDefaults.standard.set(model.id, forKey: "selectedModelId")
                addToRecent(model.id)
            }
        }
    }
    
    // MARK: - Pinned & Recent Models
    
    /// IDs of pinned models (persisted)
    private(set) var pinnedModelIds: [String] = [] {
        didSet {
            UserDefaults.standard.set(pinnedModelIds, forKey: "pinnedModelIds")
        }
    }
    
    /// IDs of recently used models (persisted, max 5)
    private(set) var recentModelIds: [String] = [] {
        didSet {
            UserDefaults.standard.set(recentModelIds, forKey: "recentModelIds")
        }
    }
    
    /// Active provider filter (nil = show all)
    var connectionFilter: LLMProvider? = nil
    
    // MARK: - Computed Properties
    
    /// All available models (regular + private)
    var allModels: [ModelOption] {
        models + privateModels
    }
    
    /// Pinned models (resolved from IDs)
    var pinnedModels: [ModelOption] {
        pinnedModelIds.compactMap { id in allModels.first { $0.id == id } }
    }
    
    /// Recently used models (resolved from IDs, excluding pinned, max 5)
    var recentModels: [ModelOption] {
        let pinSet = Set(pinnedModelIds)
        return recentModelIds
            .filter { !pinSet.contains($0) }
            .prefix(5)
            .compactMap { id in allModels.first { $0.id == id } }
    }
    
    /// Models grouped by provider, with optional filter applied
    var groupedModels: [(provider: LLMProvider, models: [ModelOption])] {
        let source: [ModelOption]
        if let filter = connectionFilter {
            source = allModels.filter { $0.provider == filter }
        } else {
            source = allModels
        }
        let grouped = Dictionary(grouping: source) { $0.provider }
        return LLMProvider.allCases.compactMap { provider in
            guard let providerModels = grouped[provider], !providerModels.isEmpty else { return nil }
            return (provider: provider, models: providerModels)
        }
    }
    
    /// Providers that have at least one model (for filter chips)
    var availableProviders: [LLMProvider] {
        let providers = Set(allModels.map(\.provider))
        return LLMProvider.allCases.filter { providers.contains($0) }
    }
    
    /// Whether any models are available
    var hasModels: Bool {
        !allModels.isEmpty
    }
    
    /// Whether the selected model is a private inference model
    var isPrivateModelSelected: Bool {
        guard let model = selectedModel else { return false }
        return isPrivateModel(model.id)
    }
    
    // MARK: - Dependencies
    
    private let credentialService: CredentialServiceProtocol
    private let llmService: LLMServiceProtocol
    private let networkService: NetworkServiceProtocol
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(
        credentialService: CredentialServiceProtocol,
        llmService: LLMServiceProtocol,
        networkService: NetworkServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.credentialService = credentialService
        self.llmService = llmService
        self.networkService = networkService
        self.authService = authService
        
        // Restore persisted state
        pinnedModelIds = UserDefaults.standard.stringArray(forKey: "pinnedModelIds") ?? []
        recentModelIds = UserDefaults.standard.stringArray(forKey: "recentModelIds") ?? []
        
        // Restore last selected model
        if let savedModelId = UserDefaults.standard.string(forKey: "selectedModelId") {
            // Will be resolved after models are fetched
            Task {
                await fetchModels()
                selectedModel = allModels.first { $0.id == savedModelId }
            }
        }
    }
    
    // MARK: - Actions
    
    func fetchModels() async {
        isLoading = true
        error = nil
        
        var allRegularModels: [ModelOption] = []
        
        // Fetch regular models from all credentials in parallel
        if !credentialService.credentials.isEmpty {
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
                    allRegularModels.append(contentsOf: credentialModels)
                }
            }
        }
        
        models = allRegularModels.sorted { $0.name < $1.name }
        
        // Also fetch private models
        await fetchPrivateModels()
        
        isLoading = false
        
        // Select first model if none selected
        if selectedModel == nil, let firstModel = allModels.first {
            selectedModel = firstModel
        }
        
        // Re-validate selected model
        if let selected = selectedModel, !allModels.contains(where: { $0.id == selected.id }) {
            selectedModel = allModels.first
        }
    }
    
    /// Fetches available private inference models from server
    private func fetchPrivateModels() async {
        do {
            let token = try await authService.getToken()
            let privateModelInfos: [PrivateModelInfo] = try await networkService.call(
                procedure: APIEndpoint.Enclaves.listModels,
                token: token
            )
            
            // Convert to ModelOption with private: prefix
            privateModels = privateModelInfos.map { info in
                ModelOption(
                    id: "\(PRIVATE_MODEL_PREFIX)\(info.id)",
                    name: info.effectiveDisplayName,
                    provider: .private,
                    credentialId: "" // Private models don't need a credential
                )
            }
            
            print("[ModelSelector] Fetched \(privateModels.count) private models")
        } catch {
            print("[ModelSelector] Failed to fetch private models: \(error)")
            // Don't fail - private models are optional
            privateModels = []
        }
    }
    
    func selectModel(_ model: ModelOption) {
        // Release previous enclave if switching away from private
        if let assignment = currentEnclaveAssignment, !isPrivateModel(model.id) {
            Task {
                await releaseEnclave(assignmentId: assignment.id)
            }
        }
        selectedModel = model
    }
    
    /// Toggle pin state for a model
    func togglePin(_ modelId: String) {
        if let idx = pinnedModelIds.firstIndex(of: modelId) {
            pinnedModelIds.remove(at: idx)
        } else {
            pinnedModelIds.append(modelId)
        }
    }
    
    /// Whether a model is pinned
    func isPinned(_ modelId: String) -> Bool {
        pinnedModelIds.contains(modelId)
    }
    
    /// Add a model to the MRU list
    private func addToRecent(_ modelId: String) {
        recentModelIds.removeAll { $0 == modelId }
        recentModelIds.insert(modelId, at: 0)
        if recentModelIds.count > 5 {
            recentModelIds = Array(recentModelIds.prefix(5))
        }
    }
    
    func getCredentialForSelectedModel() -> DecryptedCredential? {
        guard let model = selectedModel else { return nil }
        // Private models don't need credentials
        if isPrivateModel(model.id) { return nil }
        return credentialService.getCredential(byId: model.credentialId)
    }
    
    // MARK: - Enclave Management
    
    /// Requests an enclave for the current private model
    /// Returns the enclave config needed for inference
    func requestEnclaveForCurrentModel(sessionId: String) async throws -> EnclaveConfig {
        guard let model = selectedModel, isPrivateModel(model.id) else {
            throw ModelSelectorError.notPrivateModel
        }
        
        let token: String
        do {
            token = try await authService.getToken()
        } catch {
            throw ModelSelectorError.notAuthenticated
        }
        
        // Extract the actual model ID (without private: prefix)
        let modelId = String(model.id.dropFirst(PRIVATE_MODEL_PREFIX.count))
        
        let input = RequestEnclaveInput(
            modelId: modelId,
            tier: "shared",
            sessionId: sessionId
        )
        
        let response: RequestEnclaveResponse = try await networkService.call(
            procedure: APIEndpoint.Enclaves.requestEnclave,
            input: input,
            token: token
        )
        
        // Store assignment for cleanup
        currentEnclaveAssignment = EnclaveAssignment(
            id: response.assignmentId,
            enclaveId: response.enclaveId
        )
        
        // Build EnclaveConfig from response
        let config = EnclaveConfig(
            id: response.endpoint.id,
            name: model.name,
            endpoint: "https://\(response.endpoint.host):\(response.endpoint.port)",
            wsEndpoint: response.wsEndpoint,
            attestationEndpoint: response.attestationEndpoint,
            allowUnverified: response.allowUnverified ?? false,
            expectedMeasurements: nil
        )
        
        print("[ModelSelector] Got enclave assignment: \(response.assignmentId)")
        return config
    }
    
    /// Releases the current enclave assignment
    func releaseEnclave(assignmentId: String) async {
        do {
            let token = try await authService.getToken()
            let input = ReleaseEnclaveInput(assignmentId: assignmentId)
            let _: EmptyEnclaveResponse = try await networkService.call(
                procedure: APIEndpoint.Enclaves.releaseEnclave,
                input: input,
                token: token
            )
            
            if currentEnclaveAssignment?.id == assignmentId {
                currentEnclaveAssignment = nil
            }
            
            print("[ModelSelector] Released enclave assignment: \(assignmentId)")
        } catch {
            print("[ModelSelector] Failed to release enclave: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct EnclaveAssignment {
    let id: String
    let enclaveId: String
}

private struct EmptyEnclaveResponse: Decodable {}

enum ModelSelectorError: LocalizedError {
    case notPrivateModel
    case notAuthenticated
    case enclaveUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notPrivateModel:
            return "Selected model is not a private inference model"
        case .notAuthenticated:
            return "Not authenticated"
        case .enclaveUnavailable:
            return "No enclaves available"
        }
    }
}
