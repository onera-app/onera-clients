---
name: apple-hig
description: Apple Human Interface Guidelines - core principles across iOS, iPadOS, macOS, watchOS
---

# Apple Human Interface Guidelines

Core design principles that apply across ALL Apple platforms.

## The Golden Rule

**Use native components. Follow platform conventions. Customize only when Apple provides no solution.**

---

## Core Design Principles

### 1. Clarity
- Content is paramount
- UI should be unobtrusive
- Use whitespace effectively
- Typography creates hierarchy

### 2. Deference
- UI defers to content
- Translucent elements where appropriate
- Motion is purposeful, not decorative

### 3. Depth
- Layering creates hierarchy
- Subtle shadows and materials
- Transitions reveal relationships

---

## Native Components - Always Use

| Need | Component |
|------|-----------|
| Lists | `List` |
| Forms/Settings | `Form` |
| Navigation (iOS) | `NavigationStack` |
| Navigation (iPad/Mac) | `NavigationSplitView` |
| Tabs | `TabView` |
| Modals | `.sheet`, `.fullScreenCover` |
| Alerts | `.alert`, `.confirmationDialog` |
| Search | `.searchable` |
| Refresh | `.refreshable` |
| Loading | `ProgressView` |
| Empty States | `ContentUnavailableView` |
| Icons | SF Symbols |

---

## Typography

### Use System Text Styles

```swift
Text("Large Title").font(.largeTitle)  // Headlines
Text("Title").font(.title)              // Section headers
Text("Headline").font(.headline)        // Emphasized body
Text("Body").font(.body)                // Primary content
Text("Callout").font(.callout)          // Secondary content
Text("Caption").font(.caption)          // Metadata
```

### Dynamic Type Support

All text MUST scale with user's accessibility settings:

```swift
// Automatic scaling
Text("Content").font(.body)

// Custom sizing that scales
@ScaledMetric var iconSize: CGFloat = 24
```

**NEVER use fixed font sizes for body text.**

---

## Colors

### Semantic Colors

```swift
// Text
Color.primary       // Main text
Color.secondary     // Secondary text
Color.accentColor   // Interactive elements

// Backgrounds
Color(.systemBackground)
Color(.secondarySystemBackground)
Color(.tertiarySystemBackground)

// Grouped content
Color(.systemGroupedBackground)
Color(.secondarySystemGroupedBackground)
```

### Dark Mode

All apps MUST support Dark Mode automatically using semantic colors.

**NEVER hard-code colors like:**
```swift
// WRONG
Color(red: 0.2, green: 0.2, blue: 0.2)

// RIGHT
Color(.systemBackground)
```

---

## Touch Targets

| Platform | Minimum Size |
|----------|-------------|
| iOS | 44 × 44 points |
| iPadOS | 44 × 44 points |
| macOS | No minimum (use hover states) |
| watchOS | 38 × 38 points |

```swift
// Expand hit area
Button { } label: {
    Image(systemName: "gear")
        .frame(width: 44, height: 44)
}
.contentShape(Rectangle())
```

---

## Spacing

### Standard Values

| Name | Points | Usage |
|------|--------|-------|
| Compact | 8 | Tight groupings |
| Standard | 16 | Default spacing |
| Relaxed | 24 | Section separation |
| Large | 32 | Major sections |

```swift
// Use system padding
.padding()        // 16pt default
.padding(8)       // Compact
.padding(24)      // Relaxed
```

---

## Navigation Patterns

### iOS: NavigationStack

```swift
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
```

### iPad/Mac: NavigationSplitView

```swift
NavigationSplitView {
    Sidebar()
} content: {
    ContentList()
} detail: {
    Detail()
}
```

### watchOS: NavigationStack (simple)

```swift
NavigationStack {
    List { }
        .navigationDestination(for: Item.self) { }
}
```

---

## Modals

### Sheets (Non-blocking)

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Full Screen Cover (Immersive)

```swift
.fullScreenCover(isPresented: $showFullscreen) {
    ImmersiveContent()
}
```

### Alerts (Critical)

```swift
.alert("Title", isPresented: $showAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) { }
} message: {
    Text("This action cannot be undone.")
}
```

### Confirmation Dialog (Choices)

```swift
.confirmationDialog("Select Option", isPresented: $showDialog) {
    Button("Option 1") { }
    Button("Option 2") { }
    Button("Cancel", role: .cancel) { }
}
```

---

## Loading States

### Always Use ProgressView

```swift
// Indeterminate
ProgressView()

// With label
ProgressView("Loading...")

// Determinate
ProgressView(value: progress, total: 100)

// In buttons
Button {
    // action
} label: {
    if isLoading {
        ProgressView()
    } else {
        Text("Submit")
    }
}
.disabled(isLoading)
```

---

## Empty States

### Always Use ContentUnavailableView

```swift
ContentUnavailableView(
    "No Messages",
    systemImage: "bubble.left",
    description: Text("Start a conversation to see messages here.")
)

// With action
ContentUnavailableView {
    Label("No Results", systemImage: "magnifyingglass")
} description: {
    Text("Try a different search term")
} actions: {
    Button("Clear Search") { }
}
```

---

## Accessibility

### Required for Every View

1. **Labels**: All images and icons need `accessibilityLabel`
2. **Hints**: Interactive elements need `accessibilityHint`
3. **Traits**: Custom views need appropriate traits
4. **Values**: Dynamic content needs `accessibilityValue`

```swift
Button { } label: {
    Image(systemName: "plus")
}
.accessibilityLabel("Add new item")
.accessibilityHint("Creates a new conversation")

// Custom view
CustomControl()
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
```

### Respect User Settings

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
@Environment(\.dynamicTypeSize) var dynamicTypeSize

withAnimation(reduceMotion ? nil : .spring()) {
    // animation
}
```

---

## Haptics

```swift
// SwiftUI (iOS 17+)
.sensoryFeedback(.impact(weight: .medium), trigger: value)
.sensoryFeedback(.success, trigger: isComplete)
.sensoryFeedback(.error, trigger: hasError)

// UIKit style
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()
```

---

## SF Symbols

### Always Use for Standard Actions

| Action | Symbol |
|--------|--------|
| Add | `plus` |
| Delete | `trash` |
| Edit | `pencil` |
| Share | `square.and.arrow.up` |
| Search | `magnifyingglass` |
| Settings | `gear` |
| Close | `xmark` |
| Back | `chevron.left` |
| Forward | `chevron.right` |
| Refresh | `arrow.clockwise` |
| Send | `paperplane` |

```swift
Image(systemName: "paperplane.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.blue)
```

---

## Anti-Patterns

### NEVER Do These

| Bad | Good |
|-----|------|
| Custom navigation state | `NavigationStack` |
| Custom tab bars | `TabView` |
| Custom alerts | `.alert` modifier |
| Custom scroll lists | `List` |
| Custom spinners | `ProgressView` |
| Custom empty states | `ContentUnavailableView` |
| Custom icons (standard) | SF Symbols |
| Fixed font sizes | System text styles |
| Hard-coded colors | Semantic colors |

---

## Resources

- [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
