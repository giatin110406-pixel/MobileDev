package com.neobrutalism.neo_brutalism_locket.addme

import org.opencv.calib3d.Calib3d
import org.opencv.core.*
import org.opencv.features2d.DescriptorMatcher
import org.opencv.features2d.SIFT
import org.opencv.imgproc.Imgproc
import kotlin.math.*

/**
 * "Add me": puts the person who held the camera into the group photo.
 *
 * shot 1 = the group without the holder, shot 2 = the same scene with the holder standing in.
 * The holder is cut out of shot 2 along a seam through background pixels both shots agree on (a
 * closed minimum-cost path, dynamic programming), then laid onto shot 1. When the pair does not
 * allow that, the result says why instead of guessing.
 *
 * A port of server/eval/add_me.py, with its measured thresholds; keep the two in step.
 * Mats are BGR 8-bit. Not thread-safe: one merge at a time per instance.
 */
class AddMeMerger {
    class Result(
        val ok: Boolean,
        val reason: String? = null,
        /** BGR, the size of shot 1; owned by the caller. */
        val image: Mat? = null,
        val info: Map<String, Any?> = emptyMap(),
    )

    companion object {
        const val REASON_ALIGN = "align_failed"
        const val REASON_BACKGROUND = "background_changed"
        const val REASON_NO_PERSON = "no_new_person"
        const val REASON_TOO_LARGE = "change_too_large"
        const val REASON_NEEDS_MATTING = "needs_matting"
        const val REASON_SEVERAL = "several_changes"

        const val WORK = 640
        const val MIN_MATCHES = 20
        const val MIN_INLIERS = 15
        const val MIN_INLIER_RATIO = 0.35
        const val MAX_CORNER_SHIFT = 0.25
        const val MIN_PERSON_AREA = 0.004
        const val MAX_PERSON_AREA = 0.60
        const val MAX_OTHER_CHANGE = 0.03
        const val MAX_SECOND_CHANGE = 0.15
        const val JOIN = 0.04
        const val MAX_SEAM_COST = 14.0
        const val ANGLES = 360
    }

    fun merge(shot1: Mat, shot2: Mat): Result {
        val info = LinkedHashMap<String, Any?>()
        val valid = Mat()
        val moved = align(shot1, shot2, valid, info) ?: run {
            valid.release()
            return Result(false, REASON_ALIGN, info = info)
        }
        try {
            matchExposure(shot1, moved, valid)
            val d = difference(shot1, moved, valid)
            val h = d.size
            val w = d[0].size
            val total = (h * w).toDouble()
            val (labels, areas) = changedRegions(d)
            if (areas.isEmpty() || areas[0].second / total < MIN_PERSON_AREA) {
                return Result(false, REASON_NO_PERSON, info = info)
            }
            // The biggest change, with any change right next to it (a head that a collar the
            // colour of the background split off the body).
            val chosen = HashSet<Int>().apply { add(areas[0].first) }
            val reach = (max(3, (WORK * JOIN).roundToInt())) or 1
            val near = dilate(maskOf(labels, chosen), reach, ellipse = true)
            for (y in 0 until h) for (x in 0 until w) {
                if (near[y][x] && labels[y][x] > 0) chosen.add(labels[y][x])
            }
            val chosenArea = areas.filter { it.first in chosen }.sumOf { it.second }.toDouble()
            val rest = areas.filter { it.first !in chosen }
            val person = dilate(maskOf(labels, chosen), 5, ellipse = false)
            val area = person.sumOf { row -> row.count { it } } / total
            val others = rest.sumOf { it.second } / total
            info["person_area"] = area
            info["other_change"] = others
            if (area > MAX_PERSON_AREA) return Result(false, REASON_TOO_LARGE, info = info)
            if (others > MAX_OTHER_CHANGE) return Result(false, REASON_BACKGROUND, info = info)
            if (rest.isNotEmpty()) {
                val second = rest.maxOf { it.second }.toDouble()
                info["second_change"] = second / chosenArea
                if (second / total >= MIN_PERSON_AREA && second >= MAX_SECOND_CHANGE * chosenArea) {
                    return Result(false, REASON_SEVERAL, info = info)
                }
            }
            val (cut, seamCost) = findSeam(d, person)
            info["seam_cost"] = seamCost
            if (seamCost > MAX_SEAM_COST) return Result(false, REASON_NEEDS_MATTING, info = info)
            return Result(true, image = blend(shot1, moved, cut), info = info)
        } finally {
            moved.release()
            valid.release()
        }
    }

