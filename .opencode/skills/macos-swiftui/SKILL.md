---
name: macos-swiftui
description: macOS-specific SwiftUI patterns - NavigationSplitView, Commands, Settings, Windows, Keyboard shortcuts
---

# macOS SwiftUI Patterns

Comprehensive reference for building native macOS apps with SwiftUI.

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
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1200, height: 800)
        
        // Settings window (⌘,)
        Settings {
            SettingsView()
        }
        
        // Menu bar extra (optional)
        MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}

// Optional: AppDelegate for lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup code
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // Keep running in menu bar
    }
}
```

---

## NavigationSplitView

### Two-Column Layout
```swift
struct ContentView: View {
    @State private var selectedFolder: Folder?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedFolder)
        } detail: {
            if let folder = selectedFolder {
                FolderDetailView(folder: folder)
            } else {
                PlaceholderView()
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
    }
}
```

### Three-Column Layout
```swift
struct ThreeColumnView: View {
    @State private var selectedSection: Section?
    @State private var selectedItem: Item?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(sections, selection: $selectedSection) { section in
                Label(section.name, systemImage: section.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            // Content list
            if let section = selectedSection {
                List(section.items, selection: $selectedItem) { item in
                    ItemRow(item: item)
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            // Detail view
            if let item = selectedItem {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "doc")
            }
        }
        .navigationSplitViewStyle(.balanced)  // or .prominentDetail, .automatic
    }
}
```

### Sidebar Styling
```swift
List(selection: $selection) {
    Section("Chats") {
        ForEach(chats) { chat in
            Label(chat.title, systemImage: "bubble.left")
        }
    }
    
    Section("Folders") {
        ForEach(folders) { folder in
            Label(folder.name, systemImage: "folder")
        }
    }
}
.listStyle(.sidebar)
.navigationTitle("Onera")
```

---

## Commands (Menu Bar)

### Custom Commands Structure
```swift
struct AppCommands: Commands {
    @FocusedBinding(\.document) var document
    
