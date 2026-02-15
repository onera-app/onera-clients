# ===== Onera ProGuard Rules =====

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ===== Kotlin Serialization =====
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep @Serializable classes
-keep,includedescriptorclasses class chat.onera.mobile.**$$serializer { *; }
-keepclassmembers class chat.onera.mobile.** {
    *** Companion;
}
-keepclasseswithmembers class chat.onera.mobile.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ===== Retrofit + OkHttp =====
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-dontwarn org.codehaus.mojo.animal_sniffer.*

# ===== Clerk SDK =====
-keep class com.clerk.api.** { *; }
-dontwarn com.clerk.api.**

# ===== Lazysodium (libsodium) =====
-keep class com.goterl.lazysodium.** { *; }
-keep class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**

# ===== Credential Manager (Passkeys) =====
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.** { *; }

# ===== Room =====
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# ===== Hilt =====
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper { *; }

# ===== Compose =====
-dontwarn androidx.compose.**

# ===== Coil =====
-dontwarn coil.**

# ===== Data classes used in tRPC =====
-keep class chat.onera.mobile.data.remote.dto.** { *; }
-keep class chat.onera.mobile.data.remote.trpc.** { *; }
-keep class chat.onera.mobile.domain.model.** { *; }
