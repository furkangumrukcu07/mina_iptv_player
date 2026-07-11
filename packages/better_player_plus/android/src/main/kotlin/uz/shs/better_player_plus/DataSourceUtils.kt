package uz.shs.better_player_plus

import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource

@UnstableApi
internal object DataSourceUtils {
    private const val USER_AGENT = "User-Agent"
    private const val USER_AGENT_PROPERTY = "http.agent"

    /**
     * IPTV (M3U veya Xtream URL’leri aynı fabrikayı kullanır).
     * Canlı: kısa timeout; VOD: uzun okuma süresi.
     */

    @JvmStatic
    fun getUserAgent(headers: Map<String, String>?): String? {
        var userAgent = System.getProperty(USER_AGENT_PROPERTY)
        if (headers != null && headers.containsKey(USER_AGENT)) {
            val userAgentHeader = headers[USER_AGENT]
            if (userAgentHeader != null) {
                userAgent = userAgentHeader
            }
        }
        return userAgent
    }

    @JvmStatic
    fun getDataSourceFactory(
        userAgent: String?,
        headers: Map<String, String>?,
        profile: MinaIptvHttpProfile = MinaIptvHttpProfile.VOD,
    ): DataSource.Factory {
        val dataSourceFactory: DataSource.Factory = DefaultHttpDataSource.Factory()
            .setUserAgent(userAgent)
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(profile.connectTimeoutMs)
            .setReadTimeoutMs(profile.readTimeoutMs)
        if (headers != null) {
            val notNullHeaders = mutableMapOf<String, String>()
            headers.forEach { entry ->
                notNullHeaders[entry.key] = entry.value
            }
            (dataSourceFactory as DefaultHttpDataSource.Factory).setDefaultRequestProperties(
                notNullHeaders
            )
        }
        return dataSourceFactory
    }

    @JvmStatic
    fun isHTTP(uri: Uri?): Boolean {
        if (uri == null || uri.scheme == null) {
            return false
        }
        val scheme = uri.scheme
        return scheme == "http" || scheme == "https"
    }
}