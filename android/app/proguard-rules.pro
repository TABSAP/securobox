-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

-keep class androidx.security.crypto.** { *; }

-keep class com.tekartik.** { *; }

-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-dontwarn com.google.mlkit.**

-keepattributes *Annotation*
-keepclasseswithmembernames class * { native <methods>; }
