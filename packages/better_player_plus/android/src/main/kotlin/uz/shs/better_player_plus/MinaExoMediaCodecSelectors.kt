package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import java.util.Locale

/**
 * ExoPlayer [MediaCodecSelector] yardımcıları.
 *
 * Xiaomi/HyperOS'ta yazılım `c2.android.*` H.264 kod çözücüsü bazı canlı
 * yayınlarda U/V (chroma) kanallarını karıştırıp mavi/pembe cilt tonu üretir;
 * `OMX.google.*` yazılım yolu genelde doğru renk uzayı verir.
 */
@UnstableApi
internal object MinaExoMediaCodecSelectors {

    fun forPlayback(
        context: Context,
        preferSoftware: Boolean,
        xiaomiFamily: Boolean,
        compatStore: MinaPlaybackCodecCompatStore,
    ): MediaCodecSelector {
        val base: MediaCodecSelector =
            if (preferSoftware) {
                forPreferSoftware(xiaomiFamily)
            } else {
                MediaCodecSelector.DEFAULT
            }
        return MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
            val infos =
                base.getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder)
            infos.sortedWith(
                compareBy<MediaCodecInfo>(
                    { info -> if (compatStore.isDeprioritized(info.name, mimeType)) 1 else 0 },
                    { info ->
                        if (preferSoftware) {
                            softwareRank(info.name)
                        } else if (info.hardwareAccelerated) {
                            0
                        } else {
                            1
                        }
                    },
                    { info -> info.name },
                ),
            )
        }
    }

    fun forPreferSoftware(xiaomiFamily: Boolean): MediaCodecSelector {
        if (!xiaomiFamily) return MediaCodecSelector.PREFER_SOFTWARE
        return MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
            val all = MediaCodecUtil.getDecoderInfos(
                mimeType,
                requiresSecureDecoder,
                requiresTunnelingDecoder,
            )
            val software = all.filter { !it.hardwareAccelerated }
            if (software.isEmpty()) {
                return@MediaCodecSelector all
            }
            software.sortedWith(
                compareBy(
                    { info -> softwareRank(info.name) },
                    { info -> info.name },
                ),
            )
        }
    }

    private fun softwareRank(name: String): Int {
        val n = name.lowercase(Locale.US)
        return when {
            n.startsWith("omx.google.") -> 0
            n.startsWith("c2.android.") -> 2
            else -> 1
        }
    }
}
