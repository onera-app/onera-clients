package chat.onera.mobile.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")

/**
 * Manages user preferences using DataStore.
 */
@Singleton
class UserPreferences @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    companion object {
        private val THEME_MODE_KEY = stringPreferencesKey("theme_mode")
        
        const val THEME_SYSTEM = "System"
        const val THEME_LIGHT = "Light"
        const val THEME_DARK = "Dark"

        // General / Model Parameters
        private val SYSTEM_PROMPT_KEY = stringPreferencesKey("system_prompt")
        private val STREAM_RESPONSE_KEY = booleanPreferencesKey("stream_response")
        private val TEMPERATURE_KEY = floatPreferencesKey("temperature")
        private val TOP_P_KEY = floatPreferencesKey("top_p")
        private val TOP_K_KEY = intPreferencesKey("top_k")
        private val MAX_TOKENS_KEY = intPreferencesKey("max_tokens")
        private val FREQUENCY_PENALTY_KEY = floatPreferencesKey("frequency_penalty")
        private val PRESENCE_PENALTY_KEY = floatPreferencesKey("presence_penalty")
        private val SEED_KEY = intPreferencesKey("seed")

        // Audio – TTS
        private val TTS_ENABLED_KEY = booleanPreferencesKey("tts_enabled")
        private val TTS_SPEED_KEY = floatPreferencesKey("tts_speed")
        private val TTS_PITCH_KEY = floatPreferencesKey("tts_pitch")
        private val TTS_AUTO_PLAY_KEY = booleanPreferencesKey("tts_auto_play")

        // Audio – STT
        private val STT_ENABLED_KEY = booleanPreferencesKey("stt_enabled")
        private val STT_AUTO_SEND_KEY = booleanPreferencesKey("stt_auto_send")

        // Tools – Web Search
        private val WEB_SEARCH_ENABLED_KEY = booleanPreferencesKey("web_search_enabled")
        private val WEB_SEARCH_PROVIDER_KEY = stringPreferencesKey("web_search_provider")

        // Tools – Native AI Search
        private val GOOGLE_SEARCH_ENABLED_KEY = booleanPreferencesKey("google_search_enabled")
        private val XAI_SEARCH_ENABLED_KEY = booleanPreferencesKey("xai_search_enabled")

        // Tools – External Search Provider API Keys
        private val TAVILY_API_KEY = stringPreferencesKey("tavily_api_key")
        private val SERPER_API_KEY = stringPreferencesKey("serper_api_key")
        private val BRAVE_API_KEY = stringPreferencesKey("brave_api_key")
        private val EXA_API_KEY = stringPreferencesKey("exa_api_key")

        // Provider-specific settings
        private val OPENAI_REASONING_EFFORT = stringPreferencesKey("openai_reasoning_effort")
        private val OPENAI_REASONING_SUMMARY = stringPreferencesKey("openai_reasoning_summary")
        private val ANTHROPIC_EXTENDED_THINKING = booleanPreferencesKey("anthropic_extended_thinking")

        // General defaults
        const val DEFAULT_SYSTEM_PROMPT = ""
        const val DEFAULT_STREAM_RESPONSE = true
        const val DEFAULT_TEMPERATURE = 0.7f
        const val DEFAULT_TOP_P = 1.0f
        const val DEFAULT_TOP_K = 40
        const val DEFAULT_MAX_TOKENS = 0
        const val DEFAULT_FREQUENCY_PENALTY = 0.0f
        const val DEFAULT_PRESENCE_PENALTY = 0.0f
        const val DEFAULT_SEED = 0

        // Audio defaults
        const val DEFAULT_TTS_ENABLED = true
        const val DEFAULT_TTS_SPEED = 1.0f
        const val DEFAULT_TTS_PITCH = 1.0f
        const val DEFAULT_TTS_AUTO_PLAY = false
        const val DEFAULT_STT_ENABLED = true
        const val DEFAULT_STT_AUTO_SEND = false

