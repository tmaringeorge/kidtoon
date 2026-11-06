package ro.kidtoon.tv.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.Calendar

class AtelierTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun paletteHasANameForEveryColor() {
        assertEquals(KidPalette.colors.size, KidPalette.names.size)
    }

    @Test
    fun coloringNavigationFollowsTheArrow() {
        // Trei zone pe un rând și una dedesubt.
        val c = listOf(10f to 10f, 50f to 10f, 90f to 10f, 50f to 80f)
        assertEquals(2, ColoringNav.neighbor(c, 1, 1, 0))
        assertEquals(0, ColoringNav.neighbor(c, 1, -1, 0))
        assertEquals(3, ColoringNav.neighbor(c, 1, 0, 1))
        assertEquals(-1, ColoringNav.neighbor(c, 2, 1, 0))
        assertEquals(3, ColoringNav.neighbor(c, -1, 1, 0))
    }

    @Test
    fun cursorSpeedsUpAndStaysOnThePage() {
        assertTrue(DpadCursor.step(9) > DpadCursor.step(0))
        assertTrue(DpadCursor.step(1000) <= DpadCursor.MAX_STEP)
        assertEquals(1f to 0f, DpadCursor.move(0.999f, 0.001f, 1, -1, 50))
    }

    @Test
    fun piecesMoveScaleAndHitTest() {
        val p = Piece(PieceShape.SQUARE, x = 0.5f, y = 0.5f, size = 0.2f)
        assertTrue(p.contains(0.5f, 0.5f, 1f))
        assertFalse(p.contains(0.9f, 0.9f, 1f))
        assertEquals(1f, p.moveBy(2f, 0f).x)
        assertEquals(Piece.MAX_SIZE, p.scaleBy(100f).size)
        assertEquals(Piece.MIN_SIZE, p.scaleBy(0.001f).size)
        // Dreptunghiul e mai lat decât înalt.
        val r = Piece(PieceShape.RECT, x = 0.5f, y = 0.5f, size = 0.2f)
        assertTrue(r.contains(0.65f, 0.5f, 1f))
        assertFalse(r.contains(0.5f, 0.65f, 1f))
    }

    @Test
    fun templatesStartWithAnEmptySheet() {
        assertTrue(buildTemplates.first().make().isEmpty())
        assertTrue(buildTemplates.drop(1).all { it.make().isNotEmpty() && it.background in buildBackgrounds.indices })
    }

    @Test
    fun galleryListsNewestFirstAcrossKinds() {
        val store = ArtStore(tmp.newFolder("atelier"))
        fun at(h: Int) = Calendar.getInstance().apply { set(2026, 0, 2, h, 0, 0) }
        store.save("desen", byteArrayOf(1), at(9))
        store.save("colorat", byteArrayOf(2), at(11))
        store.save("construit", byteArrayOf(3), at(10))
        val names = store.list().map { it.name }
        assertEquals(listOf("colorat_20260102_110000.png", "construit_20260102_100000.png", "desen_20260102_090000.png"), names)
        assertEquals("🖍️ Colorat", ArtStore.kindOf(store.list().first()))
        store.delete(store.list().first())
        assertEquals(2, store.list().size)
    }
}
