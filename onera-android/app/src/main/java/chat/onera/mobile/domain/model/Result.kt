package chat.onera.mobile.domain.model

/**
 * A sealed class representing the result of an operation that can either succeed or fail.
 * This provides a type-safe way to handle success and error cases without exceptions.
 * 
 * Usage:
 * ```kotlin
 * // In UseCase
 * suspend fun execute(): Result<Chat> {
 *     return Result.runCatching {
 *         repository.createChat(title)
 *     }
 * }
 * 
 * // In ViewModel
 * when (val result = useCase.execute()) {
 *     is Result.Success -> updateState { copy(chat = result.data) }
 *     is Result.Error -> sendEffect(ShowError(result.message))
 * }
 * ```
 */
sealed class Result<out T> {
    
    /**
     * Represents a successful operation with the resulting data.
     */
    data class Success<T>(val data: T) : Result<T>()
    
    /**
     * Represents a failed operation with error information.
     */
    data class Error(
        val exception: Throwable,
        val message: String = exception.message ?: "Unknown error"
    ) : Result<Nothing>()
    
    /**
     * Returns true if this is a successful result.
     */
    val isSuccess: Boolean
        get() = this is Success
    
    /**
     * Returns true if this is an error result.
     */
    val isError: Boolean
        get() = this is Error
    
    /**
     * Returns the data if successful, or null if error.
     */
    fun getOrNull(): T? = when (this) {
        is Success -> data
        is Error -> null
    }
    
    /**
     * Returns the data if successful, or the default value if error.
     */
    fun getOrDefault(default: @UnsafeVariance T): T = when (this) {
        is Success -> data
        is Error -> default
    }
    
    /**
     * Returns the data if successful, or throws the exception if error.
     */
    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw exception
    }
    
    /**
     * Transforms the success data using the given function.
     */
    inline fun <R> map(transform: (T) -> R): Result<R> = when (this) {
        is Success -> Success(transform(data))
        is Error -> this
    }
    
    /**
     * Transforms the success data using a function that returns a Result.
     */
    inline fun <R> flatMap(transform: (T) -> Result<R>): Result<R> = when (this) {
        is Success -> transform(data)
        is Error -> this
    }
    
    /**
     * Executes the given block if this is a success.
     */
    inline fun onSuccess(block: (T) -> Unit): Result<T> {
        if (this is Success) block(data)
        return this
    }
    
    /**
     * Executes the given block if this is an error.
     */
    inline fun onError(block: (Throwable) -> Unit): Result<T> {
        if (this is Error) block(exception)
        return this
    }
    
    /**
     * Transforms the error using the given function, keeping success unchanged.
     */
    inline fun mapError(transform: (Throwable) -> Throwable): Result<T> = when (this) {
        is Success -> this
        is Error -> Error(transform(exception))
    }
    
    /**
     * Recovers from an error by providing an alternative value.
     */
    inline fun recover(transform: (Throwable) -> @UnsafeVariance T): Result<T> = when (this) {
        is Success -> this
        is Error -> Success(transform(exception))
    }
    
    /**
     * Recovers from an error by trying another operation.
     */
    inline fun recoverCatching(transform: (Throwable) -> @UnsafeVariance T): Result<T> = when (this) {
        is Success -> this
        is Error -> Result.runCatching { transform(exception) }
    }
    
    companion object {
        /**
         * Wraps a suspend function in a Result, catching any exceptions.
         */
        inline fun <T> runCatching(block: () -> T): Result<T> {
            return try {
                Success(block())
            } catch (e: Throwable) {
                Error(e)
            }
        }
        
        /**
         * Creates a success result.
         */
        fun <T> success(data: T): Result<T> = Success(data)
        
        /**
         * Creates an error result from an exception.
         */
        fun error(exception: Throwable): Result<Nothing> = Error(exception)
        
        /**
         * Creates an error result from a message.
         */
        fun error(message: String): Result<Nothing> = Error(Exception(message), message)
    }
}

/**
 * Extension function to convert Kotlin's stdlib Result to our Result.
 */
fun <T> kotlin.Result<T>.toResult(): Result<T> = fold(
    onSuccess = { Result.Success(it) },
    onFailure = { Result.Error(it) }
)

/**
 * Combines two results into a pair, failing if either fails.
 */
fun <A, B> Result<A>.zip(other: Result<B>): Result<Pair<A, B>> = when (this) {
    is Result.Success -> when (other) {
        is Result.Success -> Result.Success(data to other.data)
        is Result.Error -> other
    }
    is Result.Error -> this
}

/**
 * Combines three results into a triple, failing if any fails.
 */
fun <A, B, C> Result<A>.zip(
    second: Result<B>,
    third: Result<C>
): Result<Triple<A, B, C>> = when (this) {
    is Result.Success -> when (second) {
        is Result.Success -> when (third) {
            is Result.Success -> Result.Success(Triple(data, second.data, third.data))
            is Result.Error -> third
        }
        is Result.Error -> second
    }
    is Result.Error -> this
}
