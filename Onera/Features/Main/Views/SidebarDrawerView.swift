//
//  SidebarDrawerView.swift
//  Onera
//
//  Slide-out drawer sidebar
//

import SwiftUI

struct SidebarDrawerView: View {
    
    @Binding var isOpen: Bool
    @Binding var selectedChatId: String?
    
    let chats: [ChatSummary]
    let groupedChats: [(ChatGroup, [ChatSummary])]
    let isLoading: Bool
    let error: Error?
    let user: User?
    let folderViewModel: FolderViewModel?
    let onSelectChat: (String) -> Void
    let onNewChat: () -> Void
    let onDeleteChat: (String) async -> Void
    let onOpenSettings: () -> Void
    let onRefresh: () async -> Void
    let onOpenNotes: (() -> Void)?
    
    @State private var searchText = ""
    @State private var showingFolders = false
    @State private var selectedFolderId: String?
    
    private var filteredGroupedChats: [(ChatGroup, [ChatSummary])] {
        if searchText.isEmpty {
            return groupedChats
        }
        
        return groupedChats.compactMap { group, chats in
            let filtered = chats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            return filtered.isEmpty ? nil : (group, filtered)
        }
    }
    
    var body: some View {
        drawerContent
            .background(Color(.systemBackground))
    }
    
    // MARK: - Drawer Content
    
    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Navigation items
                    navigationItems
                        .padding(.bottom, 24)
                    
                    // Chat history
                    chatHistoryList
                }
            }
            
            // Footer
            footerSection
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(alignment: .center, spacing: 10) {
            // Search field pill
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(.systemGray))
                
                TextField("", text: $searchText, prompt: Text("Search").foregroundStyle(Color(.systemGray)))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("searchField")
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.systemGray))
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // New chat button (separate from search, no background)
            Button {
                onNewChat()
                withAnimation { isOpen = false }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(height: 40)
            }
            .accessibilityIdentifier("newChatButton")
        }
    }
    
    // MARK: - Navigation Items
    
    private var navigationItems: some View {
        VStack(spacing: 4) {
            // Notes
            NavigationItemRow(
                icon: "note.text",
                title: "Notes",
                isSelected: false,
                accessibilityId: "notesButton"
            ) {
                onOpenNotes?()
            }
            
            // Folders section - styled to match NavigationItemRow
            VStack(spacing: 0) {
                // Folders header row
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingFolders.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                        
                        Text("Folders")
                            .font(.body)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showingFolders ? 90 : 0))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showingFolders ? Color(.secondarySystemBackground).opacity(0.5) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("foldersSection")
                
                // Expanded folder tree
                if showingFolders {
                    if let folderViewModel = folderViewModel {
                        FolderTreeView(
                            viewModel: folderViewModel,
                            selectedFolderId: selectedFolderId,
                            onSelectFolder: { folderId in
                                selectedFolderId = folderId
                                // TODO: Filter chats by folder when implemented
                            },
                            showAllOption: false
                        )
                        .padding(.leading, 24)
                        .padding(.top, 4)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Chat History
    
    private var chatHistoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Loading state
            if isLoading && chats.isEmpty {
                loadingView
            }
            // Error state
            else if let error = error, chats.isEmpty {
                errorView(error)
            }
            // Empty state
            else if chats.isEmpty && !isLoading {
                emptyStateView
            }
            // Chat list with section headers
            else {
                ForEach(filteredGroupedChats, id: \.0) { group, groupChats in
                    // Section header
                    sectionHeader(group.displayName)
                    
                    ForEach(groupChats) { chat in
                        ChatHistoryRow(
                            chat: chat,
                            isSelected: selectedChatId == chat.id,
                            onSelect: {
                                onSelectChat(chat.id)
                                withAnimation { isOpen = false }
                            },
                            onDelete: {
                                Task { await onDeleteChat(chat.id) }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading chats...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            
            Text("Failed to load chats")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await onRefresh() }
            } label: {
                Text("Retry")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No chats yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Start a new conversation")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Button {
            onOpenSettings()
        } label: {
            HStack(spacing: 12) {
                if let user = user {
                    userAvatar(user)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
                
                Text(user?.displayName ?? "Sign In")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
        }
        .padding(16)
        .accessibilityIdentifier("settingsButton")
    }
    
    private func userAvatar(_ user: User) -> some View {
        ZStack {
            if let imageURL = user.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray3)
                }
            } else {
                Color(.systemGray3)
                Text(user.initials)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(.systemBackground))
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

// MARK: - Navigation Item Row

private struct NavigationItemRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var accessibilityId: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .medium : .regular)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(.secondarySystemBackground) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityIdentifier(accessibilityId ?? title.lowercased())
    }
}

// MARK: - Chat History Row

private struct ChatHistoryRow: View {
    let chat: ChatSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(chat.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(.secondarySystemBackground) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityIdentifier("chatRow_\(chat.id)")
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete Chat",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this chat?")
        }
    }
}
