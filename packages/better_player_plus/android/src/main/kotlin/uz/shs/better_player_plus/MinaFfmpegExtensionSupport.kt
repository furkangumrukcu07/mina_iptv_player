package uz.shs.better_player_plus

import androidx.media3.exoplayer.DefaultRenderersFactory

/**
 * FFmpeg extension: TV'de [EXTENSION_RENDERER_MODE_ON] (platform önce, mp2/AC3 tamamlayıcı);
 * AAR yoksa TV'de OFF, telefonda PREFER.
 */
internal object MinaFfmpegExtensionSupport {

    fun extensionRendererMode(isAndroidTv: Boolean): Int {
        if (!isAvailable()) {
            return if (isAndroidTv) {
                DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF
            } else {
                DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
            }
        }
        return if (isAndroidTv) {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON
        } else {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
        }
    }

    fun isAvailable(): Boolean =
        try {
            val clazz = Class.forName("androidx.media3.decoder.ffmpeg.FfmpegLibrary")
            clazz.getMethod("isAvailable").invoke(null) as Boolean
        } catch (_: Exception) {
            false
        }
}
