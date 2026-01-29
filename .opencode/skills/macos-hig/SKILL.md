---
name: macos-hig
description: macOS Human Interface Guidelines - toolbars, sidebars, menus, pointers, accessibility
---

# macOS Human Interface Guidelines

Design principles and patterns for native macOS apps following Apple's HIG.

## Core Principles

### 1. Familiar, Not Foreign
- Use standard macOS patterns (sidebars, toolbars, menus)
- Respect keyboard-first users
- Support multiple windows naturally
- Integrate with system features (Spotlight, Services, Share)

### 2. Flexible Window Design
- Users resize and arrange windows freely
- Support full screen and Split View
- Remember window positions
- Adapt content to window size

### 3. Direct Manipulation
- Drag and drop everywhere it makes sense
- Context menus for quick actions
- Hover states for discoverability

---

## Navigation Patterns

### Sidebar Navigation (Primary Pattern)
```swift
NavigationSplitView {
    List(selection: $selection) {
        Section("Favorites") {
            ForEach(favorites) { item in
                Label(item.name, systemImage: item.icon)
            }
        }
        
        Section("Folders") {
            ForEach(folders) { folder in
                Label(folder.name, systemImage: "folder")
                    .badge(folder.unreadCount)
            }
        }
    }
    .listStyle(.sidebar)
    .frame(minWidth: 180)
} detail: {
    DetailView()
}
```

**Sidebar Guidelines:**
- Width: 180-280 points (user resizable)
- Show hierarchy with disclosure groups
- Use badges for counts/status
- Support drag reordering
- Allow hiding (⌘⌥S standard)

### Source List Sections
```swift
List {
    Section("Library") {
        // Primary navigation
    }
    
    Section("Collections") {
        // User-created groups
    }
    
    Section("Smart Collections") {
        // Auto-generated groups
    }
}
```

---

## Toolbars

### Toolbar Anatomy
```
┌─────────────────────────────────────────────────────────────┐
│ ← →  │  Title  │                    │ Search │ ⚙ │ + │ ⋯ │
│ nav  │         │     spacer         │        │ actions   │
└─────────────────────────────────────────────────────────────┘
```

### Toolbar Implementation
```swift
.toolbar {
    // Navigation (leading)
    ToolbarItem(placement: .navigation) {
        Button(systemImage: "sidebar.leading") {
            toggleSidebar()
        }
        .help("Toggle Sidebar")
    }
    
    // Principal (center) - optional
    ToolbarItem(placement: .principal) {
        Picker("View", selection: $viewMode) {
            Label("List", systemImage: "list.bullet").tag(ViewMode.list)
            Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
        }
        .pickerStyle(.segmented)
    }
    
    // Primary action
    ToolbarItem(placement: .primaryAction) {
        Button("New", systemImage: "plus") {
            createNew()
        }
        .help("Create New Chat (⌘N)")
    }
    
    // Secondary actions (overflow)
    ToolbarItem(placement: .secondaryAction) {
        Menu("More", systemImage: "ellipsis.circle") {
            Button("Export") { }
            Button("Share") { }
        }
    }
}
```

### Toolbar Best Practices
- **Primary actions**: Always visible, 1-3 items
- **Secondary actions**: In overflow menu
- **Customizable**: Allow via `ToolbarContentBuilder`
- **Help tags**: Add `.help()` for tooltips
- **Keyboard shortcuts**: Document in help tags

### Toolbar Styles
```swift
.toolbarRole(.browser)       // Back/forward navigation
.toolbarRole(.editor)        // Document editing
.toolbarRole(.navigationStack)  // Standard navigation
```

---

## Menus

### Menu Bar Structure
```
┌──────────────────────────────────────────────────────────────────┐
│  App │ File │ Edit │ View │ [Custom] │ Window │ Help │          │
└──────────────────────────────────────────────────────────────────┘
```

### Standard Menu Items

**App Menu:**
- About [App Name]
- Settings... (⌘,)
- Hide [App Name] (⌘H)
- Hide Others (⌘⌥H)
- Quit [App Name] (⌘Q)

**File Menu:**
- New (⌘N)
- Open... (⌘O)
- Save (⌘S)
- Close (⌘W)

**Edit Menu:**
- Undo (⌘Z)
- Redo (⌘⇧Z)
- Cut (⌘X)
- Copy (⌘C)
- Paste (⌘V)
- Select All (⌘A)
- Find... (⌘F)

### Context Menus
```swift
ItemRow(item: item)
    .contextMenu {
        // Primary actions first
        Button("Open") { open(item) }
        Button("Open in New Window") { openInWindow(item) }
        
        Divider()
        
        // Secondary actions
        Button("Duplicate") { duplicate(item) }
        Button("Rename...") { rename(item) }
        
        Divider()
        
        // Sharing
        ShareLink(item: item.url)
        
        Divider()
        
        // Destructive last
        Button("Delete", role: .destructive) { delete(item) }
    }
```

**Context Menu Guidelines:**
- Most common action first
- Group related items
- Destructive actions last with separator
- Match menu bar commands when applicable
- Show keyboard shortcuts

---

## Windows

### Window Types

| Type | Use Case | Example |
|------|----------|---------|
| **Document** | User content | Text editors, image editors |
| **App** | Single main window | Preferences, activity |
| **Utility** | Supporting info | Inspectors, palettes |
| **Panel** | Floating tools | Tool palettes |

