package chat.onera.mobile.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

// Syntax highlighting colors (similar to VS Code dark theme)
private object SyntaxColors {
    val keyword = Color(0xFF569CD6)      // blue
    val string = Color(0xFFCE9178)       // orange-ish
    val number = Color(0xFFB5CEA8)       // light green
    val comment = Color(0xFF6A9955)      // green
    val function = Color(0xFFDCDCAA)     // yellow
    val type = Color(0xFF4EC9B0)         // teal
    val operator = Color(0xFFD4D4D4)     // light gray
    val variable = Color(0xFF9CDCFE)     // light blue
    val annotation = Color(0xFFDCDCAA)   // yellow
    val default = Color(0xFFD4D4D4)      // light gray
}

/**
 * Code block view with syntax highlighting and copy button
 */
@Composable
fun CodeBlockView(
    code: String,
    language: String?,
    onCopy: (() -> Unit)?,
    modifier: Modifier = Modifier
) {
    var copied by remember { mutableStateOf(false) }
    
    // Reset copied state after delay
    LaunchedEffect(copied) {
        if (copied) {
            delay(2000)
            copied = false
        }
    }
    
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        color = Color(0xFF1E1E1E) // VS Code dark background
    ) {
        Column {
            // Header with language and copy button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF2D2D2D))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = language?.uppercase() ?: "CODE",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color(0xFF858585),
                    fontFamily = FontFamily.Monospace
                )
                
                if (onCopy != null) {
                    TextButton(
                        onClick = {
                            onCopy()
                            copied = true
                        },
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Icon(
                            imageVector = if (copied) Icons.Filled.Check else Icons.Outlined.ContentCopy,
                            contentDescription = if (copied) "Copied" else "Copy code",
                            modifier = Modifier.size(14.dp),
                            tint = if (copied) Color(0xFF4EC9B0) else Color(0xFF858585)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = if (copied) "Copied!" else "Copy",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (copied) Color(0xFF4EC9B0) else Color(0xFF858585)
                        )
                    }
                }
            }
            
            // Code content with horizontal scroll
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(12.dp)
            ) {
                val highlightedCode = remember(code, language) {
                    highlightSyntax(code, language)
                }
                
                Text(
                    text = highlightedCode,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        lineHeight = 20.sp
                    )
                )
            }
        }
    }
}

/**
 * Apply syntax highlighting based on language
 */
private fun highlightSyntax(code: String, language: String?): AnnotatedString {
    return when (language?.lowercase()) {
        "kotlin", "kt" -> highlightKotlin(code)
        "java" -> highlightJava(code)
        "javascript", "js", "typescript", "ts" -> highlightJavaScript(code)
        "python", "py" -> highlightPython(code)
        "swift" -> highlightSwift(code)
        "json" -> highlightJson(code)
        "xml", "html" -> highlightXml(code)
        "sql" -> highlightSql(code)
        "bash", "sh", "shell", "zsh" -> highlightBash(code)
        else -> buildAnnotatedString { 
            withStyle(SpanStyle(color = SyntaxColors.default)) {
                append(code) 
            }
        }
    }
}

private fun highlightKotlin(code: String): AnnotatedString {
    val keywords = setOf(
        "fun", "val", "var", "class", "interface", "object", "data", "sealed", "enum",
        "if", "else", "when", "for", "while", "do", "return", "break", "continue",
        "try", "catch", "finally", "throw", "import", "package", "private", "public",
        "protected", "internal", "abstract", "override", "open", "final", "companion",
        "suspend", "inline", "crossinline", "noinline", "reified", "annotation",
        "true", "false", "null", "this", "super", "is", "as", "in", "out", "by", "lazy"
    )
    
    val types = setOf(
        "Int", "Long", "Short", "Byte", "Float", "Double", "Boolean", "Char", "String",
        "Unit", "Any", "Nothing", "List", "Map", "Set", "Array", "MutableList",
        "MutableMap", "MutableSet", "Pair", "Triple", "Flow", "StateFlow", "Channel"
    )
    
    return highlightGeneric(code, keywords, types)
}

private fun highlightJava(code: String): AnnotatedString {
    val keywords = setOf(
        "public", "private", "protected", "static", "final", "abstract", "class",
        "interface", "extends", "implements", "new", "return", "if", "else", "for",
        "while", "do", "switch", "case", "break", "continue", "try", "catch", "finally",
        "throw", "throws", "import", "package", "void", "this", "super", "true", "false",
        "null", "instanceof", "synchronized", "volatile", "transient", "native"
    )
    
    val types = setOf(
        "int", "long", "short", "byte", "float", "double", "boolean", "char",
        "String", "Integer", "Long", "Double", "Float", "Boolean", "Object",
        "List", "Map", "Set", "ArrayList", "HashMap", "HashSet"
    )
    
    return highlightGeneric(code, keywords, types)
}

