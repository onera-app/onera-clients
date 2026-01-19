//
//  MessageInputView.swift
//  Onera
//
//  Multi-line message input with attachments
//

import SwiftUI
import PhotosUI

struct MessageInputView: View {
    
    @Binding var text: String
    @Binding var attachments: [Attachment]
    let isSending: Bool
    let onSend: () -> Void
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && !isSending
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if !attachments.isEmpty {
                attachmentPreviewsView
            }
            
            inputRowView
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    // MARK: - Subviews
    
    private var attachmentPreviewsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewView(attachment: attachment) {
                        removeAttachment(attachment)
                    }
                }
            }
        }
    }
    
    private var inputRowView: some View {
        HStack(alignment: .bottom, spacing: 12) {
            attachmentButton
            textField
            sendButton
        }
    }
    
    private var attachmentButton: some View {
        PhotosPicker(
            selection: $selectedPhotos,
            maxSelectionCount: 5,
            matching: .images
        ) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .onChange(of: selectedPhotos) { _, items in
            Task { await loadPhotos(items) }
        }
    }
    
    private var textField: some View {
        TextField("Message", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .lineLimit(1...6)
    }
    
    private var sendButton: some View {
        Button {
            onSend()
        } label: {
            if isSending {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? .tint : .secondary)
            }
        }
        .disabled(!canSend)
    }
    
    // MARK: - Private Methods
    
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let attachment = Attachment(
                    type: .image,
                    data: data,
                    mimeType: "image/jpeg"
                )
                attachments.append(attachment)
            }
        }
        selectedPhotos = []
    }
    
    private func removeAttachment(_ attachment: Attachment) {
        withAnimation {
            attachments.removeAll { $0.id == attachment.id }
        }
    }
}

// MARK: - Attachment Preview

struct AttachmentPreviewView: View {
    
    let attachment: Attachment
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailView
            removeButton
        }
    }
    
    private var thumbnailView: some View {
        Group {
            switch attachment.type {
            case .image:
                if let uiImage = UIImage(data: attachment.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                
            case .file:
                Image(systemName: "doc.fill")
                    .font(.title)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var removeButton: some View {
        Button {
            onRemove()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, .black.opacity(0.6))
        }
        .offset(x: 8, y: -8)
    }
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(
            text: .constant("Hello, this is a test"),
            attachments: .constant([]),
            isSending: false,
            onSend: {}
        )
    }
}
