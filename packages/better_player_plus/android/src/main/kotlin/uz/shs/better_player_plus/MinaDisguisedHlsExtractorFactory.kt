package uz.shs.better_player_plus

import android.net.Uri
import androidx.media3.common.Format
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.analytics.PlayerId
import androidx.media3.exoplayer.hls.BundledHlsMediaChunkExtractor
import androidx.media3.exoplayer.hls.DefaultHlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsExtractorFactory
import androidx.media3.exoplayer.hls.HlsMediaChunkExtractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor
import java.io.IOException
import java.util.Locale

/**
 * Vidmody vb. aggregator HLS: segmentler `.jpg` / `.gif` uzantılı ama içerik MPEG-TS
 * (0x47 sync). Varsayılan Exo seçimi JPEG/GIF extractor'a düşer → "Source error".
 * Bu fabrika bu uzantılarda doğrudan [TsExtractor] (HLS modu) kullanır.
 */
@UnstableApi
internal class MinaDisguisedHlsExtractorFactory(
    private val delegate: DefaultHlsExtractorFactory,
) : HlsExtractorFactory {

    override fun createExtractor(
        uri: Uri,
        format: Format,
        muxedCaptionFormats: MutableList<Format>?,
        timestampAdjuster: androidx.media3.common.util.TimestampAdjuster,
        responseHeaders: MutableMap<String, MutableList<String>>,
        sniffingExtractorInput: ExtractorInput,
        playerId: PlayerId,
    ): HlsMediaChunkExtractor {
        if (isDisguisedTsSegmentUri(uri)) {
            val tsExtractor =
                TsExtractor(
                    TsExtractor.MODE_HLS,
                    timestampAdjuster,
                    DefaultTsPayloadReaderFactory(
                        MinaIptvExtractorsFactory.iptvTsPayloadReaderFlags,
                    ),
                )
            return BundledHlsMediaChunkExtractor(tsExtractor, format, timestampAdjuster)
        }
        return delegate.createExtractor(
            uri,
            format,
            muxedCaptionFormats,
            timestampAdjuster,
            responseHeaders,
            sniffingExtractorInput,
            playerId,
        )
    }

    override fun setSubtitleParserFactory(
        subtitleParserFactory: androidx.media3.extractor.text.SubtitleParser.Factory,
    ): HlsExtractorFactory {
        delegate.setSubtitleParserFactory(subtitleParserFactory)
        return this
    }

    override fun experimentalParseSubtitlesDuringExtraction(
        parseSubtitlesDuringExtraction: Boolean,
    ): HlsExtractorFactory {
        delegate.experimentalParseSubtitlesDuringExtraction(parseSubtitlesDuringExtraction)
        return this
    }

    override fun experimentalSetCodecsToParseWithinGopSampleDependencies(
        codecsToParseWithinGopSampleDependencies: Int,
    ): HlsExtractorFactory {
        delegate.experimentalSetCodecsToParseWithinGopSampleDependencies(
            codecsToParseWithinGopSampleDependencies,
        )
        return this
    }

    override fun getOutputTextFormat(format: Format): Format =
        delegate.getOutputTextFormat(format)

    companion object {
        private val DISGUISED_SEGMENT =
            Regex("""\.(gif|jpe?g|webp)$""", RegexOption.IGNORE_CASE)

        fun isDisguisedTsSegmentUri(uri: Uri?): Boolean {
            val path = uri?.path?.lowercase(Locale.US) ?: return false
            return DISGUISED_SEGMENT.containsMatchIn(path)
        }
    }
}
