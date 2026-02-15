//
//  PromptsListView.swift
//  Onera
//
//  List view for displaying custom prompts
//

import SwiftUI

struct PromptsListView: View {
    
    @Bindable var viewModel: PromptsViewModel
    @Environment(\.theme) private var theme
    
    @State private var showDeleteConfirmation = false
    @State private var promptToDelete: PromptSummary?
    
    var body: some View {
        List {
            if viewModel.filteredPrompts.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                promptsList
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("Prompts")
        .searchable(text: $viewModel.searchText, prompt: "Search prompts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.createPrompt()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new prompt")
                .accessibilityIdentifier("createPromptButton")
            }
        }
        .refreshable {
            await viewModel.refreshPrompts()
        }
        .sheet(isPresented: $viewModel.showPromptEditor) {
            PromptEditorView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete Prompt",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: promptToDelete
        ) { prompt in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePrompt(prompt) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { prompt in
            Text("Are you sure you want to delete \"\(prompt.name)\"? This action cannot be undone.")
        }
        .task {
            await viewModel.loadPrompts()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "text.quote")
                    .font(.largeTitle)
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityHidden(true)
                
                Text(viewModel.searchText.isEmpty ? "No Prompts" : "No Results")
                    .font(.headline)
                
                Text(viewModel.searchText.isEmpty
                     ? "Create custom prompts to reuse in your chats."
                     : "No prompts match your search.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                
                if viewModel.searchText.isEmpty {
                    Button {
                        viewModel.createPrompt()
                    } label: {
                        Label("Create Prompt", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.textSecondary)
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneraSpacing.xxxl)
        }
    }
    
    // MARK: - Prompts List
    
    private var promptsList: some View {
        ForEach(viewModel.filteredGroupedPrompts, id: \.0) { group, prompts in
            Section(group.displayName) {
                ForEach(prompts) { prompt in
                    PromptRowView(prompt: prompt) {
                        Task { await viewModel.editPrompt(prompt) }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            promptToDelete = prompt
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task { await viewModel.duplicatePrompt(prompt) }
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        .tint(theme.accent)
                    }
                    .contextMenu {
                        Button {
                            Task { await viewModel.editPrompt(prompt) }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button {
                            Task { await viewModel.duplicatePrompt(prompt) }
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            promptToDelete = prompt
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Prompt Row View

private struct PromptRowView: View {
    
    let prompt: PromptSummary
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let description = prompt.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, OneraSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("promptRow_\(prompt.id)")
        .accessibilityLabel("\(prompt.name). \(prompt.description ?? ""). Updated \(formattedDate)")
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: prompt.updatedAt, relativeTo: Date())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PromptsListView(
            viewModel: PromptsViewModel(
                promptRepository: MockPromptRepository(),
                authService: MockAuthService()
            )
        )
    }
}
#endif
