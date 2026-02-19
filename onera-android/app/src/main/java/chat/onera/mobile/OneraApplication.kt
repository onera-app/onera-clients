package chat.onera.mobile

import android.app.Application
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
        
        // Supabase client is initialized via Hilt (SupabaseModule)
        Timber.d("Supabase URL: ${BuildConfig.SUPABASE_URL}")
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
