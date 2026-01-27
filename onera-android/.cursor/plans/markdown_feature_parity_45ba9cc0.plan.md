---
name: Markdown Feature Parity
overview: Add copy button to code blocks and enable text selection in markdown content to match web and iOS implementations.
todos:
  - id: parse-content
    content: Add content parsing to MarkdownText.kt (separate text and code blocks)
    status: completed
  - id: selection-container
    content: Wrap text blocks in SelectionContainer for copy support
    status: completed
  - id: integrate-codeblock
    content: Use existing CodeBlockView.kt for code blocks (has copy button)
    status: completed
  - id: clipboard-callback
    content: Wire up clipboard copy in MessageBubble and other callers
    status: completed
---

# Markdown Feature Parity Plan

## Current State

### Web ([CodeBlock.tsx](apps/web/src/components/chat/CodeBlock.tsx))

- Header bar with language label and **Copy button** ("Copy" / "Copied")
- Syntax highlighting via highlight.js
- Line numbers option
- Full text selection support

### iOS ([MessageBubbleView.swift](../onera-mobile/Onera/Onera/Features/Chat/Views/MessageBubbleView.swift))

- Custom `MarkdownContentView` that **manually parses** content into text and code blocks
- `CodeBlockView` with:
  - Header showing language
  - **Copy button** with "Copy code" text and "Copied!" feedback
  - Syntax highlighting using Highlightr
  - `.textSelection(.enabled)` for text selection
- Regular markdown uses `StructuredText` with `.textSelection(.enabled)`

### Android Current State

- [MarkdownText.kt](app/src/main/java/chat/onera/mobile/presentation/components/MarkdownText.kt) uses `mikepenz/multiplatform-markdown-renderer` library directly
- Has unused `onCopyCode` parameter
- Does NOT use the existing [CodeBlockView.kt](app/src/main/java/chat/onera/mobile/presentation/components/CodeBlockView.kt) (which has copy button support)
- **No text selection** (missing `SelectionContainer`)

## Missing Features in Android

1. **Code blocks have no copy button** - Library's default code blocks used instead of custom `CodeBlockView`
2. **Text cannot be selected/copied** - No `SelectionContainer` wrapper

## Solution

### Approach: Manual Parsing (Match iOS Pattern)

Instead of fighting the library's component customization, follow iOS's approach:

1. **Parse markdown content** to separate text blocks from code blocks using regex (same pattern as iOS)
2. **Render text blocks** with the library's `Markdown` composable wrapped in `SelectionContainer`
3. **Render code blocks** with the existing `CodeBlockView.kt` (already has copy button and syntax highlighting)

### Files to Modify

1. **[MarkdownText.kt](app/src/main/java/chat/onera/mobile/presentation/components/MarkdownText.kt)**

   - Add content parsing function to extract code blocks (same regex as iOS: `` ```(\w*)\n([\s\S]*?)``` ``)
   - Create sealed class for content blocks (`TextBlock`, `CodeBlock`)
   - Render each block appropriately:
     - Text blocks: wrap in `SelectionContainer` with library's `Markdown`
     - Code blocks: use existing `CodeBlockView` with clipboard callback

2. **[MessageBubble.kt](app/src/main/java/chat/onera/mobile/presentation/features/chat/components/MessageBubble.kt)** and other callers

   - Pass `onCopyCode` callback that copies to clipboard using `ClipboardManager`

### Key Code Changes

```kotlin
// MarkdownText.kt - Content block sealed class
sealed class ContentBlock {
    data class Text(val content: String) : ContentBlock()
    data class Code(val code: String, val language: String?) : ContentBlock()
}

// Parse function (same pattern as iOS)
private fun parseContent(markdown: String): List<ContentBlock>

// Render function
@Composable
fun MarkdownText(..., onCopyCode: ((String) -> Unit)? = null) {
    val blocks = remember(markdown) { parseContent(markdown) }
    
    Column {
        blocks.forEach { block ->
            when (block) {
                is ContentBlock.Text -> SelectionContainer {
                    Markdown(content = block.content, ...)
                }
                is ContentBlock.Code -> CodeBlockView(
                    code = block.code,
                    language = block.language,
                    onCopy = { onCopyCode?.invoke(block.code) }
                )
            }
        }
    }
}
```