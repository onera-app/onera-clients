//
//  NoteEditorView.swift
//  Onera
//
//  Editor view for creating and editing notes
//

import SwiftUI

struct NoteEditorView: View {
    
    @Bindable var viewModel: NotesViewModel
    var folderViewModel: FolderViewModel?
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isPinned: Bool = false
    @State private var isArchived: Bool = false
    @State private var selectedFolderId: String?
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false
    @State private var showFolderPicker = false
    
    // Auto-save timer
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSaveTime: Date?
    
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case title, content
    }
    
    private var isNewNote: Bool {
        viewModel.editingNote?.id == nil || !viewModel.notes.contains { $0.id == viewModel.editingNote?.id }
    }
    
    private var hasChanges: Bool {
        guard let note = viewModel.editingNote else { return false }
        return title != note.title || content != note.content || isPinned != note.pinned || isArchived != note.archived || selectedFolderId != note.folderId
    }
    
    private var selectedFolderName: String {
        guard let folderId = selectedFolderId,
              let folder = folderViewModel?.getFolder(id: folderId) else {
            return "No folder"
        }
        return folder.name
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Note options bar
                    noteOptionsBar
                    
                    titleField
                    Divider()
                    contentField
                }
                .padding()
            }
            .navigationTitle(isNewNote ? "New Note" : "Edit Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismissEditor()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveNote() }
                    }
                    .disabled(title.isEmpty || isSaving)
                    .accessibilityIdentifier("saveNoteButton")
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    dismissEditor()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .sheet(isPresented: $showFolderPicker) {
                if let folderVM = folderViewModel {
                    FolderPickerSheet(
                        viewModel: folderVM,
                        selectedFolderId: $selectedFolderId,
                        title: "Move to Folder"
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .onAppear {
                if let note = viewModel.editingNote {
                    title = note.title
                    content = note.content
                    isPinned = note.pinned
                    isArchived = note.archived
                    selectedFolderId = note.folderId
                }
                
                // Auto-focus title for new notes
                if isNewNote {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        focusedField = .title
                    }
                }
            }
            .onChange(of: title) { _, _ in scheduleAutoSave() }
            .onChange(of: content) { _, _ in scheduleAutoSave() }
            .onDisappear {
                autoSaveTask?.cancel()
            }
        }
    }
    
    // MARK: - Note Options Bar
    
    private var noteOptionsBar: some View {
        HStack(spacing: 16) {
            // Folder picker
            Button {
                showFolderPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                    Text(selectedFolderName)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(OneraColors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(folderViewModel == nil)
            
            Spacer()
            
            // Pin button
            Button {
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 16))
                    .foregroundStyle(isPinned ? .orange : .secondary)
            }
            
            // Archive button
            Button {
                isArchived.toggle()
            } label: {
                Image(systemName: isArchived ? "archivebox.fill" : "archivebox")
                    .font(.system(size: 16))
                    .foregroundStyle(isArchived ? .blue : .secondary)
            }
        }
    }
    
    // MARK: - Title Field
    
    private var titleField: some View {
        TextField("Title", text: $title, axis: .vertical)
            .font(.title2.bold())
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .content
            }
            .accessibilityIdentifier("noteTitleField")
    }
    
    // MARK: - Content Field
    
    private var contentField: some View {
        TextEditor(text: $content)
            .font(.body)
            .frame(minHeight: 300)
            .focused($focusedField, equals: .content)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("noteContentField")
            .overlay(alignment: .topLeading) {
                if content.isEmpty {
                    Text("Start writing...")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
    }
    
    // MARK: - Actions
    
    private func saveNote() async {
        guard !title.isEmpty else { 
            print("[NoteEditorView] saveNote: Title is empty, not saving")
            return 
        }
        
        isSaving = true
        
        var note = viewModel.editingNote ?? Note()
        print("[NoteEditorView] saveNote: Using note id=\(note.id), isNewNote=\(isNewNote)")
        
        note.title = title
        note.content = content
        note.pinned = isPinned
        note.archived = isArchived
        note.folderId = selectedFolderId
        note.updatedAt = Date()
        
        print("[NoteEditorView] saveNote: Calling viewModel.saveNote with title='\(note.title)'")
        let success = await viewModel.saveNote(note)
        print("[NoteEditorView] saveNote: Result = \(success)")
        
        isSaving = false
        lastSaveTime = Date()
        
        if success {
            dismissEditor()
        }
    }
    
    private func scheduleAutoSave() {
        // Cancel previous auto-save task
        autoSaveTask?.cancel()
        
        // Don't auto-save new notes or if title is empty
        guard !isNewNote, !title.isEmpty else { return }
        
        // Debounce auto-save (3 seconds after last change)
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            
            // Only save if we haven't saved recently
            if let lastSave = lastSaveTime, Date().timeIntervalSince(lastSave) < 2 {
                return
            }
            
            await performAutoSave()
        }
    }
    
    private func performAutoSave() async {
        guard !title.isEmpty else { return }
        
        var note = viewModel.editingNote ?? Note()
        note.title = title
        note.content = content
        note.pinned = isPinned
        note.archived = isArchived
        note.folderId = selectedFolderId
        note.updatedAt = Date()
        
        _ = await viewModel.saveNote(note)
        lastSaveTime = Date()
    }
    
    private func dismissEditor() {
        autoSaveTask?.cancel()
        viewModel.editingNote = nil
        viewModel.showNoteEditor = false
        dismiss()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("New Note") {
    NoteEditorView(
        viewModel: {
            let vm = NotesViewModel(
                noteRepository: MockNoteRepository(),
                authService: MockAuthService()
            )
            vm.editingNote = Note()
            return vm
        }()
    )
}

#Preview("Edit Note") {
    NoteEditorView(
        viewModel: {
            let vm = NotesViewModel(
                noteRepository: MockNoteRepository(),
                authService: MockAuthService()
            )
            vm.editingNote = .mockWithContent
            return vm
        }()
    )
}
#endif
