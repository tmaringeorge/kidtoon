package ro.kidtoon.tv.ui

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** O zonă dintr-o planșă de colorat: un contur închis pe care copilul îl umple. Pagina are 100 × 100. */
class ColorRegion(val path: Path, val name: String) {
    val bounds: Rect = path.getBounds()
    val center: Offset get() = bounds.center
}

/** O planșă: zonele, de la cea din spate (fundalul) la cea din față. Aceleași planșe ca pe telefon. */
class ColoringPage(val id: String, val title: String, val emoji: String, val regions: List<ColorRegion>) {
    val centers: List<Pair<Float, Float>> by lazy { regions.map { it.center.x to it.center.y } }

    companion object {
        const val SIZE = 100f
    }
}

private fun rect(l: Float, t: Float, w: Float, h: Float) = Path().apply { addRect(Rect(l, t, l + w, t + h)) }

private fun round(l: Float, t: Float, w: Float, h: Float, r: Float) =
    Path().apply { addRoundRect(RoundRect(Rect(l, t, l + w, t + h), CornerRadius(r, r))) }

private fun circle(x: Float, y: Float, r: Float) = Path().apply { addOval(Rect(Offset(x, y), r)) }

private fun oval(x: Float, y: Float, rx: Float, ry: Float) = Path().apply { addOval(Rect(x - rx, y - ry, x + rx, y + ry)) }

private fun poly(vararg xy: Float) = Path().apply {
    moveTo(xy[0], xy[1])
    var i = 2
    while (i < xy.size) { lineTo(xy[i], xy[i + 1]); i += 2 }
    close()
}

private fun union(vararg parts: Path): Path = parts.reduce { a, b -> Path().apply { op(a, b, PathOperation.Union) } }

private fun minus(a: Path, b: Path) = Path().apply { op(a, b, PathOperation.Difference) }

private fun cloud(x: Float, y: Float, r: Float) =
    union(circle(x, y, r), circle(x - r * 0.9f, y + r * 0.3f, r * 0.75f), circle(x + r * 0.95f, y + r * 0.25f, r * 0.8f))

fun starPath(x: Float, y: Float, r: Float, points: Int = 5, inner: Float = 0.45f) = Path().apply {
    for (i in 0 until points * 2) {
        val a = -PI / 2 + i * PI / points
        val rr = if (i % 2 == 0) r else r * inner
        val px = x + rr * cos(a).toFloat()
        val py = y + rr * sin(a).toFloat()
        if (i == 0) moveTo(px, py) else lineTo(px, py)
    }
    close()
}

fun heartPath(x: Float, y: Float, r: Float) = Path().apply {
    moveTo(x, y + r * 0.9f)
    cubicTo(x - r * 1.4f, y + r * 0.1f, x - r * 0.9f, y - r * 1.0f, x, y - r * 0.35f)
    cubicTo(x + r * 0.9f, y - r * 1.0f, x + r * 1.4f, y + r * 0.1f, x, y + r * 0.9f)
    close()
}

/** O bandă de curcubeu (jumătate de inel). */
private fun band(cx: Float, cy: Float, outer: Float, inner: Float) = Path().apply {
    moveTo(cx - outer, cy)
    arcTo(Rect(Offset(cx, cy), outer), 180f, 180f, false)
    lineTo(cx + inner, cy)
    arcTo(Rect(Offset(cx, cy), inner), 0f, -180f, false)
    close()
}

private fun r(p: Path, name: String = "") = ColorRegion(p, name)

private val TAU = (2 * PI).toFloat()

