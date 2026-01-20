//
//  MessageInputView.swift
//  Onera
//
//  Message input component
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    
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
    var onProcessImage: ((UIImage, String) -> Void)?
    var onProcessFile: ((Data, String, String) -> Void)?
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingDocumentPicker = false
    @State private var showingAttachmentMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if isRecording {
                recordingIndicator
            }
            
            // Attachment previews if any
            if !attachments.isEmpty {
                attachmentPreviews
            }
            
            HStack(spacing: 12) {
                // Plus Button with menu
                attachmentButton
                
                // Input Field
                HStack(spacing: 8) {
                    TextField("", text: $text, prompt: Text("Ask anything").foregroundStyle(Color.secondary))
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .tint(Color.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .accessibilityIdentifier("messageInput")
                    
                    if text.isEmpty && !isRecording {
                        // Placeholder action icon
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.secondary)
                            .padding(.trailing, 12)
                    } else if !text.isEmpty {
                        // Send button when text present
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(.systemBackground))
                                .frame(width: 32, height: 32)
                                .background(Color.primary)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 4)
                        .disabled(!canSend || isSending)
                        .accessibilityIdentifier("sendButton")
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                
                // Mic Button
                if text.isEmpty || isRecording {
                    micButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .onChange(of: selectedPhotos) { _, newPhotos in
            Task {
                await processSelectedPhotos(newPhotos)
                selectedPhotos = []
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(onDocumentPicked: handleDocumentPicked)
        }
    }
    
    // MARK: - Attachment Button
    
    private var attachmentButton: some View {
        Menu {
            Button {
                // Trigger photo picker
            } label: {
                Label("Photo Library", systemImage: "photo")
            }
            
            Button {
                showingDocumentPicker = true
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(.systemGray2))
                .symbolRenderingMode(.hierarchical)
        } primaryAction: {
            // Default action opens photo picker
        }
        .frame(height: 48)
        .overlay {
            // Invisible PhotosPicker over the button
            PhotosPicker(selection: $selectedPhotos, matching: .any(of: [.images, .screenshots])) {
                Color.clear
            }
            .frame(height: 48)
        }
    }
    
    // MARK: - Photo Processing
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
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
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())
            
            Text("Recording...")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Done") {
                onStopRecording?()
            }
            .font(.caption.bold())
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Attachment Previews
    
    private var attachmentPreviews: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewItem(attachment: attachment) {
                        // Remove attachment
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Mic Button
    
    private var micButton: some View {
        Button {
            if isRecording {
                onStopRecording?()
            } else {
                onStartRecording?()
            }
        } label: {
            Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: 22))
                .foregroundStyle(isRecording ? .red : Color.primary)
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

// MARK: - Attachment Preview Item

private struct AttachmentPreviewItem: View {
    let attachment: Attachment
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch attachment.type {
                case .image:
                    if let uiImage = UIImage(data: attachment.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                case .file:
                    filePreview
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.6)))
            }
            .offset(x: 6, y: -6)
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
    
    private var filePreview: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(attachment.fileName ?? "File")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
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
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Document Picker

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