    var body: some Commands {
        // Replace standard commands
        CommandGroup(replacing: .newItem) {
            Button("New Chat") {
                NotificationCenter.default.post(name: .newChat, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("New Folder") {
                NotificationCenter.default.post(name: .newFolder, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        
        // Add after existing group
        CommandGroup(after: .sidebar) {
            Button("Toggle Inspector") {
                NotificationCenter.default.post(name: .toggleInspector, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
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
                Button("As JSON") { }
            }
        }
    }
}
```

### Command Group Placements
```swift
CommandGroup(replacing: .appInfo) { }      // About menu
CommandGroup(replacing: .newItem) { }       // File > New
CommandGroup(replacing: .saveItem) { }      // File > Save
CommandGroup(replacing: .undoRedo) { }      // Edit > Undo/Redo
CommandGroup(replacing: .pasteboard) { }    // Edit > Copy/Paste
CommandGroup(replacing: .windowSize) { }    // Window size
CommandGroup(replacing: .help) { }          // Help menu

CommandGroup(before: .newItem) { }          // Before New
CommandGroup(after: .newItem) { }           // After New
```

### Focused Values for Commands
```swift
// Define focused value
struct FocusedChatKey: FocusedValueKey {
    typealias Value = Binding<Chat?>
}

extension FocusedValues {
    var selectedChat: Binding<Chat?>? {
        get { self[FocusedChatKey.self] }
        set { self[FocusedChatKey.self] = newValue }
    }
}

// Provide from view
struct ChatView: View {
    @State private var chat: Chat?
    
    var body: some View {
        DetailView(chat: chat)
            .focusedSceneValue(\.selectedChat, $chat)
    }
}

// Use in commands
struct AppCommands: Commands {
    @FocusedBinding(\.selectedChat) var chat
    
    var body: some Commands {
        CommandMenu("Chat") {
            Button("Delete Chat") {
                // delete chat
            }
            .disabled(chat == nil)
        }
    }
}
```

---

## Settings Scene

### Tabbed Settings
```swift
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AccountSettingsTab()
                .tabItem {
                    Label("Account", systemImage: "person")
                }
            
            SecuritySettingsTab()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
            
            AdvancedSettingsTab()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 500, height: 350)
    }
}
```

### Settings Tab Content
```swift
struct GeneralSettingsTab: View {
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = true
    
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag(Appearance.system)
                Text("Light").tag(Appearance.light)
                Text("Dark").tag(Appearance.dark)
            }
            
            Toggle("Launch at Login", isOn: $launchAtLogin)
            Toggle("Show in Dock", isOn: $showInDock)
            
            LabeledContent("Version") {
                Text(Bundle.main.appVersion)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
```

---

## Window Management

### Multiple Window Types
```swift
@main
struct OneraApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        
        // Chat window (opened programmatically)
        WindowGroup("Chat", for: Chat.ID.self) { $chatId in
            if let chatId {
                ChatWindowView(chatId: chatId)
            }
        }
        .defaultSize(width: 600, height: 500)
        .windowResizability(.contentSize)  // or .contentMinSize, .automatic
        
        // Utility window
        Window("Activity", id: "activity") {
            ActivityView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.topTrailing)
        .defaultSize(width: 300, height: 400)
    }
}
```

### Opening Windows
```swift
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        VStack {
            Button("Open Chat Window") {
                openWindow(id: "chat", value: selectedChat.id)
            }
            
            Button("Show Activity") {
                openWindow(id: "activity")
            }
        }
    }
}
```

### Window Styles
```swift
WindowGroup { }
    .windowStyle(.hiddenTitleBar)       // No title bar
    .windowStyle(.titleBar)             // Standard (default)

Window("Utility", id: "utility") { }
    .windowStyle(.plain)                // No chrome at all
```

### Window Toolbar
```swift
NavigationSplitView {
    Sidebar()
} detail: {
    Detail()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(systemImage: "sidebar.leading") {
                    // toggle sidebar
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("New", systemImage: "plus") { }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Export") { }
                    Button("Share") { }
                }
            }
        }
        .toolbarRole(.editor)  // or .browser, .navigationStack, .automatic
}
```

---

## Keyboard Shortcuts

### View-Level Shortcuts
```swift
struct ChatView: View {
    var body: some View {
        content
            // Standard shortcuts
            .keyboardShortcut("s", modifiers: .command)  // ⌘S
            .keyboardShortcut("z", modifiers: [.command, .shift])  // ⌘⇧Z
            
            // Special keys
            .keyboardShortcut(.return, modifiers: .command)  // ⌘↩
            .keyboardShortcut(.escape)  // ESC
            .keyboardShortcut(.delete, modifiers: .command)  // ⌘⌫
            .keyboardShortcut(.tab, modifiers: .control)  // ^⇥
            
            // Arrow keys
            .keyboardShortcut(.upArrow, modifiers: .option)
            .keyboardShortcut(.downArrow, modifiers: .option)
    }
}
```

### Focus-Based Navigation
```swift
struct NavigableList: View {
    @FocusState private var focusedItem: Item.ID?
    let items: [Item]
    
