package com.neobrutalism.neo_brutalism_locket.addme

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.MatOfByte
import org.opencv.core.MatOfInt
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.util.concurrent.Executors
import kotlin.math.max

/** The "add me" channel: merge(first, second) with two JPEGs of the same frame. */
object AddMe {
    /** Photos are merged at most this big (posts are 1080 wide). */
    private const val MAX_SIDE = 1600

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** ML Kit's selfie segmenter (bundled with the app, works offline); made on first use. */
    private val segmenter by lazy {
        Segmentation.getClient(
            SelfieSegmenterOptions.Builder()
                .setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE)
                .build(),
        )
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "com.neobrutalism.neo_brutalism_locket/add_me")
            .setMethodCallHandler { call, result ->
                if (call.method != "merge") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val first = call.argument<ByteArray>("first")
                val second = call.argument<ByteArray>("second")
                if (first == null || second == null) {
                    result.error("badArgs", "first and second JPEG bytes are needed", null)
                    return@setMethodCallHandler
                }
                worker.execute {
                    val reply = try {
                        Result.success(merge(first, second))
                    } catch (e: Throwable) {
                        Result.failure(e)
                    }
                    main.post {
                        reply.fold(
                            { result.success(it) },
                            { result.error("addMeFailed", it.message, null) },
                        )
                    }
                }
            }
    }

    /** Runs on the worker. */
    fun merge(first: ByteArray, second: ByteArray): Map<String, Any?> {
        check(OpenCVLoader.initLocal()) { "OpenCV could not load on this device" }
        val shot1 = decode(first)
        val shot2 = decode(second)
        try {
            val out = AddMeMerger(::people).merge(shot1, shot2)
            val image = out.image?.let { mat ->
                val buf = MatOfByte()
                val params = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 92)
                try {
                    check(Imgcodecs.imencode(".jpg", mat, buf, params))
                    buf.toArray()
                } finally { buf.release(); params.release(); mat.release() }
            }
            return mapOf(
                "ok" to out.ok,
                "reason" to out.reason,
                "image" to image,
                "info" to out.info.mapValues { (_, v) -> if (v is Number) v.toDouble() else v?.toString() },
            )
        } finally { shot1.release(); shot2.release() }
    }

    /** The chance of a person at each pixel of a BGR image, row-major. Runs on the worker. */
    fun people(bgr: Mat): FloatArray {
        val rgba = Mat()
        Imgproc.cvtColor(bgr, rgba, Imgproc.COLOR_BGR2RGBA)
        val bitmap = Bitmap.createBitmap(bgr.cols(), bgr.rows(), Bitmap.Config.ARGB_8888)
        try {
            Utils.matToBitmap(rgba, bitmap)
            val mask = Tasks.await(segmenter.process(InputImage.fromBitmap(bitmap, 0)))
            check(mask.width == bgr.cols() && mask.height == bgr.rows()) { "Mask size differs" }
            val buffer = mask.buffer
            buffer.rewind()
            return FloatArray(mask.width * mask.height).also { buffer.asFloatBuffer().get(it) }
        } finally {
            rgba.release()
            bitmap.recycle()
        }
    }

    private fun decode(bytes: ByteArray): Mat {
        val buf = MatOfByte(*bytes)
        val img = Imgcodecs.imdecode(buf, Imgcodecs.IMREAD_COLOR)
        buf.release()
        check(!img.empty()) { "Not an image" }
        val side = max(img.rows(), img.cols())
        if (side <= MAX_SIDE) return img
        val scale = MAX_SIDE.toDouble() / side
        val small = Mat()
        Imgproc.resize(img, small, Size(img.cols() * scale, img.rows() * scale), 0.0, 0.0, Imgproc.INTER_AREA)
        img.release()
        return small
    }
}
