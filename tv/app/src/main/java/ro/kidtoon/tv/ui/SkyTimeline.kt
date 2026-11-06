package ro.kidtoon.tv.ui

import kotlin.math.min

/**
 * Animatie calma pentru copii mici, afisata cat timp se asculta radio:
 * rasare soarele, apoi se lasa seara, apare luna si stelele se numara
 * incet de la 1 la 5. Un ciclu complet dureaza un minut; nu are sclipiri
 * sau miscari bruste.
 */
object SkyTimeline {
    const val CYCLE_MS = 60_000
    const val SUN_END = 0.48f
    const val MOON_START = 0.48f
    const val FIRST_STAR = 0.60f
    const val STAR_STEP = 0.065f

    /** 1 = zi, 0 = noapte. */
    fun dayness(t: Float): Float = when {
        t < 0.40f -> 1f
        t < 0.50f -> 1f - (t - 0.40f) / 0.10f
        t < 0.92f -> 0f
        else -> (t - 0.92f) / 0.08f
    }

    fun starsVisible(t: Float): Int =
        if (t < FIRST_STAR || t >= 0.94f) 0 else min(5, ((t - FIRST_STAR) / STAR_STEP).toInt() + 1)

    private val counts = listOf("o stea", "două stele", "trei stele", "patru stele", "cinci stele")

    fun caption(t: Float): String {
        val stars = starsVisible(t)
        return when {
            t < 0.40f -> "Bună dimineața, Soare!"
            t < 0.50f -> "Se face seară"
            stars == 0 && t < 0.92f -> "A apărut Luna"
            stars > 0 -> "$stars · ${counts[stars - 1]}"
            else -> "Bună dimineața!"
        }
    }
}
