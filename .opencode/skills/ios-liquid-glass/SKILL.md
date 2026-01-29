---
name: ios-liquid-glass
description: iOS 26 Liquid Glass design system - comprehensive implementation guide for SwiftUI
---

# iOS 26 Liquid Glass Reference

Liquid Glass is Apple's design language introduced at WWDC 2025. It features translucent, dynamic materials with real-time light bending (lensing), specular highlights, adaptive shadows, and interactive behaviors.

## Core Principles

**CRITICAL**: Liquid Glass is ONLY for the navigation layer that floats above app content. NEVER apply to content itself (lists, tables, media).

### Material Variants

| Variant | Use Case | Transparency |
|---------|----------|--------------|
| `.regular` | Default for most UI (toolbars, buttons, nav bars) | Medium - adapts to any content |
| `.clear` | Media-rich backgrounds with bold foreground | High - requires dimming layer |
| `.identity` | Conditional disable | None - no effect |

### When to Use `.clear` (ALL must be met):
1. Element sits over media-rich content
2. Content won't be negatively affected by dimming
3. Content above glass is bold and bright

---

## Basic Implementation

### Simple Glass Effect
```swift
Text("Hello, Liquid Glass!")
    .padding()
    .glassEffect()  // Default: .regular variant, .capsule shape
```

### With Explicit Parameters
```swift
Text("Custom Glass")
    .padding()
    .glassEffect(.regular, in: .capsule, isEnabled: true)
```

### API Signature
```swift
func glassEffect<S: Shape>(
    _ glass: Glass = .regular,
    in shape: S = DefaultGlassEffectShape,
    isEnabled: Bool = true
) -> some View
```

---

## Glass Type Modifiers

### Tinting
```swift
// Basic tint - use for semantic meaning (primary action), NOT decoration
Text("Tinted")
    .padding()
    .glassEffect(.regular.tint(.blue))

// With opacity
Text("Subtle Tint")
    .padding()
    .glassEffect(.regular.tint(.purple.opacity(0.6)))
```

### Interactive Modifier (iOS only)
```swift
Button("Tap Me") { }
    .glassEffect(.regular.interactive())
```

**Behaviors Enabled:**
- Scaling on press
- Bouncing animation
- Shimmering effect
- Touch-point illumination radiating to nearby glass

### Method Chaining
```swift
.glassEffect(.regular.tint(.orange).interactive())
.glassEffect(.clear.interactive().tint(.blue))  // Order doesn't matter
```

---

## Shapes

```swift
// Capsule (default)
.glassEffect(.regular, in: .capsule)

// Circle
.glassEffect(.regular, in: .circle)

// Rounded Rectangle
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

// Container-concentric (aligns with container corners)
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))

// Custom shape
.glassEffect(.regular, in: CustomShape())
```

---

## GlassEffectContainer

**Purpose**: Combines multiple glass shapes into unified composition with shared sampling region.

**CRITICAL**: Glass cannot sample other glass; container provides shared sampling region.

### Basic Usage
```swift
GlassEffectContainer {
    HStack(spacing: 20) {
        Image(systemName: "pencil")
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())
        
        Image(systemName: "eraser")
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())
    }
}
```

### With Spacing (Morphing Threshold)
```swift
GlassEffectContainer(spacing: 40.0) {
    // Elements within 40 points will morph together
    ForEach(icons) { icon in
        IconView(icon)
            .glassEffect()
    }
}
```

---

## Morphing Transitions

### Requirements:
1. Elements in same `GlassEffectContainer`
2. Each view has `glassEffectID` with shared namespace
3. Views conditionally shown/hidden
4. Animation applied to state changes

### Implementation
```swift
struct MorphingExample: View {
    @State private var isExpanded = false
    @Namespace private var namespace
    
    var body: some View {
        GlassEffectContainer(spacing: 30) {
            Button(isExpanded ? "Collapse" : "Expand") {
                withAnimation(.bouncy) {
                    isExpanded.toggle()
                }
            }
            .glassEffect()
            .glassEffectID("toggle", in: namespace)
            
            if isExpanded {
                Button("Action 1") { }
                    .glassEffect()
                    .glassEffectID("action1", in: namespace)
                
                Button("Action 2") { }
                    .glassEffect()
                    .glassEffectID("action2", in: namespace)
            }
        }
    }
}
```

---

## Button Styles

| Style | Appearance | Use Case |
|-------|------------|----------|
| `.glass` | Translucent, see-through | Secondary actions |
| `.glassProminent` | Opaque, no background show-through | Primary actions |

```swift
// Secondary action
Button("Cancel") { }
    .buttonStyle(.glass)

// Primary action
Button("Save") { }
    .buttonStyle(.glassProminent)
    .tint(.blue)
```

### Control Sizes
```swift
.controlSize(.mini)
.controlSize(.small)
.controlSize(.regular)  // Default
.controlSize(.large)
.controlSize(.extraLarge)  // New in iOS 26
```

### Border Shapes
```swift
.buttonBorderShape(.capsule)     // Default
.buttonBorderShape(.roundedRectangle(radius: 8))
.buttonBorderShape(.circle)
```

---

## Toolbar Integration

Toolbars automatically receive Liquid Glass in iOS 26:

```swift
NavigationStack {
    ContentView()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", systemImage: "xmark") { }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { }
                // .confirmationAction automatically gets .glassProminent
            }
        }
}
```