    // Alignment -----------------------------------------------------------------------------

    private fun fit(img: Mat, interpolation: Int = Imgproc.INTER_AREA): Pair<Mat, Double> {
        val scale = min(1.0, WORK.toDouble() / max(img.rows(), img.cols()))
        val out = Mat()
        if (scale == 1.0) img.copyTo(out)
        else Imgproc.resize(
            img, out,
            Size((img.cols() * scale).roundToInt().toDouble(), (img.rows() * scale).roundToInt().toDouble()),
            0.0, 0.0, interpolation,
        )
        return out to scale
    }

    /** `moving` warped into `base`'s frame, or null when the shots cannot be matched. */
    private fun align(base: Mat, moving: Mat, validOut: Mat, info: MutableMap<String, Any?>): Mat? {
        val (smallB, scale) = fit(base)
        val (smallM, _) = fit(moving)
        val grayB = Mat(); val grayM = Mat()
        Imgproc.cvtColor(smallB, grayB, Imgproc.COLOR_BGR2GRAY)
        Imgproc.cvtColor(smallM, grayM, Imgproc.COLOR_BGR2GRAY)
        smallB.release(); smallM.release()
        val sift = SIFT.create(3000)
        val kb = MatOfKeyPoint(); val km = MatOfKeyPoint()
        val db = Mat(); val dm = Mat()
        val none = Mat()
        val pairs = ArrayList<MatOfDMatch>()
        val src = MatOfPoint2f(); val dst = MatOfPoint2f()
        val inlierMask = Mat()
        var hSmall: Mat? = null
        try {
            sift.detectAndCompute(grayB, none, kb, db)
            sift.detectAndCompute(grayM, none, km, dm)
            info["keypoints"] = listOf(kb.total(), km.total())
            if (db.empty() || dm.empty() || kb.total() < MIN_MATCHES || km.total() < MIN_MATCHES) return null
            DescriptorMatcher.create(DescriptorMatcher.BRUTEFORCE).knnMatch(dm, db, pairs, 2)
            val good = pairs.mapNotNull { pair ->
                val p = pair.toArray()
                if (p.size == 2 && p[0].distance < .75f * p[1].distance) p[0] else null
            }
            info["matches"] = good.size
            if (good.size < MIN_MATCHES) return null
            val ptsB = kb.toArray(); val ptsM = km.toArray()
            src.fromList(good.map { ptsM[it.queryIdx].pt })
            dst.fromList(good.map { ptsB[it.trainIdx].pt })
            hSmall = Calib3d.findHomography(src, dst, Calib3d.RANSAC, 3.0, inlierMask)
            if (hSmall.empty()) return null
            val mask = ByteArray(inlierMask.total().toInt()).also { inlierMask.get(0, 0, it) }
            val inliers = mask.count { it.toInt() != 0 }
            val ratio = inliers.toDouble() / good.size
            info["inliers"] = inliers
            info["inlier_ratio"] = ratio
            if (inliers < MIN_INLIERS || ratio < MIN_INLIER_RATIO) return null
            // small -> full resolution: H = S^-1 Hs S
            val hs = DoubleArray(9).also { hSmall.get(0, 0, it) }
            val hFull = Mat(3, 3, CvType.CV_64F).apply {
                put(0, 0,
                    hs[0], hs[1], hs[2] / scale,
                    hs[3], hs[4], hs[5] / scale,
                    hs[6] * scale, hs[7] * scale, hs[8])
            }
            try {
                val w = base.cols().toDouble(); val h = base.rows().toDouble()
                val corners = MatOfPoint2f(Point(0.0, 0.0), Point(w, 0.0), Point(w, h), Point(0.0, h))
                val movedCorners = MatOfPoint2f()
                Core.perspectiveTransform(corners, movedCorners, hFull)
                val shift = corners.toArray().zip(movedCorners.toArray())
                    .maxOf { (a, b) -> max(abs(a.x - b.x), abs(a.y - b.y)) } / hypot(w, h)
                corners.release(); movedCorners.release()
                info["corner_shift"] = shift
                if (shift > MAX_CORNER_SHIFT) return null
                val warped = Mat()
                Imgproc.warpPerspective(moving, warped, hFull, base.size(), Imgproc.INTER_LINEAR, Core.BORDER_REPLICATE)
                val ones = Mat(moving.size(), CvType.CV_8UC1, Scalar(255.0))
                Imgproc.warpPerspective(ones, validOut, hFull, base.size(), Imgproc.INTER_NEAREST)
                ones.release()
                return warped
            } finally { hFull.release() }
        } finally {
            grayB.release(); grayM.release(); kb.release(); km.release(); db.release(); dm.release()
            none.release(); pairs.forEach { it.release() }; src.release(); dst.release()
            inlierMask.release(); hSmall?.release(); sift.clear()
        }
    }

