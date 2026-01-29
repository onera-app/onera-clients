---
name: ipados-features
description: iPadOS-specific features - Stage Manager, multitasking, keyboard/trackpad, Apple Pencil
---

# iPadOS Features Reference

Comprehensive guide for iPadOS-specific capabilities: Stage Manager, multi-window, keyboard/trackpad, and Apple Pencil.

## Stage Manager & Multi-Window

### Enabling Multi-Window
In your app target or Info.plist:
```xml
<key>UIApplicationSupportsMultipleScenes</key>
<true/>
```

### Scene Configuration
```swift
@main
struct OneraApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .defaultSize(CGSize(width: 1024, height: 768))
        
        // Chat window type
        WindowGroup("Chat", for: Chat.ID.self) { $chatId in
            if let chatId {
                ChatWindowView(chatId: chatId)
            }
        }
        .defaultSize(CGSize(width: 600, height: 500))
        
        // Note window type
        WindowGroup("Note", for: Note.ID.self) { $noteId in
            if let noteId {
                NoteWindowView(noteId: noteId)
            }
        }
        .defaultSize(CGSize(width: 500, height: 600))
    }
}
```

### Opening Windows
```swift
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    
    var body: some View {
        Button("Open in New Window") {
            if supportsMultipleWindows {
                openWindow(id: "chat", value: chat.id)
            } else {
                // Fallback: navigate within current window
                navigateToChat(chat)
            }
        }
        // Only show if multi-window is supported
        .opacity(supportsMultipleWindows ? 1 : 0)
    }
}
```

### Window Size Adaptation
```swift
struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 600
            let isLandscape = geometry.size.width > geometry.size.height
            
            if isCompact {
                // Slide Over, small Stage Manager window, Split View 1/3
                CompactLayout()
            } else if isLandscape {
                // Full screen landscape, large Stage Manager window
                WideLayout()
            } else {
                // Portrait, Split View 1/2
                RegularLayout()
            }
        }
    }
}
```

### Size Classes Reference
| Configuration | Horizontal | Vertical |
|--------------|------------|----------|
| Full screen portrait | Regular | Regular |
| Full screen landscape | Regular | Compact |
| Split View 1/2 | Regular* | Regular |
| Split View 1/3 | Compact | Regular |
| Split View 2/3 | Regular | Regular |
| Slide Over | Compact | Regular |
| Stage Manager (varies) | Depends on size | Depends on size |

*On smaller iPads, 1/2 Split View may be Compact

---

## Adaptive Layouts

### NavigationSplitView for iPad
```swift
struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedFolder: Folder?
    @State private var selectedChat: Chat?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView(selectedFolder: $selectedFolder)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 350)
        } content: {
            // Content list
            if let folder = selectedFolder {
                ChatListView(folder: folder, selection: $selectedChat)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 350)
        } detail: {
            // Detail
            if let chat = selectedChat {
                ChatDetailView(chat: chat)
            } else {
                ContentUnavailableView("Select a Chat", systemImage: "bubble.left")
            }
        }
        .navigationSplitViewStyle(.balanced)  // All columns equal importance
    }
}
```

### Collapsible Sidebar
```swift
struct CollapsibleSidebar: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar()
        } detail: {
            Detail()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation {
                                columnVisibility = columnVisibility == .all ? .detailOnly : .all
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                    }
                }
        }
    }
}
```

---

## Keyboard Support

### Keyboard Shortcuts
```swift
struct ChatView: View {
    var body: some View {
        content
            // Standard shortcuts
            .keyboardShortcut("n", modifiers: .command)  // New
            .keyboardShortcut("f", modifiers: .command)  // Find
            .keyboardShortcut(.return, modifiers: .command)  // Send
            .keyboardShortcut(.escape)  // Cancel
    }
}
```

### Commands for Global Shortcuts
```swift
@main
struct OneraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Chat") {
                Button("New Chat") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Send Message") {
                    NotificationCenter.default.post(name: .sendMessage, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}
```

### UIKeyCommand (UIKit Integration)
```swift
// For more control, use UIKeyCommand in UIHostingController
class KeyboardHostingController<Content: View>: UIHostingController<Content> {
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: "New Chat",
                action: #selector(newChat),
                input: "n",
                modifierFlags: .command
            ),
            UIKeyCommand(
                title: "Search",
                action: #selector(search),
                input: "f",
                modifierFlags: .command
            )
        ]
    }
    
    @objc func newChat() {
        NotificationCenter.default.post(name: .newChat, object: nil)
    }
    
    @objc func search() {
        NotificationCenter.default.post(name: .search, object: nil)
    }
}
```

