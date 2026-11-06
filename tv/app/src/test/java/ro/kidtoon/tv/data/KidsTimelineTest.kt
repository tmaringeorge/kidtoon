package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import ro.kidtoon.tv.ui.KidsTimeline
import ro.kidtoon.tv.ui.SleepTimer

class KidsTimelineTest {
    private fun at(minute: Int, mode: RadioBackground = RadioBackground.ALL, frac: Float = 0.5f) =
        KidsTimeline.frame((minute * KidsTimeline.CYCLE_MS + frac * KidsTimeline.CYCLE_MS).toLong(), mode)

    @Test
    fun allModeRotatesScenesWithoutRepeatingForAnHour() {
        val scenes = (0 until 60).map { at(it).scene }
        assertEquals(RadioBackground.SKY, scenes[0])
        // Fiecare scena tine 2 minute, apoi vine alta, niciodata aceeasi de doua ori la rand.
        val segments = scenes.chunked(KidsTimeline.CYCLES_PER_SCENE).map { it.distinct().single() }
        segments.zipWithNext().forEach { (a, b) -> assertNotEquals(a, b) }
        assertEquals(KidsTimeline.ROTATION.toSet(), segments.take(KidsTimeline.ROTATION.size).toSet())
        // Combinatia (scena, varianta) nu se repeta intr-o ora.
        val combos = (0 until 60).map { at(it).let { f -> f.scene to f.variant } }
        assertEquals(60, combos.toSet().size)
        assertTrue(scenes.none { it == RadioBackground.ALL })
    }

    @Test
    fun singleModeStaysOnChosenScene() {
        assertTrue((0 until 30).all { at(it, RadioBackground.TRAIN).scene == RadioBackground.TRAIN })
        assertEquals(7, at(7, RadioBackground.OCEAN).variant)
    }

