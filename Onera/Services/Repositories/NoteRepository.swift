//
//  NoteRepository.swift
//  Onera
//
//  Note data repository implementation with E2EE encryption
//  Notes are encrypted directly with the master key (simpler than per-chat keys)
//

import Foundation

// MARK: - Protocol

protocol NoteRepositoryProtocol: Sendable {
    func fetchNotes(token: String, folderId: String?, archived: Bool) async throws -> [NoteSummary]
    func fetchNote(id: String, token: String) async throws -> Note
    func createNote(_ note: Note, token: String) async throws -> String
    func updateNote(_ note: Note, token: String) async throws
    func deleteNote(id: String, token: String) async throws
}

// MARK: - Implementation

final class NoteRepository: NoteRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let networkService: NetworkServiceProtocol
    private let cryptoService: CryptoServiceProtocol
    private let secureSession: SecureSessionProtocol
    
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(
        networkService: NetworkServiceProtocol,
        cryptoService: CryptoServiceProtocol,
        secureSession: SecureSessionProtocol
    ) {
        self.networkService = networkService
        self.cryptoService = cryptoService
        self.secureSession = secureSession
        
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
    
    // MARK: - Notes List
    
    func fetchNotes(token: String, folderId: String? = nil, archived: Bool = false) async throws -> [NoteSummary] {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let input = NoteListRequest(folderId: folderId, archived: archived)
        let response: [EncryptedNoteSummary] = try await networkService.query(
            procedure: APIEndpoint.Notes.list,
            input: input,
            token: token
        )
        
        return response.compactMap { encrypted in
            do {
                return try decryptNoteSummary(encrypted, masterKey: masterKey)
            } catch {
                print("Failed to decrypt note \(encrypted.id): \(error)")
                return nil
            }
        }
    }
    
    // MARK: - Single Note
    
    func fetchNote(id: String, token: String) async throws -> Note {
        guard let masterKey = await secureSession.masterKey else {
            throw E2EEError.sessionLocked
        }
        
        let response: EncryptedNoteResponse = try await networkService.query(
            procedure: APIEndpoint.Notes.get,
            input: NoteGetRequest(noteId: id),
            token: token
        )
        
        return try decryptNote(response, masterKey: masterKey)
    }
    
    func createNote(_ note: Note, token: String) async throws -> String {
        print("[NoteRepository] createNote: id=\(note.id), title='\(note.title)'")
        
        guard let masterKey = await secureSession.masterKey else {
            print("[NoteRepository] createNote: E2EE session locked")
            throw E2EEError.sessionLocked
        }
        
        let encrypted = try encryptNote(note, masterKey: masterKey)
        print("[NoteRepository] createNote: Note encrypted, calling API...")
        
        let response: NoteCreateResponse = try await networkService.call(
            procedure: APIEndpoint.Notes.create,
            input: encrypted,
            token: token
        )
        
        print("[NoteRepository] createNote: Success, new id=\(response.id)")
        return response.id
    }
    
    func updateNote(_ note: Note, token: String) async throws {
        print("[NoteRepository] updateNote: id=\(note.id), title='\(note.title)'")
        
        guard let masterKey = await secureSession.masterKey else {
            print("[NoteRepository] updateNote: E2EE session locked")
            throw E2EEError.sessionLocked
        }
        
        // Encrypt title with master key
        guard let titleData = note.title.data(using: .utf8) else {
            print("[NoteRepository] updateNote: Failed to encode title")
            throw NoteError.encryptionFailed
        }
        let (encryptedTitle, titleNonce) = try cryptoService.encrypt(
            plaintext: titleData,
            key: masterKey
        )
        
        // Encrypt content with master key
        guard let contentData = note.content.data(using: .utf8) else {
            print("[NoteRepository] updateNote: Failed to encode content")
            throw NoteError.encryptionFailed
        }
        let (encryptedContent, contentNonce) = try cryptoService.encrypt(
            plaintext: contentData,
            key: masterKey
        )
        
        print("[NoteRepository] updateNote: Note encrypted, calling API...")
        
        let _: NoteUpdateResponse = try await networkService.call(
            procedure: APIEndpoint.Notes.update,
            input: NoteUpdateRequest(
                noteId: note.id,
                encryptedTitle: encryptedTitle.base64EncodedString(),
                titleNonce: titleNonce.base64EncodedString(),
                encryptedContent: encryptedContent.base64EncodedString(),
                contentNonce: contentNonce.base64EncodedString(),
                folderId: note.folderId,
                pinned: note.pinned,
                archived: note.archived
            ),
            token: token
        )
        
        print("[NoteRepository] updateNote: Success")
    }
    
    func deleteNote(id: String, token: String) async throws {
        let _: NoteDeleteResponse = try await networkService.call(
            procedure: APIEndpoint.Notes.delete,
            input: NoteDeleteRequest(noteId: id),
            token: token
        )
    }
    
    // MARK: - Private Encryption Methods
    
    private func encryptNote(_ note: Note, masterKey: Data) throws -> NoteCreateRequest {
        // Encrypt title with master key
        guard let titleData = note.title.data(using: .utf8) else {
            throw NoteError.encryptionFailed
        }
        let (encryptedTitle, titleNonce) = try cryptoService.encrypt(
            plaintext: titleData,
            key: masterKey
        )
        
        // Encrypt content with master key
        guard let contentData = note.content.data(using: .utf8) else {
            throw NoteError.encryptionFailed
        }
        let (encryptedContent, contentNonce) = try cryptoService.encrypt(
            plaintext: contentData,
            key: masterKey
        )
        
        return NoteCreateRequest(
            encryptedTitle: encryptedTitle.base64EncodedString(),
            titleNonce: titleNonce.base64EncodedString(),
            encryptedContent: encryptedContent.base64EncodedString(),
            contentNonce: contentNonce.base64EncodedString(),
            folderId: note.folderId
        )
    }
    
    private func decryptNote(_ encrypted: EncryptedNoteResponse, masterKey: Data) throws -> Note {
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: encrypted.encryptedTitle),
              let titleNonce = Data(base64Encoded: encrypted.titleNonce) else {
            throw NoteError.decryptionFailed
        }
        
        let titleData = try cryptoService.decrypt(
            ciphertext: encryptedTitle,
            nonce: titleNonce,
            key: masterKey
        )
        
        guard let title = String(data: titleData, encoding: .utf8) else {
            throw NoteError.decryptionFailed
        }
        
        // Decrypt content
        guard let encryptedContent = Data(base64Encoded: encrypted.encryptedContent),
              let contentNonce = Data(base64Encoded: encrypted.contentNonce) else {
            throw NoteError.decryptionFailed
        }
        
        let contentData = try cryptoService.decrypt(
            ciphertext: encryptedContent,
            nonce: contentNonce,
            key: masterKey
        )
        
        guard let content = String(data: contentData, encoding: .utf8) else {
            throw NoteError.decryptionFailed
        }
        
        return Note(
            id: encrypted.id,
            title: title,
            content: content,
            folderId: encrypted.folderId,
            pinned: encrypted.pinned,
            archived: encrypted.archived,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt
        )
    }
    
    private func decryptNoteSummary(_ encrypted: EncryptedNoteSummary, masterKey: Data) throws -> NoteSummary {
        // Decrypt title
        guard let encryptedTitle = Data(base64Encoded: encrypted.encryptedTitle),
              let titleNonce = Data(base64Encoded: encrypted.titleNonce) else {
            throw NoteError.decryptionFailed
        }
        
        let titleData = try cryptoService.decrypt(
            ciphertext: encryptedTitle,
            nonce: titleNonce,
            key: masterKey
        )
        
        guard let title = String(data: titleData, encoding: .utf8) else {
            throw NoteError.decryptionFailed
        }
        
        return NoteSummary(
            id: encrypted.id,
            title: title,
            folderId: encrypted.folderId,
            pinned: encrypted.pinned,
            archived: encrypted.archived,
            createdAt: encrypted.createdAt,
            updatedAt: encrypted.updatedAt
        )
    }
}

