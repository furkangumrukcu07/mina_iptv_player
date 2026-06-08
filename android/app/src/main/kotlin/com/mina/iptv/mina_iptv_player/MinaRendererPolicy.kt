package com.mina.iptv.mina_iptv_player

import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.util.Log

/**
 * Kurulum anında cihaz form faktörüne göre Flutter render motoru:
 * - TV kutusu / Android TV / Google TV → Skia (Impeller kapalı)
 * - Tablet → Skia
 * - Telefon → Impeller
 */
object MinaRendererPolicy {
    private const val TAG = "MinaRenderer"

    enum class FormFactor {
        PHONE,
        TABLET,
        TV,
    }

    /** Impeller açık mı? (false → Skia / OpenGL yolu) */
    fun useImpeller(context: Context): Boolean =
        detectFormFactor(context) == FormFactor.PHONE

    fun detectFormFactor(context: Context): FormFactor {
        if (isAndroidTvOrTvBox(context)) return FormFactor.TV
        if (isTablet(context)) return FormFactor.TABLET
        return FormFactor.PHONE
    }

    fun logChoice(context: Context) {
        val factor = detectFormFactor(context)
        val impeller = useImpeller(context)
        Log.i(
            TAG,
            "formFactor=$factor renderer=${if (impeller) "Impeller" else "Skia"} " +
                "swDp=${context.resources.configuration.smallestScreenWidthDp}",
        )
    }

    /**
     * Android TV, Google TV ve leanback TV kutuları.
     * Bazı kutular telefon ROM'u ile gelir; UI modu yine televizyon olabilir.
     */
    fun isAndroidTvOrTvBox(context: Context): Boolean {
        val pm = context.packageManager
        if (pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) return true
        if (pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)) return true
        val ui = context.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        return ui == Configuration.UI_MODE_TYPE_TELEVISION
    }

    /**
     * Android tablet (TV değil): geniş ekran / smallestWidth ≥ 600dp.
     */
    fun isTablet(context: Context): Boolean {
        if (isAndroidTvOrTvBox(context)) return false
        val config = context.resources.configuration
        if (config.smallestScreenWidthDp >= 600) return true
        val screenLayout = config.screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK
        return screenLayout >= Configuration.SCREENLAYOUT_SIZE_LARGE
    }
}
