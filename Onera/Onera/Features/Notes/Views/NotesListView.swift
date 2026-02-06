//
//  NotesListView.swift
//  Onera
//
//  List view for displaying notes
//

import SwiftUI

struct NotesListView: View {
    
    @Bindable var viewModel: NotesViewModel
    var folderViewModel: FolderViewModel?
    
    /// When true, note editor opens in a sheet. When false, parent handles editor display (e.g., iPad detail column).
    var showEditorInSheet: Bool = true
    
    @State private var showFolderFilter = false
    @State private var selectedFilterFolderId: String?
    @State private var selectedNoteId: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    /// iPad uses NavigationLink, iPhone uses sheet
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        List(selection: $selectedNoteId) {
            // Folder filter header
            if folderViewModel != nil {
                folderFilterSection
            }
            
            if viewModel.filteredNotes.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                notesList
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("Notes")
        .searchable(text: $viewModel.searchText, prompt: "Search notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityIdentifier("createNoteButton")
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        viewModel.toggleArchived()
                    } label: {
                        Label(
                            viewModel.showArchived ? "Show Active" : "Show Archived",
                            systemImage: viewModel.showArchived ? "tray.full" : "archivebox"
                        )
                    }
                    
                    if folderViewModel != nil {
                        Divider()
                        
                        Button {
                            showFolderFilter = true
                        } label: {
                            Label("Filter by Folder", systemImage: "folder")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await viewModel.refreshNotes()
        }
        // Sheet for note editor - only when showEditorInSheet is true (iPad detail column handles it otherwise)
        .sheet(isPresented: Binding(
            get: { showEditorInSheet && viewModel.showNoteEditor },
            set: { if !$0 { viewModel.showNoteEditor = false } }
        )) {
            NavigationStack {
                NoteEditorView(viewModel: viewModel, folderViewModel: folderViewModel)
            }
        }
        // Folder filter: Popover on iPad, sheet on iPhone
        #if os(iOS)
        .popover(isPresented: $showFolderFilter, arrowEdge: .top) {
            folderPickerContent
        }
        #else
        .sheet(isPresented: $showFolderFilter) {
            folderPickerContent
        }
        #endif
        .onChange(of: selectedFilterFolderId) { _, newValue in
            viewModel.selectedFolderId = newValue
            Task {
                await viewModel.loadNotes()
            }
        }
        .task {
            await viewModel.loadNotes()
        }
    }
    
    // MARK: - Folder Picker Content
    
    @ViewBuilder
    private var folderPickerContent: some View {
        if let folderVM = folderViewModel {
            FolderPickerSheet(
                viewModel: folderVM,
                selectedFolderId: $selectedFilterFolderId,
                title: "Filter by Folder"
            )
            .frame(minWidth: isRegularWidth ? 300 : nil, 
                   idealWidth: isRegularWidth ? 350 : nil,
                   minHeight: isRegularWidth ? 300 : nil,
                   idealHeight: isRegularWidth ? 400 : nil)
            .presentationDetents(isRegularWidth ? [] : [.medium, .large])
        }
    }
    
    // MARK: - Folder Filter Section
    
    private var folderFilterSection: some View {
        Section {
            Button {
                showFolderFilter = true
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    
                    Text(selectedFilterFolderName)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if selectedFilterFolderId != nil {
                        Button {
                            selectedFilterFolderId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var selectedFilterFolderName: String {
        guard let folderId = selectedFilterFolderId,
              let folder = folderViewModel?.getFolder(id: folderId) else {
            return "All folders"
        }
        return folder.name
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "note.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.showArchived ? "No Archived Notes" : "No Notes")
                    .font(.headline)
                
                Text("Your notes will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if !viewModel.showArchived {
                    Button {
                        viewModel.createNote()
                    } label: {
                        Label("Create Note", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(.systemGray))
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    // MARK: - Notes List
    
    private var notesList: some View {
        ForEach(viewModel.filteredGroupedNotes, id: \.0) { group, notes in
            Section(group.displayName) {
                ForEach(notes) { note in
                    // Both iPad and iPhone use the same tap behavior
                    // iPad: Opens in detail column (via showNoteEditor)
                    // iPhone: Opens in sheet (via showNoteEditor)
                    NoteRowView(note: note, isSelected: selectedNoteId == note.id) {
                        selectedNoteId = note.id
                        Task { await viewModel.editNote(note) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteNote(note) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Note Row View

private struct NoteRowView: View {
    
    let note: NoteSummary
    var isSelected: Bool = false
    let onTap: () -> Void
    
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isHovered = false
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if note.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
        .onHover { hovering in
            isHovered = hovering
        }
        .listRowBackground(
            isSelected && isRegularWidth
                ? theme.accent.opacity(0.15)
                : (isHovered ? theme.secondaryBackground.opacity(0.5) : Color.clear)
        )
        .accessibilityIdentifier("noteRow_\(note.id)")
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: note.updatedAt, relativeTo: Date())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NotesListView(
            viewModel: NotesViewModel(
                noteRepository: MockNoteRepository(),
                authService: MockAuthService()
            )
        )
    }
}
#endif
