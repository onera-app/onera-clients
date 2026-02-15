package chat.onera.mobile.data.remote

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

@Singleton
class WebSearchService @Inject constructor() {
    
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    
    enum class SearchProvider(val displayName: String) {
        TAVILY("Tavily"),
        BRAVE("Brave Search"),
        SERPER("Serper"),
        EXA("Exa")
    }
    
    @Serializable
    data class WebSearchResult(
        val title: String,
        val url: String,
        val snippet: String,
        val content: String? = null,
        val publishedDate: String? = null,
        val score: Double? = null
    )
    
    suspend fun search(
        query: String,
        provider: SearchProvider,
        apiKey: String,
        maxResults: Int = 5
    ): List<WebSearchResult> = withContext(Dispatchers.IO) {
        try {
            when (provider) {
                SearchProvider.TAVILY -> searchTavily(query, apiKey, maxResults)
                SearchProvider.BRAVE -> searchBrave(query, apiKey, maxResults)
                SearchProvider.SERPER -> searchSerper(query, apiKey, maxResults)
                SearchProvider.EXA -> searchExa(query, apiKey, maxResults)
            }
        } catch (e: Exception) {
            Timber.e(e, "Web search failed with ${provider.name}")
            emptyList()
        }
    }
    
    private fun searchTavily(query: String, apiKey: String, maxResults: Int): List<WebSearchResult> {
        val body = json.encodeToString(
            kotlinx.serialization.serializer<Map<String, String>>(),
            mapOf(
                "api_key" to apiKey,
                "query" to query,
                "max_results" to maxResults.toString(),
                "include_answer" to "false"
            )
        )
        val request = Request.Builder()
            .url("https://api.tavily.com/search")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()
        
        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: return emptyList()
        return parseTavilyResponse(responseBody)
    }
    
    private fun searchBrave(query: String, apiKey: String, maxResults: Int): List<WebSearchResult> {
        val request = Request.Builder()
            .url("https://api.search.brave.com/res/v1/web/search?q=${java.net.URLEncoder.encode(query, "UTF-8")}&count=$maxResults")
            .get()
            .header("X-Subscription-Token", apiKey)
            .header("Accept", "application/json")
            .build()
        
        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: return emptyList()
        return parseBraveResponse(responseBody)
    }
    
    private fun searchSerper(query: String, apiKey: String, maxResults: Int): List<WebSearchResult> {
        val body = json.encodeToString(
            kotlinx.serialization.serializer<Map<String, String>>(),
            mapOf("q" to query, "num" to maxResults.toString())
        )
        val request = Request.Builder()
            .url("https://google.serper.dev/search")
            .post(body.toRequestBody("application/json".toMediaType()))
            .header("X-API-KEY", apiKey)
            .build()
        
        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: return emptyList()
        return parseSerperResponse(responseBody)
    }
    
    private fun searchExa(query: String, apiKey: String, maxResults: Int): List<WebSearchResult> {
        val body = json.encodeToString(
            kotlinx.serialization.serializer<Map<String, String>>(),
            mapOf(
                "query" to query,
                "num_results" to maxResults.toString(),
                "type" to "neural"
            )
        )
        val request = Request.Builder()
            .url("https://api.exa.ai/search")
            .post(body.toRequestBody("application/json".toMediaType()))
            .header("x-api-key", apiKey)
            .build()
        
        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: return emptyList()
        return parseExaResponse(responseBody)
    }
    
    // Parse methods using lenient JSON parsing
    private fun parseTavilyResponse(body: String): List<WebSearchResult> {
        val data = json.decodeFromString<Map<String, JsonElement>>(body)
        val results = data["results"] as? JsonArray ?: return emptyList()
        return results.mapNotNull { element ->
            val obj = element as? JsonObject ?: return@mapNotNull null
            WebSearchResult(
                title = obj["title"]?.toString()?.trim('"') ?: "",
                url = obj["url"]?.toString()?.trim('"') ?: "",
                snippet = obj["content"]?.toString()?.trim('"') ?: "",
                score = obj["score"]?.toString()?.toDoubleOrNull()
            )
        }
    }
    
    private fun parseBraveResponse(body: String): List<WebSearchResult> {
        val data = json.decodeFromString<Map<String, JsonElement>>(body)
        val web = data["web"] as? JsonObject ?: return emptyList()
        val results = web["results"] as? JsonArray ?: return emptyList()
        return results.mapNotNull { element ->
            val obj = element as? JsonObject ?: return@mapNotNull null
            WebSearchResult(
                title = obj["title"]?.toString()?.trim('"') ?: "",
                url = obj["url"]?.toString()?.trim('"') ?: "",
                snippet = obj["description"]?.toString()?.trim('"') ?: ""
            )
        }
    }
    
    private fun parseSerperResponse(body: String): List<WebSearchResult> {
        val data = json.decodeFromString<Map<String, JsonElement>>(body)
        val organic = data["organic"] as? JsonArray ?: return emptyList()
        return organic.mapNotNull { element ->
            val obj = element as? JsonObject ?: return@mapNotNull null
            WebSearchResult(
                title = obj["title"]?.toString()?.trim('"') ?: "",
                url = obj["link"]?.toString()?.trim('"') ?: "",
                snippet = obj["snippet"]?.toString()?.trim('"') ?: ""
            )
        }
    }
    
    private fun parseExaResponse(body: String): List<WebSearchResult> {
        val data = json.decodeFromString<Map<String, JsonElement>>(body)
        val results = data["results"] as? JsonArray ?: return emptyList()
        return results.mapNotNull { element ->
            val obj = element as? JsonObject ?: return@mapNotNull null
            WebSearchResult(
                title = obj["title"]?.toString()?.trim('"') ?: "",
                url = obj["url"]?.toString()?.trim('"') ?: "",
                snippet = obj["text"]?.toString()?.trim('"')?.take(200) ?: ""
            )
        }
    }
    
    companion object {
        /**
         * Format search results as context to inject into the LLM prompt.
         */
        fun formatResultsForContext(query: String, results: List<WebSearchResult>): String {
            if (results.isEmpty()) return ""
            val entries = results.mapIndexed { i, r ->
                """<result index="${i + 1}">
<url>${r.url}</url>
<title>${r.title}</title>
<snippet>${r.snippet}</snippet>
</result>"""
            }.joinToString("\n")
            return """<search_results query="$query">
$entries
</search_results>"""
        }
    }
}