### Focus System
```swift
struct FocusableList: View {
    @FocusState private var focusedItem: Item.ID?
    let items: [Item]
    
    var body: some View {
        List(items) { item in
            ItemRow(item: item)
                .focused($focusedItem, equals: item.id)
                .focusEffectDisabled()  // Custom focus style
                .background(focusedItem == item.id ? Color.accentColor.opacity(0.1) : .clear)
        }
        .focusable()
        .onMoveCommand { direction in
            moveFocus(direction)
        }
    }
    
    private func moveFocus(_ direction: MoveCommandDirection) {
        guard let current = focusedItem,
              let index = items.firstIndex(where: { $0.id == current }) else {
            focusedItem = items.first?.id
            return
        }
        
        switch direction {
        case .up where index > 0:
            focusedItem = items[index - 1].id
        case .down where index < items.count - 1:
            focusedItem = items[index + 1].id
        default:
            break
        }
    }
}
```

---

## Trackpad & Pointer

### Hover Effects
```swift
struct HoverableCard: View {
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            // Content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(radius: isHovered ? 8 : 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
```

### Continuous Hover Tracking
```swift
struct HoverTrackingView: View {
    @State private var hoverLocation: CGPoint?
    
    var body: some View {
        Canvas { context, size in
            // Draw hover indicator
            if let location = hoverLocation {
                let rect = CGRect(
                    x: location.x - 25,
                    y: location.y - 25,
                    width: 50,
                    height: 50
                )
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.accentColor.opacity(0.3))
                )
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
            }
        }
    }
}
```

### Pointer Styles
```swift
// Link cursor
Button("Learn More") { }
    .pointerStyle(.link)

// Resize
Rectangle()
    .frame(width: 4)
    .pointerStyle(.horizontalResize)

// Custom highlight effect
Button("Action") { }
    .pointerStyle(.automatic)  // Default lift effect
```

### Trackpad Gestures
```swift
struct GestureView: View {
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    
    var body: some View {
        Image("photo")
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = value.magnification
                    }
            )
            .gesture(
                RotateGesture()
                    .onChanged { value in
                        rotation = value.rotation
                    }
            )
            // Two-finger scroll is automatic in ScrollView
    }
}
```

---

## Apple Pencil

### PencilKit Canvas
```swift
import PencilKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var drawing: PKDrawing
    @State private var toolPicker = PKToolPicker()
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.drawing = drawing
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 5)
        
        // Drawing policy
        canvasView.drawingPolicy = .pencilOnly  // or .anyInput, .default
        
        // Tool picker
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        
        // Finger vs Pencil
        canvasView.allowsFingerDrawing = false  // Pencil only
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        
        init(_ parent: DrawingCanvas) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
```

### Drawing Tools
```swift
// Pen
let pen = PKInkingTool(.pen, color: .black, width: 5)

// Pencil (texture)
let pencil = PKInkingTool(.pencil, color: .gray, width: 3)

// Marker (transparent)
let marker = PKInkingTool(.marker, color: .yellow, width: 20)

// Monoline (consistent width)
let monoline = PKInkingTool(.monoline, color: .blue, width: 2)

// Fountain pen (variable width)
let fountain = PKInkingTool(.fountainPen, color: .black, width: 4)

// Watercolor
let watercolor = PKInkingTool(.watercolor, color: .blue, width: 30)

// Crayon
let crayon = PKInkingTool(.crayon, color: .orange, width: 15)

// Eraser
let eraser = PKEraserTool(.vector)  // or .bitmap, .fixedWidthBitmap(width:)

// Lasso (selection)
let lasso = PKLassoTool()
```

### Pencil Interactions (SwiftUI)
```swift
struct PencilInteractiveView: View {
    @State private var showToolPicker = false
    @State private var currentTool: DrawingTool = .pen
    
    var body: some View {
        DrawingCanvas()
            // Double-tap Apple Pencil (2nd gen+)
            .onPencilDoubleTap { value in
                switch value.preferredAction {
                case .switchEraser:
                    toggleEraser()
                case .switchPrevious:
                    switchToPreviousTool()
                case .showColorPalette:
                    showColorPicker()
                case .showInkAttributes:
                    showToolAttributes()
                default:
                    break
                }
            }
            // Squeeze Apple Pencil Pro
            .onPencilSqueeze { phase in
                switch phase {
                case .began:
                    showToolPicker = true
                case .ended:
                    showToolPicker = false
                @unknown default:
                    break
                }
            }
    }
}
```

