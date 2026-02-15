package chat.onera.mobile.presentation.features.prompts

import chat.onera.mobile.domain.model.Prompt
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState

data class PromptsState(
    val prompts: List<Prompt> = emptyList(),
    val isLoading: Boolean = true,
    val searchQuery: String = "",
    val selectedPrompt: Prompt? = null
) : UiState {
    val filteredPrompts: List<Prompt>
        get() = if (searchQuery.isBlank()) {
            prompts
        } else {
            prompts.filter {
                it.name.contains(searchQuery, ignoreCase = true) ||
                it.description.contains(searchQuery, ignoreCase = true) ||
                it.content.contains(searchQuery, ignoreCase = true)
            }
        }
}

sealed interface PromptsIntent : UiIntent {
    data object LoadPrompts : PromptsIntent
    data class Search(val query: String) : PromptsIntent
    data class DeletePrompt(val id: String) : PromptsIntent
    data class SelectPrompt(val id: String) : PromptsIntent
}

sealed interface PromptsEffect : UiEffect {
    data class ShowError(val message: String) : PromptsEffect
    data class NavigateToEditor(val promptId: String?) : PromptsEffect
}
