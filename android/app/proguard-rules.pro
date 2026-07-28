# ProGuard Rules for MixVy (Flutter, Firebase, WebRTC, Agora)

# Flutter & Dart core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase SDKs
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.firebase** { *; }
-dontwarn com.google.firebase.**

# Flutter WebRTC (and Native WebRTC)
-keep class com.oney.WebRTCModule.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-dontwarn com.oney.WebRTCModule.**

# Agora RTC Engine SDK
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Play Core deferred components/integrity optional classes referenced by
# transitive libraries and Flutter embedding; silence missing optional APIs.
-dontwarn com.google.android.play.core.common.PlayCoreDialogWrapperActivity
-dontwarn com.google.android.play.core.listener.StateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# General reflection & serialization safety
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions
-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn sun.misc.Unsafe
