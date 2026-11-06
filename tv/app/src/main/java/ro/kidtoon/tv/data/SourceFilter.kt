package ro.kidtoon.tv.data

import java.net.URI

/**
 * Filtru de siguranta: exclude stream-urile care sunt, cu mare probabilitate,
 * retransmisii neautorizate (restream-uri de pe domenii de unica folosinta,
 * panouri IPTV cu user/parola in URL etc). Listele publice (inclusiv iptv-org)
 * contin uneori astfel de intrari; aplicatia nu le afiseaza.
 */
object SourceFilter {
    private val blockedHostSuffixes = listOf(
        ".cfd", ".sbs", ".click", ".xyz", ".top", ".shop", ".online",
    )
    private val blockedHostParts = listOf(
        "cool-tv", "vip-acasatv", "xykt-fix", "megogo", "vcdn.biz",
    )
    /** /live/user/pass/123.ts sau /user/pass/123.m3u8 = panou Xtream (tipic pentru IPTV pirat). */
    private val xtreamPath = Regex("""/(live/)?[A-Za-z0-9]{4,}/[A-Za-z0-9]{4,}/\d+(\.(ts|m3u8))?$""")

    fun isAllowed(url: String): Boolean {
        val uri = runCatching { URI(url) }.getOrNull() ?: return false
        val host = uri.host?.lowercase() ?: return false
        if (blockedHostSuffixes.any { host.endsWith(it) }) return false
        if (blockedHostParts.any { host.contains(it) }) return false
        if (xtreamPath.containsMatchIn(uri.path.orEmpty())) return false
        return true
    }
}
