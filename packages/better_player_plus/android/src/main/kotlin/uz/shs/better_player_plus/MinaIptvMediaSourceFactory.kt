package uz.shs.better_player_plus

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.dash.DefaultDashChunkSource
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.smoothstreaming.DefaultSsChunkSource
import androidx.media3.exoplayer.smoothstreaming.SsMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import java.util.Locale

@UnstableApi
internal object MinaIptvMediaSourceFactory {

    const val FORMAT_SS = "ss"
    const val FORMAT_DASH = "dash"
    const val FORMAT_HLS = "hls"
    const val FORMAT_OTHER = "other"

    fun isLikelyLiveIptvUrl(uri: Uri?, formatHint: String?): Boolean {
        val raw = uri?.toString()?.lowercase(Locale.US) ?: return formatHint == FORMAT_HLS
        return raw.contains("/live/") ||
            raw.contains("output=ts") ||
            raw.contains("output=m3u8") ||
            raw.endsWith(".ts") ||
            raw.contains(".m3u8") ||
            formatHint == FORMAT_HLS
    }

    fun isLikelyMpegTsUrl(uri: Uri?): Boolean {
        val raw = uri?.toString()?.lowercase(Locale.US) ?: return false
        return raw.endsWith(".ts") ||
            raw.contains("output=ts") ||
            raw.contains("ext=ts") ||
            raw.contains("type=ts")
    }

    fun isLikelyHlsUrl(uri: Uri?): Boolean {
        val raw = uri?.toString()?.lowercase(Locale.US) ?: return false
        return raw.contains(".m3u8") ||
            raw.contains("output=m3u8") ||
            raw.contains("output=m3u") ||
            raw.contains("type=m3u8") ||
            raw.contains("ext=m3u8")
    }

    fun resolveContentType(uri: Uri?, formatHint: String?): Int {
        when (formatHint) {
            FORMAT_SS -> return C.CONTENT_TYPE_SS
            FORMAT_DASH -> return C.CONTENT_TYPE_DASH
            FORMAT_HLS -> return C.CONTENT_TYPE_HLS
            FORMAT_OTHER -> return C.CONTENT_TYPE_OTHER
        }
        // formatHint yok: uzantıdan önce URL'de HLS ipucu (TsExtractor yanlış yolunu kes).
        if (isLikelyHlsUrl(uri)) return C.CONTENT_TYPE_HLS
        if (isLikelyMpegTsUrl(uri)) return C.CONTENT_TYPE_OTHER

        var lastPathSegment = uri?.lastPathSegment ?: ""
        // Query'yi düş (channel.m3u8?token=…).
        val q = lastPathSegment.indexOf('?')
        if (q >= 0) lastPathSegment = lastPathSegment.substring(0, q)
        val parts = lastPathSegment.split(".")
        if (parts.size < 2) {
            return C.CONTENT_TYPE_OTHER
        }
        return Util.inferContentTypeForExtension(parts.last())
    }

    fun build(
        uri: Uri?,
        mediaDataSourceFactory: DataSource.Factory,
        formatHint: String?,
        cacheKey: String?,
        context: Context,
        drmSessionManager: DrmSessionManager? = null,
    ): MediaSource {
        val type = resolveContentType(uri, formatHint)
        val mediaItemBuilder = MediaItem.Builder().setUri(uri)
        if (!cacheKey.isNullOrEmpty()) {
            mediaItemBuilder.setCustomCacheKey(cacheKey)
        }
        // Exo'ya net MIME: HLS'de Progressive/TsExtractor ile başlamayı engeller.
        when (type) {
            C.CONTENT_TYPE_HLS ->
                mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
            C.CONTENT_TYPE_DASH ->
                mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
            C.CONTENT_TYPE_SS ->
                mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_SS)
            C.CONTENT_TYPE_OTHER ->
                if (isLikelyMpegTsUrl(uri)) {
                    // Canlı taşıma akışı — mp4/mkv progressive sanılmasın.
                    mediaItemBuilder.setMimeType(MimeTypes.VIDEO_MP2T)
                    if (isLikelyLiveIptvUrl(uri, formatHint)) {
                        mediaItemBuilder.setLiveConfiguration(
                            MediaItem.LiveConfiguration.Builder().build(),
                        )
                    }
                }
        }
        val mediaItem = mediaItemBuilder.build()
        val drmSessionManagerProvider: DrmSessionManagerProvider? =
            drmSessionManager?.let { manager ->
                DrmSessionManagerProvider { manager }
            }

        return when (type) {
            C.CONTENT_TYPE_SS ->
                SsMediaSource.Factory(
                    DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                    DefaultDataSource.Factory(context, mediaDataSourceFactory),
                ).apply {
                    if (drmSessionManagerProvider != null) {
                        setDrmSessionManagerProvider(drmSessionManagerProvider)
                    }
                }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_DASH ->
                DashMediaSource.Factory(
                    DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                    DefaultDataSource.Factory(context, mediaDataSourceFactory),
                ).apply {
                    if (drmSessionManagerProvider != null) {
                        setDrmSessionManagerProvider(drmSessionManagerProvider)
                    }
                }.createMediaSource(mediaItem)

            C.CONTENT_TYPE_HLS -> {
                val isLive = isLikelyLiveIptvUrl(uri, formatHint)
                val defaultFactory =
                    DefaultHlsExtractorFactory(
                        MinaIptvExtractorsFactory.iptvTsPayloadReaderFlags,
                        false,
                    )
                val hlsExtractorFactory =
                    MinaDisguisedHlsExtractorFactory(defaultFactory)
                HlsMediaSource.Factory(mediaDataSourceFactory)
                    .setAllowChunklessPreparation(true)
                    .setExtractorFactory(hlsExtractorFactory)
                    .setLoadErrorHandlingPolicy(MinaIptvLoadErrorHandlingPolicy(isLive))
                    .apply {
                        if (drmSessionManagerProvider != null) {
                            setDrmSessionManagerProvider(drmSessionManagerProvider)
                        }
                    }.createMediaSource(mediaItem)
            }

            C.CONTENT_TYPE_OTHER -> {
                val liveTs = isLikelyMpegTsUrl(uri) &&
                    isLikelyLiveIptvUrl(uri, formatHint)
                val dataFactory = if (liveTs) {
                    MinaLiveMpegTsSupport.unboundedDataSourceFactory(
                        mediaDataSourceFactory,
                    )
                } else {
                    mediaDataSourceFactory
                }
                val extractors = if (liveTs) {
                    MinaLiveMpegTsSupport.extractorsFactory()
                } else {
                    MinaIptvExtractorsFactory.create(
                        liveMpegTs = isLikelyMpegTsUrl(uri),
                    )
                }
                ProgressiveMediaSource.Factory(dataFactory, extractors)
                    .apply {
                        if (drmSessionManagerProvider != null) {
                            setDrmSessionManagerProvider(drmSessionManagerProvider)
                        }
                    }.createMediaSource(mediaItem)
            }

            else -> throw IllegalStateException("Unsupported type: $type")
        }
    }
}
