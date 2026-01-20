//
//  FolderRepository.swift
//  Onera
//
//  Folder data repository implementation
//  Note: Folders are NOT encrypted - they are plain text for organization
//

import Foundation

// MARK: - Protocol

protocol FolderRepositoryProtocol: Sendable {
    func fetchFolders(token: String) async throws -> [Folder]
    func fetchFolder(id: String, token: String) async throws -> Folder
    func createFolder(name: String, parentId: String?, token: String) async throws -> Folder
    func updateFolder(id: String, name: String?, parentId: String?, token: String) async throws -> Folder
    func deleteFolder(id: String, token: String) async throws
}

// MARK: - Implementation

final class FolderRepository: FolderRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            // Try to decode as milliseconds timestamp first (matching web's Int64 timestamps)
            if let milliseconds = try? container.decode(Int64.self) {
                return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
            }
            // Fall back to ISO8601
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
    }
    
    // MARK: - Folders List
    
    func fetchFolders(token: String) async throws -> [Folder] {
        let response: [FolderResponse] = try await networkService.call(
            procedure: APIEndpoint.Folders.list,
            token: token
        )
        
        return response.map { $0.toFolder() }
    }
    
    // MARK: - Single Folder
    
    func fetchFolder(id: String, token: String) async throws -> Folder {
        let response: FolderResponse = try await networkService.query(
            procedure: APIEndpoint.Folders.get,
            input: FolderGetRequest(folderId: id),
            token: token
        )
        
        return response.toFolder()
    }
    
    func createFolder(name: String, parentId: String?, token: String) async throws -> Folder {
        let response: FolderResponse = try await networkService.call(
            procedure: APIEndpoint.Folders.create,
            input: FolderCreateRequest(name: name, parentId: parentId),
            token: token
        )
        
        return response.toFolder()
    }
    
    func updateFolder(id: String, name: String?, parentId: String?, token: String) async throws -> Folder {
        let response: FolderResponse = try await networkService.call(
            procedure: APIEndpoint.Folders.update,
            input: FolderUpdateRequest(folderId: id, name: name, parentId: parentId),
            token: token
        )
        
        return response.toFolder()
    }
    
    func deleteFolder(id: String, token: String) async throws {
        let _: FolderDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.Folders.delete,
            input: FolderDeleteRequest(folderId: id),
            token: token
        )
    }
}

// MARK: - API Request/Response Models

private struct FolderGetRequest: Codable {
    let folderId: String
}

private struct FolderResponse: Codable {
    let id: String
    let userId: String
    let name: String
    let parentId: String?
    let createdAt: Date
    let updatedAt: Date
    
    func toFolder() -> Folder {
        Folder(
            id: id,
            name: name,
            parentId: parentId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct FolderCreateRequest: Codable {
    let name: String
    let parentId: String?
}

private struct FolderUpdateRequest: Codable {
    let folderId: String
    let name: String?
    let parentId: String?
}

private struct FolderDeleteRequest: Codable {
    let folderId: String
}

private struct FolderDeleteResponse: Codable {
    let success: Bool
}

// MARK: - Mock Implementation

#if DEBUG
final class MockFolderRepository: FolderRepositoryProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var mockFolders: [Folder] = Folder.mockFolders
    
    func fetchFolders(token: String) async throws -> [Folder] {
        if shouldFail { throw FolderError.folderNotFound }
        return mockFolders
    }
    
    func fetchFolder(id: String, token: String) async throws -> Folder {
        if shouldFail { throw FolderError.folderNotFound }
        return mockFolders.first { $0.id == id } ?? .mock()
    }
    
    func createFolder(name: String, parentId: String?, token: String) async throws -> Folder {
        if shouldFail { throw FolderError.createFailed }
        let folder = Folder(name: name, parentId: parentId)
        mockFolders.append(folder)
        return folder
    }
    
    func updateFolder(id: String, name: String?, parentId: String?, token: String) async throws -> Folder {
        if shouldFail { throw FolderError.updateFailed }
        guard let index = mockFolders.firstIndex(where: { $0.id == id }) else {
            throw FolderError.folderNotFound
        }
        var folder = mockFolders[index]
        if let name = name { folder.name = name }
        if let parentId = parentId { folder.parentId = parentId }
        mockFolders[index] = folder
        return folder
    }
    
    func deleteFolder(id: String, token: String) async throws {
        if shouldFail { throw FolderError.deleteFailed }
        mockFolders.removeAll { $0.id == id }
    }
}
#endif
