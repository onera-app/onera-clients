package chat.onera.mobile.presentation.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.onera.mobile.domain.model.ToolCallData
import chat.onera.mobile.domain.model.ToolCallState

/**
 * Convert tool name from snake_case or camelCase to Title Case.
 */
private fun formatToolName(name: String): String {
    // Split on underscores, hyphens, or camelCase boundaries
    val words = name
        .replace(Regex("([a-z])([A-Z])"), "$1 $2") // camelCase -> camel Case
        .replace(Regex("[_\\-]"), " ") // snake_case / kebab-case -> spaces
        .split(" ")
        .filter { it.isNotBlank() }
        .map { word ->
            word.replaceFirstChar { it.uppercase() }
        }
    return words.joinToString(" ")
}

/**
 * Try to pretty-print JSON arguments. Falls back to raw string.
 */
private fun prettyPrintJson(json: String): String {
    if (json.isBlank()) return ""
    return try {
        val trimmed = json.trim()
        if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) return trimmed

        val sb = StringBuilder()
        var indent = 0
        var inString = false
        var escaped = false

        for (char in trimmed) {
            when {
                escaped -> {
                    sb.append(char)
                    escaped = false
                }
                char == '\\' && inString -> {
                    sb.append(char)
                    escaped = true
                }
                char == '"' -> {
                    inString = !inString
                    sb.append(char)
                }
                inString -> sb.append(char)
                char == '{' || char == '[' -> {
                    sb.append(char)
                    indent += 2
                    sb.append('\n')
                    sb.append(" ".repeat(indent))
                }
                char == '}' || char == ']' -> {
                    indent = (indent - 2).coerceAtLeast(0)
                    sb.append('\n')
                    sb.append(" ".repeat(indent))
                    sb.append(char)
                }
                char == ',' -> {
                    sb.append(char)
                    sb.append('\n')
                    sb.append(" ".repeat(indent))
                }
                char == ':' -> {
                    sb.append(": ")
                }
                !char.isWhitespace() -> sb.append(char)
            }
        }
        sb.toString()
    } catch (_: Exception) {
        json
    }
}

@Composable
fun ToolInvocationCard(
    toolCall: ToolCallData,
    modifier: Modifier = Modifier
) {
    var isExpanded by remember { mutableStateOf(false) }
    val displayName = remember(toolCall.name) { formatToolName(toolCall.name) }
    val prettyArgs = remember(toolCall.arguments) { prettyPrintJson(toolCall.arguments) }

    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 1.dp
    ) {
        Column {
            // Header row - always visible, clickable to expand
            Surface(
                onClick = { isExpanded = !isExpanded },
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Wrench icon
                    Icon(
                        imageVector = Icons.Outlined.Build,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    // Tool name
                    Text(
                        text = displayName,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f)
                    )

                    // State indicator
                    ToolStateIndicator(state = toolCall.state)

                    // Expand/collapse chevron
                    Icon(
                        imageVector = if (isExpanded) Icons.Default.KeyboardArrowUp
                        else Icons.Default.KeyboardArrowDown,
                        contentDescription = if (isExpanded) "Collapse" else "Expand",
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Expandable body
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Input section
                    if (prettyArgs.isNotBlank()) {
                        Text(
                            text = "Input",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.surface
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState())
                                    .padding(8.dp)
                            ) {
                                Text(
                                    text = prettyArgs,
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 12.sp,
                                        lineHeight = 18.sp
                                    ),
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }

                    // Output section (completed)
                    if (toolCall.state == ToolCallState.COMPLETED && !toolCall.result.isNullOrBlank()) {
                        Text(
                            text = "Output",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.surface
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 200.dp)
                                    .horizontalScroll(rememberScrollState())
                                    .padding(8.dp)
                            ) {
                                Text(
                                    text = toolCall.result,
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        fontFamily = FontFamily.Monospace,
                                        fontSize = 12.sp,
                                        lineHeight = 18.sp
                                    ),
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }

                    // Error section (failed)
                    if (toolCall.state == ToolCallState.FAILED && !toolCall.result.isNullOrBlank()) {
                        Text(
                            text = "Error",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.error
                        )
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.errorContainer
                        ) {
                            Text(
                                text = toolCall.result,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.sp
                                ),
                                color = MaterialTheme.colorScheme.onErrorContainer,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(8.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ToolStateIndicator(state: ToolCallState) {
    when (state) {
        ToolCallState.STREAMING, ToolCallState.RUNNING -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(12.dp),
                    strokeWidth = 1.5.dp,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "Running...",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }

        ToolCallState.COMPLETED -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.tertiary
                )
                Text(
                    text = "Completed",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        }

        ToolCallState.FAILED -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Error,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.error
                )
                Text(
                    text = "Failed",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

/**
 * Renders a list of tool invocation cards for a message.
 */
@Composable
fun ToolInvocationsView(
    toolCalls: List<ToolCallData>,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        toolCalls.forEach { toolCall ->
            ToolInvocationCard(
                toolCall = toolCall,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
