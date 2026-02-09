//
//  ChatListViewModel.swift
//  Onera
//
//  Chat list/sidebar view model
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatListViewModel {
    
    // MARK: - State
    
    private(set) var chats: [ChatSummary] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var groupedChats: [(ChatGroup, [ChatSummary])] {
        let grouped = Dictionary(grouping: chats) { $0.group }
        let orderedGroups: [ChatGroup] = [.today, .yesterday, .previousWeek, .previousMonth]
        
        var result: [(ChatGroup, [ChatSummary])] = []
        
        // Add standard groups in order
        for group in orderedGroups {
            if let items = grouped[group], !items.isEmpty {
                let sorted = items.sorted { $0.updatedAt > $1.updatedAt }
                result.append((group, sorted))
            }
        }
        
        // Add older groups sorted by month
        let olderGroups = grouped.keys
            .compactMap { group -> (ChatGroup, [ChatSummary])? in
                if case .older = group, let items = grouped[group] {
                    let sorted = items.sorted { $0.updatedAt > $1.updatedAt }
                    return (group, sorted)
                }
                return nil
            }
            .sorted { lhs, rhs in
                guard case .older(let month1) = lhs.0,
                      case .older(let month2) = rhs.0 else { return false }
                return month1 > month2
            }
        
        result.append(contentsOf: olderGroups)
        
        return result
    }
    
    var isEmpty: Bool {
        chats.isEmpty && !isLoading
    }
    
    // MARK: - Dependencies
    
    private let authService: AuthServiceProtocol
    private let chatRepository: ChatRepositoryProtocol
    
    // MARK: - Initialization
    
    init(
        authService: AuthServiceProtocol,
        chatRepository: ChatRepositoryProtocol
    ) {
        self.authService = authService
        self.chatRepository = chatRepository
    }
    
    // MARK: - Actions
    
    func loadChats() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            print("[ChatListViewModel] Fetching chats with token...")
            chats = try await chatRepository.fetchChats(token: token)
            print("[ChatListViewModel] Fetched \(chats.count) chats")
        } catch {
            print("[ChatListViewModel] Error fetching chats: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteChat(_ id: String) async {
        do {
            let token = try await authService.getToken()
            try await chatRepository.deleteChat(id: id, token: token)
            chats.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
    }
    
    func addOrUpdateChat(_ summary: ChatSummary) {
        if let index = chats.firstIndex(where: { $0.id == summary.id }) {
            chats[index] = summary
        } else {
            chats.insert(summary, at: 0)
        }
    }
    
    func removeChat(_ id: String) {
        chats.removeAll { $0.id == id }
    }
    
    func togglePinned(_ chat: ChatSummary) async {
        let newPinned = !chat.pinned
        do {
            let token = try await authService.getToken()
            try await chatRepository.updateChatPinned(chatId: chat.id, pinned: newPinned, token: token)
            // Update local state
            if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                chats[index] = ChatSummary(
                    id: chat.id,
                    title: chat.title,
                    createdAt: chat.createdAt,
                    updatedAt: chat.updatedAt,
                    folderId: chat.folderId,
                    pinned: newPinned,
                    archived: chat.archived
                )
            }
        } catch {
            self.error = error
        }
    }
    
    func toggleArchived(_ chat: ChatSummary) async {
        let newArchived = !chat.archived
        do {
            let token = try await authService.getToken()
            try await chatRepository.updateChatArchived(chatId: chat.id, archived: newArchived, token: token)
            // Update local state
            if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                chats[index] = ChatSummary(
                    id: chat.id,
                    title: chat.title,
                    createdAt: chat.createdAt,
                    updatedAt: chat.updatedAt,
                    folderId: chat.folderId,
                    pinned: chat.pinned,
                    archived: newArchived
                )
            }
        } catch {
            self.error = error
        }
    }
    
    func moveChatToFolder(_ chat: ChatSummary, folderId: String?) async {
        do {
            let token = try await authService.getToken()
            try await chatRepository.updateChatFolder(chatId: chat.id, folderId: folderId, token: token)
            // Update local state
            if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                chats[index] = ChatSummary(
                    id: chat.id,
                    title: chat.title,
                    createdAt: chat.createdAt,
                    updatedAt: chat.updatedAt,
                    folderId: folderId,
                    pinned: chat.pinned,
                    archived: chat.archived
                )
            }
        } catch {
            self.error = error
        }
    }
}
