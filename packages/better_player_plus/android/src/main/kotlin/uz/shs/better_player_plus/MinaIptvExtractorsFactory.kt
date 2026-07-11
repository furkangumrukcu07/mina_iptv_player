package uz.shs.better_player_plus

import androidx.media3.common.Format
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor

/**
 * IPTV MPEG-TS: canlı progressive `.ts` için TsExtractor.
 * MODE_SINGLE_PMT (MODE_HLS progressive'de seek() IllegalStateException atar).
 * CBR seeking kapalı. Canlıda ayrıca [MinaLiveMpegTsSupport] kullanılır.
 */
@UnstableApi
internal object MinaIptvExtractorsFactory {

    private val TS_SUBTITLE_FORMATS = listOf(
        Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_CEA608).build(),
        Format.Builder().setSampleMimeType(MimeTypes.APPLICATION_CEA708).build(),
    )

    /** Canlı TS payload: access unit + non-IDR keyframe (FLAG_ALLOW_NON_KEYFRAME tarzı). */
    val iptvTsPayloadReaderFlags: Int =
        DefaultTsPayloadReaderFactory.FLAG_DETECT_ACCESS_UNITS or
            DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES or
            DefaultTsPayloadReaderFactory.FLAG_IGNORE_SPLICE_INFO_STREAM

    fun create(liveMpegTs: Boolean): DefaultExtractorsFactory {
        val factory = DefaultExtractorsFactory()
            .setConstantBitrateSeekingEnabled(false)
            .setConstantBitrateSeekingAlwaysEnabled(false)
        if (!liveMpegTs) return factory
        return factory
            .setTsExtractorMode(TsExtractor.MODE_SINGLE_PMT)
            .setTsExtractorFlags(iptvTsPayloadReaderFlags)
            .setTsSubtitleFormats(TS_SUBTITLE_FORMATS)
    }
}

