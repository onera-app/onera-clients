---
name: Chat UI and Notes Fixes
overview: Fix TTS/regenerate functionality, implement native iOS context menus for message actions, parse thinking tags from LLM responses, and debug notes saving.
todos:
  - id: thinking-parser
    content: Parse <think> tags from LLM response content and show in ReasoningView
    status: completed
  - id: user-context-menu
    content: Replace user message buttons with native iOS context menu (Copy, Edit)
    status: completed
  - id: assistant-actions
    content: Remove thumbs up/down from assistant actions, add context menu for additional options
    status: completed
  - id: edit-regenerate
    content: Add explicit 'Save & Regenerate' option when editing messages
    status: completed
  - id: notes-debug
    content: Fix notes saving - check isNewNote detection and add debug logging
    status: completed
---

# Chat UI and Notes Fixes

## 1. Parse `<think>` Tags from LLM Responses

Currently, reasoning is only shown if `message.reasoning` is set (via SDK reasoning events). LLM responses with `<think>` tags in the content are not parsed.

**Changes to [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift):**

- Add a `parseThinkingContent()` function that extracts content within `<think>`, `<thinking>`, `<reason>`, `<reasoning>` tags
- Parse the message content to extract thinking blocks and display content
- Show `ReasoningView` with extracted thinking content
- Display remaining content (without thinking tags) in `MarkdownContentView`
```swift
// Parsed content struct
struct ParsedMessageContent {
    let displayContent: String
    let thinkingContent: String?
    let isThinking: Bool
}

// Parse thinking tags from content
private func parseThinkingContent(_ content: String) -> ParsedMessageContent
```


## 2. Replace Action Buttons with Native iOS Context Menu

Based on the ChatGPT screenshots, actions should be in a native context menu (long-press), not buttons below the bubble.

**For User Messages:**

- Remove `userActionButtons` view
- Add `.contextMenu` with Copy and Edit options
- Keep inline editing mode as-is

**For Assistant Messages:**

- Remove thumbs up/down and share buttons from `assistantActionButtons`
- Keep only: Copy, Regenerate, Read aloud (these are common quick actions shown in ChatGPT)
- Add `.contextMenu` for additional options

**Updated `assistantActionButtons`:**

```swift
HStack(spacing: 16) {
    // Copy
    // Regenerate  
    // Read aloud / Stop
    Spacer()
}
```

## 3. Verify TTS and Regenerate Are Working

The code paths look correct:

- `handleSpeak` -> `viewModel.speak()` -> `speechService.speak()`
- `handleRegenerate` -> `viewModel.regenerateMessage()`

**Verification needed in [ChatViewModel.swift](Onera/Features/Chat/ViewModels/ChatViewModel.swift):**

- Ensure `regenerateMessage()` method exists and works
- Ensure speech service is properly initialized

## 4. Add Regenerate Option After Editing Message

Currently when user edits a message, it auto-regenerates. User wants an explicit choice.

**Changes to [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift):**

- Add `onSaveEdit` callback that allows choosing whether to regenerate
- Show "Save" and "Save & Regenerate" buttons when editing

## 5. Debug Notes Not Saving

Looking at the web vs mobile implementation:

- Web: Uses `trpc.notes.create.useMutation` and `trpc.notes.update.useMutation` with encrypted fields
- Mobile: Uses `NoteRepository.createNote()` and `updateNote()` with encryption

**Potential issues to check in [NoteRepository.swift](Onera/Services/Repositories/NoteRepository.swift):**

- Verify API endpoint paths match server
- Check if `isNewNote` detection in [NoteEditorView.swift](Onera/Features/Notes/Views/NoteEditorView.swift) is working correctly
- Add debug logging to see if save is being called and what errors occur

The `isNewNote` check at line 36 may be incorrect:

```swift
private var isNewNote: Bool {
    viewModel.editingNote?.id == nil || !viewModel.notes.contains { $0.id == viewModel.editingNote?.id }
}
```

New notes have auto-generated UUIDs, so `id == nil` may never be true.

## Files to Modify

- [Onera/Features/Chat/Views/MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift) - Context menus, thinking parsing, remove thumbs
- [Onera/Features/Chat/ViewModels/ChatViewModel.swift](Onera/Features/Chat/ViewModels/ChatViewModel.swift) - Verify regenerate/speak
- [Onera/Features/Notes/Views/NoteEditorView.swift](Onera/Features/Notes/Views/NoteEditorView.swift) - Fix isNewNote detection
- [Onera/Core/Models/Note.swift](Onera/Core/Models/Note.swift) - Check Note initialization