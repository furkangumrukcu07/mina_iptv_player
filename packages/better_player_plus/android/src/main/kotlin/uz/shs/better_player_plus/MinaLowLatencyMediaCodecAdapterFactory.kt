package uz.shs.better_player_plus

import android.media.MediaFormat
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.mediacodec.DefaultMediaCodecAdapterFactory
import androidx.media3.exoplayer.mediacodec.MediaCodecAdapter
import java.io.IOException
import java.util.Locale

/**
 * API 31+ ve donanım kod çözücüde [MediaFormat.KEY_LOW_LATENCY] (AOSP yazılım `OMX.google` /
 * `c2.android` bu anahtarda sık -1010 verir; atlanır).
 */
@UnstableApi
internal class MinaLowLatencyMediaCodecAdapterFactory(
    context: android.content.Context,
    private val enableLowLatencyHints: Boolean,
) : MediaCodecAdapter.Factory {

    private val delegate = DefaultMediaCodecAdapterFactory(context)

    @Throws(IOException::class)
    override fun createAdapter(configuration: MediaCodecAdapter.Configuration): MediaCodecAdapter {
        if (!enableLowLatencyHints || Build.VERSION.SDK_INT < 31) {
            return delegate.createAdapter(configuration)
        }
        val mime = configuration.format.sampleMimeType ?: ""
        if (!mime.startsWith("video/")) {
            return delegate.createAdapter(configuration)
        }
        val codecName = configuration.codecInfo.name.lowercase(Locale.US)
        // Yazılım kod çözücü: KEY_LOW_LATENCY configure hatası (-1010) — örn. Samsung SM-T530 logları.
        if (codecName.startsWith("omx.google.") ||
            codecName.startsWith("c2.android.")
        ) {
            return delegate.createAdapter(configuration)
        }
        val mf = configuration.mediaFormat
        if (mf.containsKey(MediaFormat.KEY_LOW_LATENCY)) {
            return delegate.createAdapter(configuration)
        }
        return delegate.createAdapter(wrapVideoConfigWithLowLatency(configuration))
    }

    @RequiresApi(31)
    private fun wrapVideoConfigWithLowLatency(
        configuration: MediaCodecAdapter.Configuration,
    ): MediaCodecAdapter.Configuration {
        val copy = MediaFormat(configuration.mediaFormat)
        copy.setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
        return MediaCodecAdapter.Configuration.createForVideoDecoding(
            configuration.codecInfo,
            copy,
            configuration.format,
            configuration.surface,
            configuration.crypto,
        )
    }

    companion object {
        /** Bilinen regresyonlar için model filtresi (gerekirce genişletilir). */
        fun isLowLatencyBlocklisted(): Boolean = false

        fun shouldEnableLowLatencyHeuristics(): Boolean {
            if (Build.VERSION.SDK_INT < 31) return false
            if (isLowLatencyBlocklisted()) return false
            return true
        }
    }
}
