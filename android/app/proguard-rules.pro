## Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

## Keep Play Core (Flutter deferred components / split install)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

## flutter_secure_storage
-keep class androidx.security.crypto.** { *; }

## sqflite
-keep class com.tekartik.** { *; }

## Syncfusion PDF Viewer
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

## just_audio / ExoMedia
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

## ML Kit (face detection — in-app Face Unlock)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-dontwarn com.google.mlkit.**

## Generic — keep annotations & native methods
-keepattributes *Annotation*
-keepclasseswithmembernames class * { native <methods>; }
