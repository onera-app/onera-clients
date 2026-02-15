package chat.onera.mobile.domain.model

data class Prompt(
    val id: String,
    val name: String,
    val description: String = "",
    val content: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
) {
    /**
     * Extract variable names from template content.
     * Variables use the format {{variable_name}}.
     */
    val variables: List<String>
        get() = Regex("\\{\\{\\s*(\\w+)\\s*\\}\\}").findAll(content)
            .map { it.groupValues[1] }
            .distinct()
            .toList()

    /**
     * Resolve the template by replacing variables with values.
     */
    fun resolve(values: Map<String, String>): String {
        var resolved = content
        for ((key, value) in values) {
            resolved = resolved.replace(Regex("\\{\\{\\s*$key\\s*\\}\\}"), value)
        }
        return resolved
    }
}

data class PromptSummary(
    val id: String,
    val name: String,
    val description: String = ""
)
