//
//  PromptsViewModel.swift
//  Onera
//
//  ViewModel for managing custom prompts
//

import Foundation
import Observation

@MainActor
@Observable
final class PromptsViewModel {
    
    // MARK: - State
    
    private(set) var prompts: [PromptSummary] = []
    private(set) var groupedPrompts: [(PromptGroup, [PromptSummary])] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var searchText = ""
    
    // MARK: - Editor State
    
    var showPromptEditor = false
    var editingPrompt: Prompt?
    var isCreatingNew = false
    
    // MARK: - Dependencies
    
    private let promptRepository: PromptRepositoryProtocol
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(
        promptRepository: PromptRepositoryProtocol,
        authService: AuthServiceProtocol
    ) {
        self.promptRepository = promptRepository
        self.authService = authService
    }
    
    // MARK: - Actions
    
    func loadPrompts() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            prompts = try await promptRepository.fetchPrompts(token: token)
            updateGroupedPrompts()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshPrompts() async {
        await loadPrompts()
    }
    
    func createPrompt() {
        editingPrompt = Prompt()
        isCreatingNew = true
        showPromptEditor = true
    }
    
    func editPrompt(_ summary: PromptSummary) async {
        do {
            let token = try await authService.getToken()
            let prompt = try await promptRepository.fetchPrompt(id: summary.id, token: token)
            editingPrompt = prompt
            isCreatingNew = false
            showPromptEditor = true
        } catch {
            self.error = error
        }
    }
    
    func savePrompt(_ prompt: Prompt) async -> Bool {
        do {
            let token = try await authService.getToken()
            
            let promptExists = prompts.contains(where: { $0.id == prompt.id })
            print("[PromptsViewModel] savePrompt: promptId=\(prompt.id), name='\(prompt.name)', promptExists=\(promptExists), promptsCount=\(prompts.count)")
            
            if promptExists {
                // Update existing prompt
                print("[PromptsViewModel] Updating existing prompt...")
                try await promptRepository.updatePrompt(prompt, token: token)
                print("[PromptsViewModel] Prompt updated successfully")
            } else {
                // Create new prompt
                print("[PromptsViewModel] Creating new prompt...")
                let newId = try await promptRepository.createPrompt(prompt, token: token)
                print("[PromptsViewModel] Prompt created successfully with id: \(newId)")
            }
            
            await loadPrompts()
            return true
        } catch {
            print("[PromptsViewModel] Error saving prompt: \(error)")
            self.error = error
            return false
        }
    }
    
    func deletePrompt(_ summary: PromptSummary) async {
        do {
            let token = try await authService.getToken()
            try await promptRepository.deletePrompt(id: summary.id, token: token)
            await loadPrompts()
        } catch {
            self.error = error
        }
    }
    
    func duplicatePrompt(_ summary: PromptSummary) async {
        do {
            let token = try await authService.getToken()
            let original = try await promptRepository.fetchPrompt(id: summary.id, token: token)
            
            let duplicate = Prompt(
                name: "\(original.name) (Copy)",
                description: original.description,
                content: original.content
            )
            
            _ = try await promptRepository.createPrompt(duplicate, token: token)
            await loadPrompts()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Search
    
    var filteredPrompts: [PromptSummary] {
        if searchText.isEmpty {
            return prompts
        }
        return prompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var filteredGroupedPrompts: [(PromptGroup, [PromptSummary])] {
        if searchText.isEmpty {
            return groupedPrompts
        }
        
        let filtered = filteredPrompts
        return groupedPrompts.compactMap { group, prompts in
            let matchingPrompts = prompts.filter { filtered.contains($0) }
            return matchingPrompts.isEmpty ? nil : (group, matchingPrompts)
        }
    }
    
    // MARK: - Prompt Usage
    
    /// Get a prompt ready for use in chat (with variables filled in)
    func usePrompt(_ summary: PromptSummary, variables: [String: String] = [:]) async -> String? {
        do {
            let token = try await authService.getToken()
            let prompt = try await promptRepository.fetchPrompt(id: summary.id, token: token)
            return prompt.filled(with: variables)
        } catch {
            self.error = error
            return nil
        }
    }
    
    // MARK: - Private
    
    private func updateGroupedPrompts() {
        let grouped = Dictionary(grouping: prompts) { $0.group }
        groupedPrompts = grouped.keys.sorted().map { group in
            (group, grouped[group] ?? [])
        }
    }
}
