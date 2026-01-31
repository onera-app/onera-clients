package chat.onera.mobile.presentation.features.settings.credentials

import timber.log.Timber
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.model.Credential
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.domain.repository.StoredCredential
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.base.UiEffect
import chat.onera.mobile.presentation.base.UiIntent
import chat.onera.mobile.presentation.base.UiState
import chat.onera.mobile.presentation.features.main.ModelProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CredentialsViewModel @Inject constructor(
    private val credentialRepository: CredentialRepository,
    private val llmRepository: LLMRepository
) : BaseViewModel<CredentialsState, CredentialsIntent, CredentialsEffect>(CredentialsState()) {

    init {
        loadCredentials()
    }

    override fun handleIntent(intent: CredentialsIntent) {
        when (intent) {
            is CredentialsIntent.LoadCredentials -> loadCredentials()
            is CredentialsIntent.AddCredential -> addCredential(intent.provider, intent.name, intent.apiKey, intent.baseUrl)
            is CredentialsIntent.DeleteCredential -> deleteCredential(intent.credentialId)
            is CredentialsIntent.ValidateKey -> validateKey(intent.credentialId)
        }
    }

    private fun loadCredentials() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            try {
                // First refresh from server to get latest
                credentialRepository.refreshCredentials()
                
                // Then get credentials from repository
                val serverCredentials = credentialRepository.getCredentials()
                val credentials = serverCredentials.map { it.toApiCredential() }
                updateState { 
                    copy(
                        credentials = credentials,
                        isLoading = false
                    ) 
                }
                Timber.d("Loaded ${credentials.size} credentials from server")
            } catch (e: Exception) {
                Timber.e(e, "Failed to load credentials")
                updateState { copy(isLoading = false) }
                sendEffect(CredentialsEffect.ShowError(e.message ?: "Failed to load credentials"))
            }
        }
    }
    
    private fun Credential.toApiCredential(): ApiCredential {
        // Map domain LLMProvider to presentation ModelProvider by name
        val modelProvider = try {
            ModelProvider.valueOf(provider.name)
        } catch (e: Exception) {
            // Fallback for providers not in presentation layer
            ModelProvider.OPENAI
        }
        return ApiCredential(
            id = id,
            provider = modelProvider,
            name = name,
            maskedKey = maskedApiKey,
            createdAt = createdAt
        )
    }

    private fun addCredential(provider: ModelProvider, name: String, apiKey: String, baseUrl: String?) {
        viewModelScope.launch {
            updateState { copy(isValidating = true) }
            try {
                // Add the credential
                val credentialId = llmRepository.addCredential(
                    provider = provider.name,
                    name = name.ifBlank { provider.displayName },
                    apiKey = apiKey,
                    baseUrl = baseUrl
                )
                
                Timber.d("Added credential: $credentialId")
                
                // Optionally validate the credential
                val isValid = try {
                    llmRepository.validateCredential(credentialId)
                } catch (e: Exception) {
                    Timber.w(e, "Validation failed, but credential saved")
                    // Don't fail the add if validation fails - user might be offline
                    true
                }
                
                updateState { copy(isValidating = false, isKeyValid = isValid) }
                
                // Reload credentials
                loadCredentials()
                
                sendEffect(CredentialsEffect.CredentialAdded)
            } catch (e: Exception) {
                Timber.e(e, "Failed to add credential")
                updateState { copy(isValidating = false, isKeyValid = false) }
                sendEffect(CredentialsEffect.ShowError(e.message ?: "Failed to add credential"))
            }
        }
    }

    private fun deleteCredential(credentialId: String) {
        viewModelScope.launch {
            try {
                llmRepository.deleteCredential(credentialId)
                Timber.d("Deleted credential: $credentialId")
                
                // Reload credentials
                loadCredentials()
            } catch (e: Exception) {
                Timber.e(e, "Failed to delete credential")
                sendEffect(CredentialsEffect.ShowError(e.message ?: "Failed to delete credential"))
            }
        }
    }

    private fun validateKey(credentialId: String) {
        viewModelScope.launch {
            updateState { copy(isValidating = true) }
            try {
                val isValid = llmRepository.validateCredential(credentialId)
                updateState { copy(isValidating = false, isKeyValid = isValid) }
                
                if (!isValid) {
                    sendEffect(CredentialsEffect.ShowError("Invalid API key"))
                }
            } catch (e: Exception) {
                Timber.e(e, "Validation failed")
                updateState { copy(isValidating = false, isKeyValid = false) }
                sendEffect(CredentialsEffect.ShowError("Validation failed: ${e.message}"))
            }
        }
    }
    
    /**
     * Convert StoredCredential to ApiCredential for UI
     */
    private fun StoredCredential.toApiCredential(): ApiCredential {
        val modelProvider = try {
            ModelProvider.valueOf(provider.uppercase())
        } catch (e: Exception) {
            // If provider doesn't match ModelProvider enum, default to CUSTOM
            ModelProvider.CUSTOM
        }
        
        return ApiCredential(
            id = id,
            provider = modelProvider,
            name = name,
            maskedKey = maskedKey,
            createdAt = createdAt
        )
    }
}

data class CredentialsState(
    val credentials: List<ApiCredential> = emptyList(),
    val isLoading: Boolean = true,
    val isValidating: Boolean = false,
    val isKeyValid: Boolean? = null
) : UiState

data class ApiCredential(
    val id: String,
    val provider: ModelProvider,
    val name: String,
    val maskedKey: String,
    val createdAt: Long
)

sealed interface CredentialsIntent : UiIntent {
    data object LoadCredentials : CredentialsIntent
    data class AddCredential(
        val provider: ModelProvider, 
        val name: String, 
        val apiKey: String,
        val baseUrl: String? = null
    ) : CredentialsIntent
    data class DeleteCredential(val credentialId: String) : CredentialsIntent
    data class ValidateKey(val credentialId: String) : CredentialsIntent
}

sealed interface CredentialsEffect : UiEffect {
    data class ShowError(val message: String) : CredentialsEffect
    data object CredentialAdded : CredentialsEffect
}
