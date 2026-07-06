package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector

/**
 * **Mina Güvenli Doku Profili** (Texture-Safe Exo Profile)
 *
 * Flutter [SurfaceProducer] / texture yolunu korur; Media Tunneling kapalı kalır.
 * Zayıf Android TV kutularında 4K HEVC oynatırken:
 * - donanım kod çözücü yedeklemesi ([setEnableDecoderFallback])
 * - geç kalan kareleri çizmeden atlama (A/V senkronu)
 * - kare birleştirme beklemesini kapatma (güncel kareye yetişme)
 */
@UnstableApi
internal object MinaTvTextureSafeRenderersFactory {
    /**
     * Varsayılan 15 ms yerine daha agresif eşik: dekoder girdisi geç kaldıysa
     * GPU/CPU harcamadan at (4K HEVC takılmasını dondurma yerine kare atlama ile çözer).
     */
    private const val LATE_THRESHOLD_TO_DROP_DECODER_INPUT_US = 8_000L

    /** TV texture yolunda kare birleştirme beklemesi kapalı → senkrona yetiş. */
    private const val ALLOWED_VIDEO_JOINING_TIME_MS = 0L

    fun shouldEnable(isAndroidTv: Boolean, preferSoftwareVideoDecoder: Boolean): Boolean =
        isAndroidTv && !preferSoftwareVideoDecoder

    fun build(
        context: Context,
        preferSoftwareVideoDecoder: Boolean,
        extensionRendererMode: Int,
        enableLowLatencyPath: Boolean,
    ): DefaultRenderersFactory {
        val mediaCodecSelector =
            if (preferSoftwareVideoDecoder) {
                MediaCodecSelector.PREFER_SOFTWARE
            } else {
                MediaCodecSelector.DEFAULT
            }
        val factory =
            object : DefaultRenderersFactory(context) {
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
                .setAllowedVideoJoiningTimeMs(ALLOWED_VIDEO_JOINING_TIME_MS)
                .experimentalSetLateThresholdToDropDecoderInputUs(
                    LATE_THRESHOLD_TO_DROP_DECODER_INPUT_US,
                )
                .apply {
                    if (enableLowLatencyPath) {
                        forceDisableMediaCodecAsynchronousQueueing()
                    }
                }
        return factory
    }
}
