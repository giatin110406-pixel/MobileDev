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
 * The holder is whoever shot 2 sees as a person where shot 1 saw nobody and the colours really
 * changed; only they are laid onto shot 1. Anything else that changed between the shots (leaves,
 * a group member shifting, a retake a step to the side) is left as shot 1 had it, so the pair
 * does not have to match exactly. It refuses only when the shots are not of the same scene, when
 * nobody new is found, or when the newcomer fills most of the frame.
 *
 * A port of server/eval/add_me_people.py, with its thresholds; keep the two in step.
 * [segment] gives the chance of a person per pixel for a BGR image (row-major, its size).
 * Mats are BGR 8-bit. Not thread-safe: one merge at a time per instance.
 */
class AddMeMerger(private val segment: (Mat) -> FloatArray) {
    class Result(
        val ok: Boolean,
        val reason: String? = null,
        /** BGR, the size of shot 1; owned by the caller. */
        val image: Mat? = null,
        val info: Map<String, Any?> = emptyMap(),
    )

    companion object {
        const val REASON_ALIGN = "align_failed"
        const val REASON_NO_PERSON = "no_new_person"
        const val REASON_TOO_LARGE = "change_too_large"

        const val WORK = 640
        const val MIN_MATCHES = 20
        const val MIN_INLIERS = 15
        const val MIN_INLIER_RATIO = 0.35
        const val MAX_CORNER_SHIFT = 0.25
        const val MIN_PERSON_AREA = 0.004
        const val MAX_PERSON_AREA = 0.60
        /** Segmenter confidence that counts as "a person is here". */
        const val PERSON = 0.5f
        /** A body in shot 2 this much on shot 1's people is someone who was already there. */
        const val SEEN_BEFORE = 0.35
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
            val n = h * w
            val total = n.toDouble()
            val p1 = people(shot1, w, h)
            val p2 = people(moved, w, h)
            val flat = FloatArray(n) { d[it / w][it % w] }
            val thr = changeThreshold(flat)
            val changed = BooleanArray(n) { flat[it] > thr }

            // New patches: a person in shot 2, nobody in shot 1, and the colour changed.
            val newMask = toMat(h, w) { p2[it] && !p1[it] && changed[it] }
            Imgproc.morphologyEx(newMask, newMask, Imgproc.MORPH_OPEN, Mat.ones(3, 3, CvType.CV_8U))
            val k = max(9, (WORK * 0.03).roundToInt()) or 1
            val bodyMask = toMat(h, w) { p2[it] }
            Imgproc.morphologyEx(bodyMask, bodyMask, Imgproc.MORPH_CLOSE,
                Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(k.toDouble(), k.toDouble())))
            val patches = labelsOf(newMask)
            val bodies = labelsOf(bodyMask)
            newMask.release(); bodyMask.release()

            // Each patch belongs to bodies in shot 2. A group member who shifted makes a patch
            // too, but their body mostly covers where shot 1 had them: a body shot 1 did not have
            // comes first, then the bigger patch.
            val patchArea = HashMap<Int, Int>()
            val patchBodies = HashMap<Int, MutableSet<Int>>()
            val bodySize = HashMap<Int, Int>()
            val bodySeen = HashMap<Int, Int>()
            for (i in 0 until n) {
                val b = bodies[i]
                if (b > 0) {
                    bodySize.merge(b, 1, Int::plus)
                    if (p1[i]) bodySeen.merge(b, 1, Int::plus)
                }
                val c = patches[i]
                if (c > 0) {
                    patchArea.merge(c, 1, Int::plus)
                    if (b > 0) patchBodies.getOrPut(c) { HashSet() }.add(b)
                }
            }
            val candidates = patchArea.mapNotNull { (c, a) ->
                val area = a / total
                if (area < MIN_PERSON_AREA) return@mapNotNull null
                val ids = patchBodies[c].orEmpty()
                val size = ids.sumOf { bodySize[it] ?: 0 }
                val seen = ids.sumOf { bodySeen[it] ?: 0 }.toDouble() / max(1, size)
                Candidate(area, ids, seen)
            }
            info["candidates"] = candidates.size
            val best = candidates.minWithOrNull(
                compareBy<Candidate> { it.seen > SEEN_BEFORE }.thenByDescending { it.area },
            ) ?: return Result(false, REASON_NO_PERSON, info = info)
            info["new_area"] = best.area
            info["seen_before"] = best.seen