/** Planșele de colorat incluse în aplicație. */
val coloringPages: List<ColoringPage> by lazy {
    listOf(
        ColoringPage("casa", "Căsuța", "🏠", listOf(
            r(rect(0f, 0f, 100f, 66f), "cerul"),
            r(rect(0f, 66f, 100f, 34f), "iarba"),
            r(circle(86f, 14f, 9f), "soarele"),
            r(cloud(22f, 14f, 7f), "norul"),
            r(rect(58f, 22f, 7f, 14f), "hornul"),
            r(rect(24f, 42f, 42f, 36f), "peretele"),
            r(poly(18f, 44f, 45f, 18f, 72f, 44f), "acoperișul"),
            r(round(39f, 56f, 12f, 22f, 2f), "ușa"),
            r(rect(28f, 50f, 8f, 8f), "fereastra"),
            r(rect(54f, 50f, 8f, 8f), "fereastra"),
            r(rect(80f, 52f, 6f, 24f), "trunchiul"),
            r(union(circle(83f, 44f, 10f), circle(77f, 50f, 6f), circle(89f, 50f, 6f)), "coroana"),
            r(poly(0f, 86f, 100f, 86f, 100f, 100f, 0f, 100f), "cărarea"),
        )),
        ColoringPage("peste", "Peștișorul", "🐠", listOf(
            r(rect(0f, 0f, 100f, 84f), "apa"),
            r(rect(0f, 84f, 100f, 16f), "nisipul"),
            r(poly(70f, 50f, 92f, 32f, 92f, 68f), "coada"),
            r(oval(46f, 50f, 27f, 18f), "corpul"),
            r(poly(36f, 34f, 50f, 20f, 58f, 35f), "aripioara"),
            r(poly(44f, 64f, 54f, 76f, 58f, 62f), "aripioara"),
            r(circle(30f, 46f, 4.5f), "ochiul"),
            r(minus(oval(44f, 50f, 4f, 12f), rect(0f, 0f, 41f, 100f)), "dunga"),
            r(circle(16f, 30f, 3f), "bula"),
            r(circle(12f, 20f, 2.2f), "bula"),
            r(circle(18f, 11f, 1.6f), "bula"),
            r(union(round(8f, 62f, 4f, 24f, 2f), round(13f, 68f, 4f, 18f, 2f)), "alga"),
            r(poly(80f, 92f, 84f, 84f, 88f, 92f), "scoica"),
        )),
        ColoringPage("floare", "Floarea", "🌸", buildList {
            add(r(rect(0f, 0f, 100f, 100f), "fundalul"))
            add(r(circle(85f, 15f, 8f), "soarele"))
            add(r(rect(48f, 46f, 4f, 32f), "tulpina"))
            add(r(oval(40f, 62f, 9f, 4f), "frunza"))
            add(r(oval(60f, 58f, 9f, 4f), "frunza"))
            for (i in 0 until 6) {
                val a = i * TAU / 6
                add(r(circle(50f + 13f * cos(a), 32f + 13f * sin(a), 8.5f), "petala"))
            }
            add(r(circle(50f, 32f, 8f), "mijlocul"))
            add(r(poly(34f, 76f, 66f, 76f, 61f, 96f, 39f, 96f), "ghiveciul"))
            add(r(rect(32f, 74f, 36f, 5f), "marginea"))
        }),
        ColoringPage("masina", "Mașinuța", "🚗", buildList {
            add(r(rect(0f, 0f, 100f, 70f), "cerul"))
            add(r(rect(0f, 70f, 100f, 30f), "drumul"))
            add(r(cloud(75f, 18f, 7f), "norul"))
            add(r(poly(28f, 46f, 36f, 30f, 66f, 30f, 76f, 46f), "cabina"))
            add(r(round(12f, 44f, 76f, 20f, 6f), "mașina"))
            add(r(poly(38f, 44f, 41f, 34f, 50f, 34f, 50f, 44f), "geamul"))
            add(r(poly(53f, 44f, 53f, 34f, 63f, 34f, 70f, 44f), "geamul"))
            add(r(circle(85f, 50f, 2.6f), "farul"))
            add(r(circle(30f, 66f, 9f), "roata"))
            add(r(circle(70f, 66f, 9f), "roata"))
            add(r(circle(30f, 66f, 3.5f), "janta"))
            add(r(circle(70f, 66f, 3.5f), "janta"))
            for (i in 0 until 4) add(r(rect(4f + i * 26f, 85f, 14f, 3f), "linia"))
        }),
        ColoringPage("fluture", "Fluturele", "🦋", listOf(
            r(rect(0f, 0f, 100f, 100f), "fundalul"),
            r(oval(30f, 34f, 20f, 17f), "aripa"),
            r(oval(70f, 34f, 20f, 17f), "aripa"),
            r(oval(34f, 66f, 15f, 13f), "aripa"),
            r(oval(66f, 66f, 15f, 13f), "aripa"),
            r(circle(28f, 33f, 6f), "bulina"),
            r(circle(72f, 33f, 6f), "bulina"),
            r(circle(34f, 67f, 4.5f), "bulina"),
            r(circle(66f, 67f, 4.5f), "bulina"),
            r(oval(50f, 52f, 5f, 26f), "corpul"),
            r(circle(50f, 24f, 6f), "capul"),
            r(circle(40f, 10f, 3f), "antena"),
            r(circle(60f, 10f, 3f), "antena"),
        )),
        ColoringPage("pisica", "Pisicuța", "🐱", listOf(
            r(rect(0f, 0f, 100f, 100f), "fundalul"),
            r(round(72f, 40f, 8f, 44f, 4f), "coada"),
            r(oval(50f, 70f, 24f, 22f), "corpul"),
            r(poly(28f, 30f, 30f, 8f, 44f, 22f), "urechea"),
            r(poly(72f, 30f, 70f, 8f, 56f, 22f), "urechea"),
            r(circle(50f, 34f, 22f), "capul"),
            r(oval(41f, 31f, 4f, 5f), "ochiul"),
            r(oval(59f, 31f, 4f, 5f), "ochiul"),
            r(poly(46f, 40f, 54f, 40f, 50f, 45f), "năsucul"),
            r(oval(50f, 74f, 12f, 14f), "burtica"),
            r(oval(38f, 90f, 7f, 4f), "lăbuța"),
            r(oval(62f, 90f, 7f, 4f), "lăbuța"),
        )),
        ColoringPage("racheta", "Racheta", "🚀", listOf(
            r(rect(0f, 0f, 100f, 100f), "cerul"),
            r(circle(82f, 80f, 13f), "planeta"),
            r(minus(oval(82f, 80f, 22f, 5f), circle(82f, 80f, 13f)), "inelul"),
            r(starPath(16f, 16f, 5f), "steaua"),
            r(starPath(84f, 20f, 4f), "steaua"),
            r(starPath(18f, 74f, 4f), "steaua"),
            r(poly(40f, 78f, 50f, 98f, 60f, 78f), "flacăra"),
            r(poly(36f, 62f, 26f, 82f, 40f, 78f), "aripa"),
            r(poly(64f, 62f, 74f, 82f, 60f, 78f), "aripa"),
            r(round(38f, 30f, 24f, 50f, 8f), "racheta"),
            r(poly(38f, 32f, 50f, 6f, 62f, 32f), "vârful"),
            r(circle(50f, 46f, 7f), "geamul"),
        )),
        ColoringPage("dragon", "Dinozaurul", "🦖", buildList {
            add(r(rect(0f, 0f, 100f, 76f), "cerul"))
            add(r(rect(0f, 76f, 100f, 24f), "iarba"))
            add(r(poly(18f, 62f, 2f, 50f, 26f, 54f), "coada"))
            for (i in 0 until 4) {
                add(r(poly(30f + i * 9, 44f - i * 2, 34.5f + i * 9, 32f - i * 2, 39f + i * 9, 44f - i * 2), "țepii"))
            }
            add(r(oval(44f, 60f, 24f, 17f), "corpul"))
            add(r(oval(46f, 64f, 13f, 10f), "burtica"))
            add(r(round(32f, 70f, 8f, 14f, 3f), "piciorul"))
            add(r(round(52f, 70f, 8f, 14f, 3f), "piciorul"))
            add(r(circle(72f, 38f, 13f), "capul"))
            add(r(circle(76f, 34f, 3f), "ochiul"))
            add(r(oval(84f, 44f, 4f, 2.5f), "nasul"))
            add(r(cloud(20f, 18f, 6f), "norul"))
        }),
        ColoringPage("curcubeu", "Curcubeul", "🌈", buildList {
            add(r(rect(0f, 0f, 100f, 100f), "cerul"))
            for (i in 0 until 6) add(r(band(50f, 72f, 44f - i * 5, 39f - i * 5), "curcubeul"))
            add(r(cloud(12f, 72f, 9f), "norul"))
            add(r(cloud(88f, 72f, 9f), "norul"))
            add(r(circle(50f, 14f, 8f), "soarele"))
            add(r(heartPath(50f, 88f, 6f), "inimioara"))
        }),
        ColoringPage("forme", "Forme", "⭐", listOf(
            r(rect(0f, 0f, 100f, 100f), "fundalul"),
            r(circle(25f, 25f, 16f), "cercul"),
            r(rect(60f, 10f, 30f, 30f), "pătratul"),
            r(poly(25f, 56f, 8f, 88f, 42f, 88f), "triunghiul"),
            r(starPath(75f, 72f, 18f), "steaua"),
            r(heartPath(50f, 50f, 9f), "inima"),
            r(circle(25f, 25f, 7f), "cercul mic"),
            r(rect(69f, 19f, 12f, 12f), "pătrățelul"),
        )),
    )
}