    var body: some View {
        List(items) { item in
            ItemRow(item: item)
                .focused($focusedItem, equals: item.id)
        }
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .up:
                moveFocusUp()
            case .down:
                moveFocusDown()
            default:
                break
            }
        }
        .onExitCommand {
            focusedItem = nil
        }
        .onDeleteCommand {
            if let id = focusedItem {
                deleteItem(id)
            }
        }
    }
}
```

### Keyboard Event Handling
```swift
struct KeyboardResponder: View {
    var body: some View {
        content
            .onKeyPress(.return, modifiers: .command) {
                sendMessage()
                return .handled
            }
            .onKeyPress(characters: .alphanumerics) { press in
                handleTyping(press.characters)
                return .handled
            }
            .onKeyPress { press in
                // Catch-all handler
                print("Key: \(press.key), modifiers: \(press.modifiers)")
                return .ignored  // Let it propagate
            }
    }
}
```

---

## Table View

### Basic Table
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
            
            TableColumn("Model") { message in
                Text(message.model)
                    .foregroundStyle(.secondary)
            }
            .width(100)
            
            TableColumn("Tokens") { message in
                Text("\(message.tokens)")
                    .monospacedDigit()
            }
            .width(60)
        }
        .contextMenu(forSelectionType: Message.ID.self) { selection in
            Button("Copy") { copyMessages(selection) }
            Button("Delete", role: .destructive) { deleteMessages(selection) }
        } primaryAction: { selection in
            openMessages(selection)
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
    @State private var selectedItem: Item?
    
    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            DetailView(item: selectedItem)
                .inspector(isPresented: $showInspector) {
                    InspectorView(item: selectedItem)
                        .inspectorColumnWidth(min: 200, ideal: 280, max: 350)
                }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showInspector) {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }
}

struct InspectorView: View {
    let item: Item?
    
    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: item?.name ?? "—")
                LabeledContent("Created", value: item?.createdAt.formatted() ?? "—")
            }
            
            Section("Actions") {
                Button("Export") { }
                Button("Share") { }
            }
        }
        .formStyle(.grouped)
    }
}
```

---

## Menu Bar Extra

### Window Style
```swift
MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
    VStack(spacing: 12) {
        Text("Quick Actions")
            .font(.headline)
        
        Button("New Chat") { }
        Button("Search") { }
        
        Divider()
        
        Button("Open Onera") {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
    .padding()
    .frame(width: 200)
}
.menuBarExtraStyle(.window)
```

### Menu Style
```swift
MenuBarExtra("Onera", systemImage: "bubble.left.fill") {
    Button("New Chat") { }
        .keyboardShortcut("n", modifiers: .command)
    
    Button("Search...") { }
        .keyboardShortcut("f", modifiers: .command)
    
    Divider()
    
    Menu("Recent Chats") {
        ForEach(recentChats) { chat in
            Button(chat.title) { openChat(chat) }
        }
    }
    
    Divider()
    
    Button("Quit Onera") {
        NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
}
.menuBarExtraStyle(.menu)
```

---

## macOS-Specific Modifiers

### Frame Constraints
```swift
ContentView()
    .frame(minWidth: 800, idealWidth: 1200, maxWidth: .infinity,
           minHeight: 600, idealHeight: 800, maxHeight: .infinity)
```

### Pointer Cursor
```swift
Text("Link")
    .onTapGesture { }
    .pointerStyle(.link)

Text("Grab")
    .gesture(DragGesture())
    .pointerStyle(.grabIdle)  // or .grabActive
```

### Hover Effects
```swift
struct HoverButton: View {
    @State private var isHovered = false
    
    var body: some View {
        Button("Action") { }
            .background(isHovered ? Color.accentColor.opacity(0.1) : .clear)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
```

---

## Platform Conditionals

```swift
#if os(macOS)
    .frame(minWidth: 800, minHeight: 600)
    .keyboardShortcut("w", modifiers: .command)
#endif

// ViewBuilder approach
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

// Usage
Text("Hello")
    .macOS { $0.font(.title) }
```

---

## Quick Reference

### Common Keyboard Shortcuts
| Action | Shortcut | Code |
|--------|----------|------|
| New | ⌘N | `.keyboardShortcut("n", modifiers: .command)` |
| Save | ⌘S | `.keyboardShortcut("s", modifiers: .command)` |
| Close | ⌘W | `.keyboardShortcut("w", modifiers: .command)` |
| Quit | ⌘Q | `.keyboardShortcut("q", modifiers: .command)` |
| Find | ⌘F | `.keyboardShortcut("f", modifiers: .command)` |
| Settings | ⌘, | Automatic with `Settings { }` |
| Undo | ⌘Z | `.keyboardShortcut("z", modifiers: .command)` |
| Redo | ⌘⇧Z | `.keyboardShortcut("z", modifiers: [.command, .shift])` |

### Window Placements
```swift
.defaultPosition(.center)
.defaultPosition(.topLeading)
.defaultPosition(.topTrailing)
.defaultPosition(.bottomLeading)
.defaultPosition(.bottomTrailing)
```
