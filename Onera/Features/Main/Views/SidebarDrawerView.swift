//
//  SidebarDrawerView.swift
//  Onera
//
//  Slide-out drawer sidebar
//

import SwiftUI

struct SidebarDrawerView: View {
    
    @Environment(\.theme) private var theme
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
            .background(theme.background)
    }
    
    // MARK: - Drawer Content
    
    private var drawerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.top, OneraSpacing.lg)
                .padding(.bottom, OneraSpacing.md)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Navigation items
                    navigationItems
                        .padding(.bottom, OneraSpacing.xxl)
                    
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
        HStack(alignment: .center, spacing: OneraSpacing.compact) {
            // Search field pill with liquid glass effect
            HStack(spacing: OneraSpacing.compact) {
                Image(systemName: "magnifyingglass")
                    .font(OneraTypography.iconLabel)
                    .foregroundStyle(theme.textSecondary)
                
                TextField("", text: $searchText, prompt: Text("Search").foregroundStyle(theme.textSecondary))
                    .font(OneraTypography.body)
                    .foregroundStyle(theme.textPrimary)
                    .accessibilityIdentifier("searchField")
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(.vertical, OneraSpacing.compact)
            .padding(.horizontal, OneraSpacing.comfortable)
            .glassEffect()
            
            // New chat button with liquid glass effect
            Button {
                onNewChat()
                withAnimation { isOpen = false }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(OneraTypography.iconLarge)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .glassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("newChatButton")
        }
    }
    
    // MARK: - Navigation Items
    
    private var navigationItems: some View {
        VStack(spacing: OneraSpacing.xxs) {
            // Notes
            NavigationItemRow(
                theme: theme,
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
                    withAnimation(OneraAnimation.springQuick) {
                        showingFolders.toggle()
                    }
                } label: {
                    HStack(spacing: OneraSpacing.iconTextGap) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.textSecondary)
                        
                        Text("Folders")
                            .font(OneraTypography.body)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .rotationEffect(.degrees(showingFolders ? 90 : 0))
                    }
                    .padding(.horizontal, OneraSpacing.md)
                    .padding(.vertical, OneraSpacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: OneraRadius.medium)
                            .fill(showingFolders ? theme.secondaryBackground.opacity(0.5) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)
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
                        .padding(.leading, OneraSpacing.xxl)
                        .padding(.top, OneraSpacing.xxs)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
            }
        }
        .padding(.horizontal, OneraSpacing.sm)
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
            .font(OneraTypography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(theme.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, OneraSpacing.xl)
            .padding(.top, OneraSpacing.xl)
            .padding(.bottom, OneraSpacing.sm)
    }
    
    private var loadingView: some View {
        VStack(spacing: OneraSpacing.md) {
            ProgressView()
            Text("Loading chats...")
                .font(OneraTypography.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OneraSpacing.max)
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: OneraSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(OneraTypography.title)
                .foregroundStyle(theme.warning)
            
            Text("Failed to load chats")
                .font(OneraTypography.subheadline)
                .foregroundStyle(theme.textSecondary)
            
            Text(error.localizedDescription)
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await onRefresh() }
            } label: {
                Text("Retry")
                    .font(OneraTypography.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OneraSpacing.lg)
        .padding(.vertical, OneraSpacing.max)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: OneraSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(OneraTypography.title)
                .foregroundStyle(theme.textSecondary)
            
            Text("No chats yet")
                .font(OneraTypography.subheadline)
                .foregroundStyle(theme.textSecondary)
            
            Text("Start a new conversation")
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OneraSpacing.max)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Button {
            onOpenSettings()
        } label: {
            HStack(spacing: OneraSpacing.compact) {
                if let user = user {
                    userAvatar(user)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.textSecondary)
                }
                
                // Show only first name
                Text(user?.firstName ?? "Sign In")
                    .font(OneraTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textPrimary)
                
                // Settings indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, OneraSpacing.comfortable)
            .padding(.vertical, OneraSpacing.compact)
            .glassEffect()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OneraSpacing.lg)
        .padding(.vertical, OneraSpacing.md)
        .accessibilityIdentifier("settingsButton")
    }
    
    private func userAvatar(_ user: User) -> some View {
        ZStack {
            if let imageURL = user.imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    theme.secondaryBackground
                }
            } else {
                theme.secondaryBackground
                Text(user.initials)
                    .font(OneraTypography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.background)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

// MARK: - Navigation Item Row

private struct NavigationItemRow: View {
    let theme: ThemeColors
    let icon: String
    let title: String
    let isSelected: Bool
    var accessibilityId: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: OneraSpacing.iconTextGap) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                
                Text(title)
                    .font(OneraTypography.body)
                    .fontWeight(isSelected ? .medium : .regular)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.medium)
                    .fill(isSelected ? theme.secondaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .accessibilityIdentifier(accessibilityId ?? title.lowercased())
    }
}

// MARK: - Chat History Row

private struct ChatHistoryRow: View {
    @Environment(\.theme) private var theme
    let chat: ChatSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: OneraSpacing.iconTextGap) {
                Text(chat.title)
                    .font(OneraTypography.body)
                    .lineLimit(1)
                    .foregroundStyle(theme.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.medium)
                    .fill(isSelected ? theme.secondaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, OneraSpacing.sm)
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
