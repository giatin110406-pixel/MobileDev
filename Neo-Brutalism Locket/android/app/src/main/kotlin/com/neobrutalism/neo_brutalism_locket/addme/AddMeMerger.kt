package com.neobrutalism.neo_brutalism_locket.addme

import org.opencv.calib3d.Calib3d
import org.opencv.core.*
import org.opencv.features2d.DescriptorMatcher
import org.opencv.features2d.SIFT
import org.opencv.imgproc.Imgproc
import org.opencv.photo.Photo
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
    /** Test and debug hook: called with named intermediate pictures (BGR or one-channel 8-bit). */
    var debug: ((String, Mat) -> Unit)? = null

    class Result(
        val ok: Boolean,
        val reason: String? = null,
        /** BGR, the size of shot 1; owned by the caller. */
        val image: Mat? = null,
        val info: Map<String, Any?> = emptyMap(),
        /**
         * Set when the newcomer overlaps someone of shot 1 who is not in shot 2: the same merge with
         * the newcomer in front of them ([image] has the newcomer behind them). Owned by the caller.
         */
        val alternative: Mat? = null,
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
        /** A person of shot 1 is not in shot 2 when the model finds a person on less of their area than this... */
        const val ABSENT = 0.35
        /** ...or when this much of their area changed (the newcomer may stand where they stood). */
        const val CHANGED = 0.4
        /** Next to people of shot 1 the newcomer's edge is a hard occlusion: opacity is steepened by this. */
        const val SHARP = 6.0f
        /** Of WORK: the newcomer's hand this close to the rim of such a person stays in front. */
        const val EDGE_FRONT = 0.03
        /** Of the long side: how far from the first outline the edge may still move. */
        const val BAND = 0.0075
        const val GUIDE_RADIUS = 0.005
        const val GUIDE_EPS = 1e-3
        const val CROP_MARGIN = 0.15
        /** The person's crop is segmented at this size, so the model's grid is spent on them. */
        const val CROP_SIDE = 768
        /** Of the long side: the Poisson boundary lies this far outside the person. */
        const val HARMONY_REACH = 0.02
        /** Of the long side: how far in from the person's rim the correction is carried. */
        const val HARMONY_FADE = 0.02
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

            // People of shot 1 who are not in shot 2 (they left the frame or hold the phone) have
            // nothing in shot 2 to compare with, so "unchanged" says nothing about them: where the
            // newcomer overlaps them it is a question of who is in front. Behind (the default)
            // keeps them on top except within a hand's reach of their rim, where a hand resting
            // on a shoulder stays in front; the alternative lays the newcomer over them. People
            // who are in shot 2 too keep shot 1's pixels wherever nothing changed.
            val gone = absentPeople(p1, p2, changed, h, w, total)
            val hasGone = gone.any { it }
            info["gone_people"] = hasGone
            val deep = if (hasGone) deepInside(gone, h, w) else null

            val olds = toMat(h, w) { p1[it] }
            val behind = outline(bodies, best.bodies, p1, gone, changed, deep, h, w)
            val area = Core.countNonZero(behind) / total
            info["person_area"] = area
            if (area > MAX_PERSON_AREA) {
                behind.release()
                return Result(false, REASON_TOO_LARGE, info = info)
            }
            debug?.invoke("moved", moved)
            val image = lay(shot1, moved, behind, valid, "", olds)
            behind.release()
            var alternative: Mat? = null
            if (hasGone) {
                val front = outline(bodies, best.bodies, p1, gone, changed, null, h, w)
                alternative = lay(shot1, moved, front, valid, "_front", olds)
                front.release()
            }
            olds.release()
            return Result(true, image = image, info = info, alternative = alternative)
        } finally {
            moved.release()
            valid.release()
        }
    }

    /** The newcomer's outline at working size: their body in shot 2, without what shot 1 already
     * had and did not change (a group member they stand against stays shot 1's), minus [deep]
     * (inside someone they are behind), plus edges the segmenter missed (loose hair, a bag strap)
     * that changed right next to it. */
    private fun outline(
        bodies: IntArray, mine: Set<Int>, p1: BooleanArray, gone: BooleanArray, changed: BooleanArray,
        deep: BooleanArray?, h: Int, w: Int,
    ): Mat {
        val n = h * w
        val person = toMat(h, w) {
            bodies[it] in mine && !((p1[it] && !gone[it]) && !changed[it]) && !(deep != null && deep[it])
        }
        val near = Mat()
        Imgproc.dilate(person, near, Mat.ones(7, 7, CvType.CV_8U))
        val nearBytes = ByteArray(n).also { near.get(0, 0, it) }
        val personBytes = ByteArray(n).also { person.get(0, 0, it) }
        for (i in 0 until n) {
            if (nearBytes[i].toInt() != 0 && changed[i] && !(deep != null && deep[i])) personBytes[i] = 1
        }
        person.put(0, 0, personBytes)
        near.release()
        Imgproc.morphologyEx(person, person, Imgproc.MORPH_CLOSE, Mat.ones(5, 5, CvType.CV_8U))
        return person
    }

    /** The people of shot 1 (blobs of [p1]) whose area has changed so much that they are not in shot 2. */
    private fun absentPeople(
        p1: BooleanArray, p2: BooleanArray, changed: BooleanArray, h: Int, w: Int, total: Double,
    ): BooleanArray {
        val k = max(9, (WORK * 0.03).roundToInt()) or 1
        val closed = toMat(h, w) { p1[it] }
        Imgproc.morphologyEx(closed, closed, Imgproc.MORPH_CLOSE,
            Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(k.toDouble(), k.toDouble())))
        val labels = labelsOf(closed)
        closed.release()
        val size = HashMap<Int, Int>()
        val moved = HashMap<Int, Int>() // pixels of the blob where shot 2 also has a person
        val changedIn = HashMap<Int, Int>()
        for (i in labels.indices) {
            val l = labels[i]
            if (l == 0) continue
            size.merge(l, 1, Int::plus)
            if (p2[i]) moved.merge(l, 1, Int::plus)
            if (changed[i]) changedIn.merge(l, 1, Int::plus)
        }
        val absent = size.filter { (l, c) ->
            c >= MIN_PERSON_AREA * total &&
                ((moved[l] ?: 0).toDouble() / c < ABSENT || (changedIn[l] ?: 0).toDouble() / c > CHANGED)
        }.keys
        return BooleanArray(h * w) { labels[it] in absent }
    }

    /** [gone] without the strip within EDGE_FRONT of its rim. */
    private fun deepInside(gone: BooleanArray, h: Int, w: Int): BooleanArray {
        val m = toMat(h, w) { gone[it] }
        val dist = Mat()
        Imgproc.distanceTransform(m, dist, Imgproc.DIST_L2, 3)
        val d = FloatArray(h * w).also { dist.get(0, 0, it) }
        m.release(); dist.release()
        val reach = (EDGE_FRONT * WORK).toFloat()
        return BooleanArray(h * w) { gone[it] && d[it] > reach }
    }

    /** shot 1 with the newcomer ([outline]) laid on it. [tag] names the debug pictures. */
    private fun lay(shot1: Mat, moved: Mat, outline: Mat, valid: Mat, tag: String, olds: Mat): Mat {
        val (alpha, rect) = refineAlpha(moved, outline, valid, tag, olds)
        val lit = harmonize(shot1, moved, alpha, rect)
        val image = blend(shot1, lit, alpha, rect)
        lit.release()
        alpha.release()
        fillBlackBorders(image, moved, valid)
        return image
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

    // Edge and blending ---------------------------------------------------------------------

    /**
     * Soft opacity of the person, for the box around them (full size) it returns with. [person]
     * is their outline at working size. The model sees a crop of just them (about 3x the detail
     * of the whole frame), and the edge is snapped to the photo's own edges, in a band around
     * the outline, with a guided filter. Nothing comes from where [valid] says shot 2 has no
     * picture.
     */
    private fun refineAlpha(moved: Mat, person: Mat, valid: Mat, tag: String, olds: Mat): Pair<Mat, Rect> {
        val side = max(moved.rows(), moved.cols())
        val sx = moved.cols().toDouble() / person.cols()
        val sy = moved.rows().toDouble() / person.rows()
        val box = Imgproc.boundingRect(person)
        val mx = (box.width * sx * CROP_MARGIN).toInt() + 8
        val my = (box.height * sy * CROP_MARGIN).toInt() + 8
        val rect = Rect(
            Point(max(0.0, box.x * sx - mx), max(0.0, box.y * sy - my)),
            Point(
                min(moved.cols().toDouble(), (box.x + box.width) * sx + mx),
                min(moved.rows().toDouble(), (box.y + box.height) * sy + my),
            ),
        )
        val cw = rect.width; val ch = rect.height; val n = cw * ch
        val hardFull = Mat()
        Imgproc.resize(person, hardFull, moved.size(), 0.0, 0.0, Imgproc.INTER_NEAREST)
        val hard = hardFull.submat(rect).clone()
        hardFull.release()

        // The model on the crop alone.
        val crop = moved.submat(rect)
        val f = CROP_SIDE.toDouble() / max(cw, ch)
        val small = Mat()
        Imgproc.resize(
            crop, small,
            Size(max(1.0, (cw * f).roundToInt().toDouble()), max(1.0, (ch * f).roundToInt().toDouble())),
            0.0, 0.0, if (f < 1) Imgproc.INTER_AREA else Imgproc.INTER_CUBIC,
        )
        val smallConf = Mat(small.rows(), small.cols(), CvType.CV_32FC1)
        smallConf.put(0, 0, segment(small))
        small.release()
        val confMat = Mat()
        Imgproc.resize(smallConf, confMat, Size(cw.toDouble(), ch.toDouble()), 0.0, 0.0, Imgproc.INTER_LINEAR)
        smallConf.release()
        val conf = FloatArray(n).also { confMat.get(0, 0, it) }
        confMat.release()

        val band = max(4, (BAND * side).roundToInt())
        val k = (2 * band + 1).toDouble()
        val ker = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(k, k))
        val outerM = Mat(); val innerM = Mat()
        Imgproc.dilate(hard, outerM, ker)
        Imgproc.erode(hard, innerM, ker)
        ker.release()
        val hardB = ByteArray(n).also { hard.get(0, 0, it) }
        val outer = ByteArray(n).also { outerM.get(0, 0, it) }
        val inner = ByteArray(n).also { innerM.get(0, 0, it) }
        hard.release(); outerM.release(); innerM.release()

        val first = FloatArray(n) { i ->
            when {
                inner[i].toInt() != 0 -> 1f
                // Where the model hesitates inside the old outline, trust the outline.
                hardB[i].toInt() != 0 -> max(conf[i], 0.5f * conf[i] + 0.5f)
                outer[i].toInt() != 0 -> conf[i]
                else -> 0f
            }
        }
        val src = Mat(ch, cw, CvType.CV_32FC1).apply { put(0, 0, first) }
        val gray = Mat(); val guide = Mat()
        Imgproc.cvtColor(crop, gray, Imgproc.COLOR_BGR2GRAY)
        gray.convertTo(guide, CvType.CV_32FC1, 1.0 / 255)
        gray.release()
        val snapped = guidedFilter(guide, src, max(3, (GUIDE_RADIUS * side).roundToInt()), GUIDE_EPS)
        guide.release(); src.release()
        val snappedF = FloatArray(n).also { snapped.get(0, 0, it) }
        snapped.release()
        val validB = ByteArray(n).also { valid.submat(rect).get(0, 0, it) }
        // Where the newcomer's edge meets someone of shot 1 it is a body in front of a body, not a
        // person against a wall: a soft edge there shows as both of them half see-through.
        val oldsFull = Mat()
        Imgproc.resize(olds, oldsFull, moved.size(), 0.0, 0.0, Imgproc.INTER_NEAREST)
        val nearOldM = Mat()
        val kOld = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(4.0 * band + 1, 4.0 * band + 1))
        Imgproc.dilate(oldsFull.submat(rect), nearOldM, kOld)
        kOld.release(); oldsFull.release()
        val nearOld = ByteArray(n).also { nearOldM.get(0, 0, it) }
        nearOldM.release()
        val result = FloatArray(n) { i ->
            var a = if (outer[i].toInt() != 0 && inner[i].toInt() == 0) snappedF[i] else first[i]
            if (nearOld[i].toInt() != 0) a = ((a - 0.5f) * SHARP + 0.5f).coerceIn(0f, 1f)
            if ((validB[i].toInt() and 0xff) > 128) a.coerceIn(0f, 1f) else 0f
        }
        val alpha = Mat(ch, cw, CvType.CV_32FC1).apply { put(0, 0, result) }
        Imgproc.GaussianBlur(alpha, alpha, Size(0.0, 0.0), 0.8)
        debug?.let { out ->
            val full = Mat.zeros(moved.size(), CvType.CV_8UC1)
            val part = Mat()
            alpha.convertTo(part, CvType.CV_8UC1, 255.0)
            part.copyTo(full.submat(rect))
            out("alpha$tag", full)
            part.release(); full.release()
        }
        return alpha to rect
    }

    /** He et al.'s guided filter with a one-channel guide; both inputs CV_32F, values 0..1. */
    private fun guidedFilter(guide: Mat, src: Mat, r: Int, eps: Double): Mat {
        fun box(m: Mat) = Mat().also {
            Imgproc.boxFilter(m, it, -1, Size(2.0 * r + 1, 2.0 * r + 1), Point(-1.0, -1.0), true, Core.BORDER_REPLICATE)
        }
        val tmp = Mat()
        val meanI = box(guide); val meanP = box(src)
        Core.multiply(guide, guide, tmp); val corrI = box(tmp)
        Core.multiply(guide, src, tmp); val corrIP = box(tmp)
        Core.multiply(meanI, meanI, tmp)
        val varI = Mat(); Core.subtract(corrI, tmp, varI)
        Core.multiply(meanI, meanP, tmp)
        val covIP = Mat(); Core.subtract(corrIP, tmp, covIP)
        Core.add(varI, Scalar(eps), varI)
        val a = Mat(); Core.divide(covIP, varI, a)
        Core.multiply(a, meanI, tmp)
        val b = Mat(); Core.subtract(meanP, tmp, b)
        val meanA = box(a); val meanB = box(b)
        val q = Mat(); Core.multiply(meanA, guide, q); Core.add(q, meanB, q)
        Core.min(q, Scalar(1.0), q); Core.max(q, Scalar(0.0), q)
        listOf(tmp, meanI, meanP, corrI, corrIP, varI, covIP, a, b, meanA, meanB).forEach { it.release() }
        return q
    }

    /**
     * [moved] with its light made to continue shot 1's around the person (Poisson cloning). Two
     * phone shots differ in more than one overall gain (auto-exposure follows who is in frame, the
     * wall near a newcomer is brighter or darker, the white balance drifts), and without this the
     * newcomer's rim shows as a bright or dark outline. The cloning boundary lies in the background
     * just outside the person, where both shots show the same thing. A copy of [moved].
     */
    private fun harmonize(shot1: Mat, moved: Mat, alpha: Mat, rect: Rect): Mat {
        val result = moved.clone()
        val pad = 16
        val side = max(moved.rows(), moved.cols())
        val reach = max(15, (HARMONY_REACH * side).roundToInt())
        val solid = Mat(); val solid8 = Mat(); val mask = Mat()
        val ker = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(2.0 * reach + 1, 2.0 * reach + 1))
        val src = Mat(); val dst = Mat(); val padded = Mat(); val cloned = Mat()
        try {
            Imgproc.threshold(alpha, solid, 0.5, 255.0, Imgproc.THRESH_BINARY)
            solid.convertTo(solid8, CvType.CV_8UC1)
            Imgproc.dilate(solid8, mask, ker)
            Core.copyMakeBorder(moved.submat(rect), src, pad, pad, pad, pad, Core.BORDER_REPLICATE)
            Core.copyMakeBorder(shot1.submat(rect), dst, pad, pad, pad, pad, Core.BORDER_REPLICATE)
            Core.copyMakeBorder(mask, padded, pad, pad, pad, pad, Core.BORDER_CONSTANT, Scalar(0.0))
            val box = Imgproc.boundingRect(padded)
            if (box.width == 0 || box.height == 0) return result
            Photo.seamlessClone(
                src, dst, padded, Point(box.x + box.width / 2.0, box.y + box.height / 2.0),
                cloned, Photo.NORMAL_CLONE,
            )
            // What Poisson changed is a smooth correction; keep it at the rim, where the outline
            // would show, and fade it out going into the person so they keep the look they were
            // taken with.
            val depth = Mat()
            Imgproc.distanceTransform(solid8, depth, Imgproc.DIST_L2, 3)
            val n = rect.width * rect.height
            val d = FloatArray(n).also { depth.get(0, 0, it) }
            depth.release()
            val before = ByteArray(n * 3).also { moved.submat(rect).get(0, 0, it) }
            val after = ByteArray(n * 3)
            cloned.submat(Rect(pad, pad, rect.width, rect.height)).get(0, 0, after)
            val fade = HARMONY_FADE * side
            val mixed = ByteArray(n * 3)
            for (y in 0 until rect.height) for (x in 0 until rect.width) {
                val wgt = exp(-d[y * rect.width + x] / fade)
                for (c in 0 until 3) {
                    val i = (y * rect.width + x) * 3 + c
                    val a = before[i].toInt() and 0xff
                    val b = after[i].toInt() and 0xff
                    mixed[i] = (a + (b - a) * wgt).roundToInt().coerceIn(0, 255).toByte()
                }
            }
            result.submat(rect).put(0, 0, mixed)
        } catch (e: CvException) {
            // Keep the picture as it is: better a faint rim than no merge.
        } finally {
            listOf(solid, solid8, mask, ker, src, dst, padded, cloned).forEach { it.release() }
        }
        return result
    }

    /** shot1 with [moved] laid over it by [alpha], which covers [rect] only. */
    private fun blend(shot1: Mat, moved: Mat, alpha: Mat, rect: Rect): Mat {
        val out = shot1.clone()
        val a = Mat(); val b = Mat(); val inv = Mat(); val alpha3 = Mat()
        Core.merge(listOf(alpha, alpha, alpha), alpha3)
        val ones = Mat(alpha3.size(), alpha3.type(), Scalar(1.0, 1.0, 1.0))
        Core.subtract(ones, alpha3, inv)
        shot1.submat(rect).convertTo(a, CvType.CV_32FC3)
        moved.submat(rect).convertTo(b, CvType.CV_32FC3)
        Core.multiply(a, inv, a); Core.multiply(b, alpha3, b); Core.add(a, b, a)
        a.convertTo(out.submat(rect), CvType.CV_8UC3)
        listOf(a, b, inv, alpha3, ones).forEach { it.release() }
        return out
    }

    /**
     * Black strips along the edge of shot 1 (a camera or crop that left no picture there) are
     * filled from shot 2 where it has one, so the result has no dark band.
     */
    private fun fillBlackBorders(image: Mat, moved: Mat, valid: Mat) {
        val w = image.cols(); val h = image.rows()
        val min = max(6, max(w, h) / 200)
        val dark = Mat(); val gray = Mat()
        Imgproc.cvtColor(image, gray, Imgproc.COLOR_BGR2GRAY)
        Imgproc.threshold(gray, dark, 6.0, 1.0, Imgproc.THRESH_BINARY_INV)
        gray.release()
        val cols = Mat(); val rows = Mat()
        Core.reduce(dark, cols, 0, Core.REDUCE_AVG, CvType.CV_32F)
        Core.reduce(dark, rows, 1, Core.REDUCE_AVG, CvType.CV_32F)
        dark.release()
        val c = FloatArray(w).also { cols.get(0, 0, it) }
        val r = FloatArray(h).also { rows.get(0, 0, it) }
        cols.release(); rows.release()
        fun run(v: FloatArray, fromEnd: Boolean): Int {
            var n = 0
            while (n < v.size / 4 && v[if (fromEnd) v.size - 1 - n else n] > 0.97f) n++
            return if (n >= min) min(v.size, n + 2) else 0
        }
        val left = run(c, false); val right = run(c, true)
        val top = run(r, false); val bottom = run(r, true)
        val strips = listOf(
            Rect(0, 0, left, h), Rect(w - right, 0, right, h),
            Rect(0, 0, w, top), Rect(0, h - bottom, w, bottom),
        ).filter { it.width > 0 && it.height > 0 }
        for (strip in strips) {
            val from = moved.submat(strip); val into = image.submat(strip)
            val mv = Mat(); Imgproc.cvtColor(from, mv, Imgproc.COLOR_BGR2GRAY)
            val usable = Mat()
            Imgproc.threshold(mv, usable, 6.0, 255.0, Imgproc.THRESH_BINARY)
            Core.bitwise_and(usable, valid.submat(strip), usable)
            from.copyTo(into, usable)
            mv.release(); usable.release()
        }
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
