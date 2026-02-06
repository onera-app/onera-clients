//
//  SidebarView.swift
//  Onera
//
//  Reusable sidebar for iPad and macOS NavigationSplitView
//

import SwiftUI

struct SidebarView: View {
    
    @Bindable var folderViewModel: FolderViewModel
    @Binding var selectedChatId: String?
    @Binding var selectedSection: SidebarSection
    
    let onNewChat: () -> Void
    let onOpenSettings: () -> Void
    let onNewNote: () -> Void
    let user: User?
    
    /// Callback when a chat is dropped on a folder (chatId, folderId - nil for "All Chats")
    var onMoveChat: ((String, String?) -> Void)?
    
    @State private var isExpanded = true
    @State private var searchText = ""
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// iPad uses different toolbar layout
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        List {
            // Section selector (Chats / Notes)
            sectionSelector
            
            // Show folders only when Chats is selected
            if selectedSection == .chats {
                foldersSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Onera")
        .searchable(text: $searchText, prompt: "Search")
        #if os(iOS)
        .toolbar {
            // Primary action based on selected section
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedSection == .chats {
                    Button {
                        onNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Chat")
                } else {
                    Button {
                        onNewNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Note")
                }
            }
            
            // Account/Settings button - bottom of sidebar on iPad
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    accountButton
                    Spacer()
                }
            }
        }
        #elseif os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    onNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat (⌘N)")
            }
        }
        #endif
    }
    
    // MARK: - Account Button (HIG: Bottom of sidebar)
    
    private var accountButton: some View {
        Button {
            onOpenSettings()
        } label: {
            HStack(spacing: 8) {
                if let user = user {
                    // User avatar
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Text(user.initials)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                    
                    if isRegularWidth {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(user.email)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Image(systemName: "person.circle")
                        .font(.title2)
                }
                
                Spacer()
                
                Image(systemName: "gearshape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .accessibilityLabel("Account and Settings")
    }
    
    // MARK: - Section Selector (Chats / Notes)
    
    @ViewBuilder
    private var sectionSelector: some View {
        Section {
            ForEach(SidebarSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack {
                        Label(section.rawValue, systemImage: section.icon)
                        Spacer()
                        if selectedSection == section {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedSection == section ? theme.accent.opacity(0.15) : Color.clear)
                        .padding(.horizontal, 4)
                )
                #if os(iOS)
                .hoverEffect(.highlight)
                #endif
            }
        } header: {
            Text("Library")
        }
    }
    
    // MARK: - Folders Section
    
    @ViewBuilder
    private var foldersSection: some View {
        Section {
            // Folders list (each is a drop target)
            ForEach(folderViewModel.folders) { folder in
                FolderRowView(
                    folder: folder,
                    onMoveChat: { chatId in
                        onMoveChat?(chatId, folder.id)
                    },
                    onDelete: {
                        folderViewModel.confirmDelete(folderId: folder.id)
                    }
                )
            }
            
            // Add folder button
            Button {
                folderViewModel.newFolderName = "New Folder"
                Task {
                    await folderViewModel.createFolder()
                }
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
                    .foregroundStyle(theme.accent)
            }
            #if os(iOS)
            .hoverEffect(.highlight)
            #endif
        } header: {
            Text("Folders")
        }
    }
}

// MARK: - All Chats Drop Target

private struct AllChatsDropTarget: View {
    let onMoveChat: (String) -> Void
    
    @Environment(\.theme) private var theme
    @State private var isTargeted = false
    @State private var isHovered = false
    
    var body: some View {
        NavigationLink(value: "all") {
            Label("All Chats", systemImage: isTargeted ? "tray.and.arrow.down.fill" : "bubble.left.and.bubble.right")
                .foregroundStyle(isTargeted ? theme.accent : theme.textPrimary)
        }
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .onHover { hovering in
            isHovered = hovering
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? theme.accent.opacity(0.2) : (isHovered ? theme.secondaryBackground.opacity(0.5) : Color.clear))
                .padding(.horizontal, 4)
        )
        .dropDestination(for: String.self) { chatIds, _ in
            for chatId in chatIds {
                onMoveChat(chatId)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargeted = targeted
            }
        }
    }
}

// MARK: - Folder Row View (with Drop Target)

private struct FolderRowView: View {
    let folder: Folder
    let onMoveChat: (String) -> Void
    let onDelete: () -> Void
    
    @Environment(\.theme) private var theme
    @State private var isTargeted = false
    @State private var isHovered = false
    
    var body: some View {
        NavigationLink(value: folder.id) {
            Label(folder.name, systemImage: isTargeted ? "folder.fill.badge.plus" : "folder")
                .foregroundStyle(isTargeted ? theme.accent : theme.textPrimary)
        }
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .onHover { hovering in
            isHovered = hovering
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? theme.accent.opacity(0.2) : (isHovered ? theme.secondaryBackground.opacity(0.5) : Color.clear))
                .padding(.horizontal, 4)
        )
        .dropDestination(for: String.self) { chatIds, _ in
            for chatId in chatIds {
                onMoveChat(chatId)
            }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargeted = targeted
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}



// MARK: - Preview

#if DEBUG
#Preview {
    NavigationSplitView {
        SidebarView(
            folderViewModel: FolderViewModel(
                folderRepository: MockFolderRepository(),
                authService: MockAuthService(),
                cryptoService: CryptoService(),
                secureSession: MockSecureSession()
            ),
            selectedChatId: .constant(nil),
            selectedSection: .constant(.chats),
            onNewChat: {},
            onOpenSettings: {},
            onNewNote: {},
            user: User.mock(),
            onMoveChat: { chatId, folderId in
                print("Move chat \(chatId) to folder \(folderId ?? "none")")
            }
        )
    } detail: {
        Text("Detail")
    }
}
#endif
