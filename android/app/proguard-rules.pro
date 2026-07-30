# Flutter Engine & Play Core Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# audio_service & just_audio_background & just_audio
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }

# Keep media session / media browser service classes (critical for notifications)
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.app.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.media.session.** { *; }

-dontwarn com.ryanheise.audioservice.**
-dontwarn com.ryanheise.just_audio.**
-dontwarn com.ryanheise.just_audio_background.**

# SQLite & Drift
-dontwarn org.sqlite.**
-keep class net.sqlcipher.** { *; }

# on_audio_query
-keep class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.lucasjosino.on_audio_query.**