### Pencil Hover (Apple Pencil Pro)
```swift
struct HoverPreviewCanvas: View {
    @State private var hoverLocation: CGPoint?
    @State private var hoverAltitude: Double?
    @State private var hoverAzimuth: Double?
    
    var body: some View {
        Canvas { context, size in
            // Draw preview at hover location
            if let location = hoverLocation {
                // Size based on altitude (distance from screen)
                let previewSize = 10.0 + (hoverAltitude ?? 0) * 20.0
                
                let rect = CGRect(
                    x: location.x - previewSize / 2,
                    y: location.y - previewSize / 2,
                    width: previewSize,
                    height: previewSize
                )
                
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.blue.opacity(0.3))
                )
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
            }
        }
    }
}
```

### Pressure & Tilt (UIKit)
```swift
class DrawingView: UIView {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        let force = touch.force  // 0.0-6.67 on capable devices
        let azimuth = touch.azimuthAngle(in: self)  // Rotation around perpendicular
        let altitude = touch.altitudeAngle  // Angle from surface (π/2 = perpendicular)
        
        // Adjust stroke based on pressure and tilt
        let width = baseWidth * (1 + force / 3)
        
        // Draw with adjusted parameters
    }
}
```

---

## Drag and Drop

### Within App
```swift
struct DraggableItem: View {
    let item: Item
    
    var body: some View {
        ItemView(item: item)
            .draggable(item) {
                // Drag preview
                ItemPreview(item: item)
                    .frame(width: 200, height: 50)
            }
    }
}

struct DroppableFolder: View {
    let folder: Folder
    @State private var isTargeted = false
    
    var body: some View {
        FolderView(folder: folder)
            .background(isTargeted ? Color.accentColor.opacity(0.2) : .clear)
            .dropDestination(for: Item.self) { items, location in
                moveItems(items, to: folder)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }
}
```

### Between Apps
```swift
// Export to other apps
ItemView(item: item)
    .draggable(item.transferRepresentation) {
        ItemPreview(item: item)
    }

// Import from other apps
DropZone()
    .dropDestination(for: Data.self) { items, location in
        for data in items {
            importData(data)
        }
        return true
    }

// Support multiple types
.dropDestination(for: URL.self) { urls, _ in
    // Handle URLs
} isTargeted: { _ in }
.dropDestination(for: String.self) { strings, _ in
    // Handle text
} isTargeted: { _ in }
```

### Transferable Protocol
```swift
struct ChatItem: Transferable {
    let id: UUID
    let content: String
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: ChatItem.self, contentType: .json)
        
        ProxyRepresentation(exporting: \.content)  // Plain text fallback
    }
}
```

---

## Split View & Slide Over

### Detecting Multitasking Mode
```swift
struct MultitaskingAwareView: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    
    var isSlideOver: Bool {
        hSize == .compact && vSize == .regular
    }
    
    var isSplitView: Bool {
        // Detect by checking if we're not full width
        // More reliable with GeometryReader
        false
    }
    
    var body: some View {
        GeometryReader { geo in
            let screenWidth = UIScreen.main.bounds.width
            let isFullWidth = abs(geo.size.width - screenWidth) < 1
            
            if isSlideOver || geo.size.width < 400 {
                // Compact layout for Slide Over / narrow Split View
                CompactLayout()
            } else if !isFullWidth {
                // Split View
                SplitViewLayout()
            } else {
                // Full screen
                FullScreenLayout()
            }
        }
    }
}
```

### Optimizing for Slide Over
```swift
struct SlideOverOptimizedView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    var body: some View {
        if sizeClass == .compact {
            // Single column, simplified UI
            NavigationStack {
                List(items) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item)
                    }
                }
                .navigationDestination(for: Item.self) { item in
                    ItemDetail(item: item)
                }
            }
        } else {
            // Multi-column
            NavigationSplitView {
                Sidebar()
            } detail: {
                Detail()
            }
        }
    }
}
```

---

## Best Practices Summary

### Do
- ✅ Support all size classes gracefully
- ✅ Add keyboard shortcuts for power users
- ✅ Support Apple Pencil where it adds value
- ✅ Enable drag and drop between apps
- ✅ Use NavigationSplitView for iPad
- ✅ Test in Stage Manager with various window sizes
- ✅ Add hover states for trackpad users

### Don't
- ❌ Assume full screen
- ❌ Require touch for all interactions
- ❌ Ignore keyboard navigation
- ❌ Lock orientation
- ❌ Disable multi-window without reason
- ❌ Use fixed layouts that don't adapt

---

## Resources

- [Apple HIG: iPadOS](https://developer.apple.com/design/human-interface-guidelines/ipados)
- [Apple HIG: Apple Pencil](https://developer.apple.com/design/human-interface-guidelines/apple-pencil)
- [Apple HIG: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [PencilKit Documentation](https://developer.apple.com/documentation/pencilkit)
