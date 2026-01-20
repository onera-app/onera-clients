---
name: Mobile Feature Parity
overview: Implement TTS/STT, file attachments with LLM context, complete Notes/Folders UI, and message edit/regenerate features to achieve feature parity with the web client.
todos:
  - id: edit-regenerate
    content: Implement message edit (inline editing UI, ChatViewModel.editMessage) and regenerate (ChatViewModel.regenerateMessage, wire up existing button)
    status: completed
  - id: tts-service
    content: Create SpeechService using AVSpeechSynthesizer, wire speaker button in MessageBubbleView
    status: completed
  - id: stt-service
    content: Create SpeechRecognitionService using SFSpeechRecognizer, wire mic button in MessageInputView, add Info.plist permissions
    status: completed
  - id: file-processing
    content: Create FileProcessingService for image compression/PDF text extraction, update MessageInputView with document picker and proper previews
    status: completed
  - id: multimodal-llm
    content: Update LLMService and ChatViewModel to send attachments as multimodal context to LLM
    status: completed
  - id: folders-feature
    content: Create FolderViewModel, FolderTreeView, FolderPickerSheet, integrate with SidebarDrawerView
    status: completed
  - id: notes-enhancement
    content: Enhance NotesListView with grouping/search/folder filter, improve NoteEditorView with folder picker and auto-save, add Notes to sidebar
    status: completed
---

# Mobile Feature Parity Plan

This plan adds six major features to the iOS app matching the web client's functionality.

## 1. Speech Services (TTS and STT)

### Text-to-Speech (TTS)

Use iOS's native `AVSpeechSynthesizer` for reading assistant responses aloud.

**Files to create:**

- `Onera/Services/SpeechService.swift` - Protocol and implementation using AVSpeechSynthesizer

**Key implementation:**

```swift
import AVFoundation

protocol SpeechServiceProtocol: Sendable {
    func speak(_ text: String) async
    func stop()
    var isSpeaking: Bool { get }
}

final class SpeechService: NSObject, SpeechServiceProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    // Configure voice, rate, pitch settings
}
```

**Files to modify:**

- [`MessageBubbleView.swift`](Onera/Features/Chat/Views/MessageBubbleView.swift) - Wire up existing speaker button to call SpeechService

### Speech-to-Text (STT)

Use iOS's `Speech` framework for voice input.

**Files to create:**

- `Onera/Services/SpeechRecognitionService.swift` - Protocol and implementation using SFSpeechRecognizer

**Key implementation:**

```swift
import Speech

protocol SpeechRecognitionServiceProtocol: Sendable {
    func startRecording() async throws
    func stopRecording() async -> String?
    var isRecording: Bool { get }
}
```

**Files to modify:**

- [`MessageInputView.swift`](Onera/Features/Chat/Views/MessageInputView.swift) - Wire mic button to start/stop recording
- `Info.plist` - Add `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`

---

## 2. File and Image Attachments

Implement full attachment processing and multimodal LLM context, matching web's [`fileProcessing.ts`](apps/web/src/lib/fileProcessing.ts).

### File Processing Service

**Files to create:**

- `Onera/Services/FileProcessingService.swift` - Validate, compress, convert to base64

**Key implementation:**

```swift
struct ProcessedFile: Sendable {
    let type: AttachmentType // image, document, text
    let data: String // Base64 encoded
    let mimeType: String
    let fileName: String
    let metadata: FileMetadata // width, height, pageCount, extractedText
}

protocol FileProcessingServiceProtocol: Sendable {
    func processFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile
    func compressImage(_ data: Data) async throws -> Data
    func extractPDFText(_ data: Data) async throws -> (text: String, pageCount: Int)
}
```

**Files to modify:**

- [`MessageInputView.swift`](Onera/Features/Chat/Views/MessageInputView.swift):
  - Handle PhotosPicker selection to process images
  - Add document picker for PDFs/text files
  - Show proper attachment previews with thumbnails and remove buttons

- [`ChatViewModel.swift`](Onera/Features/Chat/ViewModels/ChatViewModel.swift):
  - Modify `sendMessage()` to include attachments in LLM context
  - Convert attachments to multimodal message parts

- [`LLMService.swift`](Onera/Services/LLMService.swift):
  - Update `streamChat` to accept attachments
  - Convert to Swift AI SDK's multimodal message format (image_url, document context)

### Attachment Preview Component

**Files to create:**

- `Onera/Features/Chat/Views/AttachmentPreviewView.swift` - Show pending attachments before send

---

## 3. Notes Feature Enhancement

The backend API is ready ([`notes.ts`](apps/server/src/trpc/routers/notes.ts)). Repository and basic ViewModel exist. Need to complete UI.

**Files to modify:**

- [`NotesListView.swift`](Onera/Features/Notes/Views/NotesListView.swift):
  - Add date grouping (Today, Yesterday, Previous 7 days)
  - Add search bar
  - Add folder filter selector
  - Add archive toggle
  - Swipe to delete

