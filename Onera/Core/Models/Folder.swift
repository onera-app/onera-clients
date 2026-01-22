//
//  Folder.swift
//  Onera
//
//  Folder domain models for organizing chats and notes
//  Note: Folder names are encrypted client-side using E2EE
//

import Foundation

// MARK: - Folder

struct Folder: Identifiable, Equatable, Sendable {
    let id: String
    var name: String  // Decrypted name for display
    var parentId: String?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        name: String = "New Folder",
        parentId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Check if this folder is a root folder (no parent)
    var isRoot: Bool {
        parentId == nil
    }
}

// MARK: - Encrypted Folder Name Data

/// Encrypted folder name data for API requests
struct EncryptedFolderName: Codable, Sendable {
    let encryptedName: String
    let nameNonce: String
}

// MARK: - Folder Tree (for hierarchical display)

struct FolderTree: Identifiable, Equatable, Sendable {
    let folder: Folder
    var children: [FolderTree]
    
    var id: String { folder.id }
    var name: String { folder.name }
    
    init(folder: Folder, children: [FolderTree] = []) {
        self.folder = folder
        self.children = children
    }
    
    /// Build a tree from a flat list of folders
    static func buildTree(from folders: [Folder]) -> [FolderTree] {
        let folderDict = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var childrenMap: [String?: [Folder]] = [:]
        
        for folder in folders {
            childrenMap[folder.parentId, default: []].append(folder)
        }
        
        func buildNode(folder: Folder) -> FolderTree {
            let children = childrenMap[folder.id] ?? []
            return FolderTree(
                folder: folder,
                children: children.map { buildNode(folder: $0) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
        
        // Start with root folders (parentId == nil)
        let rootFolders = childrenMap[nil] ?? []
        return rootFolders
            .map { buildNode(folder: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Folder Errors

enum FolderError: LocalizedError {
    case folderNotFound
    case createFailed
    case updateFailed
    case deleteFailed
    case circularReference
    
    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder not found"
        case .createFailed:
            return "Failed to create folder"
        case .updateFailed:
            return "Failed to update folder"
        case .deleteFailed:
            return "Failed to delete folder"
        case .circularReference:
            return "Cannot create circular folder reference"
        }
    }
}

// MARK: - Mock Data

#if DEBUG
extension Folder {
    static func mock(
        id: String = UUID().uuidString,
        name: String = "Mock Folder",
        parentId: String? = nil
    ) -> Folder {
        Folder(
            id: id,
            name: name,
            parentId: parentId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var mockFolders: [Folder] {
        let workId = UUID().uuidString
        let projectsId = UUID().uuidString
        
        return [
            Folder(id: workId, name: "Work"),
            Folder(name: "Personal"),
            Folder(id: projectsId, name: "Projects", parentId: workId),
            Folder(name: "Archived")
        ]
    }
}

extension FolderTree {
    static var mockTree: [FolderTree] {
        FolderTree.buildTree(from: Folder.mockFolders)
    }
}
#endif
