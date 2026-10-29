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
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
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
        private const val REQUEST_CAMERA = 7301
    }

    private val main = Handler(Looper.getMainLooper())
    private var context: Context? = null
    private var textures: TextureRegistry? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var camera: RewindCamera? = null
    private var permissionBinding: ActivityPluginBinding? = null

    // What waits for the answer to the camera permission prompt.
    private var afterPermission: ((Boolean) -> Unit)? = null
    private val permissionListener =
        PluginRegistry.RequestPermissionsResultListener { code, _, results ->
            if (code != REQUEST_CAMERA) return@RequestPermissionsResultListener false
            val granted = results.isNotEmpty() && results[0] == PackageManager.PERMISSION_GRANTED
            val next = afterPermission
            afterPermission = null
            next?.invoke(granted)
            true
        }

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
        permissionBinding = binding.also { it.addRequestPermissionsResultListener(permissionListener) }
    }

    override fun onDetachedFromActivityForConfigChanges() = Unit

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        permissionBinding = binding.also { it.addRequestPermissionsResultListener(permissionListener) }
    }

    override fun onDetachedFromActivity() {
        camera?.stop()
        camera = null
        activity = null
        permissionBinding?.removeRequestPermissionsResultListener(permissionListener)
        permissionBinding = null
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

    // Hands a RewindCamera outcome to Dart; a failure's message is
    // "code|detail".
    private fun <T> Result<T>.reply(result: MethodChannel.Result) = fold(
        onSuccess = { result.success(it) },
        onFailure = { error ->
            val parts = (error.message ?: "").split('|', limit = 2)
            result.error(parts[0].ifEmpty { "cameraBusy" }, parts.getOrNull(1), null)
        },
    )

    // The lock-screen screen never asks for the camera permission (it only
    // reports it); the main camera passes askPermission and the prompt shows.
    private fun startCamera(call: MethodCall, result: MethodChannel.Result) {
        val host = activity as? LifecycleOwner
        val appContext = context
        val registry = textures
        if (host == null || appContext == null || registry == null) {
            result.error("cameraBusy", "No screen to show the camera on", null)
            return
        }
        if (ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            val screen = activity
            if (call.argument<Boolean>("askPermission") == true && screen != null) {
                afterPermission = { granted ->
                    if (granted) {
                        startCamera(call, result)
                    } else {
                        result.error("noPermission", "Camera access is off", null)
                    }
                }
                ActivityCompat.requestPermissions(
                    screen, arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA,
                )
            } else {
                result.error("noPermission", "Camera access is off", null)
            }
            return
        }
        val next = camera?.also { it.stop() } ?: RewindCamera(
            appContext, registry, host,
        ) { event -> sink?.success(event) }.also { camera = it }
        next.start(
            call.argument<String>("lens") == "front",
            call.argument<Boolean>("continuous") == true,
            keepFrames = call.argument<Boolean>("keepFrames") != false,
        ) { outcome -> outcome.reply(result) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lockFrame" -> {
                val active = camera
                if (active == null) result.error("cameraBusy", "Camera stopped", null)
                else active.lockFrame { outcome -> outcome.reply(result) }
            }
            "unlockFrame" -> { camera?.unlockFrame(); result.success(null) }
            "armHoldFrame" -> {
                camera?.armHoldFrame(call.argument<Boolean>("on") == true)
                result.success(null)
            }
            "start" -> startCamera(call, result)
            // The main camera page (continuous mode).
            "shoot" -> {
                val active = camera
                if (active == null) {
                    result.error("cameraBusy", "The camera is not running", null)
                    return
                }
                active.shoot { outcome -> outcome.reply(result) }
            }
            "setFlash" -> {
                camera?.setFlash(call.argument<String>("mode") ?: "off")
                result.success(null)
            }
            "setZoom" -> {
                camera?.setZoom((call.argument<Number>("ratio") ?: 1.0).toFloat())
                result.success(null)
            }
            "setScanning" -> {
                camera?.scanCodes = call.argument<Boolean>("on") == true
                result.success(null)
            }
            "startVideo" -> {
                val active = camera
                if (active == null) {
                    result.error("cameraBusy", "The camera is not running", null)
                    return
                }
                active.startVideo { outcome -> outcome.map { null }.reply(result) }
            }
            "stopVideo" -> {
                val active = camera
                if (active == null) {
                    result.error("videoFailed", "The camera is not running", null)
                    return
                }
                active.stopVideo { outcome -> outcome.reply(result) }
            }
            "releaseShot" -> {
                call.argument<String>("shotId")?.let { camera?.releaseShot(it) }
                result.success(null)
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