    @Test
    fun captionsCountAndNameColors() {
        val ocean = KidsTimeline.Frame(RadioBackground.OCEAN, KidsTimeline.FISH_START + 2 * KidsTimeline.FISH_STEP + 0.01f, 0, 0)
        assertEquals("3 · trei pești", KidsTimeline.caption(ocean))
        assertEquals("Hai în mare!", KidsTimeline.caption(ocean.copy(t = 0.01f)))
        assertEquals("Vaca face Muu!", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.FARM, 0.05f, 0, 0)))
        assertEquals("Balonul roșu", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.BALLOONS, 0.05f, 0, 0)))
        // varianta 3, slotul 0 -> STEA, culoarea COLORS[6] (roz); varianta 4 -> INIMA, COLORS[0] (roșie)
        assertEquals("Steaua roz", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.SHAPES, 0.05f, 3, 0)))
        assertEquals("Inima roșie", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.SHAPES, 0.05f, 4, 4)))
        assertEquals("Cercul roșu", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.SHAPES, 0.05f, 0, 0)))
    }

    @Test
    fun trainCountsFruitInEachWagon() {
        val seen = (0..1000).map { KidsTimeline.carAtCenter(it / 1000f) }.distinct()
        assertEquals(listOf(-1, 0, 1, 2, 3, 4, 5, 6), seen)
        fun captionFor(k: Int, variant: Int): String {
            val t = (0..1000).map { it / 1000f }.first { KidsTimeline.carAtCenter(it) == k }
            return KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.TRAIN, t, variant, 0))
        }
        assertEquals("1 · un măr", captionFor(1, 0))
        assertEquals("2 · două mere", captionFor(2, 0))
        assertEquals("5 · cinci pere", captionFor(5, 1))
        assertEquals("Pa-pa, trenule!", KidsTimeline.caption(KidsTimeline.Frame(RadioBackground.TRAIN, 0.99f, 0, 0)))
    }

    @Test
    fun footballSorcovaAndSantaCaptions() {
        fun cap(scene: RadioBackground, t: Float) = KidsTimeline.caption(KidsTimeline.Frame(scene, t, 0, 0))
        assertEquals("Hai, șutează!", cap(RadioBackground.FOOTBALL, 0.05f))
        assertEquals("Gooool! 1 · un gol", cap(RadioBackground.FOOTBALL, 0.15f))
        assertEquals("Gooool! 3 · trei goluri", cap(RadioBackground.FOOTBALL, 0.55f))
        assertEquals("Sorcova, vesela,", cap(RadioBackground.SORCOVA, 0.1f))
        assertEquals("La anul și la mulți ani!", cap(RadioBackground.SORCOVA, 0.95f))
        assertEquals("Ho-ho-ho! Vine Moș Crăciun!", cap(RadioBackground.SANTA, 0.1f))
        assertEquals("2 · două cadouri", cap(RadioBackground.SANTA, 0.35f))
        assertEquals("Crăciun fericit!", cap(RadioBackground.SANTA, 0.95f))
        assertEquals(5, KidsTimeline.giftsLanded(0.89f))
    }

    @Test
    fun newScenesTellLittleStories() {
        fun cap(scene: RadioBackground, t: Float, v: Int = 0) = KidsTimeline.caption(KidsTimeline.Frame(scene, t, v, 0))
        assertEquals("Hai la dinozauri!", cap(RadioBackground.DINOS, 0.05f))
        assertEquals("2 · doi dinozauri", cap(RadioBackground.DINOS, 0.25f))
        assertEquals("Iese fum! Sunăm la pompieri", cap(RadioBackground.FIREFIGHTERS, 0.1f))
        assertEquals("Nino-nino! Vin pompierii!", cap(RadioBackground.FIREFIGHTERS, 0.3f))
        assertEquals("Bravo, pompierilor!", cap(RadioBackground.FIREFIGHTERS, 0.9f))
        assertEquals(0f, KidsTimeline.fireSize(0.85f))
        assertEquals("Ursulețul s-a lovit la lăbuță", cap(RadioBackground.DOCTOR, 0.1f))
        assertEquals("Cățelul e sănătos! Mulțumim!", cap(RadioBackground.DOCTOR, 0.9f, 1))
        assertEquals("Leul face Rrrr!", cap(RadioBackground.ZOO, 0.05f))
        assertEquals("Săpăm o groapă", cap(RadioBackground.TREES, 0.02f))
        assertEquals("3 · trei copaci", cap(RadioBackground.TREES, 0.58f))
    }

    @Test
    fun arrowsGoBothWays() {
        assertEquals(RadioBackground.TREES, RadioBackground.ALL.previous())
        assertEquals(RadioBackground.ALL, RadioBackground.TREES.next())
        assertEquals(RadioBackground.SKY, RadioBackground.OCEAN.previous())
    }

    @Test
    fun playerButtonCyclesThroughAllBackgrounds() {
        val seen = generateSequence(RadioBackground.ALL) { it.next() }.take(RadioBackground.entries.size + 1).toList()
        assertEquals(RadioBackground.entries.toList(), seen.dropLast(1))
        assertEquals(RadioBackground.ALL, seen.last())
    }

    @Test
    fun nowPlayingKeepsOnlyUsefulTitles() {
        assertEquals("Smiley - Vals", NowPlaying.clean("  Smiley -  Vals ", "Kiss FM"))
        assertEquals("Matinal cu Ana", NowPlaying.clean("Matinal cu Ana", "Radio ZU"))
        assertEquals(null, NowPlaying.clean("Kiss FM", "Kiss FM"))
        assertEquals(null, NowPlaying.clean(" - ", "Kiss FM"))
        assertEquals(null, NowPlaying.clean(null, "Kiss FM"))
    }

    @Test
    fun sleepTimerCycles() {
        assertEquals(30, SleepTimer.next(0))
        assertEquals(60, SleepTimer.next(30))
        assertEquals(60, SleepTimer.next(42))
        assertEquals(0, SleepTimer.next(90))
    }
}
