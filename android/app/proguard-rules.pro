# --- Razorpay SDK ProGuard Rules ---

# Prevent warnings related to Razorpay classes
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }

# Keep Razorpay payment methods to prevent obfuscation
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# Preserve WebView JavaScript methods (Razorpay uses WebView for some flows)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Disable method inlining optimization to avoid breaking Razorpay logic
-optimizations !method/inlining/*

# Keep attributes related to JavaScript and annotations (for WebView and other annotations)
-keepattributes JavascriptInterface
-keepattributes Annotation