### Window Sizing
```swift
// Minimum sizes
.frame(minWidth: 400, minHeight: 300)

// Recommended minimums by type:
// - Document: 500×400
// - Utility: 200×200
// - Inspector: 200×300

// Default sizes
.defaultSize(width: 1000, height: 700)
```

### Window Behavior
```swift
// Remember position
@SceneStorage("windowFrame") private var windowFrame: String?

// Full screen support (automatic)

// Close behavior
func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false  // Keep in Dock/menu bar
    // true for document-based apps
}
```

---

## Keyboard Navigation

### Focus Ring
- System draws focus rings automatically
- Don't disable unless you provide alternative
- Use `.focusable()` for custom focusable views

### Tab Navigation
```swift
Form {
    TextField("Name", text: $name)
    TextField("Email", text: $email)
    SecureField("Password", text: $password)
    
    // Tab moves through fields automatically
}
```

### Full Keyboard Access
Support users who navigate entirely by keyboard:

```swift
List(selection: $selection) {
    ForEach(items) { item in
        ItemRow(item: item)
            .focusable()
    }
}
.onMoveCommand { direction in
    handleArrowKey(direction)
}
.onExitCommand {
    clearSelection()
}
```

### Standard Shortcuts to Support
| Action | Shortcut |
|--------|----------|
| Cancel | Escape |
| Confirm | Return |
| Delete | ⌘⌫ or Delete |
| Select All | ⌘A |
| Find | ⌘F |
| Find Next | ⌘G |

---

## Pointer Interactions

### Cursor Types
```swift
// Link cursor
Button("Learn More") { }
    .pointerStyle(.link)

// Resize cursor
Divider()
    .pointerStyle(.horizontalResize)

// Grab cursor
DraggableItem()
    .pointerStyle(.grabIdle)
    .gesture(
        DragGesture()
            .onChanged { _ in }  // .grabActive automatically
    )

// Custom cursor
.pointerStyle(.init(
    shape: .custom { _ in
        Circle().frame(width: 24, height: 24)
    }
))
```

### Hover States
```swift
struct HoverableRow: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            
            // Show actions on hover
            if isHovered {
                Button(systemImage: "ellipsis") { }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? Color.accentColor.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
```

---

## Typography

### System Fonts
```swift
Text("Title").font(.largeTitle)      // 26pt
Text("Title 2").font(.title)          // 22pt
Text("Title 3").font(.title2)         // 17pt
Text("Headline").font(.headline)      // 13pt semibold
Text("Body").font(.body)              // 13pt
Text("Callout").font(.callout)        // 12pt
Text("Subheadline").font(.subheadline)// 11pt
Text("Footnote").font(.footnote)      // 10pt
Text("Caption").font(.caption)        // 10pt
Text("Caption 2").font(.caption2)     // 10pt
```

### Monospace for Data
```swift
Text("1,234").monospacedDigit()
Text("Code").monospaced()
```

---

## Colors

### Semantic Colors
```swift
// Text
Color.primary           // Main text
Color.secondary         // Secondary text
Color.tertiary          // Disabled/placeholder

// Backgrounds
Color(.windowBackground)
Color(.controlBackground)
Color(.textBackground)

// Accents
Color.accentColor       // User-selected accent
```

### Vibrancy
```swift
// Behind windows
.background(.ultraThinMaterial)
.background(.thinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)
```

---

## Drag and Drop

### Draggable Items
```swift
ItemRow(item: item)
    .draggable(item) {
        // Drag preview
        ItemPreview(item: item)
            .frame(width: 200, height: 50)
    }
```

### Drop Targets
```swift
FolderRow(folder: folder)
    .dropDestination(for: Item.self) { items, location in
        moveItems(items, to: folder)
        return true
    } isTargeted: { isTargeted in
        // Show drop indicator
    }
```

### Spring-Loading
Folders expand when hovering during drag:
```swift
FolderRow(folder: folder)
    .onDrop(of: [.item], isTargeted: $isTargeted) { providers in
        // Handle drop
    }
    .onChange(of: isTargeted) { _, targeted in
        if targeted {
            // Start timer to expand folder
            startSpringLoadTimer()
        }
    }
```

---

## Accessibility

### VoiceOver
```swift
ItemRow(item: item)
    .accessibilityLabel(item.title)
    .accessibilityHint("Double-click to open")
    .accessibilityValue(item.isRead ? "Read" : "Unread")
    .accessibilityAddTraits(.isButton)
```

### Keyboard Accessibility
- All actions reachable via keyboard
- Logical tab order
- Visible focus indicators

### Reduce Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

withAnimation(reduceMotion ? nil : .spring()) {
    // animation
}
```

---

## Anti-Patterns

### Don't
- ❌ Custom window chrome (use system title bar)
- ❌ Non-standard keyboard shortcuts for standard actions
- ❌ Hover-only functionality with no keyboard alternative
- ❌ Fixed window sizes (allow resizing)
- ❌ Single window when multiple makes sense
- ❌ Custom context menus that ignore system conventions
- ❌ Modal dialogs for non-critical actions

### Do
- ✅ Use NavigationSplitView for sidebar navigation
- ✅ Support standard keyboard shortcuts
- ✅ Allow window resizing and remember positions
- ✅ Use system colors and materials
- ✅ Provide keyboard alternatives for all actions
- ✅ Use standard menu structure
- ✅ Support drag and drop

---

## Resources

- [Apple HIG: macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
- [Apple HIG: Keyboard](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Apple HIG: Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
