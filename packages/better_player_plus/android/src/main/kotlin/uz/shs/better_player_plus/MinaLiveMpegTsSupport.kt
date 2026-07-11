package uz.shs.better_player_plus

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.util.TimestampAdjuster
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.extractor.Extractor
import androidx.media3.extractor.ExtractorInput
import androidx.media3.extractor.ExtractorOutput
import androidx.media3.extractor.ExtractorsFactory
import androidx.media3.extractor.PositionHolder
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor
import java.io.IOException

/**
 * Canlı progressive MPEG-TS (Better/Exo):
 *
 * 1) Bazı paneller `.ts` için Content-Length gönderir → TsExtractor track keşfi
 *    sonrası `pendingSeekToStart` + `seek(0)` → canlı pencerede Source error /
 *    [TsExtractor.seek] IllegalStateException (özellikle MODE_HLS).
 * 2) Bu yüzden DataSource uzunluğu [C.LENGTH_UNSET] maskelenir ve seek
 *    IllegalStateException yutulur; extractor [MODE_SINGLE_PMT] kalır
 *    (MODE_HLS progressive'de seek yasak).
 */
@UnstableApi
internal object MinaLiveMpegTsSupport {
    private const val TAG = "MinaLiveMpegTs"

    fun extractorsFactory(): ExtractorsFactory =
        ExtractorsFactory {
            arrayOf(
                SafeSeekTsExtractor(
                    TsExtractor(
                        TsExtractor.MODE_SINGLE_PMT,
                        TimestampAdjuster(0),
                        DefaultTsPayloadReaderFactory(
                            MinaIptvExtractorsFactory.iptvTsPayloadReaderFlags,
                        ),
                    ),
                ),
            )
        }

    fun unboundedDataSourceFactory(
        upstream: DataSource.Factory,
    ): DataSource.Factory = DataSource.Factory {
        UnboundedLengthDataSource(upstream.createDataSource())
    }

    /** HTTP Content-Length'i gizle → canlıda seek-to-start tetiklenmesin. */
    private class UnboundedLengthDataSource(
        private val upstream: DataSource,
    ) : DataSource {
        override fun addTransferListener(transferListener: TransferListener) {
            upstream.addTransferListener(transferListener)
        }

        @Throws(IOException::class)
        override fun open(dataSpec: DataSpec): Long {
            upstream.open(dataSpec)
            return C.LENGTH_UNSET.toLong()
        }

        @Throws(IOException::class)
        override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
            upstream.read(buffer, offset, length)

        override fun getUri() = upstream.uri

        override fun getResponseHeaders(): MutableMap<String, MutableList<String>> =
            upstream.responseHeaders

        @Throws(IOException::class)
        override fun close() {
            upstream.close()
        }
    }

    /** ProgressiveMediaPeriod seek çağrılarını canlı TS için güvenli tut. */
    private class SafeSeekTsExtractor(
        private val delegate: TsExtractor,
    ) : Extractor {
        override fun sniff(input: ExtractorInput): Boolean = delegate.sniff(input)

        override fun init(output: ExtractorOutput) {
            delegate.init(output)
        }

        override fun seek(position: Long, timeUs: Long) {
            try {
                delegate.seek(position, timeUs)
            } catch (e: IllegalStateException) {
                Log.w(TAG, "TsExtractor.seek ignored (live MPEG-TS): $e")
            }
        }

        @Throws(IOException::class)
        override fun read(input: ExtractorInput, seekPosition: PositionHolder): Int =
            delegate.read(input, seekPosition)

        override fun release() {
            delegate.release()
        }
    }
}
