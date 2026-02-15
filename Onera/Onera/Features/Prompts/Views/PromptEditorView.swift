//
//  PromptEditorView.swift
//  Onera
//
//  Editor view for creating and editing custom prompts
//

import SwiftUI

struct PromptEditorView: View {
    
    @Bindable var viewModel: PromptsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var content: String = ""
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var showDiscardAlert = false
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, description, content
    }
    
    private var isNew: Bool {
        viewModel.isCreatingNew
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Prompt Name", text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .focused($focusedField, equals: .name)
                        .onChange(of: name) { _, _ in hasChanges = true }
                        .accessibilityLabel("Prompt name")
                } header: {
                    Text("Name")
                } footer: {
                    Text("Give your prompt a descriptive name")
                }
                
                // Description Section
                Section {
                    TextField("Brief description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .description)
                        .onChange(of: description) { _, _ in hasChanges = true }
                        .accessibilityLabel("Prompt description")
                } header: {
                    Text("Description")
                } footer: {
                    Text("Optional description of what this prompt does")
                }
                
                // Content Section
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                        .font(.body.monospaced())
                        .focused($focusedField, equals: .content)
                        .onChange(of: content) { _, _ in hasChanges = true }
                        .accessibilityLabel("Prompt content")
                } header: {
                    Text("Content")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use {{variable}} syntax for placeholders")
                        if !detectedVariables.isEmpty {
                            Text("Variables: \(detectedVariables.joined(separator: ", "))")
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                
                // Preview Section (if content has variables)
                if !detectedVariables.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(detectedVariables, id: \.self) { variable in
                                HStack {
                                    Text(variable)
                                        .font(.caption.monospaced())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(theme.accent.opacity(0.1))
                                        .foregroundStyle(theme.accent)
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                    
                                    Text("placeholder")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Variables")
                    } footer: {
                        Text("These placeholders will be filled in when using the prompt")
                    }
                }
            }
            .navigationTitle(isNew ? "New Prompt" : "Edit Prompt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(isNew ? "Create" : "Save")
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .onAppear {
                loadPrompt()
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }
    
    // MARK: - Computed Properties
    
    private var detectedVariables: [String] {
        let pattern = "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        
        var variables: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: content) {
                let variable = String(content[range])
                if !variables.contains(variable) {
                    variables.append(variable)
                }
            }
        }
        return variables
    }
    
    // MARK: - Actions
    
    private func loadPrompt() {
        guard let prompt = viewModel.editingPrompt else { return }
        name = prompt.name
        description = prompt.description ?? ""
        content = prompt.content
        hasChanges = false
        
        // Focus name field for new prompts
        if isNew {
            focusedField = .name
        }
    }
    
    private func save() async {
        guard canSave else { return }
        
        isSaving = true
        
        let prompt = Prompt(
            id: viewModel.editingPrompt?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: viewModel.editingPrompt?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        let success = await viewModel.savePrompt(prompt)
        
        isSaving = false
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("New Prompt") {
    let viewModel = PromptsViewModel(
        promptRepository: MockPromptRepository(),
        authService: MockAuthService()
    )
    viewModel.createPrompt()
    
    return PromptEditorView(viewModel: viewModel)
}

#Preview("Edit Prompt") {
    let viewModel = PromptsViewModel(
        promptRepository: MockPromptRepository(),
        authService: MockAuthService()
    )
    viewModel.editingPrompt = .codeReviewPrompt
    viewModel.isCreatingNew = false
    viewModel.showPromptEditor = true
    
    return PromptEditorView(viewModel: viewModel)
}
#endif
