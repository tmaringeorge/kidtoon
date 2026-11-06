package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RadioFrequenciesTest {
    @Test
    fun matchesCommonNamesToBucharestFrequencies() {
        assertEquals(96.1, RadioFrequencies.bucharest("Kiss FM")!!, 0.0)
        assertEquals(96.1, RadioFrequencies.bucharest("KISS FM 96.1")!!, 0.0)
        assertEquals(89.0, RadioFrequencies.bucharest("Radio ZU")!!, 0.0)
        assertEquals(105.3, RadioFrequencies.bucharest("Radio România Actualități")!!, 0.0)
        assertEquals(100.2, RadioFrequencies.bucharest("Virgin Radio Romania")!!, 0.0)
        assertEquals(89.5, RadioFrequencies.bucharest("Dance FM 89.5 Bucuresti")!!, 0.0)
        assertEquals(106.7, RadioFrequencies.bucharest("Europa FM")!!, 0.0)
        // Canalele tematice (online) nu primesc frecventa postului mare.
        assertNull(RadioFrequencies.bucharest("Kiss FM Ballads"))
        assertNull(RadioFrequencies.bucharest("Magic FM Relax"))
        assertEquals("96.1 FM", RadioFrequencies.label(96.1))
    }

    @Test
    fun sortsAlphabeticallyAndByFrequency() {
        fun st(name: String) = RadioStation(id = name, name = name, url = "http://x")
        val list = listOf(st("Radio ZU"), st("Europa FM"), st("Ăla Radio"), st("Kiss FM"), st("Alt Post"))
        assertEquals(list, RadioSort.POPULAR.apply(list))
        // In alfabetul romanesc „ă” vine dupa „a”.
        assertEquals(listOf("Alt Post", "Ăla Radio", "Europa FM", "Kiss FM", "Radio ZU"), RadioSort.ALPHA.apply(list).map { it.name })
        assertEquals(listOf("Radio ZU", "Kiss FM", "Europa FM", "Alt Post", "Ăla Radio"), RadioSort.FREQUENCY.apply(list).map { it.name })
    }
}
