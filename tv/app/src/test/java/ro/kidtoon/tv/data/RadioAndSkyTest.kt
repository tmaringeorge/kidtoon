package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import ro.kidtoon.tv.ui.SkyTimeline

class RadioAndSkyTest {
    @Test
    fun parsesRadioBrowserJsonAndDropsDuplicates() {
        val body = """
            [
              {"stationuuid":"a","name":" Europa FM ","url":"http://x/a","url_resolved":"https://x/a.mp3","favicon":"https://x/a.png","tags":"news,talk","bitrate":128},
              {"stationuuid":"b","name":"EUROPA FM","url":"http://x/b","url_resolved":"","favicon":null,"tags":null},
              {"stationuuid":"c","name":"Fara stream","url":"","url_resolved":""},
              {"stationuuid":"d","name":"Radio ZU","url":"http://zu/live","url_resolved":null,"favicon":"","extra":1}
            ]
        """.trimIndent()
        val list = RadioParser.parse(body)
        assertEquals(listOf("Europa FM", "Radio ZU"), list.map { it.name })
        assertEquals("https://x/a.mp3", list[0].streamUrl)
        assertEquals(listOf("news", "talk"), list[0].tagList)
        assertEquals("http://zu/live", list[1].streamUrl)
        assertNull(list[1].logo)
    }

    @Test
    fun skyTimelineCountsStarsOneToFive() {
        assertEquals(1f, SkyTimeline.dayness(0.1f))
        assertEquals(0f, SkyTimeline.dayness(0.7f))
        assertEquals(0, SkyTimeline.starsVisible(0.55f))
        assertEquals(1, SkyTimeline.starsVisible(SkyTimeline.FIRST_STAR + 0.001f))
        assertEquals(5, SkyTimeline.starsVisible(0.92f))
        assertEquals("3 · trei stele", SkyTimeline.caption(SkyTimeline.FIRST_STAR + 2 * SkyTimeline.STAR_STEP + 0.01f))
        assertEquals("Bună dimineața, Soare!", SkyTimeline.caption(0.2f))
    }
}
