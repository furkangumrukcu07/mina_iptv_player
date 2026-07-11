package uz.shs.better_player_plus

import android.os.Handler
import android.os.Looper
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer

/**
 * Canlı yayında kare/buffering takılması — startup grace ile yanlış reconnect azaltır.
 */
@UnstableApi
internal class MinaIptvVideoStallMonitor(
    private val player: ExoPlayer,
    private val eventSink: QueuingEventSink,
    private val isLiveStream: () -> Boolean,
) : Player.Listener {

    private val handler = Handler(Looper.getMainLooper())
    private var prepareAtMs = 0L
    private var firstFrameAtMs = 0L
    private var lastPositionMs = 0L
    private var lastAdvanceAtMs = 0L
    private var playbackEstablished = false
    private var lastVideoStallEmitMs = 0L
    private var lastBufferingStallEmitMs = 0L
    private var bufferingSinceMs = 0L

    fun onPrepare() {
        prepareAtMs = System.currentTimeMillis()
        lastPositionMs = 0L
        lastAdvanceAtMs = prepareAtMs
        firstFrameAtMs = 0L
        playbackEstablished = false
        bufferingSinceMs = 0L
        scheduleCheck()
    }

    fun release() {
        handler.removeCallbacks(checkRunnable)
        player.removeListener(this)
    }

    override fun onRenderedFirstFrame() {
        firstFrameAtMs = System.currentTimeMillis()
        maybeEmitPlaybackEstablished()
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING -> {
                if (bufferingSinceMs == 0L) {
                    bufferingSinceMs = System.currentTimeMillis()
                }
            }
            Player.STATE_READY -> {
                bufferingSinceMs = 0L
                maybeEmitPlaybackEstablished()
            }
            else -> bufferingSinceMs = 0L
        }
    }

    private val checkRunnable =
        Runnable {
            checkStall()
            scheduleCheck()
        }

    private fun scheduleCheck() {
        handler.removeCallbacks(checkRunnable)
        handler.postDelayed(checkRunnable, POLL_MS)
    }

    private fun checkStall() {
        if (!isLiveStream()) return
        val now = System.currentTimeMillis()
        if (prepareAtMs == 0L) return

        val inStartupGrace = now - prepareAtMs < STARTUP_GRACE_MS && firstFrameAtMs == 0L
        if (inStartupGrace) return

        val pos = player.currentPosition
        if (pos > lastPositionMs + 50L) {
            lastPositionMs = pos
            lastAdvanceAtMs = now
        }

        maybeEmitPlaybackEstablished()

        if (player.isPlaying && player.playbackState == Player.STATE_READY) {
            val threshold =
                if (playbackEstablished) POSITION_STALL_MS else STARTUP_POSITION_STALL_MS
            if (firstFrameAtMs > 0L && now - lastAdvanceAtMs >= threshold) {
                if (now - lastVideoStallEmitMs >= STALL_DEBOUNCE_MS) {
                    lastVideoStallEmitMs = now
                    lastAdvanceAtMs = now
                    emit("videoStall")
                }
            }
        }

        if (bufferingSinceMs > 0L && playbackEstablished) {
            if (now - bufferingSinceMs >= BUFFERING_STALL_MS) {
                if (now - lastBufferingStallEmitMs >= STALL_DEBOUNCE_MS) {
                    lastBufferingStallEmitMs = now
                    bufferingSinceMs = now
                    emit("bufferingStall")
                }
            }
        }
    }

    private fun maybeEmitPlaybackEstablished() {
        if (playbackEstablished) return
        if (!player.isPlaying) return
        if (player.currentPosition <= 0L) return
        playbackEstablished = true
        emit("playbackEstablished")
    }

    private fun emit(eventName: String) {
        val event: MutableMap<String, Any> = HashMap(1)
        event["event"] = eventName
        eventSink.success(event)
    }

    companion object {
        private const val POLL_MS = 1_000L
        private const val STARTUP_GRACE_MS = 12_000L
        // Kısa ağ blip'leri (2–5 sn) stall sayılmasın; Exo kendi rebuffer'ını yapsın.
        private const val POSITION_STALL_MS = 12_000L
        private const val STARTUP_POSITION_STALL_MS = 18_000L
        private const val BUFFERING_STALL_MS = 16_000L
        private const val STALL_DEBOUNCE_MS = 25_000L
    }
}