### Toolbar Spacing
```swift
.toolbar {
    ToolbarItemGroup(placement: .topBarTrailing) {
        Button("Draw", systemImage: "pencil") { }
        Button("Erase", systemImage: "eraser") { }
    }
    
    ToolbarSpacer(.fixed, spacing: 20)
    
    ToolbarItem(placement: .topBarTrailing) {
        Button("Save", systemImage: "checkmark") { }
            .buttonStyle(.glassProminent)
    }
}
```

---

## TabView

### Search Tab Role
```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
    }
    
    Tab("Search", systemImage: "magnifyingglass", role: .search) {
        NavigationStack {
            SearchView()
        }
    }
}
.searchable(text: $searchText)
```

### Tab Bar Behaviors
```swift
.tabBarMinimizeBehavior(.onScrollDown)  // Collapses during scroll
.tabBarMinimizeBehavior(.automatic)
.tabBarMinimizeBehavior(.never)

// Bottom accessory
.tabViewBottomAccessory {
    NowPlayingView()
}
```

---

## Sheet Presentations

Sheets automatically receive inset Liquid Glass:

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationDetents([.medium, .large])
}
```

### Sheet Morphing from Toolbar
```swift
struct ContentView: View {
    @Namespace private var transition
    @State private var showInfo = false
    
    var body: some View {
        NavigationStack {
            ContentView()
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Info", systemImage: "info") {
                            showInfo = true
                        }
                        .matchedTransitionSource(id: "info", in: transition)
                    }
                }
                .sheet(isPresented: $showInfo) {
                    InfoSheet()
                        .navigationTransition(.zoom(sourceID: "info", in: transition))
                }
        }
    }
}
```

---

## Advanced: glassEffectUnion

Manually combine glass effects too distant for spacing:

```swift
struct UnionExample: View {
    @Namespace var controls
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                Button("Edit") { }
                    .buttonStyle(.glass)
                    .glassEffectUnion(id: "tools", namespace: controls)
                
                Spacer().frame(height: 100)  // Large gap
                
                Button("Delete") { }
                    .buttonStyle(.glass)
                    .glassEffectUnion(id: "tools", namespace: controls)
            }
        }
    }
}
```

---

## Accessibility

**Automatic Adaptations** (no code changes):
- **Reduced Transparency**: Increases frosting
- **Increased Contrast**: Stark colors and borders
- **Reduced Motion**: Tones down animations
- **Tinted Mode** (iOS 26.1+): User-controlled opacity

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    Text("Accessible")
        .padding()
        .glassEffect(reduceTransparency ? .identity : .regular)
}
```

**Best Practice**: Let system handle accessibility automatically.

---

## Performance Optimization

### Always Use Container
```swift
// ✅ GOOD - Efficient
GlassEffectContainer {
    HStack {
        Button("Edit") { }.glassEffect()
        Button("Delete") { }.glassEffect()
    }
}

// ❌ BAD - Inefficient
HStack {
    Button("Edit") { }.glassEffect()
    Button("Delete") { }.glassEffect()
}
```

### Conditional Glass
```swift
.glassEffect(shouldShowGlass ? .regular : .identity)
```

### Avoid Continuous Animations on Glass

---

## Anti-Patterns

### Visual
- ❌ Glass everywhere (overuse)
- ❌ Glass-on-glass stacking
- ❌ Content layer glass
- ❌ Tinting everything

### Technical
- ❌ Multiple glass effects without container
- ❌ Custom opacity bypassing accessibility

---

## Complete Example: Floating Action Cluster

```swift
struct FloatingActionCluster: View {
    @State private var isExpanded = false
    @Namespace private var namespace
    
    let actions = [
        ("photo", Color.blue),
        ("video", Color.purple),
        ("doc.text", Color.green)
    ]
    
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 12) {
                if isExpanded {
                    ForEach(actions, id: \.0) { icon, color in
                        Button { } label: {
                            Image(systemName: icon)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(color)
                        .glassEffectID(icon, in: namespace)
                    }
                }
                
                Button {
                    withAnimation(.bouncy(duration: 0.35)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2.bold())
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .tint(.orange)
                .glassEffectID("toggle", in: namespace)
            }
        }
    }
}
```

---

## API Quick Reference

### Core Modifiers
```swift
.glassEffect()
.glassEffect(_ glass: Glass, in shape: Shape, isEnabled: Bool)
.glassEffectID(_ id: ID, in namespace: Namespace.ID)
.glassEffectUnion(id: ID, namespace: Namespace.ID)
.glassEffectTransition(_ transition: GlassEffectTransition)
```

### Glass Types
```swift
Glass.regular              // Default
Glass.clear                // High transparency
Glass.identity             // No effect

.tint(_ color: Color)      // Add tint
.interactive()             // Enable interactions
```

### Button Styles
```swift
.buttonStyle(.glass)
.buttonStyle(.glassProminent)
```

### Container
```swift
GlassEffectContainer { }
GlassEffectContainer(spacing: CGFloat) { }
```

---

## Known Issues (Beta)

1. **Interactive Shape Mismatch**: `.interactive()` with `RoundedRectangle` responds as Capsule
   - Workaround: Use `.buttonStyle(.glass)`

2. **glassProminent Circle Artifacts**:
   ```swift
   Button { } label: { }
       .buttonStyle(.glassProminent)
       .buttonBorderShape(.circle)
       .clipShape(Circle())  // Fixes artifacts
   ```

---

## Resources

- WWDC 2025 Session 219: "Meet Liquid Glass"
- WWDC 2025 Session 323: "Build a SwiftUI app with the new design"
- Apple HIG: Materials documentation
