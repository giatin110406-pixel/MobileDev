package com.neobrutalism.neo_brutalism_locket.addme

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.content.res.AssetManager
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.nio.FloatBuffer
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Portrait matting for the edge of the person "add me" lays on a photo: MODNet (Apache-2.0),
 * run with ONNX Runtime on the device. It gives a soft opacity with hair-fine edges, where the
 * selfie segmenter only gives a coarse outline.
 *
 * The model file is the asset `modnet.onnx` (26 MB, in git; android/tools/fetch_modnet.ps1 restores
 * it and checks its SHA-256). When it is missing or cannot run, [alpha] throws and the caller keeps
 * the coarser edge.
 */
object Matting {
    private const val ASSET = "modnet.onnx"
    /** The picture is matted at this long side (rows and columns multiples of 32). */
    private const val LONG_SIDE = 640

    @Volatile private var assets: AssetManager? = null

    fun init(context: Context) {
        assets = context.applicationContext.assets
    }

    private val env: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

    private val session: OrtSession by lazy {
        val bytes = checkNotNull(assets) { "Matting.init was not called" }
            .open(ASSET).use { it.readBytes() }
        env.createSession(bytes, OrtSession.SessionOptions().apply { setIntraOpNumThreads(4) })
    }

    /** The opacity (0..1) of the person at each pixel of a BGR image, row-major, its size. */
    fun alpha(bgr: Mat): FloatArray {
        val w = bgr.cols()
        val h = bgr.rows()
        val f = LONG_SIDE.toDouble() / max(w, h)
        val nw = max(32, (w * f / 32).roundToInt() * 32)
        val nh = max(32, (h * f / 32).roundToInt() * 32)
        val small = Mat(); val rgb = Mat(); val scaled = Mat(); val out = Mat(); val full = Mat()
        try {
            Imgproc.resize(
                bgr, small, Size(nw.toDouble(), nh.toDouble()), 0.0, 0.0,
                if (f < 1) Imgproc.INTER_AREA else Imgproc.INTER_CUBIC,
            )
            Imgproc.cvtColor(small, rgb, Imgproc.COLOR_BGR2RGB)
            rgb.convertTo(scaled, CvType.CV_32FC3, 1.0 / 127.5, -1.0) // (x / 255 - .5) / .5
            val interleaved = FloatArray(nh * nw * 3).also { scaled.get(0, 0, it) }
            val n = nh * nw
            val planar = FloatArray(n * 3)
            for (i in 0 until n) for (c in 0 until 3) planar[c * n + i] = interleaved[i * 3 + c]
            val tensor = OnnxTensor.createTensor(
                env, FloatBuffer.wrap(planar), longArrayOf(1, 3, nh.toLong(), nw.toLong()),
            )
            tensor.use {
                session.run(mapOf("input" to it)).use { result ->
                    @Suppress("UNCHECKED_CAST")
                    val matte = (result[0].value as Array<Array<Array<FloatArray>>>)[0][0]
                    out.create(nh, nw, CvType.CV_32FC1)
                    out.put(0, 0, FloatArray(n).also { flat ->
                        for (y in 0 until nh) System.arraycopy(matte[y], 0, flat, y * nw, nw)
                    })
                }
            }
            Imgproc.resize(out, full, Size(w.toDouble(), h.toDouble()), 0.0, 0.0, Imgproc.INTER_LINEAR)
            return FloatArray(w * h).also { full.get(0, 0, it) }
        } finally {
            listOf(small, rgb, scaled, out, full).forEach { it.release() }
        }
    }
}
