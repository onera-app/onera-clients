//
//  DataSettingsView.swift
//  Onera
//
//  Data management settings - export, import, delete chats
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct DataSettingsView: View {
    
    @Environment(\.theme) private var theme
    @Environment(\.dependencies) private var dependencies
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showDeleteConfirmation = false
    @State private var showExportSuccess = false
    @State private var showImportPicker = false
    @State private var exportError: String?
    @State private var importError: String?
    
    var body: some View {
        Form {
            exportSection
            importSection
            archiveSection
            dangerZoneSection
        }
        .formStyle(.grouped)
        .navigationTitle("Data")
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your chats have been exported successfully.")
        }
        .alert("Export Error", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
        .alert("Import Error", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            if let error = importError {
                Text(error)
            }
        }
        .confirmationDialog(
            "Delete All Chats",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                Task { await deleteAllChats() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your conversations will be permanently deleted.")
        }
        #if os(macOS)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            onCompletion: handleImportFile
        )
        #endif
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Chats")
                    .font(.headline)
                
                Text("Download all your conversations as a JSON file")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button {
                    Task { await exportChats() }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isExporting ? "Exporting..." : "Export All Chats")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Chats")
                    .font(.headline)
                
                Text("Import conversations from a previously exported file")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button {
                    showImportPicker = true
                } label: {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isImporting ? "Importing..." : "Import Chats")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Archive Section
    
    private var archiveSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Archive Chats")
                    .font(.headline)
                
                Text("Archive all conversations to hide them from the sidebar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Button {
                    // Archive functionality
                } label: {
                    HStack {
                        Image(systemName: "archivebox")
                        Text("Archive All Chats")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)
                
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Danger Zone Section
    
    private var dangerZoneSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delete All Chats")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Permanently delete all conversations. This action cannot be undone. Make sure to export your data first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Chats")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Actions
    
    private func exportChats() async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let token = try await dependencies.authService.getToken()
            
            // Fetch all chats
            let chats = try await dependencies.chatRepository.fetchChats(token: token)
            
            // Create export data structure
            let exportData = ChatExportData(
                version: 1,
                exportedAt: Date(),
                chats: chats.map { chat in
                    ChatExportItem(
                        id: chat.id,
                        title: chat.title,
                        folderId: chat.folderId,
                        createdAt: chat.createdAt,
                        updatedAt: chat.updatedAt
                    )
                }
            )
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(exportData)
            
            // Save file
            #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "onera-export-\(formattedDate).json"
            
            let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
            if response == .OK, let url = panel.url {
                try jsonData.write(to: url)
                showExportSuccess = true
            }
            #elseif os(iOS)
            // Use share sheet on iOS
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("onera-export-\(formattedDate).json")
            try jsonData.write(to: tempURL)
            
            // Present share sheet
            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: [tempURL],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }
            #endif
        } catch {
            exportError = error.localizedDescription
        }
    }
    
    #if os(macOS)
    private func handleImportFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { await importChats(from: url) }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
    #endif
    
    private func importChats(from url: URL) async {
        isImporting = true
        defer { isImporting = false }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importData = try decoder.decode(ChatExportData.self, from: data)
            
            // TODO: Implement actual import logic
            // This would involve creating new chats from the imported data
            
            print("Imported \(importData.chats.count) chats")
        } catch {
            importError = "Failed to import: \(error.localizedDescription)"
        }
    }
    
    private func deleteAllChats() async {
        do {
            let token = try await dependencies.authService.getToken()
            let chats = try await dependencies.chatRepository.fetchChats(token: token)
            
            for chat in chats {
                try await dependencies.chatRepository.deleteChat(id: chat.id, token: token)
            }
        } catch {
            exportError = "Failed to delete chats: \(error.localizedDescription)"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Data Models

private struct ChatExportData: Codable {
    let version: Int
    let exportedAt: Date
    let chats: [ChatExportItem]
}

private struct ChatExportItem: Codable {
    let id: String
    let title: String
    let folderId: String?
    let createdAt: Date
    let updatedAt: Date
}

#if DEBUG
#Preview {
    NavigationStack {
        DataSettingsView()
            .withDependencies(MockDependencyContainer())
    }
}
#endif
