package chat.onera.mobile.di

import chat.onera.mobile.data.remote.api.ChatApiService
import chat.onera.mobile.data.remote.trpc.AuthTokenProvider
import chat.onera.mobile.data.remote.trpc.ClerkAuthTokenProvider
import chat.onera.mobile.data.remote.trpc.TRPCClient
import chat.onera.mobile.data.remote.websocket.WebSocketService
import chat.onera.mobile.BuildConfig
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        isLenient = true
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        
        return OkHttpClient.Builder()
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        json: Json
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
    }

    @Provides
    @Singleton
    fun provideChatApiService(retrofit: Retrofit): ChatApiService {
        return retrofit.create(ChatApiService::class.java)
    }
    
    @Provides
    @Singleton
    fun provideWebSocketService(): WebSocketService {
        return WebSocketService()
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class AuthTokenModule {
    
    @Binds
    @Singleton
    abstract fun bindAuthTokenProvider(
        clerkAuthTokenProvider: ClerkAuthTokenProvider
    ): AuthTokenProvider
}
