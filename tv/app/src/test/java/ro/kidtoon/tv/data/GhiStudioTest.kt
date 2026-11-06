package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GhiStudioTest {
    private val book by lazy {
        val f = listOf("../../assets/ghi/episodes.json", "assets/ghi/episodes.json", "episodes.json")
            .map(::File).first { it.exists() }
        GhiBook.parse(f.readText())
    }

    /** Exact ce trimite telefonul (StudioLibrary.exportForTv). */
    private val export = """{"version":1,"people":[{"id":"p1","name":"Bunicul Ion","skin":"#F2C6A0","hair":"#CFD8DC","top":"#42A5F5","bottom":"#455A64","shoes":"#4E342E","style":"short","dress":false,"hat":"straw","beard":true,"glasses":true}],"episodes":[{"id":"studio_e1","title":"GHI la bunicul","set":"farm","learn":"Ne-am jucat împreună cu GHI.","beats":[{"say":"Bunicul îi dă un măr","sec":8,"ghi":{"pose":"stand","x":0.3,"face":"happy"},"props":[],"people":[{"who":"p1","x":0.68,"pose":"hold","face":"happy","hold":"🍎"}]},{"say":"Care e mărul? Arată cu degetul!","sec":14,"ghi":{"pose":"stand","x":0.3,"face":"happy"},"props":[{"e":"🐈","x":0.56,"y":0.5,"s":0.12,"m":"bob"},{"e":"🍎","x":0.72,"y":0.5,"s":0.12,"m":"bob"},{"e":"🌻","x":0.88,"y":0.5,"s":0.12,"m":"bob"}],"ask":{"answer":1,"yes":"Bravo! Ai găsit mărul!","no":"Mai caută puțin!","hint":"Uite! Mărul e aici, unde strălucește."},"cam":[1.0,1.0]}]}]}"""

    @Test
    fun phoneExportIsRead() {
        val pack = GhiStudio.parse(export)
        val p = pack.people.single()
        assertEquals("Bunicul Ion", p.name)
        assertEquals(0xFFCFD8DC, p.hair)
        assertEquals("straw", p.hat)
        assertTrue(p.beard && p.glasses)
        val ep = pack.episodes.single()
        assertEquals("studio_e1", ep.id)
        assertEquals("p1", ep.beats[0].people.single().who)
        assertEquals("🍎", ep.beats[0].people.single().hold)
        val ask = ep.beats[1]
        assertEquals("🍎", ask.props[ask.ask!!.answer].emoji)
    }

    @Test
    fun studioEpisodesComeAfterTheAppOnes() {
        val pack = GhiStudio.parse(export)
        val merged = GhiStudio.merge(book, pack)
        assertEquals(book.episodes.size + 1, merged.episodes.size)
        assertEquals("studio_e1", merged.episodes.last().id)
        // A doua primire înlocuiește episoadele Studio, nu le dublează.
        assertEquals(merged.episodes.size, GhiStudio.merge(merged, pack).episodes.size)
        // Un decor necunoscut nu strică episodul.
        val odd = pack.copy(episodes = pack.episodes.map { it.copy(set = "luna") })
        assertTrue(GhiStudio.merge(book, odd).episodes.last().set in book.sets)
    }

    @Test
    fun onlyStudioEpisodesAreAccepted() {
        val sneaky = export.replace("studio_e1", "peste")
        assertTrue(GhiStudio.parse(sneaky).episodes.isEmpty())
    }

    @Test
    fun requestNeedsTheCode() {
        val ok = GhiStudio.handle("POST /ghi HTTP/1.1", mapOf("x-ghi-code" to "4821"), export, "4821")
        assertEquals(200, ok.status)
        assertEquals("1", ok.body)
        assertEquals(403, GhiStudio.handle("POST /ghi HTTP/1.1", mapOf("x-ghi-code" to "1111"), export, "4821").status)
        assertEquals(403, GhiStudio.handle("POST /ghi HTTP/1.1", emptyMap(), export, "4821").status)
        assertEquals(404, GhiStudio.handle("GET / HTTP/1.1", mapOf("x-ghi-code" to "4821"), "", "4821").status)
        assertEquals(400, GhiStudio.handle("POST /ghi HTTP/1.1", mapOf("x-ghi-code" to "4821"), "{nu", "4821").status)
        repeat(50) { assertEquals(4, GhiStudio.newCode().length) }
    }
}
