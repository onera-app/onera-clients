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
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Attachment previews
            if !attachments.isEmpty {
                attachmentPreviewsView
            }
            
            // Input row
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: selectedPhotos) { _, items in
                    Task {
                        await loadPhotos(items)
                    }
                }
                
                // Text input
                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .onSubmit {
                        if !text.isEmpty {
                            onSend()
                        }
                    }
                
                // Send button
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
                .disabled(!canSend || isSending)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }
    
    private var attachmentPreviewsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreview(attachment: attachment) {
                        withAnimation {
                            attachments.removeAll { $0.id == attachment.id }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
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
}

struct AttachmentPreview: View {
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
                    }
                case .file:
                    Image(systemName: "doc.fill")
                        .font(.title)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
}

#Preview {
    VStack {
        Spacer()
        MessageInputView(
            text: .constant("Hello, this is a test message"),
            attachments: .constant([]),
            isSending: false,
            onSend: {}
        )
    }
}
