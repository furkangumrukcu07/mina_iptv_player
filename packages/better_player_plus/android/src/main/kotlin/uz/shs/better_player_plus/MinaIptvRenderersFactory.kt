package uz.shs.better_player_plus

import android.content.Context
import android.os.Handler
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.video.VideoRendererEventListener

/**
 * IPTV Exo renderers: uyumluluk hafızası, codec reuse yasağı, TV texture-safe ekleri.
 */
@UnstableApi
internal object MinaIptvRenderersFactory {

    private const val LATE_THRESHOLD_TO_DROP_DECODER_INPUT_US = 15_000L
    private const val ALLOWED_VIDEO_JOINING_TIME_MS = 0L

    fun build(
        context: Context,
        preferSoftwareVideoDecoder: Boolean,
        isXiaomiFamilyDevice: Boolean,
        extensionRendererMode: Int,
        enableLowLatencyPath: Boolean,
        disallowCodecReuse: Boolean,
        textureSafeTvProfile: Boolean,
    ): DefaultRenderersFactory {
        val compatStore = MinaPlaybackCodecCompatStore(context)
        val mediaCodecSelector = MinaExoMediaCodecSelectors.forPlayback(
            context = context,
            preferSoftware = preferSoftwareVideoDecoder,
            xiaomiFamily = isXiaomiFamilyDevice,
            compatStore = compatStore,
        )
        val factory =
            object : DefaultRenderersFactory(context) {
                override fun buildVideoRenderers(
                    context: Context,
                    extensionRendererMode: Int,
                    mediaCodecSelector: MediaCodecSelector,
                    enableDecoderFallback: Boolean,
                    eventHandler: Handler,
                    eventListener: VideoRendererEventListener,
                    allowedVideoJoiningTimeMs: Long,
                    out: ArrayList<Renderer>,
                ) {
                    if (disallowCodecReuse) {
                        out.add(
                            MinaNoReuseMediaCodecVideoRenderer(
                                context,
                                codecAdapterFactory,
                                mediaCodecSelector,
                                allowedVideoJoiningTimeMs,
                                enableDecoderFallback,
                                eventHandler,
                                eventListener,
                            ),
                        )
                        buildMiscellaneousRenderers(
                            context,
                            eventHandler,
                            extensionRendererMode,
                            out,
                        )
                    } else {
                        super.buildVideoRenderers(
                            context,
                            extensionRendererMode,
                            mediaCodecSelector,
                            enableDecoderFallback,
                            eventHandler,
                            eventListener,
                            allowedVideoJoiningTimeMs,
                            out,
                        )
                    }
                }

                override fun getCodecAdapterFactory(): MediaCodecAdapter.Factory {
                    return if (enableLowLatencyPath) {
                        MinaLowLatencyMediaCodecAdapterFactory(context, true)
                    } else {
                        super.getCodecAdapterFactory()
                    }
                }
            }
                .setExtensionRendererMode(extensionRendererMode)
                .setMediaCodecSelector(mediaCodecSelector)
                .setEnableDecoderFallback(true)
                .setEnableAudioTrackPlaybackParams(true)

        if (textureSafeTvProfile) {
            factory
                .setAllowedVideoJoiningTimeMs(ALLOWED_VIDEO_JOINING_TIME_MS)
                .experimentalSetLateThresholdToDropDecoderInputUs(
                    LATE_THRESHOLD_TO_DROP_DECODER_INPUT_US,
                )
        }
        if (enableLowLatencyPath) {
            factory.forceDisableMediaCodecAsynchronousQueueing()
        }
        return factory
    }
}
