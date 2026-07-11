package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.common.PlaybackException
import java.security.MessageDigest
import java.util.Locale

/**
 * URL + ses mime başına FFmpeg/SW ses öğrenme hafızası (AC3/DTS donanım hataları).
 */
internal class MinaAudioCompatStore(context: Context) {

    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun shouldPreferFfmpegAudio(url: String?): Boolean {
        val key = urlKey(url) ?: return false
        return prefs.getInt(key, 0) >= PREFER_FFMPEG_THRESHOLD
    }

    fun recordAudioFailure(url: String?, error: PlaybackException) {
        val key = urlKey(url) ?: return
        val text = buildString {
            append(error.errorCodeName)
            append(' ')
            append(error.message ?: "")
            error.cause?.let { append(' ').append(it.message ?: "") }
        }.lowercase(Locale.US)
        if (!looksLikeAudioFailure(text)) return
        val next = prefs.getInt(key, 0) + 1
        prefs.edit().putInt(key, next).apply()
    }

    private fun urlKey(url: String?): String? {
        if (url.isNullOrBlank()) return null
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(url.trim().toByteArray(Charsets.UTF_8))
        return hash.joinToString("") { "%02x".format(it) }.take(32)
    }

    private fun looksLikeAudioFailure(text: String): Boolean =
        text.contains("audio") ||
            text.contains("ac3") ||
            text.contains("eac3") ||
            text.contains("dts") ||
            text.contains("ffmpeg") ||
            (text.contains("decoder") && text.contains("audio"))

    companion object {
        private const val PREFS = "mina_exo_audio_compat_v1"
        private const val PREFER_FFMPEG_THRESHOLD = 2
    }
}
