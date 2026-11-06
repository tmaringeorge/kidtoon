package ro.kidtoon.tv.data

/**
 * Parser pentru liste M3U / M3U8 extinse (formatul folosit de iptv-org si de
 * majoritatea furnizorilor). Suporta tvg-id, tvg-logo, group-title, url-tvg,
 * http-user-agent / http-referrer si liniile #EXTVLCOPT.
 */
object M3uParser {
    private val attrRegex = Regex("""([\w-]+)="([^"]*)"""")

    fun parse(text: String, sourceName: String): ParsedPlaylist {
        val channels = mutableListOf<Channel>()
        val epgUrls = mutableListOf<String>()

        var pendingInfo: String? = null
        var pendingUa: String? = null
        var pendingRef: String? = null
        var pendingGroup: String? = null

        text.lineSequence().forEach { raw ->
            val line = raw.trim()
            when {
                line.isEmpty() -> Unit
                line.startsWith("#EXTM3U") -> {
                    attrs(line).forEach { (k, v) ->
                        if (k == "url-tvg" || k == "x-tvg-url") {
                            epgUrls += v.split(',').map { it.trim() }.filter { it.isNotEmpty() }
                        }
                    }
                }
                line.startsWith("#EXTINF") -> {
                    pendingInfo = line
                    pendingUa = null; pendingRef = null; pendingGroup = null
                }
                line.startsWith("#EXTVLCOPT:") -> {
                    val opt = line.removePrefix("#EXTVLCOPT:")
                    when {
                        opt.startsWith("http-user-agent=") -> pendingUa = opt.substringAfter('=')
                        opt.startsWith("http-referrer=") -> pendingRef = opt.substringAfter('=')
                    }
                }
                line.startsWith("#EXTGRP:") -> pendingGroup = line.substringAfter(':').trim()
                line.startsWith("#") -> Unit
                else -> {
                    val info = pendingInfo
                    if (info != null) {
                        buildChannel(info, line, pendingUa, pendingRef, pendingGroup, sourceName)
                            ?.let { channels += it }
                    }
                    pendingInfo = null
                }
            }
        }
        return ParsedPlaylist(channels, epgUrls.distinct())
    }

    private fun attrs(line: String): Map<String, String> =
        attrRegex.findAll(line).associate { it.groupValues[1].lowercase() to it.groupValues[2] }

    private fun buildChannel(
        info: String, url: String, ua: String?, ref: String?, grp: String?, sourceName: String,
    ): Channel? {
        if (!url.startsWith("http://") && !url.startsWith("https://")) return null
        val a = attrs(info)
        val name = nameOf(info).ifBlank { a["tvg-name"].orEmpty() }.ifBlank { return null }
        val groups = (a["group-title"] ?: grp).orEmpty()
            .split(';')
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.equals("Undefined", true) }
        val tvgId = a["tvg-id"]?.takeIf { it.isNotBlank() }
        return Channel(
            key = (tvgId ?: name) + "|" + url.hashCode().toUInt().toString(16),
            name = cleanName(name),
            url = url,
            logo = a["tvg-logo"]?.takeIf { it.isNotBlank() },
            tvgId = tvgId,
            categories = groups.map(Categories::localize).distinct(),
            userAgent = ua ?: a["http-user-agent"],
            referrer = ref ?: a["http-referrer"],
            sourceName = sourceName,
        )
    }

    /** Numele e dupa prima virgula din afara ghilimelelor (poate contine si el virgule). */
    private fun nameOf(info: String): String {
        var inQuotes = false
        info.forEachIndexed { i, c ->
            if (c == '"') inQuotes = !inQuotes
            else if (c == ',' && !inQuotes) return info.substring(i + 1).trim()
        }
        return ""
    }

    /** Scoate sufixe ca "(1080p)" sau "[Not 24/7]" din numele afisat. */
    fun cleanName(name: String): String =
        name.replace(Regex("""\s*\((\d{3,4}[pi])\)"""), "")
            .replace(Regex("""\s*\[[^\]]*]"""), "")
            .trim()
}

object Categories {
    const val ALL = "Toate"
    const val FAVORITES = "Favorite"
    const val RECENT = "Recente"
    const val OTHER = "Altele"

    private val map = mapOf(
        "general" to "Generaliste",
        "news" to "Știri",
        "sports" to "Sport",
        "music" to "Muzică",
        "religious" to "Religie",
        "culture" to "Cultură",
        "kids" to "Copii",
        "animation" to "Copii",
        "movies" to "Filme",
        "series" to "Seriale",
        "entertainment" to "Divertisment",
        "documentary" to "Documentare",
        "education" to "Educație",
        "lifestyle" to "Lifestyle",
        "cooking" to "Gastronomie",
        "travel" to "Călătorii",
        "business" to "Business",
        "comedy" to "Comedie",
        "science" to "Știință",
        "weather" to "Meteo",
        "auto" to "Auto",
        "outdoor" to "Natură",
        "family" to "Familie",
        "legislative" to "Instituții",
        "shop" to "Teleshopping",
        "classic" to "Clasice",
    )

    fun localize(group: String): String = map[group.lowercase()] ?: group
}