            // The whole person shot 2 sees there, less what shot 1 already had and did not change
            // (a group member they stand against stays shot 1's), plus edges the segmenter missed
            // (loose hair, a bag strap) that changed right next to it.
            val person = toMat(h, w) { bodies[it] in best.bodies && !(p1[it] && !changed[it]) }
            val near = Mat()
            Imgproc.dilate(person, near, Mat.ones(7, 7, CvType.CV_8U))
            val nearBytes = ByteArray(n).also { near.get(0, 0, it) }
            val personBytes = ByteArray(n).also { person.get(0, 0, it) }
            for (i in 0 until n) if (nearBytes[i].toInt() != 0 && changed[i]) personBytes[i] = 1
            person.put(0, 0, personBytes)
            near.release()
            Imgproc.morphologyEx(person, person, Imgproc.MORPH_CLOSE, Mat.ones(5, 5, CvType.CV_8U))
            val area = Core.countNonZero(person) / total
            info["person_area"] = area
            if (area > MAX_PERSON_AREA) {
                person.release()
                return Result(false, REASON_TOO_LARGE, info = info)
            }
            Imgproc.dilate(person, person, Mat.ones(3, 3, CvType.CV_8U))
            val image = blend(shot1, moved, person)
            person.release()
            return Result(true, image = image, info = info)
        } finally {
            moved.release()
            valid.release()
        }
    }

    private class Candidate(val area: Double, val bodies: Set<Int>, val seen: Double)

    /** Where [img] has a person, at the working size. */
    private fun people(img: Mat, w: Int, h: Int): BooleanArray {
        val (small, _) = fit(img)
        try {
            check(small.cols() == w && small.rows() == h)
            val p = segment(small)
            return BooleanArray(w * h) { p[it] > PERSON }
        } finally { small.release() }
    }

    /** Colour change that stands out from this pair's noise (median + 5 MAD), so a noisy night
     * shot does not light up everywhere. */
    private fun changeThreshold(d: FloatArray): Double {
        val med = median(d.copyOf(), d.size)
        val dev = FloatArray(d.size) { abs(d[it] - med.toFloat()) }
        return max(18.0, med + 5.0 * median(dev, dev.size) * 1.4826)
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

    // Blending ------------------------------------------------------------------------------

    /** shot1 with [cut] (a 0/1 mask at working size) laid over it from `moved`, soft at the
     * edge. Only the box around the cut is worked on in floating point, so a big photo does not
     * need several copies of itself. */
    private fun blend(shot1: Mat, moved: Mat, cut: Mat): Mat {
        val out = shot1.clone()
        if (Core.countNonZero(cut) == 0) return out
        val box = Imgproc.boundingRect(cut)
        val sigma = max(1.5, 0.003 * max(shot1.rows(), shot1.cols()))
        val sx = shot1.cols().toDouble() / cut.cols(); val sy = shot1.rows().toDouble() / cut.rows()
        val pad = (4 * sigma + max(sx, sy)).toInt() + 2
        val roi = Rect(
            Point(max(0.0, box.x * sx - pad), max(0.0, box.y * sy - pad)),
            Point(
                min(shot1.cols().toDouble(), (box.x + box.width) * sx + pad),
                min(shot1.rows().toDouble(), (box.y + box.height) * sy + pad),
            ),
        )
        val small = Mat()
        cut.convertTo(small, CvType.CV_32FC1)
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

    private inline fun toMat(h: Int, w: Int, on: (Int) -> Boolean): Mat =
        Mat(h, w, CvType.CV_8UC1).apply { put(0, 0, ByteArray(h * w) { if (on(it)) 1 else 0 }) }

    /** 8-connected component labels of a 0/1 mask, row-major (0 = background). */
    private fun labelsOf(mask: Mat): IntArray {
        val labels = Mat()
        try {
            Imgproc.connectedComponents(mask, labels, 8, CvType.CV_32S)
            return IntArray(mask.rows() * mask.cols()).also { labels.get(0, 0, it) }
        } finally { labels.release() }
    }

    /** numpy.median of the first n values (sorts them in place). */
    private fun median(values: FloatArray, n: Int): Double {
        java.util.Arrays.sort(values, 0, n)
        return if (n % 2 == 1) values[n / 2].toDouble()
        else (values[n / 2 - 1].toDouble() + values[n / 2]) / 2
    }
}
