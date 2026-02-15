package chat.onera.mobile.presentation.features.prompts

import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.repository.PromptRepository
import chat.onera.mobile.presentation.base.BaseViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

@HiltViewModel
class PromptsViewModel @Inject constructor(
    private val promptRepository: PromptRepository
) : BaseViewModel<PromptsState, PromptsIntent, PromptsEffect>(PromptsState()) {

    init {
        observePrompts()
        refreshPrompts()
    }

    override fun handleIntent(intent: PromptsIntent) {
        when (intent) {
            is PromptsIntent.LoadPrompts -> refreshPrompts()
            is PromptsIntent.Search -> search(intent.query)
            is PromptsIntent.DeletePrompt -> deletePrompt(intent.id)
            is PromptsIntent.SelectPrompt -> selectPrompt(intent.id)
        }
    }

    private fun observePrompts() {
        promptRepository.observePrompts()
            .onEach { prompts ->
                updateState {
                    copy(
                        prompts = prompts.sortedByDescending { it.updatedAt },
                        isLoading = false
                    )
                }
            }
            .catch { e ->
                Timber.e(e, "Failed to observe prompts")
                updateState { copy(isLoading = false) }
                sendEffect(PromptsEffect.ShowError(e.message ?: "Failed to load prompts"))
            }
            .launchIn(viewModelScope)
    }

    private fun refreshPrompts() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                promptRepository.refreshPrompts()
                updateState { copy(isLoading = false) }
            } catch (e: Exception) {
                Timber.e(e, "Failed to refresh prompts")
                updateState { copy(isLoading = false) }
                sendEffect(PromptsEffect.ShowError(e.message ?: "Failed to refresh prompts"))
            }
        }
    }

    private fun search(query: String) {
        updateState { copy(searchQuery = query) }
    }

    private fun deletePrompt(promptId: String) {
        viewModelScope.launch {
            try {
                promptRepository.deletePrompt(promptId)
                // Clear selection if deleted prompt was selected
                if (currentState.selectedPrompt?.id == promptId) {
                    updateState { copy(selectedPrompt = null) }
                }
                Timber.d("Prompt deleted: $promptId")
            } catch (e: Exception) {
                Timber.e(e, "Failed to delete prompt")
                sendEffect(PromptsEffect.ShowError(e.message ?: "Failed to delete prompt"))
            }
        }
    }

    private fun selectPrompt(promptId: String) {
        viewModelScope.launch {
            try {
                val prompt = promptRepository.getPrompt(promptId)
                updateState { copy(selectedPrompt = prompt) }
            } catch (e: Exception) {
                Timber.e(e, "Failed to select prompt")
                sendEffect(PromptsEffect.ShowError(e.message ?: "Failed to load prompt"))
            }
        }
    }
}
