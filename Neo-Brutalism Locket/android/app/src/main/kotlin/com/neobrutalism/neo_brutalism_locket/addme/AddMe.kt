package com.neobrutalism.neo_brutalism_locket.addme

import android.content.Context
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
import java.io.File
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

    /**
     * With a file named add_me_debug_on in the app's external files folder, every merge keeps its
     * two shots, the shot-2 picture lined up on shot 1, the person's opacity, the result and the
     * numbers under add_me_debug/ there (adb pull). Off unless that file is put there.
     */
    @Volatile private var debugRoot: File? = null

    fun register(messenger: BinaryMessenger, context: Context) {
        debugRoot = context.getExternalFilesDir(null)
        Matting.init(context)
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
        val dump = debugRun()
        dump?.let { File(it, "shot1.jpg").writeBytes(first); File(it, "shot2.jpg").writeBytes(second) }
        try {
            val merger = AddMeMerger(::people, Matting::alpha)
            if (dump != null) {
                merger.debug = { name, mat ->
                    Imgcodecs.imwrite(File(dump, if (mat.channels() == 1) "$name.png" else "$name.jpg").path, mat)
                }
            }
            val out = merger.merge(shot1, shot2)
            dump?.let { dir ->
                out.image?.let { Imgcodecs.imwrite(File(dir, "result.jpg").path, it) }
                File(dir, "info.txt").writeText("ok=${out.ok} reason=${out.reason} ${out.info}")
            }
            out.alternative?.let { dump?.let { dir -> Imgcodecs.imwrite(File(dir, "result_front.jpg").path, it) } }
            val image = out.image?.let(::encode)
            val alternative = out.alternative?.let(::encode)
            return mapOf(
                "ok" to out.ok,
                "reason" to out.reason,
                "image" to image,
                "alternative" to alternative,
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

    /** JPEG bytes of [mat], which is released. */
    private fun encode(mat: Mat): ByteArray {
        val buf = MatOfByte()
        val params = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 92)
        try {
            check(Imgcodecs.imencode(".jpg", mat, buf, params))
            return buf.toArray()
        } finally { buf.release(); params.release(); mat.release() }
    }

    private fun debugRun(): File? {
        val root = debugRoot ?: return null
        if (!File(root, "add_me_debug_on").exists()) return null
        val all = File(root, "add_me_debug")
        all.listFiles()?.sortedBy { it.name }?.dropLast(11)?.forEach { it.deleteRecursively() }
        return File(all, System.currentTimeMillis().toString()).also { it.mkdirs() }
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
