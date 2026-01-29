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
    let onMoveChatToFolder: ((String, String?) async -> Void)?
    let onOpenSettings: () -> Void
    let onRefresh: () async -> Void
    let onOpenNotes: (() -> Void)?
    
    @State private var searchText = ""
    @State private var showingFolders = false
    @State private var selectedFolderId: String?
    @State private var settingsTrigger = false
    @State private var chatToMoveToFolder: ChatSummary?
    
    private var filteredGroupedChats: [(ChatGroup, [ChatSummary])] {
        var result = groupedChats
        
        // Filter by folder if selected
        if let folderId = selectedFolderId {
            result = result.compactMap { group, chats in
                let filtered = chats.filter { $0.folderId == folderId }
                return filtered.isEmpty ? nil : (group, filtered)
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.compactMap { group, chats in
                let filtered = chats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
                return filtered.isEmpty ? nil : (group, filtered)
            }
        }
        
        return result
    }
    
    var body: some View {
        drawerContent
            .background(theme.background)
            .sheet(item: $chatToMoveToFolder) { chat in
                if let folderViewModel = folderViewModel {
                    FolderPickerSheet(
                        viewModel: folderViewModel,
                        selectedFolderId: Binding(
                            get: { chat.folderId },
                            set: { newFolderId in
                                Task {
                                    await onMoveChatToFolder?(chat.id, newFolderId)
                                }
                            }
                        ),
                        title: "Move to Folder",
                        allowNone: true
                    )
                    .presentationDetents([.medium, .large])
                }
            }
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
        // Search field pill with liquid glass effect
        HStack(spacing: OneraSpacing.compact) {
            Image(systemName: "magnifyingglass")
                .font(OneraTypography.iconLabel)
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)
            
            TextField("", text: $searchText, prompt: Text("Search").foregroundStyle(theme.textSecondary))
                .font(OneraTypography.body)
                .foregroundStyle(theme.textPrimary)
                .accessibilityIdentifier("searchField")
                .accessibilityLabel("Search chats")
                .accessibilityHint("Filter chat history by title")
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the search text")
            }
        }
        .padding(.vertical, OneraSpacing.compact)
        .padding(.horizontal, OneraSpacing.comfortable)
        .oneraGlass()
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
                            .accessibilityHidden(true)
                        
                        Text("Folders")
                            .font(OneraTypography.body)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                            .rotationEffect(.degrees(showingFolders ? 90 : 0))
                            .accessibilityHidden(true)
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
                .sensoryFeedback(.selection, trigger: showingFolders)
                .foregroundStyle(theme.textPrimary)
                .accessibilityIdentifier("foldersSection")
                .accessibilityLabel("Folders")
                .accessibilityHint(showingFolders ? "Double tap to collapse" : "Double tap to expand")
                .accessibilityValue(showingFolders ? "Expanded" : "Collapsed")
                
                // Expanded folder tree
                if showingFolders {
                    if let folderViewModel = folderViewModel {
                        FolderTreeView(
                            viewModel: folderViewModel,
                            selectedFolderId: selectedFolderId,
                            onSelectFolder: { folderId in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    // Toggle: if same folder selected, deselect to show all
                                    if selectedFolderId == folderId {
                                        selectedFolderId = nil
                                    } else {
                                        selectedFolderId = folderId
                                    }
                                }
                            },
                            showAllOption: true
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
                            canMoveToFolder: folderViewModel != nil && onMoveChatToFolder != nil,
                            onSelect: {
                                onSelectChat(chat.id)
                                withAnimation { isOpen = false }
                            },
                            onDelete: {
                                Task { await onDeleteChat(chat.id) }
                            },
                            onMoveToFolder: {
                                chatToMoveToFolder = chat
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
                .accessibilityLabel("Loading chats")
            Text("Loading chats...")
                .font(OneraTypography.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OneraSpacing.max)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading chat history")
    }
    
    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Failed to load chats", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button {
                Task { await onRefresh() }
            } label: {
                Text("Retry")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Attempts to load chats again")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, OneraSpacing.lg)
        .padding(.vertical, OneraSpacing.max)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No chats yet",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Start a new conversation")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, OneraSpacing.max)
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Button {
            settingsTrigger.toggle()
            onOpenSettings()
        } label: {
            HStack(spacing: OneraSpacing.compact) {
                if let user = user {
                    userAvatar(user)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
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
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, OneraSpacing.comfortable)
            .padding(.vertical, OneraSpacing.compact)
            .oneraGlass()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: settingsTrigger)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OneraSpacing.lg)
        .padding(.vertical, OneraSpacing.md)
        .accessibilityIdentifier("settingsButton")
        .accessibilityLabel("Settings for \(user?.firstName ?? "account")")
        .accessibilityHint("Opens settings and profile options")
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
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(OneraTypography.body)
                    .fontWeight(isSelected ? .medium : .regular)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: AccessibilitySize.minTouchTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.medium)
                    .fill(isSelected ? theme.secondaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .accessibilityIdentifier(accessibilityId ?? title.lowercased())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Chat History Row

private struct ChatHistoryRow: View {
    @Environment(\.theme) private var theme
    let chat: ChatSummary
    let isSelected: Bool
    var canMoveToFolder: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void
    var onMoveToFolder: (() -> Void)?
    
    @State private var showDeleteConfirmation = false
    @State private var selectionTrigger = false
    
    var body: some View {
        Button {
            selectionTrigger.toggle()
            onSelect()
        } label: {
            HStack(spacing: OneraSpacing.iconTextGap) {
                Text(chat.title)
                    .font(OneraTypography.body)
                    .lineLimit(1)
                    .foregroundStyle(theme.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.compact)
            .frame(maxWidth: .infinity, minHeight: AccessibilitySize.minTouchTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.medium)
                    .fill(isSelected ? theme.secondaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .padding(.horizontal, OneraSpacing.sm)
        .accessibilityIdentifier("chatRow_\(chat.id)")
        .accessibilityLabel(chat.title)
        .accessibilityHint("Opens this conversation")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .contextMenu {
            if canMoveToFolder {
                Button {
                    onMoveToFolder?()
                } label: {
                    Label(chat.folderId == nil ? "Move to Folder" : "Change Folder", systemImage: "folder")
                }
            }
            
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
