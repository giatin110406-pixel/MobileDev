# flutter_onnxruntime (quest photo check) loads ONNX Runtime classes by name
-keep class ai.onnxruntime.** { *; }
# google_mlkit_text_recognition (check before posting) only ships the Latin
# model; the other scripts are optional classes the plugin refers to.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