    /** Per-channel gain from the median pixel-by-pixel ratio over the background (in place). */
    private fun matchExposure(base: Mat, moving: Mat, valid: Mat) {
        val (b, _) = fit(base); val (m, _) = fit(moving); val (v, _) = fit(valid)
        try {
            val bb = ByteArray((b.total() * 3).toInt()).also { b.get(0, 0, it) }
            val mb = ByteArray((m.total() * 3).toInt()).also { m.get(0, 0, it) }
            val vb = ByteArray(v.total().toInt()).also { v.get(0, 0, it) }
            val ratios = Array(3) { FloatArray(vb.size) }
            var n = 0
            for (i in vb.indices) {
                if ((vb[i].toInt() and 0xff) <= 128) continue
                var ok = true
                for (c in 0 until 3) {
                    val x = bb[i * 3 + c].toInt() and 0xff; val y = mb[i * 3 + c].toInt() and 0xff
                    if (x <= 8 || y <= 8 || x >= 250 || y >= 250) { ok = false; break }
                }
                if (!ok) continue
                for (c in 0 until 3) {
                    ratios[c][n] = (bb[i * 3 + c].toInt() and 0xff).toFloat() / (mb[i * 3 + c].toInt() and 0xff)
                }
                n++
            }
            if (n < 1000) return
            val gains = DoubleArray(3) { c -> median(ratios[c], n).coerceIn(.7, 1.4) }
            Core.multiply(moving, Scalar(gains[0], gains[1], gains[2]), moving)
        } finally { b.release(); m.release(); v.release() }
    }

    /** Colour distance (Lab, lightly blurred) at working size; 0 where `moving` has no data. */
    private fun difference(base: Mat, moving: Mat, valid: Mat): Array<FloatArray> {
        val (b, _) = fit(base); val (m, _) = fit(moving); val (v, _) = fit(valid)
        val labB = Mat(); val labM = Mat()
        try {
            for ((src, lab) in listOf(b to labB, m to labM)) {
                Imgproc.cvtColor(src, lab, Imgproc.COLOR_BGR2Lab)
                lab.convertTo(lab, CvType.CV_32FC3)
                Imgproc.GaussianBlur(lab, lab, Size(0.0, 0.0), 2.0)
            }
            val h = b.rows(); val w = b.cols()
            val fb = FloatArray(h * w * 3).also { labB.get(0, 0, it) }
            val fm = FloatArray(h * w * 3).also { labM.get(0, 0, it) }
            val vb = ByteArray(h * w).also { v.get(0, 0, it) }
            return Array(h) { y ->
                FloatArray(w) { x ->
                    val i = y * w + x
                    if ((vb[i].toInt() and 0xff) < 128) 0f else {
                        val d0 = fb[i * 3] - fm[i * 3]
                        val d1 = fb[i * 3 + 1] - fm[i * 3 + 1]
                        val d2 = fb[i * 3 + 2] - fm[i * 3 + 2]
                        sqrt(d0 * d0 + d1 * d1 + d2 * d2)
                    }
                }
            }
        } finally { b.release(); m.release(); v.release(); labB.release(); labM.release() }
    }

