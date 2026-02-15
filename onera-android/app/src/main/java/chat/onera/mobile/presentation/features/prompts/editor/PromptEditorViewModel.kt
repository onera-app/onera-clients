package chat.onera.mobile.presentation.features.prompts.editor

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.model.Prompt
import chat.onera.mobile.domain.repository.PromptRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.navigation.NavArgs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import timber.log.Timber
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class PromptEditorViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val promptRepository: PromptRepository
) : BaseViewModel<PromptEditorState, PromptEditorIntent, PromptEditorEffect>(PromptEditorState()) {

    private val promptId: String? = savedStateHandle[NavArgs.PROMPT_ID]

    init {
        sendIntent(PromptEditorIntent.LoadPrompt(promptId))
    }

    override fun handleIntent(intent: PromptEditorIntent) {
        when (intent) {
            is PromptEditorIntent.LoadPrompt -> loadPrompt(intent.promptId)
            is PromptEditorIntent.UpdateName -> updateName(intent.name)
            is PromptEditorIntent.UpdateDescription -> updateDescription(intent.description)
            is PromptEditorIntent.UpdateContent -> updateContent(intent.content)
            is PromptEditorIntent.Save -> savePrompt()
            is PromptEditorIntent.SaveAndClose -> saveAndClose()
            is PromptEditorIntent.Discard -> discard()
        }
    }

    private fun loadPrompt(promptId: String?) {
        if (promptId == null) {
            updateState {
                copy(
                    isNewPrompt = true,
                    isLoading = false
                )
            }
            return
        }

        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                val prompt = promptRepository.getPrompt(promptId)
                if (prompt != null) {
                    updateState {
                        copy(
                            promptId = prompt.id,
                            name = prompt.name,
                            description = prompt.description,
                            content = prompt.content,
                            variables = prompt.variables,
                            isNewPrompt = false,
                            isLoading = false,
                            originalName = prompt.name,
                            originalDescription = prompt.description,
                            originalContent = prompt.content
                        )
                    }
                } else {
                    updateState { copy(isLoading = false) }
                    sendEffect(PromptEditorEffect.ShowError("Prompt not found"))
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to load prompt")
                updateState { copy(isLoading = false) }
                sendEffect(PromptEditorEffect.ShowError(e.message ?: "Failed to load prompt"))
            }
        }
    }

    private fun updateName(name: String) {
        updateState {
            copy(
                name = name,
                hasChanges = name != originalName || description != originalDescription || content != originalContent
            )
        }
    }

    private fun updateDescription(description: String) {
        updateState {
            copy(
                description = description,
                hasChanges = name != originalName || description != originalDescription || content != originalContent
            )
        }
    }

    private fun updateContent(content: String) {
        val variables = extractVariables(content)
        updateState {
            copy(
                content = content,
                variables = variables,
                hasChanges = name != originalName || description != originalDescription || content != originalContent
            )
        }
    }

    private fun extractVariables(content: String): List<String> {
        return Regex("\\{\\{\\s*(\\w+)\\s*\\}\\}")
            .findAll(content)
            .map { it.groupValues[1] }
            .distinct()
            .toList()
    }

    private fun savePrompt() {
        if (currentState.name.isBlank()) {
            sendEffect(PromptEditorEffect.ShowError("Name cannot be empty"))
            return
        }

        viewModelScope.launch {
            updateState { copy(isSaving = true) }
            try {
                if (currentState.isNewPrompt) {
                    val newId = promptRepository.createPrompt(
                        name = currentState.name,
                        description = currentState.description,
                        content = currentState.content
                    )
                    updateState {
                        copy(
                            promptId = newId,
                            isNewPrompt = false,
                            isSaving = false,
                            hasChanges = false,
                            originalName = name,
                            originalDescription = description,
                            originalContent = content
                        )
                    }
                } else {
                    val prompt = Prompt(
                        id = currentState.promptId ?: UUID.randomUUID().toString(),
                        name = currentState.name,
                        description = currentState.description,
                        content = currentState.content,
                        updatedAt = System.currentTimeMillis()
                    )
                    promptRepository.updatePrompt(prompt)
                    updateState {
                        copy(
                            isSaving = false,
                            hasChanges = false,
                            originalName = name,
                            originalDescription = description,
                            originalContent = content
                        )
                    }
                }
            } catch (e: Exception) {
                Timber.e(e, "Failed to save prompt")
                updateState { copy(isSaving = false) }
                sendEffect(PromptEditorEffect.ShowError(e.message ?: "Failed to save prompt"))
            }
        }
    }

    private fun saveAndClose() {
        if (currentState.name.isBlank()) {
            sendEffect(PromptEditorEffect.ShowError("Name cannot be empty"))
            return
        }

        viewModelScope.launch {
            updateState { copy(isSaving = true) }
            try {
                if (currentState.isNewPrompt) {
                    promptRepository.createPrompt(
                        name = currentState.name,
                        description = currentState.description,
                        content = currentState.content
                    )
                } else {
                    val prompt = Prompt(
                        id = currentState.promptId ?: UUID.randomUUID().toString(),
                        name = currentState.name,
                        description = currentState.description,
                        content = currentState.content,
                        updatedAt = System.currentTimeMillis()
                    )
                    promptRepository.updatePrompt(prompt)
                }
                updateState { copy(isSaving = false) }
                sendEffect(PromptEditorEffect.PromptSaved)
            } catch (e: Exception) {
                Timber.e(e, "Failed to save prompt")
                updateState { copy(isSaving = false) }
                sendEffect(PromptEditorEffect.ShowError(e.message ?: "Failed to save prompt"))
            }
        }
    }

    private fun discard() {
        if (currentState.hasChanges) {
            sendEffect(PromptEditorEffect.ShowDiscardConfirmation)
        } else {
            sendEffect(PromptEditorEffect.PromptDiscarded)
        }
    }
}
