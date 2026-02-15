package chat.onera.mobile.presentation.features.prompts.editor

import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState

data class PromptEditorState(
    val promptId: String? = null,
    val name: String = "",
    val description: String = "",
    val content: String = "",
    val variables: List<String> = emptyList(),
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val isNewPrompt: Boolean = true,
    val hasChanges: Boolean = false,
    val originalName: String = "",
    val originalDescription: String = "",
    val originalContent: String = ""
) : UiState

sealed interface PromptEditorIntent : UiIntent {
    data class LoadPrompt(val promptId: String?) : PromptEditorIntent
    data class UpdateName(val name: String) : PromptEditorIntent
    data class UpdateDescription(val description: String) : PromptEditorIntent
    data class UpdateContent(val content: String) : PromptEditorIntent
    data object Save : PromptEditorIntent
    data object SaveAndClose : PromptEditorIntent
    data object Discard : PromptEditorIntent
}

sealed interface PromptEditorEffect : UiEffect {
    data object PromptSaved : PromptEditorEffect
    data object PromptDiscarded : PromptEditorEffect
    data class ShowError(val message: String) : PromptEditorEffect
    data object ShowDiscardConfirmation : PromptEditorEffect
}
