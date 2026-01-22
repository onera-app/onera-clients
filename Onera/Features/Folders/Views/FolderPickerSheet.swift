//
//  FolderPickerSheet.swift
//  Onera
//
//  Modal sheet for selecting a folder
//

import SwiftUI

struct FolderPickerSheet: View {
    
    @Bindable var viewModel: FolderViewModel
    @Binding var selectedFolderId: String?
    @Environment(\.dismiss) private var dismiss
    
    var title: String = "Select Folder"
    var allowNone: Bool = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // No folder option
                    if allowNone {
                        FolderPickerRow(
                            name: "No folder",
                            icon: "folder.badge.minus",
                            isSelected: selectedFolderId == nil
                        ) {
                            selectedFolderId = nil
                            dismiss()
                        }
                    }
                    
                    // Folder list
                    ForEach(viewModel.folderTree) { node in
                        FolderPickerNodeView(
                            node: node,
                            viewModel: viewModel,
                            selectedFolderId: $selectedFolderId,
                            depth: 0,
                            onSelect: {
                                dismiss()
                            }
                        )
                    }
                    
                    // Create new folder option
                    if !viewModel.isCreatingFolder {
                        Button {
                            viewModel.startCreatingFolder()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.blue)
                                
                                Text("Create new folder")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // New folder creation row
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                            
                            TextField("Folder name", text: $viewModel.newFolderName)
                                .font(.body)
                                .textFieldStyle(.roundedBorder)
                            
                            Button {
                                Task {
                                    await viewModel.createFolder()
                                }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.green)
                            }
                            .disabled(viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Button {
                                viewModel.cancelCreatingFolder()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if viewModel.folders.isEmpty {
                    await viewModel.loadFolders()
                }
            }
        }
    }
}

// MARK: - Folder Picker Row

private struct FolderPickerRow: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                Text(name)
                    .font(.body)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - Folder Picker Node View

private struct FolderPickerNodeView: View {
    let node: FolderTree
    @Bindable var viewModel: FolderViewModel
    @Binding var selectedFolderId: String?
    let depth: Int
    let onSelect: () -> Void
    
    private var isExpanded: Bool {
        viewModel.isExpanded(node.id)
    }
    
    private var isSelected: Bool {
        selectedFolderId == node.id
    }
    
    private var hasChildren: Bool {
        !node.children.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder row
            Button {
                selectedFolderId = node.id
                onSelect()
            } label: {
                HStack(spacing: 8) {
                    // Expand toggle
                    if hasChildren {
                        Button {
                            viewModel.toggleExpanded(folderId: node.id)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 16)
                    }
                    
                    Image(systemName: "folder.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    
                    Text(node.name)
                        .font(.body)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.leading, CGFloat(depth * 20) + 16)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            
            // Children
            if isExpanded {
                ForEach(node.children) { child in
                    FolderPickerNodeView(
                        node: child,
                        viewModel: viewModel,
                        selectedFolderId: $selectedFolderId,
                        depth: depth + 1,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}

#Preview {
    FolderPickerSheet(
        viewModel: FolderViewModel(
            folderRepository: MockFolderRepository(),
            authService: MockAuthService(),
            cryptoService: CryptoService(),
            secureSession: MockSecureSession()
        ),
        selectedFolderId: .constant(nil)
    )
}
