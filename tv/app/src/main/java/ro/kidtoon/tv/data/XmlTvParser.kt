package ro.kidtoon.tv.data

import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/** Ghid TV: emisiuni pe canal, cu cautare dupa tvg-id sau dupa nume. */
class Epg(
    private val byId: Map<String, List<Programme>>,
    private val idByName: Map<String, String>,
) {
    fun programmesFor(channel: Channel): List<Programme> {
        channel.tvgId?.let { id ->
            byId[id]?.let { return it }
            // iptv-org foloseste "TVR1.ro@SD"; multe ghiduri doar "TVR1.ro".
            byId[id.substringBefore('@')]?.let { return it }
        }
        val id = idByName[normalize(channel.name)] ?: return emptyList()
        return byId[id].orEmpty()
    }

    fun nowAndNext(channel: Channel, now: Long = System.currentTimeMillis()): Pair<Programme?, Programme?> {
        val list = programmesFor(channel)
        val idx = list.indexOfFirst { it.isLive(now) }
        if (idx < 0) return null to list.firstOrNull { it.start > now }
        return list[idx] to list.getOrNull(idx + 1)
    }

    val isEmpty get() = byId.isEmpty()

    companion object {
        val EMPTY = Epg(emptyMap(), emptyMap())

        fun normalize(name: String): String =
            M3uParser.cleanName(name).lowercase(Locale.ROOT)
                .replace(Regex("""\b(hd|fhd|uhd|4k|sd|tv)\b"""), "")
                .replace(Regex("[^a-z0-9]"), "")

        fun merge(parts: List<Epg>): Epg {
            if (parts.size == 1) return parts[0]
            val ids = HashMap<String, List<Programme>>()
            val names = HashMap<String, String>()
            parts.forEach { ids.putAll(it.byId); names.putAll(it.idByName) }
            return Epg(ids, names)
        }
    }
}

/**
 * Parser XMLTV in flux (fisierele pot avea zeci de MB). Pastreaza doar
 * emisiunile dintr-o fereastra de timp in jurul momentului curent.
 */
object XmlTvParser {
    fun parse(
        input: InputStream,
        now: Long = System.currentTimeMillis(),
        keepPastMs: Long = 3 * 3600_000L,
        keepFutureMs: Long = 36 * 3600_000L,
    ): Epg {
        val parser = XmlPullParserFactory.newInstance().newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(input, null)

        val programmes = HashMap<String, MutableList<Programme>>()
        val idByName = HashMap<String, String>()

        var channelId: String? = null
        var progChannel: String? = null
        var start = 0L
        var stop = 0L
        var title: String? = null
        var desc: String? = null
        var textTarget: String? = null

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> when (parser.name) {
                    "channel" -> channelId = parser.getAttributeValue(null, "id")
                    "display-name" -> if (channelId != null) textTarget = "display-name"
                    "programme" -> {
                        progChannel = parser.getAttributeValue(null, "channel")
                        start = parseTime(parser.getAttributeValue(null, "start"))
                        stop = parseTime(parser.getAttributeValue(null, "stop"))
                        title = null; desc = null
                    }
                    "title" -> if (progChannel != null && title == null) textTarget = "title"
                    "desc" -> if (progChannel != null && desc == null) textTarget = "desc"
                }
                XmlPullParser.TEXT -> {
                    val t = parser.text?.trim().orEmpty()
                    if (t.isNotEmpty()) when (textTarget) {
                        "display-name" -> channelId?.let { idByName.putIfAbsent(Epg.normalize(t), it) }
                        "title" -> title = t
                        "desc" -> desc = t
                    }
                }
                XmlPullParser.END_TAG -> {
                    when (parser.name) {
                        "channel" -> channelId = null
                        "programme" -> {
                            val ch = progChannel
                            val tt = title
                            if (ch != null && tt != null && stop > now - keepPastMs && start < now + keepFutureMs) {
                                programmes.getOrPut(ch) { mutableListOf() } += Programme(start, stop, tt, desc)
                            }
                            progChannel = null
                        }
                    }
                    textTarget = null
                }
            }
            event = parser.next()
        }
        programmes.values.forEach { list -> list.sortBy { it.start } }
        return Epg(programmes, idByName)
    }

    private val formats = ThreadLocal.withInitial {
        listOf(
            SimpleDateFormat("yyyyMMddHHmmss Z", Locale.US),
            SimpleDateFormat("yyyyMMddHHmmss", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") },
            SimpleDateFormat("yyyyMMddHHmm", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") },
        )
    }

    fun parseTime(value: String?): Long {
        if (value.isNullOrBlank()) return 0L
        val v = value.trim()
        for (f in formats.get()!!) {
            runCatching { return f.parse(v)!!.time }
        }
        return 0L
    }
}
