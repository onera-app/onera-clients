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
    
    let onNewChat: () -> Void
    let onOpenSettings: () -> Void
    let onOpenNotes: () -> Void
    let user: User?
    
    @State private var isExpanded = true
    @State private var searchText = ""
    @Environment(\.theme) private var theme
    
    var body: some View {
        List {
            // User section
            if let user = user {
                userSection(user)
            }
            
            // Quick actions
            quickActionsSection
            
            // Folders section
            foldersSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Onera")
        .searchable(text: $searchText, prompt: "Search")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        onNewChat()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        onOpenNotes()
                    } label: {
                        Label("Notes", systemImage: "note.text")
                    }
                    
                    Divider()
                    
                    Button {
                        onOpenSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
    
    // MARK: - User Section
    
    @ViewBuilder
    private func userSection(_ user: User) -> some View {
        Section {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(user.initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.headline)
                    
                    Text(user.email ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Quick Actions Section
    
    @ViewBuilder
    private var quickActionsSection: some View {
        Section {
            Button {
                onNewChat()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
            }
            .foregroundStyle(theme.textPrimary)
            
            Button {
                onOpenNotes()
            } label: {
                Label("Notes", systemImage: "note.text")
            }
            .foregroundStyle(theme.textPrimary)
            
            Button {
                onOpenSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .foregroundStyle(theme.textPrimary)
        }
    }
    
    // MARK: - Folders Section
    
    @ViewBuilder
    private var foldersSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                // All Chats
                NavigationLink(value: "all") {
                    Label("All Chats", systemImage: "bubble.left.and.bubble.right")
                }
                
                // Folders
                ForEach(folderViewModel.folders) { folder in
                    NavigationLink(value: folder.id) {
                        Label(folder.name, systemImage: "folder")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            folderViewModel.confirmDelete(folderId: folder.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                
                // Add folder button
                Button {
                    folderViewModel.newFolderName = "New Folder"
                    Task {
                        await folderViewModel.createFolder()
                    }
                } label: {
                    Label("Add Folder", systemImage: "plus")
                        .foregroundStyle(theme.accent)
                }
            } label: {
                Label("Folders", systemImage: "folder")
                    .font(.headline)
            }
        } header: {
            Text("Library")
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
            onNewChat: {},
            onOpenSettings: {},
            onOpenNotes: {},
            user: User.mock()
        )
    } detail: {
        Text("Detail")
    }
}
#endif
