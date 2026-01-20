//
//  NotesViewModel.swift
//  Onera
//
//  ViewModel for managing notes
//

import Foundation
import Observation

@MainActor
@Observable
final class NotesViewModel {
    
    // MARK: - State
    
    private(set) var notes: [NoteSummary] = []
    private(set) var groupedNotes: [(NoteGroup, [NoteSummary])] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    var searchText = ""
    var showArchived = false
    var selectedFolderId: String?
    
    // MARK: - Editor State
    
    var showNoteEditor = false
    var editingNote: Note?
    
    // MARK: - Dependencies
    
    private let noteRepository: NoteRepositoryProtocol
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    init(
        noteRepository: NoteRepositoryProtocol,
        authService: AuthServiceProtocol
    ) {
        self.noteRepository = noteRepository
        self.authService = authService
    }
    
    // MARK: - Actions
    
    func loadNotes() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.getToken()
            
            notes = try await noteRepository.fetchNotes(
                token: token,
                folderId: selectedFolderId,
                archived: showArchived
            )
            
            updateGroupedNotes()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshNotes() async {
        await loadNotes()
    }
    
    func createNote() {
        editingNote = Note()
        showNoteEditor = true
    }
    
    func editNote(_ summary: NoteSummary) async {
        do {
            let token = try await authService.getToken()
            let note = try await noteRepository.fetchNote(id: summary.id, token: token)
            editingNote = note
            showNoteEditor = true
        } catch {
            self.error = error
        }
    }
    
    func saveNote(_ note: Note) async -> Bool {
        do {
            let token = try await authService.getToken()
            
            let noteExists = notes.contains(where: { $0.id == note.id })
            print("[NotesViewModel] saveNote: noteId=\(note.id), title='\(note.title)', noteExists=\(noteExists), notesCount=\(notes.count)")
            
            if noteExists {
                // Update existing note
                print("[NotesViewModel] Updating existing note...")
                try await noteRepository.updateNote(note, token: token)
                print("[NotesViewModel] Note updated successfully")
            } else {
                // Create new note
                print("[NotesViewModel] Creating new note...")
                let newId = try await noteRepository.createNote(note, token: token)
                print("[NotesViewModel] Note created successfully with id: \(newId)")
            }
            
            await loadNotes()
            return true
        } catch {
            print("[NotesViewModel] Error saving note: \(error)")
            self.error = error
            return false
        }
    }
    
    func deleteNote(_ summary: NoteSummary) async {
        do {
            let token = try await authService.getToken()
            try await noteRepository.deleteNote(id: summary.id, token: token)
            await loadNotes()
        } catch {
            self.error = error
        }
    }
    
    func toggleArchived() {
        showArchived.toggle()
        Task {
            await loadNotes()
        }
    }
    
    // MARK: - Search
    
    var filteredNotes: [NoteSummary] {
        if searchText.isEmpty {
            return notes
        }
        return notes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredGroupedNotes: [(NoteGroup, [NoteSummary])] {
        if searchText.isEmpty {
            return groupedNotes
        }
        
        let filtered = filteredNotes
        return groupedNotes.compactMap { group, notes in
            let matchingNotes = notes.filter { filtered.contains($0) }
            return matchingNotes.isEmpty ? nil : (group, matchingNotes)
        }
    }
    
    // MARK: - Private
    
    private func updateGroupedNotes() {
        let grouped = Dictionary(grouping: notes) { $0.group }
        groupedNotes = grouped.keys.sorted().map { group in
            (group, grouped[group] ?? [])
        }
    }
}
