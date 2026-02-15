//
//  PencilCanvasView.swift
//  Onera
//
//  Apple Pencil drawing canvas for iPad notes
//

import SwiftUI
import PencilKit

#if os(iOS)

// MARK: - Pencil Canvas View

struct PencilCanvasView: View {
    @Binding var drawing: PKDrawing
    @Binding var isDrawingMode: Bool
    
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @Environment(\.undoManager) private var undoManager
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            PencilCanvasRepresentable(
                canvasView: $canvasView,
                drawing: $drawing,
                isDrawingMode: $isDrawingMode,
                toolPicker: toolPicker
            )
            .ignoresSafeArea(edges: .bottom)
            
            // Drawing mode toggle
            drawingModeToggle
                .padding()
        }
        .onAppear {
            setupToolPicker()
        }
        .onChange(of: colorScheme) { _, newScheme in
            updateCanvasBackground(for: newScheme)
        }
    }
    
    // MARK: - Drawing Mode Toggle
    
    private var drawingModeToggle: some View {
        HStack(spacing: 12) {
            // Undo button
            Button {
                undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(!(undoManager?.canUndo ?? false))
            
            // Redo button
            Button {
                undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.body.weight(.medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(!(undoManager?.canRedo ?? false))
            
            Divider()
                .frame(height: 24)
            
            // Toggle drawing/text mode
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDrawingMode.toggle()
                }
                if isDrawingMode {
                    toolPicker.setVisible(true, forFirstResponder: canvasView)
                    canvasView.becomeFirstResponder()
                } else {
                    toolPicker.setVisible(false, forFirstResponder: canvasView)
                    canvasView.resignFirstResponder()
                }
            } label: {
                Image(systemName: isDrawingMode ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                    .font(.title3.weight(.medium))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .tint(isDrawingMode ? .accentColor : .secondary)
        }
        .padding(OneraSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OneraRadius.medium))
    }
    
    // MARK: - Private Methods
    
    private func setupToolPicker() {
        toolPicker.addObserver(canvasView)
        if isDrawingMode {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            canvasView.becomeFirstResponder()
        }
    }
    
    private func updateCanvasBackground(for colorScheme: ColorScheme) {
        canvasView.backgroundColor = colorScheme == .dark ? .black : .white
    }
}

// MARK: - Canvas UIViewRepresentable

struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var drawing: PKDrawing
    @Binding var isDrawingMode: Bool
    
    let toolPicker: PKToolPicker
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .pencilOnly // Only Apple Pencil draws
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.alwaysBounceVertical = true
        canvasView.showsVerticalScrollIndicator = true
        
        // Enable finger scrolling when not in drawing mode
        updateDrawingGestureRecognizer()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        updateDrawingGestureRecognizer()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateDrawingGestureRecognizer() {
        // When in drawing mode, only Pencil can draw
        // When not in drawing mode, fingers scroll
        canvasView.drawingGestureRecognizer.isEnabled = isDrawingMode
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: PencilCanvasRepresentable
        
        init(_ parent: PencilCanvasRepresentable) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

// MARK: - Drawing Data Extensions

extension PKDrawing {
    /// Convert drawing to data for storage
    var storageData: Data {
        dataRepresentation()
    }
    
    /// Create drawing from stored data
    static func from(data: Data) -> PKDrawing? {
        try? PKDrawing(data: data)
    }
}

// MARK: - Drawing Thumbnail

extension PKDrawing {
    /// Generate a thumbnail image of the drawing
    func thumbnail(size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage {
        image(from: bounds, scale: scale)
    }
}

// MARK: - Preview

#Preview {
    PencilCanvasView(
        drawing: .constant(PKDrawing()),
        isDrawingMode: .constant(true)
    )
}

#endif
