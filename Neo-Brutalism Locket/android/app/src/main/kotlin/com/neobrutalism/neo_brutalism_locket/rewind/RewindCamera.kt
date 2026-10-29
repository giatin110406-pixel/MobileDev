package com.neobrutalism.neo_brutalism_locket.rewind

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraMetadata
import android.media.ExifInterface
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

// The camera behind the rewind screen and, on Android, behind the main camera
// page too: CameraX with a preview that Flutter shows as a texture, a frame
// stream that is kept as JPEGs in a FrameRing, and a full-quality still taken
// at the press. Talks to Dart through RewindPlugin. Every public method is
// called on the main thread.
//
// Two ways of using it. The rewind screen (continuous = false) watches until
// one press, shows the strip, and is done. The main camera (continuous = true)
// never stops watching: each press (shoot) returns the still at once, and the
// frames around it follow about a second later as a "burst" event, while the
// ring starts watching again for the next shot.
class RewindCamera(
    private val context: Context,
    private val textures: TextureRegistry,
    private val owner: LifecycleOwner,
    // Called on the main thread.
    private val emit: (Map<String, Any?>) -> Unit,
) {
    companion object {
        // Side of the square frames kept (and the shorter side asked of the
        // camera). 1080 is what a post is uploaded at; the plan's fallbacks
        // if a phone cannot keep up are 900, then 720.
        const val FRAME_SIDE = 1080
        private const val FRAME_JPEG_QUALITY = 85
        private const val FINALIZE_JPEG_QUALITY = 92

        // How long after the press we wait for the late frames and the
        // full-quality still before showing what there is.
        private const val SETTLE_TIMEOUT_MS = 4000L

        // The late frames of a burst: 1 s is what is asked, so 2 s is already
        // a camera that is not delivering.
        private const val BURST_TIMEOUT_MS = 2000L

        // Shots of the main camera kept on disk (one is on screen at a time).
        private const val SHOTS_KEPT = 3
        private val SHOT_ID = Regex("[0-9a-f-]{36}")
        private const val STATS_WINDOW = 150

        private val activeSessions = HashSet<String>()

        /** Deletes session folders nobody is using (left by a dead process). */
        fun sweepCache(context: Context) {
            val root = File(context.cacheDir, "rewind")
            root.listFiles()?.forEach { dir ->
                if (synchronized(activeSessions) { dir.name !in activeSessions }) {
                    dir.deleteRecursively()
                }
            }
        }

        /** The frame at [path] turned upright and encoded again. */
        fun finalizeFrame(path: String, rotationDegrees: Int): ByteArray {
            val source = BitmapFactory.decodeFile(path)
                ?: throw IllegalStateException("Could not decode frame")
            val upright = if (rotationDegrees % 360 == 0) {
                source
            } else {
                val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
                Bitmap.createBitmap(
                    source, 0, 0, source.width, source.height, matrix, true,
                ).also { source.recycle() }
            }
            return ByteArrayOutputStream().use { out ->
                upright.compress(Bitmap.CompressFormat.JPEG, FINALIZE_JPEG_QUALITY, out)
                upright.recycle()
                out.toByteArray()
            }
        }
    }

    private class Still(val jpeg: ByteArray, val timestampNs: Long, val rotation: Int)

    private val main = Handler(Looper.getMainLooper())
    private val mainExecutor = ContextCompat.getMainExecutor(context)
    private val ring = FrameRing()

    private var provider: ProcessCameraProvider? = null
    private var cameraSelector: CameraSelector? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var analysis: ImageAnalysis? = null
    private var capture: ImageCapture? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var analysisExecutor: ExecutorService? = null
    private var ioExecutor: ExecutorService? = null
    private var stateObserver: Observer<CameraState>? = null
    private var stopped = true

    // The reply to `start` waits for the first preview surface (that is when
    // the real preview size is known).
    private var pendingStart: ((Result<Map<String, Any?>>) -> Unit)? = null
    private var startInfo: Map<String, Any?>? = null

    private var continuous = false
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null
    private var videoFile: File? = null
    private var videoStopReply: ((Result<String>) -> Unit)? = null

    // The shot whose late frames are being collected (continuous mode).
    private var burstShotId: String? = null
    private var burstPressNs = 0L
    private val burstTimeout = Runnable { finishBurst() }

    private var realtimeClock = true
    private var sessionId = ""
    private var pressNs = 0L
    private var still: Still? = null
    private var stillSettled = false
    private var finished = false
    private val settleTimeout = Runnable {
        ring.freeze()
        stillSettled = true
        finishIfReady()
    }

    // Numbers for the debug overlay (guarded by `stats`).
    private val stats = Any()
    private val compressMs = ArrayDeque<Double>()
    private val jpegSizes = ArrayDeque<Int>()
    private val keptAtMs = ArrayDeque<Long>()
    private var analysisSize: Size? = null
    private var previewSize: Size? = null
    private var hqLagMs: Long? = null

    @Suppress("DEPRECATION")
    private val trimCallbacks = object : ComponentCallbacks2 {
        override fun onTrimMemory(level: Int) {
            // Low on memory while only waiting: let the old frames go.
            if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW &&
                ring.state == FrameRing.State.ARMED
            ) {
                ring.reset()
            }
        }

        override fun onConfigurationChanged(newConfig: Configuration) = Unit

        @Suppress("OVERRIDE_DEPRECATION")
        override fun onLowMemory() = Unit
    }

    fun start(
        front: Boolean,
        continuous: Boolean,
        reply: (Result<Map<String, Any?>>) -> Unit,
    ) {
        stop()
        stopped = false
        this.continuous = continuous
        pendingStart = reply
        analysisExecutor = Executors.newSingleThreadExecutor()
        ioExecutor = Executors.newSingleThreadExecutor()
        context.registerComponentCallbacks(trimCallbacks)
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                bind(future.get(), front)
            } catch (e: Exception) {
                fail("cameraBusy", e.message)
            }
        }, mainExecutor)
        // A camera that never answers must not hang the screen.
        main.postDelayed({
            if (pendingStart != null) fail("cameraBusy", "The camera did not start")
        }, SETTLE_TIMEOUT_MS)
    }

    private fun fail(code: String, message: String?) {
        val reply = pendingStart
        pendingStart = null
        if (reply != null) {
            stop()
            reply(Result.failure(IllegalStateException("$code|${message ?: ""}")))
        } else if (!stopped) {
            emit(mapOf("type" to "error", "code" to code, "message" to message))
        }
    }

    private fun resolution(bound: Size?): ResolutionSelector {
        val builder = ResolutionSelector.Builder()
            .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
        builder.setResolutionStrategy(
            if (bound == null) {
                ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY
            } else {
                ResolutionStrategy(
                    bound, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                )
            },
        )
        return builder.build()
    }

    private fun bind(p: ProcessCameraProvider, front: Boolean) {
        if (stopped) return
        val selector = if (front) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        if (!p.hasCamera(selector)) throw IllegalStateException("No such camera")
        provider = p
        cameraSelector = selector
        sessionId = UUID.randomUUID().toString()
        synchronized(activeSessions) { activeSessions.add(sessionId) }

        val frameBound = Size(FRAME_SIDE * 4 / 3, FRAME_SIDE)
        val surfaceProducer = textures.createSurfaceProducer()
        producer = surfaceProducer

        val newPreview = Preview.Builder()
            .setResolutionSelector(resolution(frameBound))
            .setTargetRotation(Surface.ROTATION_0)
            .build()
        newPreview.setSurfaceProvider(mainExecutor) { request ->
            if (stopped) {
                request.willNotProvideSurface()
                return@setSurfaceProvider
            }
            surfaceProducer.setCallback(
                object : TextureRegistry.SurfaceProducer.Callback {
                    override fun onSurfaceAvailable() = Unit

                    // The engine took the surface back (app in the
                    // background): ask CameraX for a new one.
                    override fun onSurfaceCleanup() {
                        if (!stopped) request.invalidate()
                    }
                },
            )
            val size = request.resolution
            surfaceProducer.setSize(size.width, size.height)
            val surface = surfaceProducer.forcedNewSurface
            request.provideSurface(surface, mainExecutor) { surface.release() }
            synchronized(stats) { previewSize = size }
            val reply = pendingStart
            val info = startInfo
            if (reply != null && info != null) {
                pendingStart = null
                reply(
                    Result.success(
                        info + mapOf(
                            "previewWidth" to size.width,
                            "previewHeight" to size.height,
                            "handlesCropAndRotation" to
                                surfaceProducer.handlesCropAndRotation(),
                        ),
                    ),
                )
            }
        }
        preview = newPreview

        val newAnalysis = ImageAnalysis.Builder()
            .setResolutionSelector(resolution(frameBound))
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_NV21)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetRotation(Surface.ROTATION_0)
            .build()
        newAnalysis.setAnalyzer(analysisExecutor!!) { image ->
            try {
                analyze(image)
            } catch (_: Exception) {
                // One bad frame is skipped.
            } finally {
                image.close()
            }
        }
        analysis = newAnalysis

        val newCapture = ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setResolutionSelector(resolution(null))
            .setTargetRotation(Surface.ROTATION_0)
            .build()
        capture = newCapture

        // Never unbindAll(): the camera plugin shares this provider.
        val bound = p.bindToLifecycle(owner, selector, newPreview, newAnalysis, newCapture)
        camera = bound
        realtimeClock = readsRealtimeClock(bound.cameraInfo)
        val zoom = bound.cameraInfo.zoomState.value
        startInfo = mapOf(
            "minZoom" to (zoom?.minZoomRatio ?: 1f).toDouble(),
            "maxZoom" to (zoom?.maxZoomRatio ?: 1f).toDouble(),
            "textureId" to surfaceProducer.id(),
            "sensorOrientation" to bound.cameraInfo.getSensorRotationDegrees(Surface.ROTATION_0),
            "lensFacing" to if (front) "front" else "back",
        )
        val observer = Observer<CameraState> { state ->
            val error = state.error ?: return@Observer
            if (error.code != CameraState.ERROR_OTHER_RECOVERABLE_ERROR) {
                fail("cameraBusy", "Camera error ${error.code}")
            }
        }
        stateObserver = observer
        bound.cameraInfo.cameraState.observe(owner, observer)
    }

    // Frame timestamps come from the sensor's clock, which is either the
    // same as SystemClock.elapsedRealtimeNanos() or an unrelated one.
    @androidx.annotation.OptIn(ExperimentalCamera2Interop::class)
    private fun readsRealtimeClock(info: CameraInfo): Boolean = try {
        Camera2CameraInfo.from(info).getCameraCharacteristic(
            CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE,
        ) == CameraMetadata.SENSOR_INFO_TIMESTAMP_SOURCE_REALTIME
    } catch (_: Exception) {
        true
    }

    private fun nowOnSensorClock(): Long =
        if (realtimeClock) SystemClock.elapsedRealtimeNanos() else System.nanoTime()

    private var nv21: ByteArray? = null

    // Runs on the analysis thread, once per camera frame.
    private fun analyze(image: ImageProxy) {
        val timestamp = image.imageInfo.timestamp
        if (!ring.accepts(timestamp)) return
        val started = System.nanoTime()
        val width = image.width
        val height = image.height
        val buffer = nv21?.takeIf { it.size == width * height * 3 / 2 }
            ?: ByteArray(width * height * 3 / 2).also { nv21 = it }
        fillNv21(image, buffer)
        val side = minOf(width, height)
        // YuvImage wants an even corner for the colour planes.
        val left = ((width - side) / 2) and 1.inv()
        val top = ((height - side) / 2) and 1.inv()
        val out = ByteArrayOutputStream(side * side / 6)
        android.graphics.YuvImage(buffer, ImageFormat.NV21, width, height, null)
            .compressToJpeg(Rect(left, top, left + side, top + side), FRAME_JPEG_QUALITY, out)
        val jpeg = out.toByteArray()
        val tookMs = (System.nanoTime() - started) / 1e6
        if (ring.offer(Frame(timestamp, jpeg, image.imageInfo.rotationDegrees))) {
            synchronized(stats) {
                analysisSize = Size(width, height)
                compressMs.addLast(tookMs)
                jpegSizes.addLast(jpeg.size)
                keptAtMs.addLast(SystemClock.elapsedRealtime())
                while (compressMs.size > STATS_WINDOW) compressMs.removeFirst()
                while (jpegSizes.size > STATS_WINDOW) jpegSizes.removeFirst()
                while (keptAtMs.size > STATS_WINDOW) keptAtMs.removeFirst()
            }
            if (ring.state == FrameRing.State.FROZEN) {
                main.post { if (continuous) finishBurst() else finishIfReady() }
            }
        }
    }

    // CameraX hands NV21 as three planes: Y, then V and U sharing one
    // interleaved buffer. Phones that pad the rows take the slow path.
    private fun fillNv21(image: ImageProxy, out: ByteArray) {
        val width = image.width
        val height = image.height
        val y = image.planes[0]
        val yBuffer = y.buffer
        if (y.rowStride == width) {
            yBuffer.position(0)
            yBuffer.get(out, 0, width * height)
        } else {
            for (row in 0 until height) {
                yBuffer.position(row * y.rowStride)
                yBuffer.get(out, row * width, width)
            }
        }
        val u = image.planes[1]
        val v = image.planes[2]
        val uBuffer = u.buffer
        val vBuffer = v.buffer
        val chromaStart = width * height
        val chromaSize = width * height / 2
        if (v.pixelStride == 2 && u.pixelStride == 2 && v.rowStride == width) {
            val copy = minOf(vBuffer.limit(), chromaSize)
            vBuffer.position(0)
            vBuffer.get(out, chromaStart, copy)
            // The V buffer stops one short of the very last U byte.
            if (copy < chromaSize) out[chromaStart + chromaSize - 1] = uBuffer.get(uBuffer.limit() - 1)
        } else {
            var pos = chromaStart
            for (row in 0 until height / 2) {
                for (col in 0 until width / 2) {
                    out[pos++] = vBuffer.get(row * v.rowStride + col * v.pixelStride)
                    out[pos++] = uBuffer.get(row * u.rowStride + col * u.pixelStride)
                }
            }
        }
    }

    /** The shutter: freeze the frames around now and take the full still. */
    fun shutter() {
        val cap = capture ?: return
        if (stopped || ring.state != FrameRing.State.ARMED) return
        pressNs = nowOnSensorClock()
        ring.press(pressNs)
        still = null
        stillSettled = false
        finished = false
        synchronized(stats) { hqLagMs = null }
        emit(mapOf("type" to "holding"))
        main.postDelayed(settleTimeout, SETTLE_TIMEOUT_MS)
        try {
            cap.takePicture(
                ioExecutor!!,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        try {
                            val buffer = image.planes[0].buffer
                            val bytes = ByteArray(buffer.remaining())
                            buffer.get(bytes)
                            val taken = Still(
                                bytes,
                                image.imageInfo.timestamp,
                                image.imageInfo.rotationDegrees,
                            )
                            main.post {
                                still = taken
                                stillSettled = true
                                synchronized(stats) {
                                    hqLagMs = (taken.timestampNs - pressNs) / 1_000_000
                                }
                                finishIfReady()
                            }
                        } finally {
                            image.close()
                        }
                    }

                    // Cancelled when the camera closes, or the camera failed:
                    // the strip then holds the stream frames only.
                    override fun onError(exception: ImageCaptureException) {
                        main.post {
                            stillSettled = true
                            finishIfReady()
                        }
                    }
                },
            )
        } catch (_: Exception) {
            stillSettled = true
        }
    }

    private fun finishIfReady() {
        if (stopped || finished) return
        if (ring.state != FrameRing.State.FROZEN || !stillSettled) return
        finished = true
        main.removeCallbacks(settleTimeout)
        val frames = ring.snapshot()
        ring.release()
        val taken = still
        val press = pressNs
        val session = sessionId
        val executor = ioExecutor ?: return
        // Frames go to disk so Dart reads them one at a time and the ring's
        // memory is free again at once.
        executor.execute {
            try {
                val dir = File(context.cacheDir, "rewind/$session").apply { mkdirs() }
                val frameList = frames.mapIndexed { index, frame ->
                    val file = File(dir, "f_$index.jpg")
                    file.writeBytes(frame.jpeg)
                    mapOf(
                        "path" to file.path,
                        "offsetMs" to Math.round((frame.timestampNs - press) / 1e6),
                        "rotation" to frame.rotationDegrees,
                    )
                }
                val hq = taken?.let {
                    val file = File(dir, "hq.jpg")
                    file.writeBytes(it.jpeg)
                    writeOrientation(file, it.rotation)
                    mapOf(
                        "path" to file.path,
                        "offsetMs" to Math.round((it.timestampNs - press) / 1e6),
                    )
                }
                main.post {
                    if (stopped) return@post
                    emit(mapOf("type" to "frozen", "frames" to frameList, "hq" to hq))
                    // Nothing more to watch: save the battery.
                    analysis?.let { provider?.unbind(it) }
                }
            } catch (e: Exception) {
                main.post { emit(mapOf("type" to "error", "code" to "writeFailed", "message" to e.message)) }
            }
        }
    }

    // The still's JPEG has no usable orientation; give it the turn CameraX
    // reported so the square crop (which reads EXIF) stands it upright.
    private fun writeOrientation(file: File, rotationDegrees: Int) {
        val value = when ((rotationDegrees % 360 + 360) % 360) {
            90 -> ExifInterface.ORIENTATION_ROTATE_90
            180 -> ExifInterface.ORIENTATION_ROTATE_180
            270 -> ExifInterface.ORIENTATION_ROTATE_270
            else -> ExifInterface.ORIENTATION_NORMAL
        }
        val exif = ExifInterface(file.path)
        exif.setAttribute(ExifInterface.TAG_ORIENTATION, value.toString())
        exif.saveAttributes()
    }

    /**
     * Continuous mode: the shutter. Replies with the full-quality still as soon
     * as it is on disk; the frames around the press follow as a "burst" event
     * and the ring is watching again after that. A press while the previous
     * burst is still being collected (or while recording) gets the still only.
     */
    fun shoot(reply: (Result<Map<String, Any?>>) -> Unit) {
        val cap = capture
        val executor = ioExecutor
        if (cap == null || executor == null || stopped) {
            reply(Result.failure(IllegalStateException("cameraBusy|The camera is not running")))
            return
        }
        val shotId = UUID.randomUUID().toString()
        val dir = File(context.cacheDir, "rewind/$sessionId/$shotId").apply { mkdirs() }
        val withBurst = ring.state == FrameRing.State.ARMED && recording == null
        if (withBurst) {
            burstShotId = shotId
            burstPressNs = nowOnSensorClock()
            ring.press(burstPressNs)
            main.postDelayed(burstTimeout, BURST_TIMEOUT_MS)
        }
        fun giveUp(message: String?) {
            if (withBurst && burstShotId == shotId) {
                burstShotId = null
                main.removeCallbacks(burstTimeout)
                ring.reset()
            }
            dir.deleteRecursively()
            reply(Result.failure(IllegalStateException("captureFailed|${message ?: ""}")))
        }
        try {
            cap.takePicture(
                executor,
                object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        try {
                            val buffer = image.planes[0].buffer
                            val bytes = ByteArray(buffer.remaining())
                            buffer.get(bytes)
                            val file = File(dir, "hq.jpg")
                            file.writeBytes(bytes)
                            writeOrientation(file, image.imageInfo.rotationDegrees)
                            main.post {
                                reply(
                                    Result.success(
                                        mapOf(
                                            "shotId" to shotId,
                                            "path" to file.path,
                                            "burst" to withBurst,
                                        ),
                                    ),
                                )
                            }
                        } catch (e: Exception) {
                            main.post { giveUp(e.message) }
                        } finally {
                            image.close()
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        main.post { giveUp(exception.message) }
                    }
                },
            )
        } catch (e: Exception) {
            giveUp(e.message)
        }
    }

    // The late frames are in (or the camera did not deliver them): write what
    // the ring holds next to the still and tell Dart, then watch again.
    private fun finishBurst() {
        val shotId = burstShotId ?: return
        if (stopped) return
        burstShotId = null
        main.removeCallbacks(burstTimeout)
        ring.freeze()
        val frames = ring.snapshot()
        val press = burstPressNs
        ring.reset()
        val executor = ioExecutor ?: return
        val session = sessionId
        executor.execute {
            try {
                val dir = File(context.cacheDir, "rewind/$session/$shotId").apply { mkdirs() }
                val list = frames.mapIndexed { index, frame ->
                    val file = File(dir, "f_$index.jpg")
                    file.writeBytes(frame.jpeg)
                    mapOf(
                        "path" to file.path,
                        "offsetMs" to Math.round((frame.timestampNs - press) / 1e6),
                        "rotation" to frame.rotationDegrees,
                    )
                }
                main.post {
                    if (stopped) return@post
                    emit(mapOf("type" to "burst", "shotId" to shotId, "frames" to list))
                    trimShots(session)
                }
            } catch (e: Exception) {
                // No frames for this shot: the still alone is still a photo.
            }
        }
    }

    // Old shots go; the newest few stay (the page on screen uses one).
    private fun trimShots(session: String) {
        val shots = File(context.cacheDir, "rewind/$session").listFiles { f -> f.isDirectory }
            ?: return
        shots.sortedByDescending { it.lastModified() }.drop(SHOTS_KEPT).forEach {
            it.deleteRecursively()
        }
    }

    /** The shot's folder is not needed any more (posted, dropped or replaced). */
    fun releaseShot(shotId: String) {
        if (!SHOT_ID.matches(shotId) || sessionId.isEmpty()) return
        File(context.cacheDir, "rewind/$sessionId/$shotId").deleteRecursively()
    }

    /** One of off, auto or on. */
    fun setFlash(mode: String) {
        capture?.flashMode = when (mode) {
            "auto" -> ImageCapture.FLASH_MODE_AUTO
            "on" -> ImageCapture.FLASH_MODE_ON
            else -> ImageCapture.FLASH_MODE_OFF
        }
    }

    fun setZoom(ratio: Float) {
        camera?.cameraControl?.setZoomRatio(ratio)
    }

    /**
     * Starts recording a clip (no sound, like the camera plugin was set up).
     * The frame stream rests meanwhile: three use cases are the most a phone
     * is promised to run together.
     */
    fun startVideo(reply: (Result<Unit>) -> Unit) {
        val p = provider
        val selector = cameraSelector
        if (p == null || selector == null || stopped || recording != null) {
            reply(Result.failure(IllegalStateException("cameraBusy|Cannot record now")))
            return
        }
        burstShotId = null
        main.removeCallbacks(burstTimeout)
        ring.reset()
        analysis?.let { if (p.isBound(it)) p.unbind(it) }
        val recorder = Recorder.Builder()
            .setQualitySelector(
                QualitySelector.from(
                    Quality.FHD,
                    FallbackStrategy.lowerQualityOrHigherThan(Quality.FHD),
                ),
            )
            .build()
        val video = VideoCapture.withOutput(recorder).also { it.targetRotation = Surface.ROTATION_0 }
        try {
            p.bindToLifecycle(owner, selector, video)
        } catch (e: Exception) {
            // A phone that cannot run preview, still and video together:
            // the still rests too while recording.
            try {
                capture?.let { p.unbind(it) }
                p.bindToLifecycle(owner, selector, video)
            } catch (e2: Exception) {
                resumeWatching()
                reply(Result.failure(IllegalStateException("cameraBusy|${e2.message ?: ""}")))
                return
            }
        }
        videoCapture = video
        val file = File(context.cacheDir, "rewind/video_${UUID.randomUUID()}.mp4")
            .also { it.parentFile?.mkdirs() }
        videoFile = file
        var replied = false
        recording = recorder
            .prepareRecording(context, FileOutputOptions.Builder(file).build())
            .start(mainExecutor) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> if (!replied) {
                        replied = true
                        reply(Result.success(Unit))
                    }
                    is VideoRecordEvent.Finalize -> {
                        recording = null
                        val stopReply = videoStopReply
                        videoStopReply = null
                        if (!replied) {
                            replied = true
                            reply(Result.failure(IllegalStateException("cameraBusy|Recording did not start")))
                        }
                        videoCapture?.let { v -> provider?.unbind(v) }
                        videoCapture = null
                        resumeWatching()
                        stopReply?.invoke(
                            if (event.hasError() && !file.exists()) {
                                Result.failure(IllegalStateException("videoFailed|${event.error}"))
                            } else {
                                Result.success(file.path)
                            },
                        )
                    }
                    else -> Unit
                }
            }
    }

    /** Stops the clip; replies with the MP4's path once it is written. */
    fun stopVideo(reply: (Result<String>) -> Unit) {
        val active = recording
        if (active == null) {
            reply(Result.failure(IllegalStateException("videoFailed|Not recording")))
            return
        }
        videoStopReply = reply
        active.stop()
    }

    // The still and the frame stream come back after a clip.
    private fun resumeWatching() {
        val p = provider ?: return
        val selector = cameraSelector ?: return
        if (stopped) return
        val back = listOfNotNull(capture, analysis).filter { !p.isBound(it) }
        if (back.isEmpty()) return
        try {
            p.bindToLifecycle(owner, selector, *back.toTypedArray())
        } catch (e: Exception) {
            emit(mapOf("type" to "error", "code" to "cameraBusy", "message" to e.message))
        }
    }

    /** Shoot again: drop the held frames and start watching afresh. */
    fun rearm() {
        if (stopped) return
        main.removeCallbacks(settleTimeout)
        File(context.cacheDir, "rewind/$sessionId").deleteRecursively()
        ring.reset()
        still = null
        stillSettled = false
        finished = false
        val a = analysis
        val p = provider
        val selector = cameraSelector
        if (a != null && p != null && selector != null && !p.isBound(a)) {
            try {
                p.bindToLifecycle(owner, selector, a)
            } catch (e: Exception) {
                emit(mapOf("type" to "error", "code" to "cameraBusy", "message" to e.message))
            }
        }
    }

    /** The numbers behind the debug overlay. */
    fun statsMap(): Map<String, Any?> = synchronized(stats) {
        val sorted = compressMs.sorted()
        fun percentile(p: Double): Double =
            if (sorted.isEmpty()) 0.0 else sorted[((sorted.size - 1) * p).toInt()]
        val now = SystemClock.elapsedRealtime()
        val lastSecond = keptAtMs.count { now - it <= 2000 } / 2.0
        mapOf(
            "keptPerSecond" to lastSecond,
            "compressP50Ms" to percentile(0.5),
            "compressP95Ms" to percentile(0.95),
            "avgJpegKb" to if (jpegSizes.isEmpty()) 0.0 else jpegSizes.average() / 1024,
            "ringBytes" to ring.totalBytes,
            "ringFrames" to ring.size,
            "dropped" to ring.dropped,
            "nativeHeapMb" to Debug.getNativeHeapAllocatedSize() / (1024.0 * 1024.0),
            "analysisWidth" to analysisSize?.width,
            "analysisHeight" to analysisSize?.height,
            "previewWidth" to previewSize?.width,
            "previewHeight" to previewSize?.height,
            "frameSide" to FRAME_SIDE,
            "hqLagMs" to hqLagMs,
        )
    }

    /** Lets everything go: only our own use cases are unbound. */
    fun stop() {
        if (stopped && provider == null) return
        stopped = true
        main.removeCallbacksAndMessages(null)
        pendingStart = null
        startInfo = null
        runCatching { context.unregisterComponentCallbacks(trimCallbacks) }
        stateObserver?.let { camera?.cameraInfo?.cameraState?.removeObserver(it) }
        stateObserver = null
        analysis?.clearAnalyzer()
        recording?.let { runCatching { it.stop() } }
        recording = null
        videoStopReply = null
        burstShotId = null
        val used = listOfNotNull(preview, analysis, capture, videoCapture)
        if (used.isNotEmpty()) provider?.unbind(*used.toTypedArray())
        preview = null
        analysis = null
        capture = null
        videoCapture = null
        camera = null
        provider = null
        producer?.release()
        producer = null
        analysisExecutor?.shutdown()
        analysisExecutor = null
        ioExecutor?.shutdown()
        ioExecutor = null
        ring.reset()
        still = null
        nv21 = null
        if (sessionId.isNotEmpty()) {
            File(context.cacheDir, "rewind/$sessionId").deleteRecursively()
            synchronized(activeSessions) { activeSessions.remove(sessionId) }
            sessionId = ""
        }
        synchronized(stats) {
            compressMs.clear()
            jpegSizes.clear()
            keptAtMs.clear()
        }
    }
}
