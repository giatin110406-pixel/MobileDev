package com.neobrutalism.neo_brutalism_locket.addme

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.MatOfByte
import org.opencv.imgcodecs.Imgcodecs

/**
 * The Kotlin merger against the Python one (server/eval/add_me_people.py) on held-out pairs from
 * server/eval/add_me_genai.py (seed 11): the same verdict and reason on every pair, and for merges
 * a picture close to the Python result. The two find people with different builds of the selfie
 * model (ML Kit here, MediaPipe there), so the person's outline may differ by a few pixels.
 */
@RunWith(AndroidJUnit4::class)
class AddMeMergerTest {
    private val assets = InstrumentationRegistry.getInstrumentation().context.assets

    @Before fun load() { assertTrue(OpenCVLoader.initLocal()) }

    private fun bytes(name: String) = assets.open("add_me/$name").use { it.readBytes() }

    private fun image(name: String): Mat {
        val buf = MatOfByte(*bytes(name))
        return Imgcodecs.imdecode(buf, Imgcodecs.IMREAD_COLOR).also { buf.release() }
    }

    @Test fun sameVerdictsAndPicturesAsPython() {
        val expected = JSONObject(String(bytes("expected.json")))
        for (name in expected.keys()) {
            val want = expected.getJSONObject(name)
            val shot1 = image("${name}_1.jpg")
            val shot2 = image("${name}_2.jpg")
            val started = System.nanoTime()
            val got = AddMeMerger(AddMe::people).merge(shot1, shot2)
            val ms = (System.nanoTime() - started) / 1e6
            println("ADDME_ROW $name ok=${got.ok} reason=${got.reason} ms=${ms.toInt()} info=${got.info}")
            assertEquals(name, want.getBoolean("ok"), got.ok)
            if (!got.ok) {
                assertEquals(name, want.getString("reason"), got.reason)
            } else {
                val python = image("${name}_python.jpg")
                val diff = Mat()
                Core.absdiff(got.image, python, diff)
                val mean = Core.mean(diff).`val`.take(3).average()
                println("ADDME_ROW $name mean difference to Python ${"%.2f".format(mean)}")
                // Over the whole photo; a person cut a few pixels differently stays well under this.
                assertTrue("$name differs from Python by $mean", mean < 4.0)
                diff.release(); python.release(); got.image!!.release()
            }
            shot1.release(); shot2.release()
        }
    }

    @Test fun channelMergesAndRefuses() {
        val merged = AddMe.merge(bytes("gap_01_1.jpg"), bytes("gap_01_2.jpg"))
        assertEquals(true, merged["ok"])
        assertTrue((merged["image"] as ByteArray).size > 10_000)
        val refused = AddMe.merge(bytes("nobody_00_1.jpg"), bytes("nobody_00_2.jpg"))
        assertEquals(false, refused["ok"])
        assertEquals("no_new_person", refused["reason"])
        assertNull(refused["image"])
    }
}
