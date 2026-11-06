package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class ParentalTest {
    @Test
    fun questionHasFourChoicesWithTheAnswer() {
        repeat(50) { seed ->
            val q = ParentQuestion.random(Random(seed))
            val c = q.choices(Random(seed))
            assertEquals(4, c.size)
            assertEquals(4, c.toSet().size)
            assertTrue(q.answer in c)
            assertTrue(c.all { it > 0 })
            assertTrue(q.check(q.answer))
        }
    }

    @Test
    fun pinIsFourDigits() {
        assertTrue(ParentPin.isValid("0420"))
        assertFalse(ParentPin.isValid("123"))
        assertFalse(ParentPin.isValid("12a4"))
    }

    private fun ch(name: String, vararg cats: String) =
        Channel(name, name, "https://ex.ro/$name.m3u8", null, null, cats.toList(), null, null, "test")

    @Test
    fun kidFilterKeepsKidsChannelsAndHidesChosenOnes() {
        val all = listOf(ch("Desene", "Copii"), ch("Stiri", "Știri"), ch("Docu", "Educație"), ch("Film", "Familie", "Filme"))
        assertEquals(listOf("Desene", "Docu", "Film"), KidFilter.apply(all, kidsOnly = true).map { it.name })
        assertEquals(listOf("Desene", "Film"), KidFilter.apply(all, kidsOnly = true, hidden = setOf("Docu")).map { it.name })
        assertEquals(4, KidFilter.apply(all, kidsOnly = false).size)
    }
}
