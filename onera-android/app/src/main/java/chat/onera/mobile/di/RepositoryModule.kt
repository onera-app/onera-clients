package chat.onera.mobile.di

import chat.onera.mobile.data.repository.AuthRepositoryImpl
import chat.onera.mobile.data.repository.ChatRepositoryImpl
import chat.onera.mobile.data.repository.CredentialRepositoryImpl
import chat.onera.mobile.data.repository.E2EERepositoryImpl
import chat.onera.mobile.data.repository.FoldersRepositoryImpl
import chat.onera.mobile.data.repository.LLMRepositoryImpl
import chat.onera.mobile.data.repository.NotesRepositoryImpl
import chat.onera.mobile.data.repository.PromptRepositoryImpl
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.E2EERepository
import chat.onera.mobile.domain.repository.FoldersRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.domain.repository.NotesRepository
import chat.onera.mobile.domain.repository.PromptRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(
        authRepositoryImpl: AuthRepositoryImpl
    ): AuthRepository

    @Binds
    @Singleton
    abstract fun bindChatRepository(
        chatRepositoryImpl: ChatRepositoryImpl
    ): ChatRepository

    @Binds
    @Singleton
    abstract fun bindE2EERepository(
        e2eeRepositoryImpl: E2EERepositoryImpl
    ): E2EERepository

    @Binds
    @Singleton
    abstract fun bindNotesRepository(
        notesRepositoryImpl: NotesRepositoryImpl
    ): NotesRepository

    @Binds
    @Singleton
    abstract fun bindFoldersRepository(
        foldersRepositoryImpl: FoldersRepositoryImpl
    ): FoldersRepository

    @Binds
    @Singleton
    abstract fun bindLLMRepository(
        llmRepositoryImpl: LLMRepositoryImpl
    ): LLMRepository

    @Binds
    @Singleton
    abstract fun bindCredentialRepository(
        credentialRepositoryImpl: CredentialRepositoryImpl
    ): CredentialRepository

    @Binds
    @Singleton
    abstract fun bindPromptRepository(
        promptRepositoryImpl: PromptRepositoryImpl
    ): PromptRepository
}
