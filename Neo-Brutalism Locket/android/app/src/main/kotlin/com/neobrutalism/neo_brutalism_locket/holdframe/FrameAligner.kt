package com.neobrutalism.neo_brutalism_locket.holdframe

import org.opencv.calib3d.Calib3d
import org.opencv.core.*
import org.opencv.features2d.DescriptorMatcher
import org.opencv.features2d.ORB
import org.opencv.imgproc.Imgproc
import kotlin.math.*

/** The measured Python ORB/RANSAC algorithm, on upright 320-square luma images.
 * All methods run on the tracker's single worker. Native Mats are explicitly released.
 */
class FrameAligner : AutoCloseable {
    data class Alignment(
        val ok: Boolean,
        val reason: String? = null,
        val dx: Double = 0.0,
        val dy: Double = 0.0,
        val roll: Double = 0.0,
        val scale: Double = 1.0,
    ) {
        val aligned get() = ok && abs(dx) <= .03 && abs(dy) <= .03 &&
            abs(roll) <= 2.0 && abs(scale - 1) <= .04

        fun toMap(): Map<String, Any?> = mapOf(
            "state" to if (!ok) "unsure" else if (aligned) "aligned" else "adjust",
            "reason" to reason, "dx" to dx, "dy" to dy, "roll" to roll, "scale" to scale,
        )
    }

    private val orb = ORB.create(800, 1.2f, 6, 31, 0, 2, ORB.HARRIS_SCORE, 31, 10)
    private val clahe = Imgproc.createCLAHE(2.0, Size(4.0, 4.0))
    private val matcher = DescriptorMatcher.create(DescriptorMatcher.BRUTEFORCE_HAMMING)
    private val lockedDescriptors = Mat()
    private val lockedPoints = MatOfKeyPoint()
    private val emptyMask = Mat()

    private fun features(gray: Mat, points: MatOfKeyPoint, descriptors: Mat) {
        val prepared = Mat()
        try {
            clahe.apply(gray, prepared)
            orb.detectAndCompute(prepared, emptyMask, points, descriptors)
        } finally { prepared.release() }
    }

    fun lock(gray: Mat): Boolean {
        features(gray, lockedPoints, lockedDescriptors)
        return !lockedDescriptors.empty() && lockedPoints.total() >= 12
    }

    fun estimate(gray: Mat): Alignment {
        val points = MatOfKeyPoint()
        val descriptors = Mat()
        val matches = ArrayList<MatOfDMatch>()
        val src = MatOfPoint2f()
        val dst = MatOfPoint2f()
        val inlierMask = Mat()
        var matrix: Mat? = null
        try {
            features(gray, points, descriptors)
            if (descriptors.empty() || points.total() < 12) return Alignment(false, "few_features")
            matcher.knnMatch(lockedDescriptors, descriptors, matches, 2)
            val good = matches.mapNotNull { pair ->
                val p = pair.toArray()
                if (p.size == 2 && p[0].distance < .75f * p[1].distance) p[0] else null
            }
            if (good.size < 12) return Alignment(false, "no_match")
            val a = lockedPoints.toArray()
            val b = points.toArray()
            src.fromList(good.map { a[it.queryIdx].pt })
            dst.fromList(good.map { b[it.trainIdx].pt })
            matrix = Calib3d.estimateAffinePartial2D(src, dst, inlierMask, Calib3d.RANSAC, 3.0, 2000, .99, 10)
            if (matrix.empty()) return Alignment(false, "no_match")
            val mask = ByteArray(inlierMask.total().toInt())
            inlierMask.get(0, 0, mask)
            val indices = good.indices.filter { mask[it].toInt() != 0 }
            if (indices.size < 10 || indices.size.toDouble() / good.size < .4) {
                return Alignment(false, "no_match")
            }
            val inliers = indices.map { a[good[it].queryIdx].pt }
            val spread = min(
                (inliers.maxOf { it.x } - inliers.minOf { it.x }) / gray.cols(),
                (inliers.maxOf { it.y } - inliers.minOf { it.y }) / gray.rows(),
            )
            if (spread < .1) return Alignment(false, "concentrated")
            val m = DoubleArray(6)
            matrix.get(0, 0, m)
            val scale = hypot(m[0], m[3])
            val roll = Math.toDegrees(atan2(m[3], m[0]))
            if (scale !in .5..2.0 || abs(roll) > 60) return Alignment(false, "implausible")
            val cx = gray.cols() / 2.0
            val cy = gray.rows() / 2.0
            return Alignment(true, dx = (m[0] * cx + m[1] * cy + m[2] - cx) / gray.cols(),
                dy = (m[3] * cx + m[4] * cy + m[5] - cy) / gray.rows(), roll = roll, scale = scale)
        } finally {
            matrix?.release()
            inlierMask.release()
            src.release()
            dst.release()
            matches.forEach { it.release() }
            points.release()
            descriptors.release()
        }
    }

    override fun close() {
        lockedDescriptors.release()
        lockedPoints.release()
        emptyMask.release()
        orb.clear()
        matcher.clear()
        clahe.collectGarbage()
        clahe.clear()
    }
}
