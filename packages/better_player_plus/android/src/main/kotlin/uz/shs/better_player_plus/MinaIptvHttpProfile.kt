package uz.shs.better_player_plus

/**
 * IPTV HTTP zaman aşımı profilleri (canlı kısa, VOD uzun, ön-yükleme daha kısa).
 */
internal enum class MinaIptvHttpProfile {
    LIVE,
    VOD,
    PRELOAD,
    ;

    val connectTimeoutMs: Int
        get() =
            when (this) {
                LIVE -> 12_000
                PRELOAD -> 10_000
                VOD -> 30_000
            }

    val readTimeoutMs: Int
        get() =
            when (this) {
                LIVE -> 20_000
                PRELOAD -> 15_000
                VOD -> 180_000
            }
}
