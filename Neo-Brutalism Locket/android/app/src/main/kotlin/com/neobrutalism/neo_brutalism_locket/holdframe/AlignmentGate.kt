package com.neobrutalism.neo_brutalism_locket.holdframe

/** A fresh sequence of matching frames, never a wall-clock timer, authorises one shot. */
class AlignmentGate {
    private var armed = false
    private var since: Long? = null
    private var last: Long? = null

    fun arm(value: Boolean) {
        armed = value
        since = null
        last = null
    }

    fun offer(aligned: Boolean, timestampMs: Long): Boolean {
        if (!armed) return false
        val previous = last
        if (!aligned || (previous != null &&
                (timestampMs <= previous || timestampMs - previous > 220))) {
            since = null
        }
        last = timestampMs
        if (!aligned) return false
        val start = since ?: timestampMs.also { since = it }
        if (timestampMs - start < 300) return false
        arm(false)
        return true
    }
}