private fun highlightJavaScript(code: String): AnnotatedString {
    val keywords = setOf(
        "const", "let", "var", "function", "class", "extends", "return", "if", "else",
        "for", "while", "do", "switch", "case", "break", "continue", "try", "catch",
        "finally", "throw", "import", "export", "from", "default", "async", "await",
        "new", "this", "super", "true", "false", "null", "undefined", "typeof",
        "instanceof", "yield", "static", "get", "set", "of", "in"
    )
    
    val types = setOf(
        "string", "number", "boolean", "object", "Array", "Object", "String",
        "Number", "Boolean", "Promise", "Map", "Set", "Date", "RegExp", "Error"
    )
    
    return highlightGeneric(code, keywords, types)
}

private fun highlightPython(code: String): AnnotatedString {
    val keywords = setOf(
        "def", "class", "if", "elif", "else", "for", "while", "try", "except",
        "finally", "with", "as", "import", "from", "return", "yield", "raise",
        "pass", "break", "continue", "lambda", "and", "or", "not", "is", "in",
        "True", "False", "None", "self", "async", "await", "global", "nonlocal"
    )
    
    val types = setOf(
        "int", "float", "str", "bool", "list", "dict", "set", "tuple", "bytes",
        "type", "object", "Exception", "List", "Dict", "Set", "Tuple", "Optional"
    )
    
    return highlightGeneric(code, keywords, types, pythonComment = true)
}

private fun highlightSwift(code: String): AnnotatedString {
    val keywords = setOf(
        "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
        "if", "else", "guard", "switch", "case", "for", "while", "repeat", "return",
        "break", "continue", "try", "catch", "throw", "throws", "import", "private",
        "public", "internal", "fileprivate", "open", "static", "final", "override",
        "true", "false", "nil", "self", "super", "init", "deinit", "async", "await",
        "some", "any", "where", "associatedtype", "typealias", "in", "inout"
    )
    
    val types = setOf(
        "Int", "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary",
        "Set", "Optional", "Result", "Error", "Void", "Any", "AnyObject", "Self"
    )
    
    return highlightGeneric(code, keywords, types)
}

private fun highlightJson(code: String): AnnotatedString {
    return buildAnnotatedString {
        var i = 0
        var inString = false
        var stringStart = -1
        
        while (i < code.length) {
            val char = code[i]
            
            when {
                char == '"' && (i == 0 || code[i - 1] != '\\') -> {
                    if (inString) {
                        // End of string - check if it's a key
                        val stringContent = code.substring(stringStart, i + 1)
                        val nextNonSpace = code.drop(i + 1).trimStart().firstOrNull()
                        val color = if (nextNonSpace == ':') SyntaxColors.variable else SyntaxColors.string
                        withStyle(SpanStyle(color = color)) {
                            append(stringContent)
                        }
                        inString = false
                    } else {
                        // Start of string
                        inString = true
                        stringStart = i
                    }
                }
                inString -> {
                    // Skip, will be handled when string ends
                }
                char.isDigit() || (char == '-' && i + 1 < code.length && code[i + 1].isDigit()) -> {
                    val numStart = i
                    while (i < code.length && (code[i].isDigit() || code[i] == '.' || code[i] == '-' || code[i] == 'e' || code[i] == 'E')) {
                        i++
                    }
                    withStyle(SpanStyle(color = SyntaxColors.number)) {
                        append(code.substring(numStart, i))
                    }
                    continue
                }
                code.substring(i).startsWith("true") || code.substring(i).startsWith("false") || code.substring(i).startsWith("null") -> {
                    val word = when {
                        code.substring(i).startsWith("true") -> "true"
                        code.substring(i).startsWith("false") -> "false"
                        else -> "null"
                    }
                    withStyle(SpanStyle(color = SyntaxColors.keyword)) {
                        append(word)
                    }
                    i += word.length
                    continue
                }
                else -> {
                    withStyle(SpanStyle(color = SyntaxColors.operator)) {
                        append(char)
                    }
                }
            }
            i++
        }
    }
}