// MARK: - API Request/Response Models

private struct NoteListRequest: Codable {
    let folderId: String?
    let archived: Bool
}

private struct NoteGetRequest: Codable {
    let noteId: String
}

private struct EncryptedNoteSummary: Codable {
    let id: String
    let userId: String
    let encryptedTitle: String
    let titleNonce: String
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
}

private struct EncryptedNoteResponse: Codable {
    let id: String
    let userId: String
    let encryptedTitle: String
    let titleNonce: String
    let encryptedContent: String
    let contentNonce: String
    let folderId: String?
    let pinned: Bool
    let archived: Bool
    let createdAt: Date
    let updatedAt: Date
}

private struct NoteCreateRequest: Codable {
    let encryptedTitle: String
    let titleNonce: String
    let encryptedContent: String
    let contentNonce: String
    let folderId: String?
}

private struct NoteCreateResponse: Codable {
    let id: String
}

private struct NoteUpdateRequest: Codable {
    let noteId: String
    let encryptedTitle: String?
    let titleNonce: String?
    let encryptedContent: String?
    let contentNonce: String?
    let folderId: String?
    let pinned: Bool?
    let archived: Bool?
}

private struct NoteUpdateResponse: Codable {
    let id: String
}

private struct NoteDeleteRequest: Codable {
    let noteId: String
}

private struct NoteDeleteResponse: Codable {
    let success: Bool
}

// MARK: - Mock Implementation

#if DEBUG
final class MockNoteRepository: NoteRepositoryProtocol, @unchecked Sendable {
    
    var shouldFail = false
    var mockNotes: [NoteSummary] = []
    var mockNote: Note?
    
    func fetchNotes(token: String, folderId: String?, archived: Bool) async throws -> [NoteSummary] {
        if shouldFail { throw NoteError.decryptionFailed }
        return mockNotes
    }
    
    func fetchNote(id: String, token: String) async throws -> Note {
        if shouldFail { throw NoteError.noteNotFound }
        return mockNote ?? .mock()
    }
    
    func createNote(_ note: Note, token: String) async throws -> String {
        if shouldFail { throw NoteError.createFailed }
        return UUID().uuidString
    }
    
    func updateNote(_ note: Note, token: String) async throws {
        if shouldFail { throw NoteError.updateFailed }
    }
    
    func deleteNote(id: String, token: String) async throws {
        if shouldFail { throw NoteError.deleteFailed }
    }
}
#endif
