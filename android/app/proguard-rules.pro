# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# SoLoud
-keep class com.gabriel.pu.** { *; }

# Google Play Core (ignore missing classes)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