private fun highlightXml(code: String): AnnotatedString {
    return buildAnnotatedString {
        var i = 0
        while (i < code.length) {
            when {
                code.substring(i).startsWith("<!--") -> {
                    val endIndex = code.indexOf("-->", i)
                    val commentEnd = if (endIndex >= 0) endIndex + 3 else code.length
                    withStyle(SpanStyle(color = SyntaxColors.comment)) {
                        append(code.substring(i, commentEnd))
                    }
                    i = commentEnd
                }
                code[i] == '<' -> {
                    withStyle(SpanStyle(color = SyntaxColors.operator)) { append('<') }
                    i++
                    
                    // Check for closing tag
                    if (i < code.length && code[i] == '/') {
                        withStyle(SpanStyle(color = SyntaxColors.operator)) { append('/') }
                        i++
                    }
                    
                    // Tag name
                    val tagStart = i
                    while (i < code.length && !code[i].isWhitespace() && code[i] != '>' && code[i] != '/') {
                        i++
                    }
                    if (i > tagStart) {
                        withStyle(SpanStyle(color = SyntaxColors.keyword)) {
                            append(code.substring(tagStart, i))
                        }
                    }
                }
                code[i] == '>' || code[i] == '/' -> {
                    withStyle(SpanStyle(color = SyntaxColors.operator)) { append(code[i]) }
                    i++
                }
                code[i] == '"' -> {
                    val stringStart = i
                    i++
                    while (i < code.length && code[i] != '"') i++
                    if (i < code.length) i++
                    withStyle(SpanStyle(color = SyntaxColors.string)) {
                        append(code.substring(stringStart, i))
                    }
                }
                code[i] == '=' -> {
                    withStyle(SpanStyle(color = SyntaxColors.operator)) { append('=') }
                    i++
                }
                code[i].isLetter() -> {
                    val attrStart = i
                    while (i < code.length && (code[i].isLetterOrDigit() || code[i] == '-' || code[i] == ':')) i++
                    withStyle(SpanStyle(color = SyntaxColors.variable)) {
                        append(code.substring(attrStart, i))
                    }
                }
                else -> {
                    withStyle(SpanStyle(color = SyntaxColors.default)) { append(code[i]) }
                    i++
                }
            }
        }
    }
}

private fun highlightSql(code: String): AnnotatedString {
    val keywords = setOf(
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "INSERT", "INTO", "VALUES",
        "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AS", "ORDER", "BY",
        "GROUP", "HAVING", "LIMIT", "OFFSET", "DISTINCT", "COUNT", "SUM", "AVG",
        "MAX", "MIN", "NULL", "IS", "IN", "LIKE", "BETWEEN", "CASE", "WHEN", "THEN",
        "ELSE", "END", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "UNIQUE", "DEFAULT",
        "select", "from", "where", "and", "or", "not", "insert", "into", "values",
        "update", "set", "delete", "create", "table", "drop", "alter", "index"
    )
    
    val types = setOf(
        "INT", "INTEGER", "VARCHAR", "TEXT", "BOOLEAN", "DATE", "DATETIME", "TIMESTAMP",
        "FLOAT", "DOUBLE", "DECIMAL", "CHAR", "BLOB"
    )
    
    return highlightGeneric(code, keywords, types)
}

private fun highlightBash(code: String): AnnotatedString {
    val keywords = setOf(
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
        "esac", "function", "return", "exit", "break", "continue", "export", "local",
        "readonly", "declare", "typeset", "unset", "shift", "source", "alias", "in"
    )
    
    val commands = setOf(
        "echo", "cd", "ls", "pwd", "mkdir", "rm", "cp", "mv", "cat", "grep", "sed",
        "awk", "find", "chmod", "chown", "sudo", "apt", "yum", "brew", "npm", "git",
        "curl", "wget", "tar", "zip", "unzip", "ssh", "scp", "docker", "kubectl"
    )
    
    return buildAnnotatedString {
        val lines = code.split('\n')
        lines.forEachIndexed { lineIndex, line ->
            if (lineIndex > 0) append('\n')
            
            var i = 0
            while (i < line.length) {
                when {
                    line[i] == '#' -> {
                        withStyle(SpanStyle(color = SyntaxColors.comment)) {
                            append(line.substring(i))
                        }
                        break
                    }
                    line[i] == '"' || line[i] == '\'' -> {
                        val quote = line[i]
                        val stringStart = i
                        i++
                        while (i < line.length && line[i] != quote) {
                            if (line[i] == '\\' && i + 1 < line.length) i++
                            i++
                        }
                        if (i < line.length) i++
                        withStyle(SpanStyle(color = SyntaxColors.string)) {
                            append(line.substring(stringStart, i))
                        }
                    }
                    line[i] == '$' -> {
                        val varStart = i
                        i++
                        if (i < line.length && line[i] == '{') {
                            while (i < line.length && line[i] != '}') i++
                            if (i < line.length) i++
                        } else {
                            while (i < line.length && (line[i].isLetterOrDigit() || line[i] == '_')) i++
                        }
                        withStyle(SpanStyle(color = SyntaxColors.variable)) {
                            append(line.substring(varStart, i))
                        }
                    }
                    line[i].isLetter() -> {
                        val wordStart = i
                        while (i < line.length && (line[i].isLetterOrDigit() || line[i] == '_' || line[i] == '-')) i++
                        val word = line.substring(wordStart, i)
                        val color = when {
                            keywords.contains(word) -> SyntaxColors.keyword
                            commands.contains(word) -> SyntaxColors.function
                            else -> SyntaxColors.default
                        }
                        withStyle(SpanStyle(color = color)) { append(word) }
                    }
                    else -> {
                        withStyle(SpanStyle(color = SyntaxColors.default)) { append(line[i]) }
                        i++
                    }
                }
            }
        }
    }
}

