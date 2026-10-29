package com.neobrutalism.neo_brutalism_locket.holdframe

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.opencv.android.OpenCVLoader
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.util.Random
import kotlin.math.abs

/** Runs the actual Android OpenCV library, including its native loader. */
@RunWith(AndroidJUnit4::class)
class FrameAlignerTest {
    @Before fun load() { assertTrue(OpenCVLoader.initLocal()) }

    private fun scene(): Mat {
        val image = Mat(320, 320, CvType.CV_8UC1, Scalar(120.0))
        val random = Random(42)
        repeat(200) {
            val x = random.nextInt(300).toDouble()
            val y = random.nextInt(300).toDouble()
            Imgproc.rectangle(image, Point(x,y), Point(x+5+random.nextInt(15), y+5+random.nextInt(15)),
                Scalar(random.nextInt(255).toDouble()), -1)
        }
        return image
    }

    @Test fun sameFrameIsAlignedAndBlankFrameIsRefused() {
        val scene = scene()
        val blank = Mat(320,320,CvType.CV_8UC1,Scalar(120.0))
        FrameAligner().use { aligner ->
            assertTrue(aligner.lock(scene))
            assertTrue(aligner.estimate(scene).aligned)
            assertFalse(aligner.estimate(blank).ok)
            assertFalse(aligner.lock(blank))
        }
        scene.release(); blank.release()
    }

    @Test fun translationAndRotationHaveTheSameSignsAsPython() {
        val scene = scene()
        FrameAligner().use { aligner ->
            assertTrue(aligner.lock(scene))
            for ((dx,dy) in listOf(.12 to 0.0, -.12 to 0.0, 0.0 to .12, 0.0 to -.12)) {
                val matrix = Mat(2,3,CvType.CV_64F)
                matrix.put(0,0,1.0,0.0,dx*320,0.0,1.0,dy*320)
                val moved = Mat()
                Imgproc.warpAffine(scene,moved,matrix,Size(320.0,320.0))
                val result = aligner.estimate(moved)
                assertTrue(result.toString(), result.ok)
                assertEquals(dx,result.dx,.025)
                assertEquals(dy,result.dy,.025)
                moved.release(); matrix.release()
            }
            for (scale in listOf(.87,1.15)) {
                // OpenCV's positive angle is anticlockwise; our positive roll is clockwise.
                val matrix = Imgproc.getRotationMatrix2D(Point(160.0,160.0),-8.0,scale)
                val moved = Mat()
                Imgproc.warpAffine(scene,moved,matrix,Size(320.0,320.0))
                val result = aligner.estimate(moved)
                assertTrue(result.toString(),result.ok)
                assertTrue(abs(result.roll-8.0)<2.0)
                assertEquals(scale,result.scale,.03)
                moved.release(); matrix.release()
            }
        }
        scene.release()
    }
}
