package ro.kidtoon.tv.data

import kotlinx.serialization.Serializable

/** Un post TV dintr-o lista M3U. */
data class Channel(
    /** Cheie stabila (tvg-id sau nume + url) folosita pentru favorite / recente. */
    val key: String,
    val name: String,
    val url: String,
    val logo: String?,
    val tvgId: String?,
    val categories: List<String>,
    val userAgent: String?,
    val referrer: String?,
    val sourceName: String,
)

/** O emisiune din ghidul TV (XMLTV). */
data class Programme(
    val start: Long,
    val stop: Long,
    val title: String,
    val description: String?,
) {
    fun isLive(now: Long) = now in start until stop
    fun progress(now: Long): Float =
        if (stop <= start) 0f else ((now - start).toFloat() / (stop - start)).coerceIn(0f, 1f)
}

/** O lista de canale adaugata de utilizator. */
@Serializable
data class PlaylistSource(
    val name: String,
    val url: String,
    val enabled: Boolean = true,
)

/** Rezultatul parsarii unui fisier M3U. */
data class ParsedPlaylist(
    val channels: List<Channel>,
    /** url-tvg / x-tvg-url din antetul #EXTM3U, daca exista. */
    val epgUrls: List<String>,
)
