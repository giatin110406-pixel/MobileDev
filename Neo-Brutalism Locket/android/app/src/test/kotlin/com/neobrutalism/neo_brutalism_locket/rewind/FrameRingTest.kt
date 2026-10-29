package com.neobrutalism.neo_brutalism_locket.rewind

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameRingTest {
    private val ms = 1_000_000L

    private fun frame(tsMs: Long, size: Int = 10) =
        Frame(tsMs * ms, ByteArray(size), 90)

    @Test
    fun armedKeepsOnlyTheLastTwoSeconds() {
        val ring = FrameRing()
        for (t in 0..4000 step 100) ring.offer(frame(t.toLong()))
        val kept = ring.snapshot().map { it.timestampNs / ms }
        assertEquals(2000L, kept.first())
        assertEquals(4000L, kept.last())
        assertEquals(21, kept.size)
        assertEquals(FrameRing.State.ARMED, ring.state)
    }

    @Test
    fun afterPressAcceptsUntilOneSecondPastThenFreezes() {
        val ring = FrameRing()
        for (t in 0..3000 step 100) ring.offer(frame(t.toLong()))
        ring.press(3000 * ms)
        assertEquals(FrameRing.State.AFTER_PRESS, ring.state)
        for (t in 3100..3900 step 100) {
            assertTrue(ring.offer(frame(t.toLong())))
            assertEquals(FrameRing.State.AFTER_PRESS, ring.state)
        }
        // Older frames are not dropped while waiting.
        assertEquals(1000L, ring.snapshot().first().timestampNs / ms)
        assertTrue(ring.offer(frame(4000)))
        assertEquals(FrameRing.State.FROZEN, ring.state)
        assertEquals(4000L, ring.snapshot().last().timestampNs / ms)
    }

    @Test
    fun framesAfterFrozenAreRefused() {
        val ring = FrameRing()
        ring.offer(frame(0))
        ring.press(0)
        ring.offer(frame(1000))
        assertEquals(FrameRing.State.FROZEN, ring.state)
        assertFalse(ring.accepts(2000 * ms))
        assertFalse(ring.offer(frame(2000)))
        assertEquals(2, ring.size)
    }

    @Test
    fun framesCloserThanTheGapAreSkipped() {
        val ring = FrameRing()
        assertTrue(ring.offer(frame(0)))
        assertFalse(ring.offer(frame(30)))
        assertFalse(ring.offer(frame(59)))
        assertTrue(ring.offer(frame(60)))
        // The gap counts from the last frame kept, not the last one offered.
        assertFalse(ring.offer(frame(100)))
        assertTrue(ring.offer(frame(120)))
        assertEquals(3, ring.size)
    }

    @Test
    fun pressTrimsFramesOlderThanTheWindow() {
        val ring = FrameRing()
        for (t in 0..5000 step 100) ring.offer(frame(t.toLong()))
        // The newest frame lags the press by 300ms.
        ring.press(5300 * ms)
        assertEquals(3300L, ring.snapshot().first().timestampNs / ms)
    }

    @Test
    fun resetGoesBackToArmedAndEmpty() {
        val ring = FrameRing()
        ring.offer(frame(0, 100))
        ring.press(0)
        ring.offer(frame(1500, 100))
        assertEquals(FrameRing.State.FROZEN, ring.state)
        ring.reset()
        assertEquals(FrameRing.State.ARMED, ring.state)
        assertEquals(0, ring.size)
        assertEquals(0L, ring.totalBytes)
        assertEquals(0, ring.dropped)
        // The gap rule starts over too.
        assertTrue(ring.offer(frame(10)))
    }

    @Test
    fun byteCeilingDropsTheOldestAndCountsThem() {
        val ring = FrameRing(maxBytes = 100)
        for (i in 0 until 5) ring.offer(frame(i * 100L, 40))
        assertTrue(ring.totalBytes <= 100)
        assertEquals(2, ring.size)
        assertEquals(3, ring.dropped)
        assertEquals(300L, ring.snapshot().first().timestampNs / ms)
    }

    @Test
    fun freezeStopsWaitingAndOnlyWorksAfterAPress() {
        val ring = FrameRing()
        ring.offer(frame(0))
        // Nothing to freeze while only waiting for the shutter.
        ring.freeze()
        assertEquals(FrameRing.State.ARMED, ring.state)
        ring.press(100 * ms)
        ring.freeze()
        assertEquals(FrameRing.State.FROZEN, ring.state)
        assertFalse(ring.offer(frame(200)))
        assertEquals(1, ring.size)
    }

    @Test
    fun aSecondPressIsIgnoredUntilReset() {
        val ring = FrameRing()
        ring.offer(frame(0))
        ring.press(100 * ms)
        ring.press(900 * ms)
        // Still waiting for the first press's window (100 + 1000).
        assertTrue(ring.offer(frame(1000)))
        assertEquals(FrameRing.State.AFTER_PRESS, ring.state)
        assertTrue(ring.offer(frame(1100)))
        assertEquals(FrameRing.State.FROZEN, ring.state)
    }

    @Test
    fun totalBytesFollowsTheFramesHeld() {
        val ring = FrameRing()
        for (t in 0..4000 step 100) ring.offer(frame(t.toLong(), 7))
        assertEquals(ring.size * 7L, ring.totalBytes)
        ring.release()
        assertEquals(0L, ring.totalBytes)
    }
}
