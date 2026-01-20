---
name: ChatGPT Style UI Improvements
overview: Implement ChatGPT-style UI features including a thinking drawer, copy feedback, TTS player overlay, and response versioning with navigation arrows.
todos:
  - id: thinking-drawer
    content: Convert ReasoningView to show bottom drawer sheet on tap instead of inline expansion
    status: completed
  - id: copy-feedback
    content: Add 'Copied' text and checkmark feedback animation to copy button
    status: completed
  - id: tts-overlay
    content: Create TTSPlayerOverlay component with play/pause, time display, and close button
    status: completed
  - id: response-versioning
    content: Implement response branching - preserve old responses on regenerate and add navigation arrows
    status: completed
---

# ChatGPT Style UI Improvements

## 1. Thinking Bottom Drawer

Replace the current inline `ReasoningView` with a tappable button that opens a bottom sheet drawer (like ChatGPT's third screenshot).

**Changes to [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift):**

- Modify `ReasoningView` to only show the tappable trigger button ("Thought for Xs >")
- Add `@State private var showThinkingDrawer = false` 
- Present a `.sheet` with `presentationDetents([.medium, .large])` containing the thinking content
- The drawer should show:
  - Title "Thought for Xs" at top
  - Bullet-pointed thinking steps (parsed from reasoning content)
  - Scrollable content area

## 2. Copy Button with "Copied" Feedback

Add visual feedback when the copy button is tapped.

**Changes to `assistantActionButtons` in [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift):**

- Add `@State private var showCopiedFeedback = false`
- When tapped: set feedback true, show "Copied" text, auto-dismiss after 2 seconds
- Change the button to show checkmark icon + "Copied" text when feedback is active
- Already has haptic feedback (UINotificationFeedbackGenerator)

## 3. TTS Player Overlay

Create a floating player overlay when TTS is playing (like ChatGPT's second screenshot).

**Create new [TTSPlayerOverlay.swift](Onera/Features/Chat/Views/TTSPlayerOverlay.swift):**

```swift
struct TTSPlayerOverlay: View {
    @Binding var isPlaying: Bool
    let currentTime: TimeInterval
    let onStop: () -> Void
    let onSeekBackward: () -> Void  // -15s
    let onSeekForward: () -> Void   // +15s
}
```

UI elements:

- Rounded dark pill overlay at top of screen
- Play/Pause button (currently only stop)
- Current time display (00:01, etc.)
- Skip backward 15s button
- Skip forward 15s button
- X close button

**Changes to [ChatView.swift](Onera/Features/Chat/Views/ChatView.swift):**

- Add the overlay when `viewModel.isSpeaking == true`
- Track elapsed time for display

**Note:** The current `SpeechService` uses `AVSpeechSynthesizer` which doesn't support seeking. We can display elapsed time but skip forward/backward won't work with native TTS. Consider showing just play/pause and close.

## 4. Response Versioning with Navigation Arrows

Enable switching between different response versions when regenerating.

**Changes to [Message.swift](Onera/Core/Models/Message.swift):**

- Already has `parentId` and `childrenIds` for branching support

**Changes to [ChatViewModel.swift](Onera/Features/Chat/ViewModels/ChatViewModel.swift):**

- Modify `regenerateMessage()` to preserve old response as sibling branch
- Add `switchToBranch(messageId:)` method
- Add `getBranchInfo(messageId:)` to get "1/2" style info

**Changes to [MessageBubbleView.swift](Onera/Features/Chat/Views/MessageBubbleView.swift):**

- Add branch navigation UI below assistant messages when siblings exist:
```
< 1/2 >
```

- Left arrow: switch to previous sibling
- Right arrow: switch to next sibling
- Callbacks: `onPreviousBranch`, `onNextBranch`

## Files to Create/Modify

- `Onera/Features/Chat/Views/MessageBubbleView.swift` - Thinking drawer, copy feedback, branch navigation
- `Onera/Features/Chat/Views/TTSPlayerOverlay.swift` - New TTS player component
- `Onera/Features/Chat/Views/ChatView.swift` - Integrate TTS overlay, pass branch callbacks
- `Onera/Features/Chat/ViewModels/ChatViewModel.swift` - Response versioning logic
- `Onera/Core/Models/Chat.swift` - May need to track currentMessageId for branching