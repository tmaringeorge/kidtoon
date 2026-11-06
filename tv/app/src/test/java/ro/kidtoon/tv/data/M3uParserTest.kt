package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class M3uParserTest {
    @Test
    fun builtInPlaylistParsesAndPassesFilter() {
        // Lista inclusă e comună cu aplicația de telefon; posturile vin din „iptv-org · Copii”.
        val text = File("src/main/assets/copii.m3u").readText()
        val p = M3uParser.parse(text, "test")
        assertTrue(p.channels.all { SourceFilter.isAllowed(it.url) })
    }

    @Test
    fun filterBlocksUnauthorizedRestreams() {
        assertFalse(SourceFilter.isAllowed("https://thor1.syndula1.cfd/ernews/use.m3u8"))
        assertFalse(SourceFilter.isAllowed("https://vip-acasatv.online:25463/lrZuGxAuP3/6782859900/714.m3u8"))
        assertFalse(SourceFilter.isAllowed("http://panel.example.com/live/user123/pass456/1234.ts"))
        assertTrue(SourceFilter.isAllowed("https://tvr-1.lg.mncdn.com/tvr1/smil:tvr1.smil/playlist.m3u8"))
    }

    @Test
    fun parsesHeaderEpgAndVlcOptions() {
        val p = M3uParser.parse(
            """
            #EXTM3U url-tvg="https://ex.ro/epg.xml.gz"
            #EXTINF:-1 tvg-id="A.ro" tvg-logo="https://ex.ro/a.png" group-title="News;Sports",Post, cu virgula (1080p) [Not 24/7]
            #EXTVLCOPT:http-referrer=https://ex.ro/
            https://ex.ro/a.m3u8
            """.trimIndent(),
            "test",
        )
        assertEquals(listOf("https://ex.ro/epg.xml.gz"), p.epgUrls)
        val ch = p.channels.single()
        assertEquals("Post, cu virgula", ch.name)
        assertEquals(listOf("Știri", "Sport"), ch.categories)
        assertEquals("https://ex.ro/", ch.referrer)
    }
}
