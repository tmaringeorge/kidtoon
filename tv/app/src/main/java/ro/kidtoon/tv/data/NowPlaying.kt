package ro.kidtoon.tv.data

/**
 * Curata titlul trimis de post in stream (ICY "StreamTitle"): melodia, emisiunea sau
 * un slogan. Intoarce null cand nu e nimic util de afisat.
 */
object NowPlaying {
    fun clean(raw: String?, stationName: String): String? {
        val t = raw?.trim()?.trim('-', '|', ' ', '\u0000')?.replace(Regex("\\s+"), " ") ?: return null
        if (t.length < 2) return null
        if (t.equals(stationName.trim(), ignoreCase = true)) return null
        if (t.all { !it.isLetter() }) return null
        return t
    }
}
