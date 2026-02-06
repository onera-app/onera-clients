//
//  FolderViewModel.swift
//  Onera
//
//  ViewModel for managing folders with E2EE encryption
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
    private let cryptoService: ExtendedCryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    // MARK: - Initialization
    
    init(
        folderRepository: FolderRepositoryProtocol,
        authService: AuthServiceProtocol,
        cryptoService: ExtendedCryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.folderRepository = folderRepository
        self.authService = authService
        self.cryptoService = cryptoService
        self.secureSession = secureSession
    }
    
    // MARK: - Actions
    
    func loadFolders() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            let encryptedFolders = try await folderRepository.fetchFolders(token: token)
            folders = decryptFolders(encryptedFolders)
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
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        do {
            let token = try await authService.getToken()
            
            // Encrypt folder name
            let encrypted = try encryptFolderName(trimmedName)
            
            let response = try await folderRepository.createFolder(
                encryptedName: encrypted.encryptedName,
                nameNonce: encrypted.nameNonce,
                parentId: newFolderParentId,
                token: token
            )
            
            // Decrypt and add to list
            let folder = decryptFolder(response)
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
        guard let folderId = editingFolderId else {
            cancelEdit()
            return
        }
        
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            cancelEdit()
            return
        }
        
        do {
            let token = try await authService.getToken()
            
            // Encrypt the new name
            let encrypted = try encryptFolderName(trimmedName)
            
            let response = try await folderRepository.updateFolder(
                id: folderId,
                encryptedName: encrypted.encryptedName,
                nameNonce: encrypted.nameNonce,
                parentId: nil,
                token: token
            )
            
            // Decrypt and update list
            let updated = decryptFolder(response)
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
    
    // MARK: - Encryption/Decryption
    
    /// Encrypts a folder name using the master key
    private func encryptFolderName(_ name: String) throws -> EncryptedFolderName {
        guard let masterKey = secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let (ciphertext, nonce) = try cryptoService.encryptString(name, key: masterKey)
        return EncryptedFolderName(encryptedName: ciphertext, nameNonce: nonce)
    }
    
    /// Decrypts a folder name using the master key
    private func decryptFolderName(encryptedName: String?, nameNonce: String?) -> String {
        guard let encryptedName = encryptedName,
              let nameNonce = nameNonce,
              let masterKey = secureSession.masterKey else {
            return "Encrypted Folder"
        }
        
        do {
            return try cryptoService.decryptString(ciphertext: encryptedName, nonce: nameNonce, key: masterKey)
        } catch {
            print("[FolderViewModel] Failed to decrypt folder name: \(error)")
            return "Encrypted Folder"
        }
    }
    
    /// Converts an encrypted folder response to a decrypted Folder model
    private func decryptFolder(_ response: EncryptedFolderResponse) -> Folder {
        let name = decryptFolderName(encryptedName: response.encryptedName, nameNonce: response.nameNonce)
        return Folder(
            id: response.id,
            name: name,
            parentId: response.parentId,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt
        )
    }
    
    /// Decrypts a list of encrypted folder responses
    private func decryptFolders(_ responses: [EncryptedFolderResponse]) -> [Folder] {
        responses.map { decryptFolder($0) }
    }
}