- [`NoteEditorView.swift`](Onera/Features/Notes/Views/NoteEditorView.swift):
  - Add folder selector dropdown
  - Add pin/archive buttons
  - Add auto-save (debounced)
  - Rich text support (basic markdown)

**Files to create:**

- `Onera/Features/Notes/Views/NoteRowView.swift` - Styled note list item

### Integration with Sidebar

**Files to modify:**

- [`SidebarDrawerView.swift`](Onera/Features/Main/Views/SidebarDrawerView.swift) - Add Notes section with navigation

---

## 4. Folders Feature

Backend API is ready ([`folders.ts`](apps/server/src/trpc/routers/folders.ts)). Repository exists ([`FolderRepository.swift`](Onera/Services/Repositories/FolderRepository.swift)).

**Files to create:**

- `Onera/Features/Folders/ViewModels/FolderViewModel.swift`:
  ```swift
  @MainActor @Observable
  final class FolderViewModel {
      var folders: [Folder] = []
      var expandedFolders: Set<String> = []
      func createFolder(name: String, parentId: String?) async
      func renameFolder(id: String, name: String) async
      func deleteFolder(id: String) async
  }
  ```

- `Onera/Features/Folders/Views/FolderTreeView.swift` - Hierarchical folder tree matching web's [`FolderTree.tsx`](apps/web/src/components/folders/FolderTree.tsx):
  - Expand/collapse with chevron
  - Inline rename editing
  - Create subfolder
  - Delete with confirmation
  - "All items" option at top

- `Onera/Features/Folders/Views/FolderPickerSheet.swift` - Modal sheet for selecting a folder

**Files to modify:**

- [`SidebarDrawerView.swift`](Onera/Features/Main/Views/SidebarDrawerView.swift) - Add folder tree above chat history
- [`ChatViewModel.swift`](Onera/Features/Chat/ViewModels/ChatViewModel.swift) - Add folder assignment to chats

---

## 5. Message Edit

The Message model already has `edited` and `editedAt` fields. Web implementation in [`UserMessage.tsx`](apps/web/src/components/chat/Message/UserMessage.tsx).

**Files to modify:**

- [`MessageBubbleView.swift`](Onera/Features/Chat/Views/MessageBubbleView.swift):
  - Add `onEdit: ((String) -> Void)?` callback
  - Add edit button to user message action bar
  - Add inline editing mode with TextField and Save/Cancel buttons
  - Show "edited" indicator if `message.edited == true`

- [`ChatViewModel.swift`](Onera/Features/Chat/ViewModels/ChatViewModel.swift):
  - Add `editMessage(messageId: String, newContent: String)`:
    ```swift
    func editMessage(messageId: String, newContent: String) async {
        guard var chat = chat,
              let index = chat.messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // Update message in place
        chat.messages[index].content = newContent
        chat.messages[index].edited = true
        chat.messages[index].editedAt = Date()
        
        // Remove all messages after edit point
        chat.messages = Array(chat.messages.prefix(through: index))
        
        self.chat = chat
        
        // Re-send to LLM
        await sendMessage()
    }
    ```

- [`ChatView.swift`](Onera/Features/Chat/Views/ChatView.swift) - Pass edit handler to MessageBubbleView

---

## 6. Regenerate Response

Web implementation in [`chat.tsx`](apps/web/src/routes/chat.tsx) `handleRegenerateMessage`.

**Files to modify:**

- [`MessageBubbleView.swift`](Onera/Features/Chat/Views/MessageBubbleView.swift):
  - Already has `onRegenerate` callback - ensure it's wired up
  - Add regenerate button to assistant message action bar (refresh icon)

- [`ChatViewModel.swift`](Onera/Features/Chat/ViewModels/ChatViewModel.swift):
  - Add `regenerateMessage(messageId: String)`:
    ```swift
    func regenerateMessage(messageId: String) async {
        guard var chat = chat,
              let index = chat.messages.firstIndex(where: { $0.id == messageId }),
              chat.messages[index].role == .assistant else { return }
        
        // Find the user message before this assistant message
        let userMessageIndex = index - 1
        guard userMessageIndex >= 0, chat.messages[userMessageIndex].role == .user else { return }
        
        // Remove the assistant message
        chat.messages.remove(at: index)
        self.chat = chat
        
        // Re-call LLM with same user message
        await streamLLMResponse()
    }
    ```

- [`ChatView.swift`](Onera/Features/Chat/Views/ChatView.swift) - Pass regenerate handler to MessageBubbleView

---

## Implementation Order

Execute in this order for best incremental progress:

1. **Message Edit and Regenerate** (simpler, core chat functionality)
2. **Speech Services (TTS/STT)** (uses native iOS APIs)
3. **File Attachments** (more complex, multimodal support)
4. **Folders Feature** (standalone UI feature)
5. **Notes Enhancement** (builds on folders)

---

## Dependencies to Add

None required - iOS frameworks used:

- `AVFoundation` - TTS
- `Speech` - STT  
- `PhotosUI` - Already imported
- `UniformTypeIdentifiers` - Document picker
- `PDFKit` - PDF text extraction