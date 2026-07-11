package uz.shs.better_player_plus

import android.content.Context
import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.source.MediaSource
import uz.shs.better_player_plus.DataSourceUtils.getDataSourceFactory
import uz.shs.better_player_plus.DataSourceUtils.getUserAgent
import uz.shs.better_player_plus.DataSourceUtils.isHTTP

/**
 * Hazır [MediaSource] önbelleği — zap sırasında playlist/manifest hazırlığını atlar.
 */
@UnstableApi
internal object MinaIptvPreloadCoordinator {

    private data class Entry(
        val mediaSource: MediaSource,
        val expiresAtMs: Long,
    )

    private val cache = LinkedHashMap<String, Entry>()
    private const val TTL_MS = 120_000L
    private const val MAX_ENTRIES = 4

    @Synchronized
    fun prepare(
        context: Context,
        url: String?,
        headers: Map<String, String>,
        formatHint: String?,
        cacheKey: String?,
    ) {
        if (url.isNullOrBlank()) return
        evictExpired()
        val key = canonicalKey(url)
        if (cache.containsKey(key)) return

        val uri = Uri.parse(url)
        if (!isHTTP(uri)) return

        val userAgent = getUserAgent(headers)
        val dataSourceFactory =
            getDataSourceFactory(userAgent, headers, MinaIptvHttpProfile.PRELOAD)
        val mediaSource =
            MinaIptvMediaSourceFactory.build(
                uri = uri,
                mediaDataSourceFactory = dataSourceFactory,
                formatHint = formatHint,
                cacheKey = cacheKey,
                context = context,
            )
        while (cache.size >= MAX_ENTRIES) {
            val oldest = cache.keys.firstOrNull() ?: break
            cache.remove(oldest)
        }
        cache[key] = Entry(mediaSource, System.currentTimeMillis() + TTL_MS)
    }

    @Synchronized
    fun tryConsume(url: String?): MediaSource? {
        if (url.isNullOrBlank()) return null
        evictExpired()
        val key = canonicalKey(url)
        val entry = cache.remove(key) ?: return null
        if (System.currentTimeMillis() > entry.expiresAtMs) return null
        return entry.mediaSource
    }

    @Synchronized
    fun cancel(url: String?) {
        if (url.isNullOrBlank()) return
        cache.remove(canonicalKey(url))
    }

    @Synchronized
    private fun evictExpired() {
        val now = System.currentTimeMillis()
        val expired = cache.filterValues { it.expiresAtMs <= now }.keys
        expired.forEach { cache.remove(it) }
    }

    private fun canonicalKey(url: String): String = url.trim()
}