    /** Labels of the changed blobs and (label, area) biggest first. The threshold follows this
     * pair's noise (median + 5 MAD), so a noisy night shot does not light up everywhere. */
    private fun changedRegions(d: Array<FloatArray>): Pair<Array<IntArray>, List<Pair<Int, Int>>> {
        val h = d.size; val w = d[0].size
        val flat = FloatArray(h * w) { d[it / w][it % w] }
        val med = median(flat.copyOf(), flat.size)
        val dev = FloatArray(flat.size) { abs(flat[it] - med.toFloat()) }
        val mad = median(dev, dev.size) * 1.4826
        val thr = max(18.0, med + 5.0 * mad)
        val mask = Mat(h, w, CvType.CV_8UC1)
        val bytes = ByteArray(h * w) { if (flat[it] > thr) 1 else 0 }
        mask.put(0, 0, bytes)
        val labels = Mat(); val stats = Mat(); val centroids = Mat()
        try {
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_OPEN, Mat.ones(3, 3, CvType.CV_8U))
            val k = max(9, (WORK * 0.03).roundToInt()) or 1
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_CLOSE,
                Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(k.toDouble(), k.toDouble())))
            val count = Imgproc.connectedComponentsWithStats(mask, labels, stats, centroids, 8, CvType.CV_32S)
            val ints = IntArray(h * w).also { labels.get(0, 0, it) }
            val areas = (1 until count).map { it to stats.get(it, Imgproc.CC_STAT_AREA)[0].toInt() }
                .sortedByDescending { it.second }
            return Array(h) { y -> IntArray(w) { x -> ints[y * w + x] } } to areas
        } finally { mask.release(); labels.release(); stats.release(); centroids.release() }
    }

    // The seam ------------------------------------------------------------------------------

    /** A closed minimum-cost cut around `person`: for every angle a radius in a band just
     * outside the blob, stepping by at most one per angle, summed colour difference smallest.
     * Returns (filled mask at working size, mean cost along the cut). */
    private fun findSeam(d: Array<FloatArray>, person: Array<BooleanArray>): Pair<Array<BooleanArray>, Double> {
        val h = person.size; val w = person[0].size
        var sx = 0.0; var sy = 0.0; var n = 0
        for (y in 0 until h) for (x in 0 until w) if (person[y][x]) { sx += x; sy += y; n++ }
        val cx = sx / n; val cy = sy / n
        val reachMax = hypot(h.toDouble(), w.toDouble()).toInt()
        val dx = DoubleArray(ANGLES) { cos(2 * PI * it / ANGLES) }
        val dy = DoubleArray(ANGLES) { sin(2 * PI * it / ANGLES) }
        val reach = IntArray(ANGLES) { a ->
            var last = 0
            for (r in 0 until reachMax) {
                val x = (cx + dx[a] * r).roundToInt().coerceIn(0, w - 1)
                val y = (cy + dy[a] * r).roundToInt().coerceIn(0, h - 1)
                if (person[y][x]) last = r
            }
            last
        }
        val band = max(12, (WORK * 0.04).roundToInt())
        val cost = Array(ANGLES) { a ->
            DoubleArray(band) { k ->
                val r = reach[a] + 1 + k
                val x = (cx + dx[a] * r).roundToInt().coerceIn(0, w - 1)
                val y = (cy + dy[a] * r).roundToInt().coerceIn(0, h - 1)
                d[y][x] + 0.01 * k
            }
        }
        val inf = 1e18
        // dp[s][j]: cheapest path that started at offset s and now sits at offset j.
        var dp = Array(band) { s -> DoubleArray(band) { j -> if (s == j) cost[0][j] else inf } }
        val back = Array(ANGLES) { Array(band) { ByteArray(band) } }
        for (a in 1 until ANGLES) {
            val next = Array(band) { DoubleArray(band) { inf } }
            for (s in 0 until band) for (j in 0 until band) {
                var best = dp[s][j]; var step = 0
                if (j > 0 && dp[s][j - 1] < best) { best = dp[s][j - 1]; step = -1 }
                if (j < band - 1 && dp[s][j + 1] < best) { best = dp[s][j + 1]; step = 1 }
                if (best < inf) next[s][j] = best + cost[a][j]
                back[a][s][j] = step.toByte()
            }
            dp = next
        }
        var bestS = 0; var bestJ = 0; var total = inf
        for (s in 0 until band) for (j in max(0, s - 1)..min(band - 1, s + 1)) {
            if (dp[s][j] < total) { total = dp[s][j]; bestS = s; bestJ = j }
        }
        val path = IntArray(ANGLES)
        path[ANGLES - 1] = bestJ
        for (a in ANGLES - 1 downTo 1) {
            path[a - 1] = (path[a] + back[a][bestS][path[a]]).coerceIn(0, band - 1)
        }
        val pts = MatOfPoint(*Array(ANGLES) { a ->
            val r = reach[a] + 1 + path[a]
            Point((cx + dx[a] * r).roundToInt().toDouble(), (cy + dy[a] * r).roundToInt().toDouble())
        })
        val filled = Mat.zeros(h, w, CvType.CV_8UC1)
        Imgproc.fillPoly(filled, listOf(pts), Scalar(1.0))
        val fb = ByteArray(h * w).also { filled.get(0, 0, it) }
        filled.release(); pts.release()
        return Array(h) { y -> BooleanArray(w) { x -> fb[y * w + x].toInt() != 0 || person[y][x] } } to total / ANGLES
    }

    /** shot1 with the cut laid over it from `moved`, soft at the edge. Only the box around the
     * cut is worked on in floating point, so a big photo does not need several copies of itself. */
    private fun blend(shot1: Mat, moved: Mat, cut: Array<BooleanArray>): Mat {
        val h = cut.size; val w = cut[0].size
        var x0 = w; var y0 = h; var x1 = -1; var y1 = -1
        for (y in 0 until h) for (x in 0 until w) if (cut[y][x]) {
            x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y)
        }
        val out = shot1.clone()
        if (x1 < 0) return out
        val sigma = max(1.5, 0.004 * max(shot1.rows(), shot1.cols()))
        val sx = shot1.cols().toDouble() / w; val sy = shot1.rows().toDouble() / h
        val pad = (4 * sigma + max(sx, sy)).toInt() + 2
        val roi = Rect(
            Point(max(0.0, x0 * sx - pad), max(0.0, y0 * sy - pad)),
            Point(min(shot1.cols().toDouble(), (x1 + 1) * sx + pad), min(shot1.rows().toDouble(), (y1 + 1) * sy + pad)),
        )
        val small = Mat(h, w, CvType.CV_32FC1)
        small.put(0, 0, FloatArray(h * w) { if (cut[it / w][it % w]) 1f else 0f })
        val full = Mat()
        Imgproc.resize(small, full, shot1.size(), 0.0, 0.0, Imgproc.INTER_LINEAR)
        val soft = full.submat(roi).clone()
        Imgproc.GaussianBlur(soft, soft, Size(0.0, 0.0), sigma)
        Core.min(soft, Scalar(1.0), soft); Core.max(soft, Scalar(0.0), soft)
        val alpha = Mat(); Core.merge(listOf(soft, soft, soft), alpha)
        val inv = Mat(alpha.size(), alpha.type(), Scalar(1.0, 1.0, 1.0))
        Core.subtract(inv, alpha, inv)
        val a = Mat(); val b = Mat()
        shot1.submat(roi).convertTo(a, CvType.CV_32FC3)
        moved.submat(roi).convertTo(b, CvType.CV_32FC3)
        Core.multiply(a, inv, a); Core.multiply(b, alpha, b); Core.add(a, b, a)
        a.convertTo(out.submat(roi), CvType.CV_8UC3)
        listOf(small, full, soft, alpha, inv, a, b).forEach { it.release() }
        return out
    }

    // Helpers -------------------------------------------------------------------------------

    private fun maskOf(labels: Array<IntArray>, keep: Set<Int>) =
        Array(labels.size) { y -> BooleanArray(labels[0].size) { x -> labels[y][x] in keep } }

    private fun dilate(mask: Array<BooleanArray>, size: Int, ellipse: Boolean): Array<BooleanArray> {
        val h = mask.size; val w = mask[0].size
        val m = Mat(h, w, CvType.CV_8UC1)
        m.put(0, 0, ByteArray(h * w) { if (mask[it / w][it % w]) 1 else 0 })
        val kernel = if (ellipse) Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(size.toDouble(), size.toDouble()))
        else Mat.ones(size, size, CvType.CV_8U)
        Imgproc.dilate(m, m, kernel)
        val b = ByteArray(h * w).also { m.get(0, 0, it) }
        m.release(); kernel.release()
        return Array(h) { y -> BooleanArray(w) { x -> b[y * w + x].toInt() != 0 } }
    }

    /** numpy.median of the first n values (sorts them in place). */
    private fun median(values: FloatArray, n: Int): Double {
        java.util.Arrays.sort(values, 0, n)
        return if (n % 2 == 1) values[n / 2].toDouble()
        else (values[n / 2 - 1].toDouble() + values[n / 2]) / 2
    }
}
