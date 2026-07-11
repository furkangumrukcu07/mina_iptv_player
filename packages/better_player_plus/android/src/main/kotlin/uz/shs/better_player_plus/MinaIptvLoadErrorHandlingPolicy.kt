package uz.shs.better_player_plus

import androidx.media3.common.ParserException
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import java.io.IOException

/**
 * IPTV canlı: Xtream HTTP 456/509 ve bozuk HLS segmentleri için genişletilmiş
 * yeniden deneme politikası.
 */
@UnstableApi
internal class MinaIptvLoadErrorHandlingPolicy(
    private val isLive: Boolean,
) : DefaultLoadErrorHandlingPolicy() {

    override fun getMinimumLoadableRetryCount(dataType: Int): Int {
        return if (isLive) LIVE_MIN_RETRIES else super.getMinimumLoadableRetryCount(dataType)
    }

    override fun getRetryDelayMsFor(loadErrorInfo: LoadErrorHandlingPolicy.LoadErrorInfo): Long {
        val code = httpResponseCode(loadErrorInfo.exception)
        if (code == HTTP_PROVIDER_AUTH || code == HTTP_PROVIDER_LIMIT) {
            // Sağlayıcı limiti / oturum — kısa gecikme ile birkaç deneme.
            return 1_500L
        }
        if (isLive && isMalformedHls(loadErrorInfo.exception)) {
            return 800L
        }
        if (isLive && isTransientNetwork(loadErrorInfo.exception)) {
            // Kısa ağ blip'leri: Exo'nun uzun backoff'u yerine hızlı yeniden dene.
            return 700L
        }
        val base = super.getRetryDelayMsFor(loadErrorInfo)
        return if (isLive) minOf(base, 2_500L).coerceAtLeast(400L) else base
    }

    override fun getFallbackSelectionFor(
        fallbackOptions: LoadErrorHandlingPolicy.FallbackOptions,
        loadErrorInfo: LoadErrorHandlingPolicy.LoadErrorInfo,
    ): LoadErrorHandlingPolicy.FallbackSelection? {
        val code = httpResponseCode(loadErrorInfo.exception)
        if (code == HTTP_PROVIDER_AUTH || code == HTTP_PROVIDER_LIMIT) {
            return null
        }
        return super.getFallbackSelectionFor(fallbackOptions, loadErrorInfo)
    }

    private fun httpResponseCode(cause: IOException): Int {
        var c: Throwable? = cause
        while (c != null) {
            if (c is HttpDataSource.InvalidResponseCodeException) {
                return c.responseCode
            }
            c = c.cause
        }
        return -1
    }

    private fun isMalformedHls(cause: IOException): Boolean {
        var c: Throwable? = cause
        while (c != null) {
            if (c is ParserException) return true
            val msg = c.message?.lowercase() ?: ""
            if (msg.contains("hls") || msg.contains("playlist") || msg.contains("manifest")) {
                return true
            }
            c = c.cause
        }
        return false
    }

    private fun isTransientNetwork(cause: IOException): Boolean {
        var c: Throwable? = cause
        while (c != null) {
            val name = c.javaClass.simpleName.lowercase()
            val msg = c.message?.lowercase() ?: ""
            if (name.contains("timeoutexception") ||
                name.contains("socketexception") ||
                name.contains("unknownhost") ||
                name.contains("interruptedio") ||
                msg.contains("timeout") ||
                msg.contains("connection reset") ||
                msg.contains("connection closed") ||
                msg.contains("broken pipe") ||
                msg.contains("software caused connection abort") ||
                msg.contains("unexpected end of stream")
            ) {
                return true
            }
            c = c.cause
        }
        return false
    }

    companion object {
        private const val LIVE_MIN_RETRIES = 18
        private const val HTTP_PROVIDER_AUTH = 456
        private const val HTTP_PROVIDER_LIMIT = 509
    }
}
