package com.neobrutalism.neo_brutalism_locket.rewind

import android.Manifest
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.Executors

// Joins the rewind screen's Dart side to RewindCamera: the method channel for
// commands, the event channel for what comes back after the shutter. Added to
// the engine of both MainActivity and the lock-screen activity.
class RewindPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL = "com.neobrutalism.neo_brutalism_locket/rewind"
        const val EVENT_CHANNEL = "com.neobrutalism.neo_brutalism_locket/rewind_events"
        private val worker = Executors.newSingleThreadExecutor()
    }

    private val main = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var textures: TextureRegistry? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var camera: RewindCamera? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val appContext = binding.applicationContext
        context = appContext
        textures = binding.textureRegistry
        methods = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        events = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
        // Folders a dead process left behind.
        worker.execute { RewindCamera.sweepCache(appContext) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        camera?.stop()
        camera = null
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        context = null
        textures = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() = Unit

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        camera?.stop()
        camera = null
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // Asks the person to unlock (PIN, fingerprint...); true once the keyguard
    // is gone. No screen lock set: it is true at once.
    private fun dismissKeyguard(result: MethodChannel.Result) {
        val host = activity
        val keyguard = host?.getSystemService(KeyguardManager::class.java)
        if (host == null || keyguard == null) {
            result.success(false)
            return
        }
        if (!keyguard.isKeyguardLocked) {
            result.success(true)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguard.requestDismissKeyguard(
                host,
                object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() = result.success(true)

                    override fun onDismissCancelled() = result.success(false)

                    override fun onDismissError() = result.success(false)
                },
            )
        } else {
            // Android 7: the window flag asks for the unlock by itself, and
            // the main app opens behind it.
            @Suppress("DEPRECATION")
            host.window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            result.success(true)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val host = activity as? LifecycleOwner
                val appContext = context
                val registry = textures
                if (host == null || appContext == null || registry == null) {
                    result.error("cameraBusy", "No screen to show the camera on", null)
                    return
                }
                // The lock-screen screen never asks for the permission.
                if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    result.error("noPermission", "Camera access is off", null)
                    return
                }
                val next = camera?.also { it.stop() } ?: RewindCamera(
                    appContext, registry, host,
                ) { event -> sink?.success(event) }.also { camera = it }
                next.start(call.argument<String>("lens") == "front") { outcome ->
                    outcome.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { error ->
                            val parts = (error.message ?: "").split('|', limit = 2)
                            result.error(parts[0].ifEmpty { "cameraBusy" }, parts.getOrNull(1), null)
                        },
                    )
                }
            }
            "shutter" -> {
                camera?.shutter()
                result.success(null)
            }
            "rearm" -> {
                camera?.rearm()
                result.success(null)
            }
            "stats" -> result.success(camera?.statsMap() ?: emptyMap<String, Any?>())
            "finalizeFrame" -> {
                val path = call.argument<String>("path")
                val rotation = call.argument<Number>("rotation")?.toInt() ?: 0
                if (path == null) {
                    result.error("badArgs", "path is required", null)
                    return
                }
                worker.execute {
                    try {
                        val bytes = RewindCamera.finalizeFrame(path, rotation)
                        main.post { result.success(bytes) }
                    } catch (e: Exception) {
                        main.post { result.error("finalizeFailed", e.message, null) }
                    }
                }
            }
            "stop" -> {
                camera?.stop()
                result.success(null)
            }
            "dismissKeyguard" -> dismissKeyguard(result)
            "handoff" -> {
                val lockscreen = activity as? RewindLockscreenActivity
                if (lockscreen == null) {
                    result.error("notLockscreen", "Only the lock-screen screen hands over", null)
                } else {
                    lockscreen.handOff(call.argument<ByteArray>("bytes"))
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
