//
//  FolderTreeView.swift
//  Onera
//
//  Hierarchical folder tree view
//

import SwiftUI

struct FolderTreeView: View {
    
    @Bindable var viewModel: FolderViewModel
    let selectedFolderId: String?
    let onSelectFolder: (String?) -> Void
    var showAllOption: Bool = true
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "All items" option
            if showAllOption {
                allItemsRow
            }
            
            // Folder tree
            ForEach(viewModel.folderTree) { node in
                FolderNodeView(
                    node: node,
                    viewModel: viewModel,
                    selectedFolderId: selectedFolderId,
                    onSelectFolder: onSelectFolder,
                    depth: 0
                )
            }
            
            // Create new folder row
            if viewModel.isCreatingFolder && viewModel.newFolderParentId == nil {
                newFolderRow
            }
            
            // New folder button
            if !viewModel.isCreatingFolder {
                newFolderButton
            }
        }
        .alert("Delete folder?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteFolder()
                }
            }
        } message: {
            Text("Items in this folder will be moved to the root level.")
        }
        .task {
            await viewModel.loadFolders()
        }
    }
    
    // MARK: - All Items Row
    
    private var allItemsRow: some View {
        Button {
            onSelectFolder(nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("All items")
                    .font(.subheadline)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.standard)
                    .fill(selectedFolderId == nil ? theme.secondaryBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
    
    // MARK: - New Folder Row
    
    private var newFolderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("Folder name", text: $viewModel.newFolderName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task {
                        await viewModel.createFolder()
                    }
                }
            
            Button {
                Task {
                    await viewModel.createFolder()
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
            }
            .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button {
                viewModel.cancelCreatingFolder()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, OneraSpacing.md)
        .padding(.vertical, OneraSpacing.sm)
    }
    
    // MARK: - New Folder Button
    
    private var newFolderButton: some View {
        Button {
            viewModel.startCreatingFolder()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.subheadline)
                
                Text("New folder")
                    .font(.subheadline)
                
                Spacer()
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Folder Node View

private struct FolderNodeView: View {
    let node: FolderTree
    @Bindable var viewModel: FolderViewModel
    let selectedFolderId: String?
    let onSelectFolder: (String?) -> Void
    let depth: Int
    @Environment(\.theme) private var theme
    
    private var isExpanded: Bool {
        viewModel.isExpanded(node.id)
    }
    
    private var isSelected: Bool {
        selectedFolderId == node.id
    }
    
    private var isEditing: Bool {
        viewModel.editingFolderId == node.id
    }
    
    private var hasChildren: Bool {
        !node.children.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder row
            HStack(spacing: 4) {
                // Expand toggle
                Button {
                    viewModel.toggleExpanded(folderId: node.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .opacity(hasChildren ? 1 : 0)
                }
                .buttonStyle(.plain)
                .frame(width: 20)
                
                // Folder icon
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                // Name or edit field
                if isEditing {
                    TextField("Folder name", text: $viewModel.editingName)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task {
                                await viewModel.saveEdit()
                            }
                        }
                } else {
                    Text(node.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Action buttons (shown on hover/selection)
                if !isEditing {
                    folderActions
                }
            }
            .padding(.leading, CGFloat(depth * 16) + 8)
            .padding(.trailing, OneraSpacing.sm)
            .padding(.vertical, OneraSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: OneraRadius.standard)
                    .fill(isSelected ? theme.secondaryBackground : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectFolder(node.id)
            }
            .contextMenu {
                Button {
                    viewModel.startCreatingFolder(parentId: node.id)
                    viewModel.expandedFolders.insert(node.id)
                } label: {
                    Label("Add Subfolder", systemImage: "folder.badge.plus")
                }
                
                Button {
                    viewModel.startEditing(folder: node.folder)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    viewModel.confirmDelete(folderId: node.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Creating subfolder
            if viewModel.isCreatingFolder && viewModel.newFolderParentId == node.id {
                subfolderCreationRow
            }
            
            // Children
            if isExpanded {
                ForEach(node.children) { child in
                    FolderNodeView(
                        node: child,
                        viewModel: viewModel,
                        selectedFolderId: selectedFolderId,
                        onSelectFolder: onSelectFolder,
                        depth: depth + 1
                    )
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private var folderActions: some View {
        // Show a "more" menu button that's always visible (but dimmed when not selected)
        Menu {
            Button {
                viewModel.startCreatingFolder(parentId: node.id)
                viewModel.expandedFolders.insert(node.id)
            } label: {
                Label("Add Subfolder", systemImage: "folder.badge.plus")
            }
            
            Button {
                viewModel.startEditing(folder: node.folder)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                viewModel.confirmDelete(folderId: node.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isSelected ? 1 : 0.5)
    }
    
    // MARK: - Subfolder Creation
    
    private var subfolderCreationRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            TextField("Folder name", text: $viewModel.newFolderName)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task {
                        await viewModel.createFolder()
                    }
                }
            
            Button {
                Task {
                    await viewModel.createFolder()
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
            }
            .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            Button {
                viewModel.cancelCreatingFolder()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, CGFloat((depth + 1) * 16) + 28)
        .padding(.trailing, OneraSpacing.sm)
        .padding(.vertical, OneraSpacing.xs)
    }
}

#if DEBUG
#Preview {
    FolderTreeView(
        viewModel: FolderViewModel(
            folderRepository: MockFolderRepository(),
            authService: MockAuthService(),
            cryptoService: CryptoService(),
            secureSession: MockSecureSession()
        ),
        selectedFolderId: nil,
        onSelectFolder: { _ in }
    )
    .frame(width: 280)
    .padding()
}
#endif