        // Tools defaults
        const val DEFAULT_WEB_SEARCH_ENABLED = false
        const val DEFAULT_WEB_SEARCH_PROVIDER = "Tavily"
        const val DEFAULT_GOOGLE_SEARCH_ENABLED = false
        const val DEFAULT_XAI_SEARCH_ENABLED = false

        // Provider-specific defaults
        const val DEFAULT_OPENAI_REASONING_EFFORT = "medium"
        const val DEFAULT_OPENAI_REASONING_SUMMARY = "auto"
        const val DEFAULT_ANTHROPIC_EXTENDED_THINKING = false
    }
    
    // ── Theme ────────────────────────────────────────────────────────────

    val themeModeFlow: Flow<String> = context.dataStore.data
        .map { preferences ->
            preferences[THEME_MODE_KEY] ?: THEME_SYSTEM
        }
    
    suspend fun setThemeMode(themeMode: String) {
        context.dataStore.edit { preferences ->
            preferences[THEME_MODE_KEY] = themeMode
        }
    }
    
    suspend fun getThemeMode(): String {
        var result = THEME_SYSTEM
        context.dataStore.data.collect { preferences ->
            result = preferences[THEME_MODE_KEY] ?: THEME_SYSTEM
        }
        return result
    }

    // ── General / Model Parameters ──────────────────────────────────────

    val systemPromptFlow: Flow<String> = context.dataStore.data
        .map { it[SYSTEM_PROMPT_KEY] ?: DEFAULT_SYSTEM_PROMPT }

    suspend fun setSystemPrompt(value: String) {
        context.dataStore.edit { it[SYSTEM_PROMPT_KEY] = value }
    }

    val streamResponseFlow: Flow<Boolean> = context.dataStore.data
        .map { it[STREAM_RESPONSE_KEY] ?: DEFAULT_STREAM_RESPONSE }

    suspend fun setStreamResponse(value: Boolean) {
        context.dataStore.edit { it[STREAM_RESPONSE_KEY] = value }
    }

    val temperatureFlow: Flow<Float> = context.dataStore.data
        .map { it[TEMPERATURE_KEY] ?: DEFAULT_TEMPERATURE }

    suspend fun setTemperature(value: Float) {
        context.dataStore.edit { it[TEMPERATURE_KEY] = value }
    }

    val topPFlow: Flow<Float> = context.dataStore.data
        .map { it[TOP_P_KEY] ?: DEFAULT_TOP_P }

    suspend fun setTopP(value: Float) {
        context.dataStore.edit { it[TOP_P_KEY] = value }
    }

    val topKFlow: Flow<Int> = context.dataStore.data
        .map { it[TOP_K_KEY] ?: DEFAULT_TOP_K }

    suspend fun setTopK(value: Int) {
        context.dataStore.edit { it[TOP_K_KEY] = value }
    }

    val maxTokensFlow: Flow<Int> = context.dataStore.data
        .map { it[MAX_TOKENS_KEY] ?: DEFAULT_MAX_TOKENS }

    suspend fun setMaxTokens(value: Int) {
        context.dataStore.edit { it[MAX_TOKENS_KEY] = value }
    }

    val frequencyPenaltyFlow: Flow<Float> = context.dataStore.data
        .map { it[FREQUENCY_PENALTY_KEY] ?: DEFAULT_FREQUENCY_PENALTY }

    suspend fun setFrequencyPenalty(value: Float) {
        context.dataStore.edit { it[FREQUENCY_PENALTY_KEY] = value }
    }

    val presencePenaltyFlow: Flow<Float> = context.dataStore.data
        .map { it[PRESENCE_PENALTY_KEY] ?: DEFAULT_PRESENCE_PENALTY }

    suspend fun setPresencePenalty(value: Float) {
        context.dataStore.edit { it[PRESENCE_PENALTY_KEY] = value }
    }

    val seedFlow: Flow<Int> = context.dataStore.data
        .map { it[SEED_KEY] ?: DEFAULT_SEED }

    suspend fun setSeed(value: Int) {
        context.dataStore.edit { it[SEED_KEY] = value }
    }

    suspend fun resetGeneralDefaults() {
        context.dataStore.edit { prefs ->
            prefs[SYSTEM_PROMPT_KEY] = DEFAULT_SYSTEM_PROMPT
            prefs[STREAM_RESPONSE_KEY] = DEFAULT_STREAM_RESPONSE
            prefs[TEMPERATURE_KEY] = DEFAULT_TEMPERATURE
            prefs[TOP_P_KEY] = DEFAULT_TOP_P
            prefs[TOP_K_KEY] = DEFAULT_TOP_K
            prefs[MAX_TOKENS_KEY] = DEFAULT_MAX_TOKENS
            prefs[FREQUENCY_PENALTY_KEY] = DEFAULT_FREQUENCY_PENALTY
            prefs[PRESENCE_PENALTY_KEY] = DEFAULT_PRESENCE_PENALTY
            prefs[SEED_KEY] = DEFAULT_SEED
        }
    }

    // ── Audio – TTS ─────────────────────────────────────────────────────

    val ttsEnabledFlow: Flow<Boolean> = context.dataStore.data
        .map { it[TTS_ENABLED_KEY] ?: DEFAULT_TTS_ENABLED }

    suspend fun setTtsEnabled(value: Boolean) {
        context.dataStore.edit { it[TTS_ENABLED_KEY] = value }
    }

    val ttsSpeedFlow: Flow<Float> = context.dataStore.data
        .map { it[TTS_SPEED_KEY] ?: DEFAULT_TTS_SPEED }

    suspend fun setTtsSpeed(value: Float) {
        context.dataStore.edit { it[TTS_SPEED_KEY] = value }
    }

    val ttsPitchFlow: Flow<Float> = context.dataStore.data
        .map { it[TTS_PITCH_KEY] ?: DEFAULT_TTS_PITCH }

    suspend fun setTtsPitch(value: Float) {
        context.dataStore.edit { it[TTS_PITCH_KEY] = value }
    }

    val ttsAutoPlayFlow: Flow<Boolean> = context.dataStore.data
        .map { it[TTS_AUTO_PLAY_KEY] ?: DEFAULT_TTS_AUTO_PLAY }

    suspend fun setTtsAutoPlay(value: Boolean) {
        context.dataStore.edit { it[TTS_AUTO_PLAY_KEY] = value }
    }

    // ── Audio – STT ─────────────────────────────────────────────────────

    val sttEnabledFlow: Flow<Boolean> = context.dataStore.data
        .map { it[STT_ENABLED_KEY] ?: DEFAULT_STT_ENABLED }

    suspend fun setSttEnabled(value: Boolean) {
        context.dataStore.edit { it[STT_ENABLED_KEY] = value }
    }

    val sttAutoSendFlow: Flow<Boolean> = context.dataStore.data
        .map { it[STT_AUTO_SEND_KEY] ?: DEFAULT_STT_AUTO_SEND }

    suspend fun setSttAutoSend(value: Boolean) {
        context.dataStore.edit { it[STT_AUTO_SEND_KEY] = value }
    }

    // ── Tools – Web Search ──────────────────────────────────────────────

    val webSearchEnabledFlow: Flow<Boolean> = context.dataStore.data
        .map { it[WEB_SEARCH_ENABLED_KEY] ?: DEFAULT_WEB_SEARCH_ENABLED }

    suspend fun setWebSearchEnabled(value: Boolean) {
        context.dataStore.edit { it[WEB_SEARCH_ENABLED_KEY] = value }
    }

    val webSearchProviderFlow: Flow<String> = context.dataStore.data
        .map { it[WEB_SEARCH_PROVIDER_KEY] ?: DEFAULT_WEB_SEARCH_PROVIDER }

    suspend fun setWebSearchProvider(value: String) {
        context.dataStore.edit { it[WEB_SEARCH_PROVIDER_KEY] = value }
    }

    // ── Tools – Native AI Search ────────────────────────────────────────

    val googleSearchEnabledFlow: Flow<Boolean> = context.dataStore.data
        .map { it[GOOGLE_SEARCH_ENABLED_KEY] ?: DEFAULT_GOOGLE_SEARCH_ENABLED }

    suspend fun setGoogleSearchEnabled(value: Boolean) {
        context.dataStore.edit { it[GOOGLE_SEARCH_ENABLED_KEY] = value }
    }

    val xaiSearchEnabledFlow: Flow<Boolean> = context.dataStore.data
        .map { it[XAI_SEARCH_ENABLED_KEY] ?: DEFAULT_XAI_SEARCH_ENABLED }

    suspend fun setXaiSearchEnabled(value: Boolean) {
        context.dataStore.edit { it[XAI_SEARCH_ENABLED_KEY] = value }
    }

    // ── Tools – External Search Provider API Keys ───────────────────────

    val tavilyApiKeyFlow: Flow<String> = context.dataStore.data
        .map { it[TAVILY_API_KEY] ?: "" }

    suspend fun setTavilyApiKey(value: String) {
        context.dataStore.edit { it[TAVILY_API_KEY] = value }
    }

    val serperApiKeyFlow: Flow<String> = context.dataStore.data
        .map { it[SERPER_API_KEY] ?: "" }

    suspend fun setSerperApiKey(value: String) {
        context.dataStore.edit { it[SERPER_API_KEY] = value }
    }

    val braveApiKeyFlow: Flow<String> = context.dataStore.data
        .map { it[BRAVE_API_KEY] ?: "" }

    suspend fun setBraveApiKey(value: String) {
        context.dataStore.edit { it[BRAVE_API_KEY] = value }
    }

    val exaApiKeyFlow: Flow<String> = context.dataStore.data
        .map { it[EXA_API_KEY] ?: "" }

    suspend fun setExaApiKey(value: String) {
        context.dataStore.edit { it[EXA_API_KEY] = value }
    }

    suspend fun deleteSearchProviderApiKey(provider: String) {
        context.dataStore.edit { prefs ->
            when (provider) {
                "Tavily" -> prefs.remove(TAVILY_API_KEY)
                "Serper" -> prefs.remove(SERPER_API_KEY)
                "Brave" -> prefs.remove(BRAVE_API_KEY)
                "Exa" -> prefs.remove(EXA_API_KEY)
            }
        }
    }

    // ── Provider-Specific Settings ──────────────────────────────────────

    val openaiReasoningEffortFlow: Flow<String> = context.dataStore.data
        .map { it[OPENAI_REASONING_EFFORT] ?: DEFAULT_OPENAI_REASONING_EFFORT }

    suspend fun setOpenaiReasoningEffort(value: String) {
        context.dataStore.edit { it[OPENAI_REASONING_EFFORT] = value }
    }

    val openaiReasoningSummaryFlow: Flow<String> = context.dataStore.data
        .map { it[OPENAI_REASONING_SUMMARY] ?: DEFAULT_OPENAI_REASONING_SUMMARY }

    suspend fun setOpenaiReasoningSummary(value: String) {
        context.dataStore.edit { it[OPENAI_REASONING_SUMMARY] = value }
    }

    val anthropicExtendedThinkingFlow: Flow<Boolean> = context.dataStore.data
        .map { it[ANTHROPIC_EXTENDED_THINKING] ?: DEFAULT_ANTHROPIC_EXTENDED_THINKING }

    suspend fun setAnthropicExtendedThinking(value: Boolean) {
        context.dataStore.edit { it[ANTHROPIC_EXTENDED_THINKING] = value }
    }
}
