package chat.onera.mobile

import android.app.Application
import com.clerk.api.Clerk
import dagger.hilt.android.HiltAndroidApp
import timber.log.Timber

@HiltAndroidApp
class OneraApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize Timber logging
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        } else {
            // In release, plant a tree that only logs warnings and errors
            Timber.plant(ReleaseTree())
        }
        
        // Initialize Clerk SDK
        Timber.d("Initializing Clerk with key: ${BuildConfig.CLERK_PUBLISHABLE_KEY.take(20)}...")
        Clerk.initialize(this, BuildConfig.CLERK_PUBLISHABLE_KEY)
    }
    
    /**
     * A Timber tree for release builds that only logs warnings and errors.
     */
    private class ReleaseTree : Timber.Tree() {
        override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
            // Only log WARN, ERROR, and ASSERT in release
            if (priority < android.util.Log.WARN) return
            
            // In production, you might want to send these to a crash reporting service
            // For now, we just use the default Android log
            when (priority) {
                android.util.Log.WARN -> android.util.Log.w(tag, message, t)
                android.util.Log.ERROR -> android.util.Log.e(tag, message, t)
                android.util.Log.ASSERT -> android.util.Log.wtf(tag, message, t)
            }
        }
    }
}
