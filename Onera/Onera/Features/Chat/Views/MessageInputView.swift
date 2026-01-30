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
                    .padding(.bottom, OneraSpacing.sm)
            }
            
            // Attachment previews if any (floats above the main input)
            if !attachments.isEmpty {
                attachmentPreviews
                    .padding(.bottom, OneraSpacing.sm)
            }
            
            // Each element floats independently with glass effect
            HStack(spacing: OneraSpacing.sm) {
                // Plus Button - floating glass pill
                attachmentButton
                
                // Input Field - floating glass pill
                HStack(spacing: OneraSpacing.sm) {
                    TextField("", text: $text, prompt: Text("Ask anything").foregroundStyle(theme.textSecondary))
                        .font(OneraTypography.body)
                        .foregroundStyle(theme.textPrimary)
                        .tint(theme.textPrimary)
                        .padding(.horizontal, OneraSpacing.lg)
                        .padding(.vertical, OneraSpacing.md)
                        .accessibilityIdentifier("messageInput")
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your message here")
                    
                    if text.isEmpty && !isRecording {
                        // Placeholder action icon (decorative)
                        Image(systemName: "waveform")
                            .font(OneraTypography.iconLarge)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.trailing, OneraSpacing.md)
                            .accessibilityHidden(true)
                    } else if !text.isEmpty {
                        // Send button when text present
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(theme.background)
                                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                                .background(theme.textPrimary)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, OneraSpacing.xs)
                        .disabled(!canSend || isSending)
                        .sensoryFeedback(.impact(weight: .medium), trigger: text.isEmpty)
                        .accessibilityIdentifier("sendButton")
                        .accessibilityLabel("Send message")
                        .accessibilityHint(canSend ? "Sends your message" : "Cannot send while processing")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .oneraGlass()
                
                // Mic Button - floating glass circle
                if text.isEmpty || isRecording {
                    micButton
                }
            }
            .padding(.horizontal, OneraSpacing.lg)
            .padding(.vertical, OneraSpacing.md)
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
    }
    
    // MARK: - Attachment Button
    
    private var attachmentButton: some View {
        Button {
            showingAttachmentOptions = true
        } label: {
            Image(systemName: "plus")
                .font(OneraTypography.iconXLarge)
                .foregroundStyle(theme.textPrimary)
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .oneraGlassCircle()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showingAttachmentOptions)
        .accessibilityLabel("Add attachment")
        .accessibilityHint("Opens menu to attach photos or files")
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                handleCameraImage(image)
            }
            .ignoresSafeArea()
        }
        #endif
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
                .font(OneraTypography.iconLarge)
                .foregroundStyle(isRecording ? theme.error : theme.textPrimary)
                .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                .oneraGlassCircle()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .animateWithReducedMotion(OneraAnimation.fast, value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start voice recording")
        .accessibilityHint(isRecording ? "Stops voice recording" : "Starts voice recording to dictate your message")
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
