package uz.shs.better_player_plus

import android.content.Context
import android.os.Handler
import androidx.media3.common.Format
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DecoderReuseEvaluation
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoRendererEventListener

/**
 * Zap / kanal değişiminde codec reuse kaynaklı renk bozulması ve takılmayı önler.
 */
internal class MinaNoReuseMediaCodecVideoRenderer(
    context: Context,
    codecAdapterFactory: MediaCodecAdapter.Factory,
    mediaCodecSelector: MediaCodecSelector,
    allowedJoiningTimeMs: Long,
    enableDecoderFallback: Boolean,
    eventHandler: Handler,
    eventListener: VideoRendererEventListener,
) : MediaCodecVideoRenderer(
    context,
    codecAdapterFactory,
    mediaCodecSelector,
    allowedJoiningTimeMs,
    enableDecoderFallback,
    eventHandler,
    eventListener,
    MAX_DROPPED_FRAMES_TO_NOTIFY,
) {
    override fun canReuseCodec(
        codecInfo: MediaCodecInfo,
        oldFormat: Format,
        newFormat: Format,
        keepsCodecOnFlush: Boolean,
    ): DecoderReuseEvaluation =
        DecoderReuseEvaluation(
            codecInfo.name,
            oldFormat,
            newFormat,
            DecoderReuseEvaluation.REUSE_RESULT_NO,
            DecoderReuseEvaluation.DISCARD_REASON_APP_OVERRIDE,
        )

    companion object {
        private const val MAX_DROPPED_FRAMES_TO_NOTIFY = 50
    }
}
