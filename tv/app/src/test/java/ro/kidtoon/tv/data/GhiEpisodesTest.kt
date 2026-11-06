package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GhiEpisodesTest {
    private val book by lazy {
        // Fisierul e comun cu telefonul: mobile/assets/ghi/episodes.json.
        val f = listOf("../../mobile/assets/ghi/episodes.json", "mobile/assets/ghi/episodes.json", "episodes.json")
            .map(::File).first { it.exists() }
        GhiBook.parse(f.readText())
    }

    @Test
    fun everyEpisodeIsComplete() {
        assertTrue(book.episodes.size >= 25)
        val ids = book.episodes.map { it.id }
        assertEquals(ids.size, ids.toSet().size)
        for (ep in book.episodes) {
            assertTrue(ep.id, ep.set in book.sets)
            assertTrue(ep.id, ep.learn.isNotBlank() && ep.title.startsWith("GHI"))
            assertTrue(ep.id, ep.beats.size in 4..12)
            ep.beats.forEach { b -> assertTrue(ep.id, b.say.isNotBlank() && b.sec in 6..20) }
        }
        val requested = listOf("peste", "fotbal", "petrecere", "joaca", "gradinita", "stetoscop", "stele", "baita", "olita", "animalute")
        assertTrue(ids.containsAll(requested))
    }

    @Test
    fun parentsAppear() {
        for (id in listOf("mami_shopping", "tati_tren", "tati_fotbal", "mami_prajituri", "tati_calculator")) {
            val ep = book.episodes.first { it.id == id }
            assertTrue(id, ep.beats.any { it.people.isNotEmpty() })
        }
        book.episodes.forEach { assertTrue(!GhiTimeline.isCut(it, 0)) }
    }

    @Test
    fun everyEpisodeAsksAQuestion() {
        for (ep in book.episodes) {
            val i = ep.beats.indexOfFirst { it.ask != null }
            assertTrue(ep.id, i > 0)
            val beat = ep.beats[i]
            val ask = beat.ask!!
            assertTrue(ep.id, ask.answer in beat.props.indices)
            // Atingerea pe răspuns îl găsește, iar lângă el nu.
            val p = beat.props[ask.answer]
            assertEquals(ep.id, ask.answer, GhiTimeline.askHit(beat, 0.2f, p.x.at(0.2f), p.y.at(0.2f), 0.56f))
            assertEquals(-1, GhiTimeline.askHit(beat, 0.2f, 0.05f, 0.05f, 0.56f))
            assertEquals(beat.say, GhiTimeline.askCaption(beat, 0.1f))
            assertEquals(ask.hint, GhiTimeline.askCaption(beat, 0.7f))
            assertEquals(ask.yes, GhiTimeline.askCaption(beat, 0.1f, answered = true))
            assertEquals(ask.no, GhiTimeline.askCaption(beat, 0.1f, wrong = true))
            // După un răspuns bun, pasul se termină peste 3,5 secunde.
            val start = GhiTimeline.beatStartMs(ep, i)
            val skip = GhiTimeline.skipAfterAnswer(ep, start + 1000)
            assertEquals(beat.sec * 1000L - 1000 - GhiTimeline.ANSWER_HOLD_MS, skip)
        }
        val parents = book.episodes.filter { it.id.startsWith("mami_") || it.id.startsWith("tati_") || it.id.startsWith("familie_") }
        assertTrue(parents.size >= 11)
        assertTrue(parents.all { it.beats.size >= 8 })
    }

    @Test
    fun professionsHaveTheirPerson() {
        val jobs = listOf("pompier", "doctor", "politist", "bucatar", "constructor", "fermier", "postas", "pilot", "veterinar", "brutar")
        for (job in jobs) {
            val ep = book.episodes.first { it.id == job }
            assertTrue(job, ep.beats.size >= 8)
            assertTrue(job, ep.beats.any { b -> b.people.any { it.who == job } })
        }
        // Oamenii nu mai sunt emoji: mami, bunica și educatoarea sunt desenați.
        val emojiPeople = setOf("👩", "👩‍🏫", "👵")
        assertTrue(book.episodes.all { e -> e.beats.all { b -> b.props.none { it.emoji in emojiPeople } } })
    }

    @Test
    fun timelineGoesTitleStoryEnd() {
        val ep = book.episodes.first { it.id == "peste" }
        assertEquals("GHI la pescuit", GhiTimeline.caption(ep, 0))
        assertEquals("GHI merge la lac cu undița", GhiTimeline.caption(ep, GhiTimeline.TITLE_MS + 500))
        assertEquals("Ssst! Stăm liniștiți și așteptăm", GhiTimeline.caption(ep, GhiTimeline.TITLE_MS + 10_500))
        assertTrue(GhiTimeline.caption(ep, GhiTimeline.durationMs(ep) - 100).startsWith("Ce am învățat"))
        assertEquals(GhiTimeline.TITLE_MS + 74_000 + GhiTimeline.END_MS, GhiTimeline.durationMs(ep))
    }

    @Test
    fun countingAndFrames() {
        assertEquals(0, GhiTimeline.counted(3, 0.05f))
        assertEquals(1, GhiTimeline.counted(3, 0.12f))
        assertEquals(3, GhiTimeline.counted(3, 0.9f))
        assertEquals(1200L, GhiTimeline.quantize(1299))
        assertEquals(0, GhiTimeline.next(27, 28))
        assertEquals(27, GhiTimeline.previous(0, 28))
        assertEquals(0.5f, Span(0f, 1f).at(0.5f), 1e-4f)
    }

    @Test
    fun touchScenes() {
        assertTrue(book.touch.size >= 8)
        book.touch.forEach { assertTrue(it.id, it.items.size == 8 && it.set in book.sets) }
        // Degetul pe al doilea lucru din primul rand.
        assertEquals(1, GhiTouchLayout.hit(8, GhiTouchLayout.x(1) + 0.01f, GhiTouchLayout.y(1), 9f / 16f))
        assertEquals(-1, GhiTouchLayout.hit(8, 0.05f, 0.05f, 9f / 16f))
        assertEquals(5, GhiTouchLayout.move(1, 8, 0, 1))
        assertEquals(1, GhiTouchLayout.move(1, 8, 0, -1))
    }

    @Test
    fun healthyScreen() {
        val min = 60_000L
        assertEquals(ScreenCare.State.Play, ScreenCare.state(4 * min, 20, 0))
        assertEquals(ScreenCare.State.Blink(1_000), ScreenCare.state(5 * min + 1_000, 20, 0))
        assertEquals(ScreenCare.State.Play, ScreenCare.state(5 * min + 30_000, 20, 0))
        assertEquals(ScreenCare.State.Rest, ScreenCare.state(20 * min, 20, 0))
        assertEquals(ScreenCare.State.Rest, ScreenCare.state(min, 20, 3))
        assertTrue(ScreenCare.state(90 * min + 1_000, 0, 0) is ScreenCare.State.Blink)
        assertEquals("Hai să clipim împreună!", ScreenCare.blinkCaption(2_000))
        assertTrue(ScreenCare.eyesClosed(1_500) && !ScreenCare.eyesClosed(500) && !ScreenCare.eyesClosed(10_000))
        assertEquals(0f, ScreenCare.eveningDim(12, 0), 0f)
        assertEquals(0.15f, ScreenCare.eveningDim(20, 0), 1e-4f)
        assertEquals(0.3f, ScreenCare.eveningDim(22, 30), 1e-4f)
    }
}
