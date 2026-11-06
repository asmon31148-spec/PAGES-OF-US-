# Flutter Rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-dontwarn io.flutter.**

# AndroidX & Multidex
-keep class androidx.multidex.** { *; }
-dontwarn androidx.**

# Keep generic signatures and annotations
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Firebase Core & Messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# WebRTC & Media
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Audio Service & Audio Players
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Home Widget
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# Image Picker & File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**
