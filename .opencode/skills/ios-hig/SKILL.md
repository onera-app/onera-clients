---
name: ios-hig
description: Apple Human Interface Guidelines patterns for SwiftUI
---

# Apple Human Interface Guidelines

## Navigation

### NavigationStack
```swift
NavigationStack(path: $path) {
    ContentView()
        .navigationDestination(for: Route.self) { route in
            destinationView(for: route)
        }
}
```

### Sheets
```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Fullscreen Cover
```swift
.fullScreenCover(isPresented: $showFullscreen) {
    FullscreenContent()
}
```

## Lists

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { delete(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button { archive(item) } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.blue)
            }
    }
}
.listStyle(.insetGrouped)
```

## Forms

```swift
Form {
    Section("Account") {
        TextField("Name", text: $name)
        TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
    }
    
    Section {
        Toggle("Notifications", isOn: $notifications)
        Picker("Theme", selection: $theme) {
            Text("Light").tag(Theme.light)
            Text("Dark").tag(Theme.dark)
            Text("System").tag(Theme.system)
        }
    }
}
```

## Icons (SF Symbols)

```swift
Image(systemName: "paperplane.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(theme.accent)
    
// Animated symbols
Image(systemName: "checkmark.circle")
    .symbolEffect(.bounce, value: isComplete)
```

## Haptics

```swift
// UIKit style
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()

// SwiftUI style (iOS 17+)
.sensoryFeedback(.impact(weight: .medium), trigger: triggerValue)
.sensoryFeedback(.success, trigger: isComplete)
```

## Accessibility

```swift
Button { } label: { 
    Image(systemName: "plus") 
}
.accessibilityLabel("Add new item")
.accessibilityHint("Creates a new conversation")
.accessibilityAddTraits(.isButton)
```

### Dynamic Type
```swift
Text("Title")
    .font(.title)  // Automatically scales

// Custom font that scales
@ScaledMetric var iconSize: CGFloat = 24
```

## Safe Areas

```swift
// Inset content above keyboard
.safeAreaInset(edge: .bottom) {
    InputBar()
}

// Ignore keyboard
.ignoresSafeArea(.keyboard)

// Respect all safe areas
.padding(.horizontal)
```

## Context Menus

```swift
Text("Long press me")
    .contextMenu {
        Button("Copy", systemImage: "doc.on.doc") { }
        Button("Share", systemImage: "square.and.arrow.up") { }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { }
    }
```

## Alerts & Confirmations

```swift
.alert("Delete Item?", isPresented: $showAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) { deleteItem() }
} message: {
    Text("This action cannot be undone.")
}

.confirmationDialog("Choose Option", isPresented: $showDialog) {
    Button("Option 1") { }
    Button("Option 2") { }
    Button("Cancel", role: .cancel) { }
}
```

## Touch Targets

- Minimum 44x44 points
- Expand hit area with `.contentShape()`

```swift
Button { } label: {
    Image(systemName: "gear")
        .frame(width: 44, height: 44)
}
.contentShape(Rectangle())
```

## Loading States

```swift
// Progress view
ProgressView()
    .progressViewStyle(.circular)

// With label
ProgressView("Loading...")

// Determinate
ProgressView(value: progress, total: 100)
```

## Empty States

```swift
ContentUnavailableView(
    "No Messages",
    systemImage: "message",
    description: Text("Start a conversation to see messages here.")
)
```

## Search

```swift
NavigationStack {
    ContentView()
}
.searchable(text: $searchText, prompt: "Search messages")
.searchSuggestions {
    ForEach(suggestions) { suggestion in
        Text(suggestion).searchCompletion(suggestion)
    }
}
```
