package com.neobrutalism.neo_brutalism_locket.holdframe

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.camera.core.ImageProxy
import org.opencv.android.OpenCVLoader
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Copies only 320x320 luma samples; ORB runs apart from both UI and rewind JPEG encoding. */
class HoldFrameTracker(private val emit: (Map<String, Any?>) -> Unit) : AutoCloseable {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private val generation = AtomicInteger(0)
    private val gate = AlignmentGate()
    @Volatile private var watching = false
    @Volatile private var closed = false
    private var lastSample = 0L // camera analysis thread only
    private var aligner: FrameAligner? = null // worker only
    private var pending: ((Result<Map<String, Any?>>) -> Unit)? = null // main only

    fun lock(reply: (Result<Map<String, Any?>>) -> Unit) {
        if (closed) {
            reply(Result.failure(IllegalStateException("cameraBusy|Camera stopped")))
            return
        }
        unlock()
        val id = generation.get()
        pending = reply
        watching = true
        main.postDelayed({
            if (id == generation.get() && pending != null) {
                val callback = pending
                pending = null
                unlock()
                callback?.invoke(Result.failure(IllegalStateException("holdNoFrame|No camera frame")))
            }
        }, 2500)
    }

    fun unlock() {
        watching = false
        generation.incrementAndGet()
        val callback = pending
        pending = null
        callback?.invoke(Result.failure(IllegalStateException("holdCancelled|Lock cancelled")))
        if (!closed) worker.execute {
            gate.arm(false)
            aligner?.close()
            aligner = null
        }
    }

    fun arm(on: Boolean) {
        if (closed) return
        worker.execute { gate.arm(on) }
    }

    fun offer(image: ImageProxy) {
        if (!watching || closed) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastSample < 90 || !busy.compareAndSet(false, true)) return
        lastSample = now
        val id = generation.get()
        // An ImageProxy is never retained after this call. Respect row/pixel stride and cropRect.
        val pixels: ByteArray
        try {
            val rect = image.cropRect
            val side = minOf(rect.width(), rect.height())
            val left = rect.left + (rect.width() - side) / 2
            val top = rect.top + (rect.height() - side) / 2
            val plane = image.planes[0]
            val buffer = plane.buffer.duplicate()
            val offset = buffer.position()
            pixels = ByteArray(320 * 320)
            for (y in 0 until 320) {
                val row = offset + (top + y * side / 320) * plane.rowStride
                for (x in 0 until 320) {
                    pixels[y * 320 + x] = buffer.get(row + (left + x * side / 320) * plane.pixelStride)
                }
            }
        } catch (_: Exception) {
            busy.set(false)
            return
        }
        val rotation = image.imageInfo.rotationDegrees
        worker.execute {
            try {
                if (closed || id != generation.get()) return@execute
                if (aligner == null && !OpenCVLoader.initLocal()) {
                    throw IllegalStateException("holdUnavailable|OpenCV unavailable")
                }
                val gray = Mat(320, 320, CvType.CV_8UC1)
                try {
                    gray.put(0, 0, pixels)
                    when (rotation) {
                        90 -> Core.rotate(gray, gray, Core.ROTATE_90_CLOCKWISE)
                        180 -> Core.rotate(gray, gray, Core.ROTATE_180)
                        270 -> Core.rotate(gray, gray, Core.ROTATE_90_COUNTERCLOCKWISE)
                    }
                    if (aligner == null) {
                        val next = FrameAligner()
                        aligner = next
                        if (!next.lock(gray)) throw IllegalStateException("holdFewFeatures|Not enough scene details")
                        val jpg = MatOfByte()
                        val params = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 85)
                        val bytes = try {
                            check(Imgcodecs.imencode(".jpg", gray, jpg, params))
                            jpg.toArray()
                        } finally { jpg.release(); params.release() }
                        main.post {
                            if (!closed && id == generation.get()) {
                                val callback = pending
                                pending = null
                                callback?.invoke(Result.success(mapOf("image" to bytes, "lockId" to id)))
                            }
                        }
                    } else {
                        val alignment = aligner!!.estimate(gray)
                        val ready = gate.offer(alignment.aligned, now)
                        val event = alignment.toMap() + mapOf(
                            "type" to "alignment", "lockId" to id, "ready" to ready,
                            "timestampMs" to now,
                        )
                        main.post {
                            // Never act on a stale result that waited behind a busy main thread.
                            if (!closed && id == generation.get() &&
                                SystemClock.elapsedRealtime() - now <= 250) emit(event)
                        }
                    }
                } finally { gray.release() }
            } catch (e: Exception) {
                fail(id, e.message ?: "holdUnavailable|Alignment failed")
            } catch (_: LinkageError) {
                fail(id, "holdUnavailable|OpenCV could not load on this device")
            } finally { busy.set(false) }
        }
    }

    private fun fail(id: Int, message: String) {
        main.post {
            if (closed || id != generation.get()) return@post
            val callback = pending
            pending = null
            unlock()
            if (callback != null) callback(Result.failure(IllegalStateException(message)))
            else emit(mapOf("type" to "error", "code" to "holdUnavailable"))
        }
    }

    override fun close() {
        if (closed) return
        unlock()
        closed = true
        main.removeCallbacksAndMessages(null)
        worker.shutdown()
    }
}