/**
 * Generic syntax highlighter for C-style languages
 */
private fun highlightGeneric(
    code: String,
    keywords: Set<String>,
    types: Set<String>,
    pythonComment: Boolean = false
): AnnotatedString {
    return buildAnnotatedString {
        var i = 0
        while (i < code.length) {
            when {
                // Comments
                code.substring(i).startsWith("//") -> {
                    val endLine = code.indexOf('\n', i)
                    val end = if (endLine >= 0) endLine else code.length
                    withStyle(SpanStyle(color = SyntaxColors.comment)) {
                        append(code.substring(i, end))
                    }
                    i = end
                }
                code.substring(i).startsWith("/*") -> {
                    val endComment = code.indexOf("*/", i)
                    val end = if (endComment >= 0) endComment + 2 else code.length
                    withStyle(SpanStyle(color = SyntaxColors.comment)) {
                        append(code.substring(i, end))
                    }
                    i = end
                }
                pythonComment && code[i] == '#' -> {
                    val endLine = code.indexOf('\n', i)
                    val end = if (endLine >= 0) endLine else code.length
                    withStyle(SpanStyle(color = SyntaxColors.comment)) {
                        append(code.substring(i, end))
                    }
                    i = end
                }
                // Strings
                code[i] == '"' || code[i] == '\'' -> {
                    val quote = code[i]
                    val stringStart = i
                    i++
                    while (i < code.length && code[i] != quote) {
                        if (code[i] == '\\' && i + 1 < code.length) i++
                        i++
                    }
                    if (i < code.length) i++
                    withStyle(SpanStyle(color = SyntaxColors.string)) {
                        append(code.substring(stringStart, i))
                    }
                }
                // Annotations
                code[i] == '@' -> {
                    val annoStart = i
                    i++
                    while (i < code.length && (code[i].isLetterOrDigit() || code[i] == '_')) i++
                    withStyle(SpanStyle(color = SyntaxColors.annotation)) {
                        append(code.substring(annoStart, i))
                    }
                }
                // Numbers
                code[i].isDigit() -> {
                    val numStart = i
                    while (i < code.length && (code[i].isDigit() || code[i] == '.' || code[i] == 'x' || code[i] == 'f' || code[i] == 'L' || code[i].lowercaseChar() in 'a'..'f')) {
                        i++
                    }
                    withStyle(SpanStyle(color = SyntaxColors.number)) {
                        append(code.substring(numStart, i))
                    }
                }
                // Words (keywords, types, identifiers)
                code[i].isLetter() || code[i] == '_' -> {
                    val wordStart = i
                    while (i < code.length && (code[i].isLetterOrDigit() || code[i] == '_')) i++
                    val word = code.substring(wordStart, i)
                    val color = when {
                        keywords.contains(word) -> SyntaxColors.keyword
                        types.contains(word) -> SyntaxColors.type
                        i < code.length && code[i] == '(' -> SyntaxColors.function
                        else -> SyntaxColors.default
                    }
                    withStyle(SpanStyle(color = color)) { append(word) }
                }
                // Operators and punctuation
                else -> {
                    withStyle(SpanStyle(color = SyntaxColors.operator)) { append(code[i]) }
                    i++
                }
            }
        }
    }
}
