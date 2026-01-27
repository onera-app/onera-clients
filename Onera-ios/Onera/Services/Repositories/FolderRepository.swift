//
//  FolderRepository.swift
//  Onera
//
//  Folder data repository implementation
//  Note: Folder names are encrypted client-side using E2EE
//

import Foundation

// MARK: - Protocol

protocol FolderRepositoryProtocol: Sendable {
    /// Fetches all folders (returns encrypted data to be decrypted by caller)
    func fetchFolders(token: String) async throws -> [EncryptedFolderResponse]
    
    /// Fetches a single folder (returns encrypted data to be decrypted by caller)
    func fetchFolder(id: String, token: String) async throws -> EncryptedFolderResponse
    
    /// Creates a folder with encrypted name
    func createFolder(encryptedName: String, nameNonce: String, parentId: String?, token: String) async throws -> EncryptedFolderResponse
    
    /// Updates a folder with encrypted name
    func updateFolder(id: String, encryptedName: String?, nameNonce: String?, parentId: String?, token: String) async throws -> EncryptedFolderResponse
    
    /// Deletes a folder
    func deleteFolder(id: String, token: String) async throws
}

// MARK: - Encrypted Folder Response (from server)

struct EncryptedFolderResponse: Codable, Sendable {
    let id: String
    let userId: String
    let encryptedName: String?
    let nameNonce: String?
    let parentId: String?
    let createdAt: Date
    let updatedAt: Date
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
    
    func fetchFolders(token: String) async throws -> [EncryptedFolderResponse] {
        return try await networkService.call(
            procedure: APIEndpoint.Folders.list,
            token: token
        )
    }
    
    // MARK: - Single Folder
    
    func fetchFolder(id: String, token: String) async throws -> EncryptedFolderResponse {
        return try await networkService.query(
            procedure: APIEndpoint.Folders.get,
            input: FolderGetRequest(folderId: id),
            token: token
        )
    }
    
    func createFolder(encryptedName: String, nameNonce: String, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        return try await networkService.call(
            procedure: APIEndpoint.Folders.create,
            input: FolderCreateRequest(
                encryptedName: encryptedName,
                nameNonce: nameNonce,
                parentId: parentId
            ),
            token: token
        )
    }
    
    func updateFolder(id: String, encryptedName: String?, nameNonce: String?, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        return try await networkService.call(
            procedure: APIEndpoint.Folders.update,
            input: FolderUpdateRequest(
                folderId: id,
                encryptedName: encryptedName,
                nameNonce: nameNonce,
                parentId: parentId
            ),
            token: token
        )
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

private struct FolderCreateRequest: Codable {
    let encryptedName: String
    let nameNonce: String
    let parentId: String?
}

private struct FolderUpdateRequest: Codable {
    let folderId: String
    let encryptedName: String?
    let nameNonce: String?
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
    var mockEncryptedFolders: [EncryptedFolderResponse] = EncryptedFolderResponse.mockFolders
    
    func fetchFolders(token: String) async throws -> [EncryptedFolderResponse] {
        if shouldFail { throw FolderError.folderNotFound }
        return mockEncryptedFolders
    }
    
    func fetchFolder(id: String, token: String) async throws -> EncryptedFolderResponse {
        if shouldFail { throw FolderError.folderNotFound }
        return mockEncryptedFolders.first { $0.id == id } ?? .mock()
    }
    
    func createFolder(encryptedName: String, nameNonce: String, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        if shouldFail { throw FolderError.createFailed }
        let folder = EncryptedFolderResponse(
            id: UUID().uuidString,
            userId: "mock-user",
            encryptedName: encryptedName,
            nameNonce: nameNonce,
            parentId: parentId,
            createdAt: Date(),
            updatedAt: Date()
        )
        mockEncryptedFolders.append(folder)
        return folder
    }
    
    func updateFolder(id: String, encryptedName: String?, nameNonce: String?, parentId: String?, token: String) async throws -> EncryptedFolderResponse {
        if shouldFail { throw FolderError.updateFailed }
        guard let index = mockEncryptedFolders.firstIndex(where: { $0.id == id }) else {
            throw FolderError.folderNotFound
        }
        let existing = mockEncryptedFolders[index]
        let folder = EncryptedFolderResponse(
            id: existing.id,
            userId: existing.userId,
            encryptedName: encryptedName ?? existing.encryptedName,
            nameNonce: nameNonce ?? existing.nameNonce,
            parentId: parentId ?? existing.parentId,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        mockEncryptedFolders[index] = folder
        return folder
    }
    
    func deleteFolder(id: String, token: String) async throws {
        if shouldFail { throw FolderError.deleteFailed }
        mockEncryptedFolders.removeAll { $0.id == id }
    }
}

extension EncryptedFolderResponse {
    static func mock(
        id: String = UUID().uuidString,
        encryptedName: String = "mock-encrypted-name",
        nameNonce: String = "mock-nonce",
        parentId: String? = nil
    ) -> EncryptedFolderResponse {
        EncryptedFolderResponse(
            id: id,
            userId: "mock-user",
            encryptedName: encryptedName,
            nameNonce: nameNonce,
            parentId: parentId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var mockFolders: [EncryptedFolderResponse] {
        let workId = UUID().uuidString
        return [
            EncryptedFolderResponse.mock(id: workId, encryptedName: "encrypted-work"),
            EncryptedFolderResponse.mock(encryptedName: "encrypted-personal"),
            EncryptedFolderResponse.mock(encryptedName: "encrypted-projects", parentId: workId),
            EncryptedFolderResponse.mock(encryptedName: "encrypted-archived")
        ]
    }
}
#endif
