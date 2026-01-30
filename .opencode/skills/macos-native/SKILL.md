---
name: macos-native
description: macOS native SwiftUI patterns - NavigationSplitView, Commands, Settings, Windows, Keyboard, Tables
---

# macOS Native SwiftUI Patterns

Comprehensive reference for building native macOS apps that follow Apple HIG.

---

## App Structure

### Complete App Template

```swift
@main
struct OneraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .commands { AppCommands() }
        .defaultSize(width: 1100, height: 750)
        
        // Settings (⌘,)
        Settings {
            SettingsView()
        }
        
        // Menu bar extra
        MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
        
        // Pop-out windows
        WindowGroup("Chat", for: String.self) { $chatId in
            if let chatId { ChatWindowView(chatId: chatId) }
        }
        .defaultSize(width: 650, height: 550)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep in menu bar
    }
}
```

---

## NavigationSplitView

### Two-Column

```swift
struct ContentView: View {
    @State private var selection: Item?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            if let selection {
                DetailView(item: selection)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "doc")
            }
        }
    }
}
```

### Three-Column

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    Sidebar()
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
} content: {
    ContentList()
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
} detail: {
    Detail()
}
.navigationSplitViewStyle(.balanced)
```

### Sidebar Styling

```swift
List(selection: $selection) {
    Section("Favorites") {
        ForEach(favorites) { item in
            Label(item.name, systemImage: item.icon)
                .badge(item.count)
        }
    }
    
    Section("Folders") {
        ForEach(folders) { folder in
            Label(folder.name, systemImage: "folder")
        }
    }
}
.listStyle(.sidebar)
```

---

## Commands (Menu Bar)

### Custom Commands

```swift
struct AppCommands: Commands {
    var body: some Commands {
        // Replace File > New
        CommandGroup(replacing: .newItem) {
            Button("New Chat") { }
                .keyboardShortcut("n", modifiers: .command)
            
            Button("New Folder") { }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        // Custom menu
        CommandMenu("Chat") {
            Button("Send Message") { }
                .keyboardShortcut(.return, modifiers: .command)
            
            Divider()
            
            Button("Clear History") { }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            
            Divider()
            
            Menu("Export") {
                Button("As PDF") { }
                Button("As Markdown") { }
            }
        }
        
        // Add to View menu
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") { }
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
```

### Command Placements

```swift
CommandGroup(replacing: .newItem) { }    // File > New
CommandGroup(replacing: .saveItem) { }    // File > Save
CommandGroup(replacing: .undoRedo) { }    // Edit > Undo/Redo
CommandGroup(replacing: .help) { }        // Help menu
CommandGroup(before: .sidebar) { }        // Before sidebar toggle
CommandGroup(after: .sidebar) { }         // After sidebar toggle
```

---

## Keyboard Shortcuts

### Standard Shortcuts

| Action | Shortcut | Code |
|--------|----------|------|
| New | ⌘N | `.keyboardShortcut("n", modifiers: .command)` |
| Save | ⌘S | `.keyboardShortcut("s", modifiers: .command)` |
| Close | ⌘W | `.keyboardShortcut("w", modifiers: .command)` |
| Find | ⌘F | `.keyboardShortcut("f", modifiers: .command)` |
| Settings | ⌘, | Automatic with `Settings { }` |
| Send | ⌘↩ | `.keyboardShortcut(.return, modifiers: .command)` |
| Cancel | Esc | `.keyboardShortcut(.escape)` |

### Focus Navigation

```swift
struct NavigableList: View {
    @FocusState private var focusedItem: Item.ID?
    
    var body: some View {
        List(items) { item in
            ItemRow(item: item)
                .focused($focusedItem, equals: item.id)
        }
        .focusable()
        .onMoveCommand { direction in
            moveFocus(direction)
        }
        .onDeleteCommand {
            if let id = focusedItem { delete(id) }
        }
        .onExitCommand {
            focusedItem = nil
        }
    }
}
```

### Key Press Handling

```swift
.onKeyPress(.return, modifiers: .command) {
    sendMessage()
    return .handled
}
.onKeyPress(characters: .alphanumerics) { press in
    handleTyping(press.characters)
    return .handled
}
```

---

## Window Management

### Multiple Windows

```swift
@main
struct OneraApp: App {
    var body: some Scene {
        // Main
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 750)
        .windowStyle(.hiddenTitleBar)
        
        // Document window
        WindowGroup("Chat", for: String.self) { $id in
            if let id { ChatWindowView(chatId: id) }
        }
        .defaultSize(width: 650, height: 550)
        
        // Utility window
        Window("Activity", id: "activity") {
            ActivityView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.topTrailing)
    }
}
```

### Opening Windows

```swift
@Environment(\.openWindow) private var openWindow

Button("Open in New Window") {
    openWindow(id: "Chat", value: chat.id)
}
```

### Window Styles

```swift
.windowStyle(.automatic)      // Standard
.windowStyle(.hiddenTitleBar) // No title bar
.windowStyle(.titleBar)       // Explicit title bar

.windowToolbarStyle(.unified)
.windowToolbarStyle(.unified(showsTitle: false))
```

---

## Settings Scene

```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            
            AccountTab()
                .tabItem { Label("Account", systemImage: "person") }
            
            SecurityTab()
                .tabItem { Label("Security", systemImage: "lock.shield") }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralTab: View {
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            
            Toggle("Launch at Login", isOn: $launchAtLogin)
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

---

## Table View

```swift
struct MessagesTable: View {
    @State private var selection = Set<Message.ID>()
    @State private var sortOrder = [KeyPathComparator(\Message.date, order: .reverse)]
    
    var body: some View {
        Table(messages, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { message in
                Text(message.date, style: .date)
            }
            .width(min: 80, ideal: 100, max: 120)
            
            TableColumn("Content", value: \.content)
            
            TableColumn("Status") { message in
                StatusBadge(status: message.status)
            }
            .width(80)
        }
        .contextMenu(forSelectionType: Message.ID.self) { selection in
            Button("Copy") { }
            Button("Delete", role: .destructive) { }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}
```

---

## Inspector Panel

```swift
struct ContentView: View {
    @State private var showInspector = false
    
    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            Detail()
                .inspector(isPresented: $showInspector) {
                    InspectorView()
                        .inspectorColumnWidth(min: 200, ideal: 280, max: 350)
                }
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showInspector) {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }
}
```

---

## Toolbar

```swift
.toolbar {
    ToolbarItem(placement: .navigation) {
        Button(systemImage: "sidebar.leading") { }
            .help("Toggle Sidebar (⌘⌥S)")
    }
    
    ToolbarItem(placement: .principal) {
        Picker("View", selection: $viewMode) {
            Label("List", systemImage: "list.bullet").tag(0)
            Label("Grid", systemImage: "square.grid.2x2").tag(1)
        }
        .pickerStyle(.segmented)
    }
    
    ToolbarItem(placement: .primaryAction) {
        Button("New", systemImage: "plus") { }
            .help("New Chat (⌘N)")
    }
    
    ToolbarItem(placement: .secondaryAction) {
        Menu("More", systemImage: "ellipsis.circle") {
            Button("Export") { }
            Button("Share") { }
        }
    }
}
.toolbarRole(.editor)
```

---

## Menu Bar Extra

### Window Style

```swift
MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
    VStack(spacing: 12) {
        TextField("Quick message...", text: $message)
            .textFieldStyle(.roundedBorder)
        
        Divider()
        
        Button("Open Onera") {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
    .padding()
    .frame(width: 280)
}
.menuBarExtraStyle(.window)
```

### Menu Style

```swift
MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
    Button("New Chat") { }
        .keyboardShortcut("n", modifiers: .command)
    
    Divider()
    
    Menu("Recent") {
        ForEach(recentChats) { chat in
            Button(chat.title) { }
        }
    }
    
    Divider()
    
    Button("Quit") {
        NSApplication.shared.terminate(nil)
    }
}
.menuBarExtraStyle(.menu)
```

---

## Context Menus

```swift
ItemRow(item: item)
    .contextMenu {
        Button("Open") { }
        Button("Open in New Window") { }
        
        Divider()
        
        Button("Duplicate") { }
        Button("Rename...") { }
        
        Divider()
        
        ShareLink(item: item.url)
        
        Divider()
        
        Button("Delete", role: .destructive) { }
    }
```

---

## Hover States

```swift
struct HoverableRow: View {
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            
            if isHovered {
                Button(systemImage: "ellipsis") { }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovered ? Color.accentColor.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { isHovered = $0 }
    }
}
```

---

## Drag and Drop

```swift
// Draggable
ItemRow(item: item)
    .draggable(item) {
        ItemPreview(item: item)
    }

// Drop target
FolderRow(folder: folder)
    .dropDestination(for: Item.self) { items, _ in
        moveItems(items, to: folder)
        return true
    } isTargeted: { isTargeted in
        // Show indicator
    }
```

---

## Platform Conditionals

```swift
#if os(macOS)
    .frame(minWidth: 800, minHeight: 600)
    .keyboardShortcut("w", modifiers: .command)
#endif

extension View {
    @ViewBuilder
    func macOS<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        #if os(macOS)
        transform(self)
        #else
        self
        #endif
    }
}
```

---

## Anti-Patterns

| Bad | Good |
|-----|------|
| `NavigationStack` (iOS style) | `NavigationSplitView` |
| Custom window chrome | System title bar |
| Single window only | Multiple `WindowGroup` |
| No keyboard shortcuts | Shortcuts for all actions |
| Custom settings window | `Settings { }` scene |
| Tab bar navigation | Sidebar navigation |
