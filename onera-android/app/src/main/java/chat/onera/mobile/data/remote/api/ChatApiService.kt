package chat.onera.mobile.data.remote.api

import chat.onera.mobile.data.remote.dto.ChatCompletionRequest
import chat.onera.mobile.data.remote.dto.ChatCompletionResponse
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Streaming

interface ChatApiService {
    
    @POST("chat/completions")
    suspend fun sendMessage(
        @Body request: ChatCompletionRequest
    ): Response<ChatCompletionResponse>
    
    @Streaming
    @POST("chat/completions/stream")
    suspend fun sendMessageStream(
        @Body request: ChatCompletionRequest
    ): Response<ResponseBody>
}
