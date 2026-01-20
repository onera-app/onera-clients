---
name: Thinking UI and Sidebar Fixes
overview: Add a polished thinking/reasoning UI for AI models, fix the non-functional Notes button by implementing navigation, and improve the Folders UI in the sidebar.
todos:
  - id: reasoning-ui
    content: Create enhanced ReasoningView with auto-collapse, duration tracking, and streaming indicator
    status: completed
  - id: notes-navigation
    content: Wire up Notes button in MainView with proper sheet navigation to NotesListView
    status: completed
  - id: folder-ui
    content: Fix folder action button visibility and add context menu for folder operations
    status: completed
  - id: folder-styling
    content: Improve folder section styling in sidebar to match NavigationItemRow appearance
    status: completed
---

# Thinking UI and Sidebar Fixes

## 1. Enhanced Thinking/Reasoning UI

The current `reasoningDisclosure` in [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift) is basic. We need to match the web's behavior:

**Create a new `ReasoningView` component** with:

- Collapsible disclosure that auto-opens when streaming reasoning, auto-closes when complete
- Duration tracking ("Thought for X seconds")
- Streaming indicator with pulsing animation while thinking
- Brain icon similar to web version
- Scrollable content area with max height

Key changes to `MessageBubbleView`:

- Replace simple `DisclosureGroup` with new `ReasoningView`
- Pass `isStreaming` state to enable auto-collapse behavior
- Track and display reasoning duration

## 2. Fix Notes Button Navigation

The issue is in [MainView.swift](Onera/Features/Main/Views/MainView.swift) line 83:

```swift
onOpenNotes: nil  // This is why it does nothing
```

**Changes needed:**

- Add `@State private var showNotes = false` to MainView
- Add `@State private var notesViewModel: NotesViewModel?` 
- Initialize `notesViewModel` in `setupViewModels()`
- Pass actual callback: `onOpenNotes: { showNotes = true }`
- Add `.sheet(isPresented: $showNotes)` presenting `NotesListView`

## 3. Fix Folder UI Issues

In [FolderTreeView.swift](Onera/Features/Folders/Views/FolderTreeView.swift), the action buttons are invisible:

```swift
.opacity(isSelected ? 1 : 0)  // Line 287 - buttons only show when selected
```

**Changes needed:**

- Show action buttons on hover/long-press or always show them dimmed
- Add context menu as alternative for actions (rename, delete, add subfolder)
- Improve visual consistency of the folders DisclosureGroup in sidebar to match NavigationItemRow styling
- Consider using swipe actions for delete on mobile

## Files to Modify

- `Onera/Features/Chat/Views/MessageBubbleView.swift` - Enhanced reasoning UI
- `Onera/Features/Main/Views/MainView.swift` - Notes navigation
- `Onera/Features/Folders/Views/FolderTreeView.swift` - Folder UI improvements
- `Onera/Features/Main/Views/SidebarDrawerView.swift` - Consistent folder section styling