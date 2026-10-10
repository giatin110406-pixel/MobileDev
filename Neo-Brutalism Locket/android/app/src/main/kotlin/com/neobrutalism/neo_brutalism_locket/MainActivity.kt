package com.neobrutalism.neo_brutalism_locket

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.neobrutalism.neo_brutalism_locket/haptics",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // What the phone says about vibration.
                "status" -> {
                    val vibrator = vibrator()
                    result.success(
                        mapOf(
                            "hasVibrator" to (vibrator?.hasVibrator() == true),
                            "hasAmplitudeControl" to (
                                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                    vibrator?.hasAmplitudeControl() == true
                                ),
                            // The "touch vibration" switch in the phone's
                            // settings: when it is off every system haptic
                            // (View.performHapticFeedback) stays silent.
                            "touchFeedbackOn" to (
                                Settings.System.getInt(
                                    contentResolver,
                                    Settings.System.HAPTIC_FEEDBACK_ENABLED,
                                    1,
                                ) == 1
                                ),
                            "sdk" to Build.VERSION.SDK_INT,
                        ),
                    )
                }
                // Runs the motor for [ms] at [amplitude] (1-255), directly.
                "buzz" -> {
                    val vibrator = vibrator()
                    if (vibrator == null || !vibrator.hasVibrator()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val ms = (call.argument<Number>("ms") ?: 20).toLong()
                    val amplitude = (call.argument<Number>("amplitude") ?: 150).toInt()
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val strength = if (vibrator.hasAmplitudeControl()) {
                                amplitude.coerceIn(1, 255)
                            } else {
                                VibrationEffect.DEFAULT_AMPLITUDE
                            }
                            vibrator.vibrate(VibrationEffect.createOneShot(ms, strength))
                        } else {
                            @Suppress("DEPRECATION")
                            vibrator.vibrate(ms)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
}
