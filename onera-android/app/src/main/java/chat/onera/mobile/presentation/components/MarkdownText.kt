package chat.onera.mobile.presentation.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import com.mikepenz.markdown.compose.Markdown
import com.mikepenz.markdown.m3.markdownColor
import com.mikepenz.markdown.m3.markdownTypography

/**
 * Content block types for parsed markdown
 */
sealed class ContentBlock {
    data class Text(val content: String) : ContentBlock()
    data class Code(val code: String, val language: String?) : ContentBlock()
}

/**
 * Parse markdown content into text and code blocks.
 * Uses the same regex pattern as iOS for consistency.
 */
private fun parseMarkdownContent(markdown: String): List<ContentBlock> {
    if (markdown.isBlank()) return emptyList()
    
    val blocks = mutableListOf<ContentBlock>()
    // Same pattern as iOS: ```(\w*)\n([\s\S]*?)```
    // But we need to handle optional newline after language
    val pattern = Regex("```(\\w*)\\n?([\\s\\S]*?)```")
    
    var lastEnd = 0
    
    pattern.findAll(markdown).forEach { match ->
        // Text before code block
        if (match.range.first > lastEnd) {
            val textContent = markdown.substring(lastEnd, match.range.first).trim()
            if (textContent.isNotEmpty()) {
                blocks.add(ContentBlock.Text(textContent))
            }
        }
        
        // Code block
        val language = match.groupValues[1].ifEmpty { null }
        val code = match.groupValues[2].trimEnd()
        blocks.add(ContentBlock.Code(code, language))
        
        lastEnd = match.range.last + 1
    }
    
    // Remaining text after last code block
    if (lastEnd < markdown.length) {
        val remainingText = markdown.substring(lastEnd).trim()
        if (remainingText.isNotEmpty()) {
            blocks.add(ContentBlock.Text(remainingText))
        }
    }
    
    // If no blocks found, treat entire content as text
    if (blocks.isEmpty()) {
        blocks.add(ContentBlock.Text(markdown))
    }
    
    return blocks
}

/**
 * Markdown text renderer with code block copy support and text selection.
 * 
 * Features:
 * - Headers, bold, italic, strikethrough
 * - Code blocks with syntax highlighting and **copy button**
 * - Text selection support via SelectionContainer
 * - Lists (ordered and unordered)
 * - Links and images
 * - Block quotes
 * - Tables
 */
@Composable
fun MarkdownText(
    markdown: String,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    style: TextStyle = LocalTextStyle.current,
    onCopyCode: ((String) -> Unit)? = null
) {
    val isDarkTheme = isSystemInDarkTheme()
    
    // Parse content into blocks
    val blocks = remember(markdown) { parseMarkdownContent(markdown) }
    
    // Custom colors based on theme - using M3 defaults with overrides
    val markdownColors = markdownColor(
        text = if (color != Color.Unspecified) color else MaterialTheme.colorScheme.onSurface,
        codeText = MaterialTheme.colorScheme.onSurfaceVariant,
        codeBackground = if (isDarkTheme) Color(0xFF1E1E1E) else Color(0xFFF5F5F5),
        inlineCodeText = MaterialTheme.colorScheme.onSurfaceVariant,
        inlineCodeBackground = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        linkText = MaterialTheme.colorScheme.primary,
        dividerColor = MaterialTheme.colorScheme.outlineVariant
    )
    
    // Custom typography using M3 defaults
    val markdownTypography = markdownTypography(
        text = style,
        h1 = MaterialTheme.typography.headlineLarge,
        h2 = MaterialTheme.typography.headlineMedium,
        h3 = MaterialTheme.typography.headlineSmall,
        h4 = MaterialTheme.typography.titleLarge,
        h5 = MaterialTheme.typography.titleMedium,
        h6 = MaterialTheme.typography.titleSmall,
        code = MaterialTheme.typography.bodyMedium.copy(
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
        ),
        quote = MaterialTheme.typography.bodyLarge.copy(
            color = MaterialTheme.colorScheme.onSurfaceVariant
        ),
        paragraph = style,
        list = style,
        ordered = style
    )
    
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        blocks.forEach { block ->
            when (block) {
                is ContentBlock.Text -> {
                    // Wrap text in SelectionContainer for copy support
                    SelectionContainer {
                        Markdown(
                            content = block.content,
                            colors = markdownColors,
                            typography = markdownTypography
                        )
                    }
                }
                is ContentBlock.Code -> {
                    // Use custom CodeBlockView with copy button
                    CodeBlockView(
                        code = block.code,
                        language = block.language,
                        onCopy = onCopyCode?.let { callback -> { callback(block.code) } }
                    )
                }
            }
        }
    }
}
