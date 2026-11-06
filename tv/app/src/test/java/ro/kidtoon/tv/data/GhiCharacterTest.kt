package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GhiCharacterTest {
    private val raw by lazy {
        listOf("../../mobile/assets/ghi/episodes.json", "mobile/assets/ghi/episodes.json", "episodes.json")
            .map(::File).first { it.exists() }.readText()
    }

    private fun texts(b: GhiBook) = b.episodes.flatMap { e -> listOf(e.title, e.learn) + e.beats.map { it.say } }.joinToString("\n")

    @Test
    fun girlLionNamedAna() {
        val b = GhiBook.parse(GhiCharacter("Ana", girl = true, avatar = "leu").personalize(raw))
        val all = texts(b)
        assertFalse(all.contains("GHI"))
        assertFalse(all.contains("{"))
        assertTrue(all.contains("Ana e fericită"))
        assertTrue(all.contains("Mami o îmbrățișează"))
        assertTrue(all.contains("ca o leoaică cuminte"))
    }

    @Test
    fun defaultStaysTheSame() {
        val all = texts(GhiBook.parse(GhiCharacter().personalize(raw)))
        assertTrue(all.contains("GHI e fericit"))
        assertTrue(all.contains("Mami îl îmbrățișează"))
        assertTrue(all.contains("GHI dragonul zboară"))
    }

    @Test
    fun sameWordsAsThePhone() {
        val c = GhiCharacter("Mara", girl = true, avatar = "balaur")
        assertEquals("Mara, bălăurița, e {x} tristă", c.personalize("GHI, {dragonul}, e {x} {trist|tristă}"))
        assertEquals("Ion", GhiCharacter.clean("  \"Ion{}\"  "))
        assertEquals("GHI", GhiCharacter.clean(""))
        assertEquals(c, GhiCharacter.decode(c.encode()))
        assertEquals(GhiCharacter(), GhiCharacter.decode("stricat"))
    }

    @Test
    fun phoneSendsTheCharacter() {
        val pack = GhiStudio.parse("""{"version":1,"character":{"name":"Ana","girl":true,"avatar":"urs"},"people":[],"episodes":[]}""")
        assertEquals(GhiCharacter("Ana", true, "urs"), pack.character)
        assertEquals(null, GhiStudio.parse("""{"people":[],"episodes":[]}""").character)
    }
}
