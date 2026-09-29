# Flutter Engine & Play Core Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# audio_service / just_audio_background / just_audio
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-dontwarn com.ryanheise.audioservice.**
-dontwarn com.ryanheise.just_audio.**
-dontwarn com.ryanheise.just_audio_background.**

# ExoPlayer / Media3
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# Media session & notification
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.app.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.media.session.** { *; }

# flutter_background_service
-keep class id.flutter.flutter_background_service.** { *; }
-dontwarn id.flutter.flutter_background_service.**

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# SQLite / Drift
-dontwarn org.sqlite.**
-keep class net.sqlcipher.** { *; }
-keep class com.github.wenzewoo.** { *; }

# on_audio_query
-keep class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.lucasjosino.on_audio_query.**

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# receive_sharing_intent
-keep class com.kasem.sharing.** { *; }
-dontwarn com.kasem.sharing.**

# DES Encryption (dart_des / JioSaavn URL decryption)
# Dart's dart:convert and crypto run in Dart VM, but native interop must be kept
-keep class javax.crypto.** { *; }
-keep class javax.crypto.spec.** { *; }
-dontwarn javax.crypto.**

# OkHttp / Dio networking (critical: R8 strips these in aggressive mode)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okio.**

# Gson (used by some Flutter plugins)
-keepattributes Signature
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
