package uz.shs.better_player_plus

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory

/**
 * **Mina Güvenli Doku Profili** (Texture-Safe Exo Profile) — [MinaIptvRenderersFactory] üzerinden.
 */
@UnstableApi
internal object MinaTvTextureSafeRenderersFactory {

    fun shouldEnable(isAndroidTv: Boolean, preferSoftwareVideoDecoder: Boolean): Boolean =
        isAndroidTv && !preferSoftwareVideoDecoder

    fun build(
        context: Context,
        preferSoftwareVideoDecoder: Boolean,
        isXiaomiFamilyDevice: Boolean,
        extensionRendererMode: Int,
        enableLowLatencyPath: Boolean,
    ): DefaultRenderersFactory =
        MinaIptvRenderersFactory.build(
            context = context,
            preferSoftwareVideoDecoder = preferSoftwareVideoDecoder,
            isXiaomiFamilyDevice = isXiaomiFamilyDevice,
            extensionRendererMode = extensionRendererMode,
            enableLowLatencyPath = enableLowLatencyPath,
            disallowCodecReuse = true,
            textureSafeTvProfile = true,
        )
}
