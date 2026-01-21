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
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var showingAttachmentOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator (floats above the main input)
            if isRecording {
                recordingIndicator
                    .padding(.bottom, 8)
            }
            
            // Attachment previews if any (floats above the main input)
            if !attachments.isEmpty {
                attachmentPreviews
                    .padding(.bottom, 8)
            }
            
            // Each element floats independently with glass effect
            HStack(spacing: 8) {
                // Plus Button - floating glass pill
                attachmentButton
                
                // Input Field - floating glass pill
                HStack(spacing: 8) {
                    TextField("", text: $text, prompt: Text("Ask anything").foregroundStyle(.secondary))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .tint(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .accessibilityIdentifier("messageInput")
                    
                    if text.isEmpty && !isRecording {
                        // Placeholder action icon
                        Image(systemName: "waveform")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 12)
                    } else if !text.isEmpty {
                        // Send button when text present
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(.systemBackground))
                                .frame(width: 30, height: 30)
                                .background(Color.primary)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 6)
                        .disabled(!canSend || isSending)
                        .accessibilityIdentifier("sendButton")
                    }
                }
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                
                // Mic Button - floating glass circle
                if text.isEmpty || isRecording {
                    micButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            showingAttachmentOptions = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 44, height: 44)
        }
        .confirmationDialog("Add Attachment", isPresented: $showingAttachmentOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingPhotosPicker = true
            }
            Button("Choose File") {
                showingDocumentPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotos, matching: .any(of: [.images, .screenshots]))
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                handleCameraImage(image)
            }
            .ignoresSafeArea()
        }
    }
    
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
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 12)
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
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 12)
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
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isRecording ? .red : .primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
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

// MARK: - Camera Picker

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
