package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.common.PlaybackException
import java.util.Locale

/**
 * Cihaz + codec başına öğrenen uyumluluk hafızası.
 * ≥3 hata → codec sıralamada geriye atılır.
 */
internal class MinaPlaybackCodecCompatStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun recordDecoderFailure(codecName: String, mimeType: String) {
        val key = storageKey(codecName, mimeType)
        val next = prefs.getInt(key, 0) + 1
        prefs.edit().putInt(key, next).apply()
    }

    fun failureCount(codecName: String, mimeType: String): Int =
        prefs.getInt(storageKey(codecName, mimeType), 0)

    fun isDeprioritized(codecName: String, mimeType: String): Boolean =
        failureCount(codecName, mimeType) >= DEPRIORITIZE_THRESHOLD

    fun recordFromPlaybackException(error: PlaybackException) {
        val text = buildString {
            append(error.errorCodeName)
            append(' ')
            append(error.message ?: "")
            error.cause?.let { append(' ').append(it.message ?: "") }
        }.lowercase(Locale.US)
        if (!looksLikeDecoderFailure(text)) return
        val mime = extractMime(text) ?: "video/*"
        extractCodecNames(text).forEach { recordDecoderFailure(it, mime) }
    }

    private fun storageKey(codecName: String, mimeType: String): String {
        val c = codecName.trim().lowercase(Locale.US).take(96)
        val m = mimeType.trim().lowercase(Locale.US).take(48)
        return "$m|$c"
    }

    private fun looksLikeDecoderFailure(text: String): Boolean =
        text.contains("mediacodec") ||
            text.contains("decoder") ||
            text.contains("codec") ||
            text.contains("omx.") ||
            text.contains("c2.")

    private fun extractMime(text: String): String? {
        for (token in listOf("video/avc", "video/hevc", "video/mp2t", "video/mp4")) {
            if (text.contains(token)) return token
        }
        return null
    }

    private fun extractCodecNames(text: String): List<String> {
        val out = mutableListOf<String>()
        val patterns = listOf(
            Regex("""(omx\.[a-z0-9._-]+)"""),
            Regex("""(c2\.[a-z0-9._-]+)"""),
            Regex("""(ffmpeg[a-z0-9._-]*)"""),
        )
        for (re in patterns) {
            re.findAll(text).forEach { m ->
                val name = m.groupValues[1]
                if (name.isNotBlank()) out.add(name)
            }
        }
        return out.distinct()
    }

    companion object {
        private const val PREFS = "mina_exo_codec_compat_v1"
        private const val DEPRIORITIZE_THRESHOLD = 3
    }
}
