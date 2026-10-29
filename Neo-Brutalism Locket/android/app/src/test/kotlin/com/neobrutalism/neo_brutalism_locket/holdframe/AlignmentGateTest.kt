package com.neobrutalism.neo_brutalism_locket.holdframe

import org.junit.Assert.*
import org.junit.Test

class AlignmentGateTest {
    @Test fun neverShootsBeforeRecipientArms() {
        val gate = AlignmentGate()
        for (t in 0L..2000L step 100) assertFalse(gate.offer(true, t))
    }

    @Test fun needsThreeHundredMillisecondsAndOnlyShootsOnce() {
        val gate = AlignmentGate()
        gate.arm(true)
        for (t in 0L..200L step 100) assertFalse(gate.offer(true, t))
        assertTrue(gate.offer(true, 300))
        for (t in 400L..1000L step 100) assertFalse(gate.offer(true, t))
    }

    @Test fun unsureOrMisalignedFrameRestartsTheWait() {
        val gate = AlignmentGate()
        gate.arm(true)
        gate.offer(true, 0); gate.offer(true, 100)
        gate.offer(false, 200)
        for (t in 300L..500L step 100) assertFalse(gate.offer(true, t))
        assertTrue(gate.offer(true, 600))
    }

    @Test fun MissingFramesDoNotCountAsBeingAligned() {
        val gate = AlignmentGate()
        gate.arm(true)
        gate.offer(true, 0); gate.offer(true, 100)
        assertFalse(gate.offer(true, 1000))
        assertFalse(gate.offer(true, 1100))
        assertFalse(gate.offer(true, 1200))
        assertTrue(gate.offer(true, 1300))
    }

    @Test fun pauseAndRearmNeedNewFrames() {
        val gate = AlignmentGate()
        gate.arm(true)
        gate.offer(true, 0); gate.offer(true, 100); gate.offer(true, 200)
        gate.arm(false)
        assertFalse(gate.offer(true, 300))
        gate.arm(true)
        for (t in 400L..600L step 100) assertFalse(gate.offer(true, t))
        assertTrue(gate.offer(true, 700))
    }

    @Test fun outOfOrderTimestampsRestartTheWait() {
        val gate = AlignmentGate()
        gate.arm(true)
        gate.offer(true, 1000); gate.offer(true, 1100)
        assertFalse(gate.offer(true, 500))
        assertFalse(gate.offer(true, 600))
    }
}
