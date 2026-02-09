//
//  MessageInputView.swift
//  Onera
//
//  Message input component
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MessageInputView: View {
    
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var text: String
    @Binding var attachments: [Attachment]
    let isSending: Bool
    var isStreaming: Bool = false
    var canSend: Bool = true
    let onSend: () -> Void
    var onStop: (() -> Void)?
    
    // Speech recognition callbacks
    var isRecording: Bool = false
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    
    // File processing callback
    var onProcessImage: ((PlatformImage, String) -> Void)?
    var onProcessFile: ((Data, String, String) -> Void)?
    
    // @mention prompt support
    var promptSummaries: [PromptSummary] = []
    var onFetchPromptContent: ((PromptSummary) async -> String?)? = nil
    
    // Web search
    var searchEnabled: Binding<Bool>?
    var isSearching: Bool = false
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingDocumentPicker = false
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var showingAttachmentOptions = false
    
    // @mention state
    @State private var showMentionPopover = false
    @State private var mentionQuery = ""
    @State private var mentionSelectedIndex = 0
    @State private var pendingPrompt: PromptSummary? = nil
    @State private var pendingPromptVariables: [String] = []
    @State private var pendingPromptResolvedContent: String? = nil
    @State private var variableValues: [String: String] = [:]
    @State private var showVariableSheet = false
    
    /// Max width for input area on iPad (matches message content width)
    private var maxInputWidth: CGFloat? {
        horizontalSizeClass == .regular ? 800 : nil
    }
    
    /// iPad uses slightly larger touch targets
    private var touchTargetSize: CGFloat {
        horizontalSizeClass == .regular ? 48 : AccessibilitySize.minTouchTarget
    }
    
    /// Prompts filtered by the current @mention query
    private var filteredMentionPrompts: [PromptSummary] {
        if mentionQuery.isEmpty {
            return Array(promptSummaries.prefix(8))
        }
        return promptSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(mentionQuery)
        }.prefix(8).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator (floats above the main input)
            if isRecording {
                recordingIndicator
                    .padding(.bottom, OneraSpacing.sm)
            }
            
            // Attachment previews if any (floats above the main input)
            if !attachments.isEmpty {
                attachmentPreviews
                    .padding(.bottom, OneraSpacing.sm)
            }
            
            // Web search indicator bar
            if let searchEnabled = searchEnabled, searchEnabled.wrappedValue {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption2)
                    Text("Web search · \(currentProviderName)")
                        .font(.caption2)
                    Spacer()
                    Button {
                        searchEnabled.wrappedValue = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .accessibilityLabel("Disable web search")
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.vertical, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Input pill
            HStack(alignment: .bottom, spacing: 8) {
                // Plus button (attachment + search)
                plusMenu
                    .frame(width: 32, height: 32)
                
                // Native multi-line TextField — grows automatically, no manual height calc
                TextField("Ask anything", text: $text, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...8)
                    .foregroundStyle(theme.textPrimary)
                    .tint(theme.textPrimary)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("messageInput")
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message here")
                
                // Right action button
                rightActionButton
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .oneraGlassRounded(24, showBorder: true, showShadow: true)
            .frame(maxWidth: maxInputWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, horizontalSizeClass == .regular ? OneraSpacing.lg : OneraSpacing.sm)
        }
        .overlay(alignment: .bottom) {
            if showMentionPopover && !filteredMentionPrompts.isEmpty {
                MentionPopupView(
                    prompts: filteredMentionPrompts,
                    selectedIndex: mentionSelectedIndex,
                    onSelect: selectMentionPrompt
                )
                .padding(.horizontal, OneraSpacing.lg)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.15), value: showMentionPopover)
        .onChange(of: text) { _, newValue in
            detectMention(in: newValue)
        }
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await processSelectedPhotos(newPhotos)
                selectedPhotos = []
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(onDocumentPicked: handleDocumentPicked)
        }
        #endif
        .sheet(isPresented: $showVariableSheet) {
            if let prompt = pendingPrompt {
                NavigationStack {
                    Form {
                        Section("Fill in variables for \(prompt.name)") {
                            ForEach(pendingPromptVariables, id: \.self) { variable in
                                TextField(variable, text: Binding(
                                    get: { variableValues[variable] ?? "" },
                                    set: { variableValues[variable] = $0 }
                                ))
                            }
                        }
                    }
                    .navigationTitle("Variables")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showVariableSheet = false
                                pendingPrompt = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Insert") {
                                insertPromptContent(prompt, variables: variableValues)
                                showVariableSheet = false
                                pendingPrompt = nil
                            }
                            .disabled(variableValues.values.contains(where: { $0.isEmpty }))
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Right Action Button
    
    @ViewBuilder
    private var rightActionButton: some View {
        if isStreaming {
            Button {
                onStop?()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.error)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop generating")
        } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sendEnabled = canSend && !isSending
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.subheadline.bold())
                    .foregroundStyle(sendEnabled ? .white : theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(sendEnabled ? theme.accent : theme.textSecondary.opacity(0.3))
                    .clipShape(Circle())
            }
            .disabled(!sendEnabled)
            .sensoryFeedback(.impact(weight: .medium), trigger: text.isEmpty)
            .accessibilityIdentifier("sendButton")
            .accessibilityLabel("Send message")
            .accessibilityHint(canSend ? "Sends your message" : "Cannot send while processing")
        } else if isRecording {
            Button {
                onStopRecording?()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.error)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Stop recording")
        } else {
            Button {
                onStartRecording?()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Start voice recording")
            .accessibilityHint("Starts voice recording to dictate your message")
        }
    }
    
    // MARK: - @Mention Detection
    
    private func detectMention(in text: String) {
        guard let atRange = text.range(of: "@", options: .backwards) else {
            showMentionPopover = false
            return
        }
        
        let afterAt = text[atRange.upperBound...]
        
        if afterAt.contains("\n") {
            showMentionPopover = false
            return
        }
        
        if atRange.lowerBound != text.startIndex {
            let charBefore = text[text.index(before: atRange.lowerBound)]
            if !charBefore.isWhitespace && !charBefore.isNewline {
                showMentionPopover = false
                return
            }
        }
        
        mentionQuery = String(afterAt)
        mentionSelectedIndex = 0
        showMentionPopover = !filteredMentionPrompts.isEmpty
    }
    
    private func selectMentionPrompt(_ prompt: PromptSummary) {
        showMentionPopover = false
        
        Task {
            guard let content = await onFetchPromptContent?(prompt) else { return }
            
            let variablePattern = "\\{\\{\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\}\\}"
            let variables: [String]
            if let regex = try? NSRegularExpression(pattern: variablePattern) {
                let range = NSRange(content.startIndex..., in: content)
                let matches = regex.matches(in: content, range: range)
                variables = matches.compactMap { match in
                    guard let r = Range(match.range(at: 1), in: content) else { return nil }
                    return String(content[r])
                }
            } else {
                variables = []
            }
            
            if variables.isEmpty {
                insertResolvedContent(content)
            } else {
                pendingPrompt = prompt
                pendingPromptVariables = Array(Set(variables))
                pendingPromptResolvedContent = content
                variableValues = [:]
                showVariableSheet = true
            }
        }
    }
    
    private func insertResolvedContent(_ content: String) {
        if let atRange = text.range(of: "@", options: .backwards) {
            let charBeforeOk: Bool
            if atRange.lowerBound == text.startIndex {
                charBeforeOk = true
            } else {
                let c = text[text.index(before: atRange.lowerBound)]
                charBeforeOk = c.isWhitespace || c.isNewline
            }
            if charBeforeOk {
                text = String(text[..<atRange.lowerBound])
            }
        }
        text += content
    }
    
    private func insertPromptContent(_ prompt: PromptSummary, variables: [String: String]) {
        if let resolved = pendingPromptResolvedContent {
            var content = resolved
            for (key, value) in variables {
                content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
                content = content.replacingOccurrences(of: "{{ \(key) }}", with: value)
            }
            insertResolvedContent(content)
        }
        pendingPromptResolvedContent = nil
    }
    
    // MARK: - Plus Menu (Combined Attachment + Search)
    
    private var plusMenu: some View {
        Menu {
            // Attachment options
            Section("Attach") {
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }
                #endif
                Button {
                    showingPhotosPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    showingDocumentPicker = true
                } label: {
                    Label("Choose File", systemImage: "doc")
                }
            }
            
            // Web search toggle
            if let searchEnabled = searchEnabled, hasSearchProvider {
                Section("Search") {
                    Button {
                        searchEnabled.wrappedValue.toggle()
                    } label: {
                        Label(
                            searchEnabled.wrappedValue ? "Disable Web Search" : "Enable Web Search",
                            systemImage: searchEnabled.wrappedValue ? "globe.badge.chevron.backward" : "globe"
                        )
                    }
                    
                    if searchEnabled.wrappedValue {
                        // Provider picker
                        ForEach(SearchProvider.allCases) { provider in
                            Button {
                                UserDefaults.standard.set(provider.rawValue, forKey: "defaultSearchProvider")
                            } label: {
                                HStack {
                                    Text(provider.displayName)
                                    if provider.rawValue == (UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily") {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 32, height: 32)
                
                // Web search enabled indicator dot
                if let searchEnabled = searchEnabled, searchEnabled.wrappedValue {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        } primaryAction: {
            showingAttachmentOptions = true
        }
        .menuStyle(.borderlessButton)
        .confirmationDialog("Add Attachment", isPresented: $showingAttachmentOptions, titleVisibility: .visible) {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    showingCamera = true
                }
            }
            #endif
            Button("Photo Library") {
                showingPhotosPicker = true
            }
            Button("Choose File") {
                showingDocumentPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotos, matching: .any(of: [.images, .screenshots]))
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                handleCameraImage(image)
            }
            .ignoresSafeArea()
        }
        #endif
        .accessibilityLabel("Add attachment or toggle search")
        .accessibilityHint("Tap to attach, hold for more options")
    }
    
    #if os(iOS)
    private func handleCameraImage(_ image: UIImage) {
        let fileName = "photo_\(UUID().uuidString.prefix(8)).jpg"
        
        if let onProcess = onProcessImage {
            onProcess(image, fileName)
        } else if let data = image.jpegData(compressionQuality: 0.8) {
            let attachment = Attachment(
                type: .image,
                data: data,
                mimeType: "image/jpeg",
                fileName: fileName
            )
            attachments.append(attachment)
        }
    }
    #endif
    
    // MARK: - Photo Processing
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    if let image = PlatformImage(data: data) {
                        let fileName = "photo_\(UUID().uuidString.prefix(8)).jpg"
                        
                        // If callback provided, use it (for processing)
                        if let onProcess = onProcessImage {
                            onProcess(image, fileName)
                        } else {
                            // Otherwise add directly as attachment
                            let attachment = Attachment(
                                type: .image,
                                data: data,
                                mimeType: "image/jpeg",
                                fileName: fileName
                            )
                            await MainActor.run {
                                attachments.append(attachment)
                            }
                        }
                    }
                }
            } catch {
                print("[MessageInputView] Failed to load photo: \(error)")
            }
        }
    }
    
    private func handleDocumentPicked(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = getMimeType(for: url)
            
            if let onProcess = onProcessFile {
                onProcess(data, fileName, mimeType)
            } else {
                let type: AttachmentType = mimeType.starts(with: "image/") ? .image : .file
                let attachment = Attachment(
                    type: type,
                    data: data,
                    mimeType: mimeType,
                    fileName: fileName
                )
                attachments.append(attachment)
            }
        } catch {
            print("[MessageInputView] Failed to read file: \(error)")
        }
    }
    
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        // Use UTType for MIME type detection
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        
        // Fallback for common types
        switch pathExtension {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        HStack(spacing: OneraSpacing.sm) {
            Circle()
                .fill(theme.error)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())
                .accessibilityHidden(true)
            
            Text("Recording...")
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textSecondary)
            
            Spacer()
            
            Button("Done") {
                onStopRecording?()
            }
            .font(OneraTypography.caption.bold())
            .foregroundStyle(theme.textPrimary)
            .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
            .accessibilityLabel("Stop recording")
            .accessibilityHint("Stops voice recording and processes your speech")
        }
        .padding(.horizontal, OneraSpacing.lg)
        .padding(.vertical, OneraSpacing.compact)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, OneraSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording in progress")
    }
    
    // MARK: - Attachment Previews
    
    private var attachmentPreviews: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OneraSpacing.sm) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewItem(attachment: attachment) {
                        // Remove attachment
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            .padding(.horizontal, OneraSpacing.lg)
            .padding(.vertical, OneraSpacing.compact)
        }
        .background(
            RoundedRectangle(cornerRadius: OneraRadius.large, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, OneraSpacing.md)
    }
    
    // MARK: - Search Helpers
    
    private var hasSearchProvider: Bool {
        let providerRaw = UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily"
        let apiKey = UserDefaults.standard.string(forKey: "search.\(providerRaw).apiKey") ?? ""
        return !apiKey.isEmpty
    }
    
    private var currentProviderName: String {
        let providerRaw = UserDefaults.standard.string(forKey: "defaultSearchProvider") ?? "tavily"
        return SearchProvider(rawValue: providerRaw)?.displayName ?? "Tavily"
    }
}

