//
//  FolderViewModel.swift
//  Onera
//
//  ViewModel for managing folders
//

import Foundation
import Observation

@MainActor
@Observable
final class FolderViewModel {
    
    // MARK: - State
    
    private(set) var folders: [Folder] = []
    private(set) var folderTree: [FolderTree] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var expandedFolders: Set<String> = []
    var editingFolderId: String?
    var editingName: String = ""
    
    // MARK: - Creating folder state
    
    var isCreatingFolder = false
    var newFolderName: String = ""
    var newFolderParentId: String?
    
    // MARK: - Delete confirmation
    
    var deletingFolderId: String?
    var showDeleteConfirmation = false
    
    // MARK: - Dependencies
    
    private let folderRepository: FolderRepositoryProtocol
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(
        folderRepository: FolderRepositoryProtocol,
        authService: AuthServiceProtocol
    ) {
        self.folderRepository = folderRepository
        self.authService = authService
    }
    
    // MARK: - Actions
    
    func loadFolders() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            folders = try await folderRepository.fetchFolders(token: token)
            folderTree = FolderTree.buildTree(from: folders)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshFolders() async {
        await loadFolders()
    }
    
    // MARK: - CRUD Operations
    
    func createFolder() async {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let token = try await authService.getToken()
            let folder = try await folderRepository.createFolder(
                name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines),
                parentId: newFolderParentId,
                token: token
            )
            
            folders.append(folder)
            folderTree = FolderTree.buildTree(from: folders)
            
            // Expand parent if creating subfolder
            if let parentId = newFolderParentId {
                expandedFolders.insert(parentId)
            }
            
            // Reset creation state
            newFolderName = ""
            newFolderParentId = nil
            isCreatingFolder = false
        } catch {
            self.error = error
        }
    }
    
    func startCreatingFolder(parentId: String? = nil) {
        newFolderParentId = parentId
        newFolderName = ""
        isCreatingFolder = true
    }
    
    func cancelCreatingFolder() {
        isCreatingFolder = false
        newFolderName = ""
        newFolderParentId = nil
    }
    
    func startEditing(folder: Folder) {
        editingFolderId = folder.id
        editingName = folder.name
    }
    
    func saveEdit() async {
        guard let folderId = editingFolderId,
              !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelEdit()
            return
        }
        
        do {
            let token = try await authService.getToken()
            let updated = try await folderRepository.updateFolder(
                id: folderId,
                name: editingName.trimmingCharacters(in: .whitespacesAndNewlines),
                parentId: nil,
                token: token
            )
            
            if let index = folders.firstIndex(where: { $0.id == folderId }) {
                folders[index] = updated
                folderTree = FolderTree.buildTree(from: folders)
            }
            
            cancelEdit()
        } catch {
            self.error = error
        }
    }
    
    func cancelEdit() {
        editingFolderId = nil
        editingName = ""
    }
    
    func confirmDelete(folderId: String) {
        deletingFolderId = folderId
        showDeleteConfirmation = true
    }
    
    func deleteFolder() async {
        guard let folderId = deletingFolderId else { return }
        
        do {
            let token = try await authService.getToken()
            try await folderRepository.deleteFolder(id: folderId, token: token)
            
            folders.removeAll { $0.id == folderId }
            folderTree = FolderTree.buildTree(from: folders)
            
            deletingFolderId = nil
            showDeleteConfirmation = false
        } catch {
            self.error = error
        }
    }
    
    func cancelDelete() {
        deletingFolderId = nil
        showDeleteConfirmation = false
    }
    
    // MARK: - Tree Operations
    
    func toggleExpanded(folderId: String) {
        if expandedFolders.contains(folderId) {
            expandedFolders.remove(folderId)
        } else {
            expandedFolders.insert(folderId)
        }
    }
    
    func isExpanded(_ folderId: String) -> Bool {
        expandedFolders.contains(folderId)
    }
    
    // MARK: - Helpers
    
    func getFolder(id: String) -> Folder? {
        folders.first { $0.id == id }
    }
    
    func clearError() {
        error = nil
    }
}
