package com.neobrutalism.neo_brutalism_locket.rewind

// One camera frame, already a JPEG (square, cut when it arrived).
class Frame(
    val timestampNs: Long,
    val jpeg: ByteArray,
    // Clockwise degrees to turn the picture so it stands upright.
    val rotationDegrees: Int,
)

// The last couple of seconds of frames, kept in time order. Plain Kotlin (no
// android.* imports) so the JVM can test it.
//
// ARMED: waiting for the shutter, only the newest [windowBeforeNs] are kept.
// AFTER_PRESS: the shutter went; older frames stay and new ones are added
// until [windowAfterNs] past the press. FROZEN: nothing more is accepted.
class FrameRing(
    private val windowBeforeNs: Long = 2_000_000_000L,
    private val windowAfterNs: Long = 1_000_000_000L,
    // Frames closer together than this are skipped (about 15 frames/second).
    private val minGapNs: Long = 60_000_000L,
    // Hard ceiling on the JPEG bytes held; the oldest frames go first.
    private val maxBytes: Long = 40L * 1024 * 1024,
) {
    enum class State { ARMED, AFTER_PRESS, FROZEN }

    private val frames = ArrayDeque<Frame>()
    private var bytes = 0L
    private var lastAcceptedNs: Long? = null
    private var pressNs = 0L
    private var stateNow = State.ARMED
    private var droppedCount = 0

    val state: State @Synchronized get() = stateNow

    /** Total JPEG bytes held right now. */
    val totalBytes: Long @Synchronized get() = bytes

    /** Frames thrown away to stay under the byte ceiling. */
    val dropped: Int @Synchronized get() = droppedCount

    val size: Int @Synchronized get() = frames.size

    /**
     * Whether a frame stamped [timestampNs] would be kept, so the caller can
     * skip the cost of compressing one that would be thrown away.
     */
    @Synchronized
    fun accepts(timestampNs: Long): Boolean {
        if (stateNow == State.FROZEN) return false
        val last = lastAcceptedNs ?: return true
        return timestampNs - last >= minGapNs
    }

    /** Adds [frame]; false if it was refused (too soon, or already frozen). */
    @Synchronized
    fun offer(frame: Frame): Boolean {
        if (!accepts(frame.timestampNs)) return false
        frames.addLast(frame)
        bytes += frame.jpeg.size
        lastAcceptedNs = frame.timestampNs
        when (stateNow) {
            State.ARMED -> {
                val cutoff = frame.timestampNs - windowBeforeNs
                while (frames.isNotEmpty() && frames.first().timestampNs < cutoff) {
                    bytes -= frames.removeFirst().jpeg.size
                }
            }
            State.AFTER_PRESS ->
                if (frame.timestampNs >= pressNs + windowAfterNs) {
                    stateNow = State.FROZEN
                }
            State.FROZEN -> Unit
        }
        while (bytes > maxBytes && frames.size > 1) {
            bytes -= frames.removeFirst().jpeg.size
            droppedCount++
        }
        return true
    }

    /** The shutter went at [timestampNs] (same clock as the frames). */
    @Synchronized
    fun press(timestampNs: Long) {
        if (stateNow != State.ARMED) return
        pressNs = timestampNs
        stateNow = State.AFTER_PRESS
        val cutoff = timestampNs - windowBeforeNs
        while (frames.isNotEmpty() && frames.first().timestampNs < cutoff) {
            bytes -= frames.removeFirst().jpeg.size
        }
    }

    /** Stops accepting frames without waiting for the full window. */
    @Synchronized
    fun freeze() {
        if (stateNow == State.AFTER_PRESS) stateNow = State.FROZEN
    }

    /** The frames held, oldest first. */
    @Synchronized
    fun snapshot(): List<Frame> = frames.toList()

    /** Back to ARMED with nothing held. */
    @Synchronized
    fun reset() {
        frames.clear()
        bytes = 0
        lastAcceptedNs = null
        pressNs = 0
        stateNow = State.ARMED
        droppedCount = 0
    }

    /** Lets go of the held frames after they were written out; stays put. */
    @Synchronized
    fun release() {
        frames.clear()
        bytes = 0
    }
}