// MARK: - Mention Popup View

private struct MentionPopupView: View {
    @Environment(\.theme) private var theme
    let prompts: [PromptSummary]
    let selectedIndex: Int
    let onSelect: (PromptSummary) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "at")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Prompts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                Button {
                    onSelect(prompt)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(prompt.name)
                                .font(.subheadline)
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            
                            if let desc = prompt.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert prompt: \(prompt.name)")
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Prompt suggestions")
    }
}

// MARK: - Attachment Preview Item

private struct AttachmentPreviewItem: View {
    @Environment(\.theme) private var theme
    let attachment: Attachment
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch attachment.type {
                case .image:
                    #if os(iOS)
                    if let uiImage = UIImage(data: attachment.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                    #elseif os(macOS)
                    if let nsImage = NSImage(data: attachment.data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                    #endif
                case .file:
                    filePreview
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.standard))
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(OneraTypography.iconLarge)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .offset(x: 6, y: -6)
            .frame(minWidth: AccessibilitySize.minTouchTarget, minHeight: AccessibilitySize.minTouchTarget)
            .accessibilityLabel("Remove attachment")
            .accessibilityHint("Removes \(attachment.fileName ?? "this attachment")")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(attachment.type == .image ? "Image attachment" : "File: \(attachment.fileName ?? "unnamed")")
        .accessibilityAddTraits(.isButton)
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(theme.secondaryBackground)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(theme.textSecondary)
            }
    }
    
    private var filePreview: some View {
        Rectangle()
            .fill(theme.tertiaryBackground)
            .overlay {
                VStack(spacing: OneraSpacing.xxs) {
                    Image(systemName: "doc.fill")
                        .font(OneraTypography.title3)
                        .foregroundStyle(theme.textSecondary)
                    Text(attachment.fileName ?? "File")
                        .font(OneraTypography.caption2)
                        .lineLimit(1)
                        .foregroundStyle(theme.textSecondary)
                }
            }
    }
}

// MARK: - Pulsing Animation Modifier

private struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .onAppear {
                withAnimation(OneraAnimation.pulse) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Document Picker

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .pdf,
            .plainText,
            .json,
            .html,
            .image
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}
#endif

// MARK: - Camera Picker

#if os(iOS)
struct CameraPicker: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction
        
        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#endif


