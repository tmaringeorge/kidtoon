package ro.kidtoon.tv.ui

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.TextMeasurer
import ro.kidtoon.tv.data.GhiPerson
import ro.kidtoon.tv.data.StudioPerson
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/** Cum arată un om: piele, păr, haine, ce poartă pe cap și ce mai are pe el. */
private class Look(
    val skin: Color, val hair: Color, val top: Color, val bottom: Color, val shoes: Color,
    val style: String = "short", val dress: Boolean = false, val hat: String? = null, val extras: Set<String> = emptySet(),
    val beard: Boolean = false, val lashes: Boolean = false, val glasses: Boolean = false, val longSleeves: Boolean = false,
    val eyes: Color = Color(0xFF5D4037),
)

private val LOOKS = mapOf(
    "mami" to Look(Color(0xFFF2C6A0), Color(0xFF5D4037), Color(0xFFE57399), Color(0xFF3F51B5), Color(0xFF6D4C41), style = "long", dress = true, lashes = true),
    "tati" to Look(Color(0xFFE8B98F), Color(0xFF3E2723), Color(0xFF42A5F5), Color(0xFF455A64), Color(0xFF263238), beard = true, extras = setOf("buttons")),
    "bunica" to Look(Color(0xFFF0C8A8), Color(0xFFCFD8DC), Color(0xFF9575CD), Color(0xFF5E35B1), Color(0xFF4E342E), style = "bun", dress = true, glasses = true, lashes = true, longSleeves = true),
    "educatoare" to Look(Color(0xFFF5CBA7), Color(0xFF8D6E63), Color(0xFF26A69A), Color(0xFF37474F), Color(0xFF5D4037), style = "bun", lashes = true, longSleeves = true),
    "pompier" to Look(Color(0xFFE0AC85), Color(0xFF3E2723), Color(0xFF3E2723), Color(0xFF3E2723), Color(0xFF212121), hat = "fire", extras = setOf("reflect"), longSleeves = true, beard = true),
    "doctor" to Look(Color(0xFFF1C27D), Color(0xFF212121), Color(0xFF81D4FA), Color(0xFF4FC3F7), Color(0xFFECEFF1), style = "bun", extras = setOf("coat", "stetho"), lashes = true, glasses = true),
    "politist" to Look(Color(0xFFA1785C), Color(0xFF212121), Color(0xFF90CAF9), Color(0xFF1A237E), Color(0xFF212121), hat = "police", extras = setOf("badge", "tie", "belt"), eyes = Color(0xFF3E2723)),
    "bucatar" to Look(Color(0xFFE8B98F), Color(0xFF4E342E), Color(0xFFFAFAFA), Color(0xFF616161), Color(0xFF212121), hat = "chef", extras = setOf("apron", "chefButtons"), beard = true),
    "constructor" to Look(Color(0xFFD7A07A), Color(0xFF3E2723), Color(0xFF1E88E5), Color(0xFF3949AB), Color(0xFF795548), hat = "hard", extras = setOf("vest"), beard = true),
    "fermier" to Look(Color(0xFFE6B48A), Color(0xFF6D4C41), Color(0xFFD32F2F), Color(0xFF1565C0), Color(0xFF4E342E), hat = "straw", extras = setOf("overall", "plaid"), beard = true),
    "postas" to Look(Color(0xFFF2C6A0), Color(0xFFFFB74D), Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF212121), style = "long", hat = "post", extras = setOf("bag"), lashes = true, eyes = Color(0xFF1E88E5)),
    "pilot" to Look(Color(0xFF8D5524), Color(0xFF1B1B1B), Color(0xFFFAFAFA), Color(0xFF1A237E), Color(0xFF111111), style = "bun", hat = "pilot", extras = setOf("tie", "wings"), lashes = true, eyes = Color(0xFF3E2723)),
    "veterinar" to Look(Color(0xFFF5D0B5), Color(0xFFBF360C), Color(0xFF66BB6A), Color(0xFF388E3C), Color(0xFFECEFF1), style = "long", extras = setOf("stetho"), lashes = true, eyes = Color(0xFF43A047)),
    "brutar" to Look(Color(0xFFEDC09A), Color(0xFF6D4C41), Color(0xFFFFF8E1), Color(0xFF8D6E63), Color(0xFF5D4037), style = "bun", hat = "baker", extras = setOf("apron"), lashes = true, longSleeves = true),
)

private fun Color.darker(f: Float = 0.8f) = Color(red * f, green * f, blue * f, alpha)
private fun Color.lighter(f: Float = 0.25f) = Color(red + (1 - red) * f, green + (1 - green) * f, blue + (1 - blue) * f, alpha)

// Offset e o clasă „value”, deci nu poate fi vararg: până la 5 puncte, ultimele opționale.
private fun poly(a: Offset, b: Offset, c: Offset, d: Offset? = null, e: Offset? = null) = Path().apply {
    moveTo(a.x, a.y)
    for (pt in listOfNotNull(b, c, d, e)) lineTo(pt.x, pt.y)
    close()
}

private fun DrawScope.line(c: Color, a: Offset, b: Offset, w: Float) = drawLine(c, a, b, w, cap = StrokeCap.Round)
private fun DrawScope.arc(c: Color, start: Float, sweep: Float, center: Boolean, r: Rect, stroke: Float? = null) =
    drawArc(c, start, sweep, center, r.topLeft, r.size, style = if (stroke == null) androidx.compose.ui.graphics.drawscope.Fill else Stroke(stroke, cap = StrokeCap.Round))
private fun centered(c: Offset, w: Float, h: Float) = Rect(c.x - w / 2, c.y - h / 2, c.x + w / 2, c.y + h / 2)

/** Personajele făcute pe telefon în Studio: desenate la fel ca mami, tati și meseriile. */
@Volatile private var customLooks: Map<String, Look> = emptyMap()

fun setStudioPeople(people: List<StudioPerson>) {
    customLooks = people.associate { p ->
        p.id to Look(
            Color(p.skin), Color(p.hair), Color(p.top), Color(p.bottom), Color(p.shoes),
            style = p.style, dress = p.dress, hat = p.hat, beard = p.beard, glasses = p.glasses,
            lashes = p.style != "short" || p.dress,
        )
    }
}

/**
 * Un om cu proporții de adult: față ovală, nas, buze, ochi cu gene, gât umbrit, mâini cu degete,
 * haine cu lumină și umbră și, la meserii, uniforma și ce poartă pe cap. Picioarele stau în (px, py).
 */
internal fun DrawScope.drawPerson(
    p: GhiPerson, local: Float, ts: Float, px: Float, py: Float, height: Float, m: TextMeasurer, gazeAt: Float = 0f,
) {
    val look = LOOKS[p.who] ?: customLooks[p.who] ?: LOOKS.getValue("mami")
    val u = height / 100f
    val sitting = p.pose == "sit"
    val walk = p.pose == "walk"
    val pi = PI.toFloat()
    val bob = if (walk) abs(sin(ts * pi * 2.4f)) * 1.2f else sin(ts * pi * 0.8f) * 0.4f
    val drop = if (sitting) 22f else 0f
    val ex = look.extras

    // Umbra pe pământ, mai închisă chiar sub tălpi.
    drawOval(Color(0x22000000), Offset(px - 18 * u, py - 2.5f * u), Size(36 * u, 6 * u))
    drawOval(Color(0x22000000), Offset(px - 11 * u, py - 1.5f * u), Size(22 * u, 3.5f * u))

    withTransform({
        translate(px, py)
        if (p.flip) scale(-1f, 1f, Offset.Zero)
        // Își mută ușor greutatea de pe un picior pe altul.
        if (!sitting && !walk) rotate(sin(ts * 0.7f + px) * 0.7f, Offset.Zero)
    }) {
        fun o(x: Float, y: Float) = Offset(x * u, (y + drop - bob) * u)
        val hipY = -48f
        val legColor = if ("overall" in ex) look.bottom else if (look.dress) look.skin.darker(0.95f) else look.bottom

        fun shoe(at: Offset) {
            drawRoundRect(look.shoes, at, Size(14 * u, 6 * u), CornerRadius(3 * u))
            line(look.shoes.lighter(0.35f), at + Offset(2 * u, 1.4f * u), at + Offset(9 * u, 1.4f * u), 0.8f * u)
            line(look.shoes.darker(0.6f), at + Offset(0f, 5.6f * u), at + Offset(14 * u, 5.6f * u), 1 * u)
        }

        // Picioarele.
        if (sitting) {
            // Scaunul.
            drawRoundRect(Color(0xFF5D4037), o(-14f, hipY + 5), Size(30 * u, 5 * u), CornerRadius(2 * u))
            drawLine(Color(0xFF4E342E), o(0f, hipY + 9), o(0f, -drop), 3 * u)
            line(Color(0xFF4E342E), o(-10f, -drop), o(10f, -drop), 3 * u)
            for (side in listOf(-4f, 4f)) {
                line(legColor.darker(), o(side - 2, hipY + 2), o(side + 20, hipY + 2), 10 * u)
                line(legColor, o(side + 20, hipY + 2), o(side + 20, hipY + 22), 9 * u)
                shoe(o(side + 15, hipY + 20))
            }
        } else {
            val swing = if (walk) sin(ts * pi * 2.4f) * 16f else 0f
            val kick = if (p.pose == "kick" && local in 0.25f..0.5f) 40f else 0f
            for ((i, side) in listOf(-5f, 5f).withIndex()) {
                val ang = if (i == 0) swing else -swing - kick
                rotate(ang, o(side, hipY)) {
                    val c = if (i == 0) legColor.darker() else legColor
                    line(c, o(side, hipY), o(side, -26f), 10 * u)
                    line(c, o(side, -26f), o(side, -5f), 8.6f * u)
                    if ("reflect" in ex) line(Color(0xFFFFEB3B), o(side - 4.3f, -16f), o(side + 4.3f, -16f), 2 * u)
                    shoe(o(side - 4, -6f))
                }
            }
        }

        val sleeves = look.longSleeves || "coat" in ex || "reflect" in ex
        val backAngle = when (p.pose) {
            "wave", "carry" -> -2.7f
            "clap" -> -1.3f + sin(ts * 9f) * 0.25f
            "walk" -> -sin(ts * pi * 2.4f) * 0.4f - 0.15f
            else -> -0.2f
        }
        personArm(o(-12f, -79f), backAngle, u, look.top.darker(), look.skin.darker(0.92f), sleeves)

        // Corpul, cu lumină din stânga și umbră în dreapta.
        val bottomY = if (look.dress) -30f else -46f
        val hem = if (look.dress) 22f else 14f
        val torso = Path().apply {
            val a = o(-13f, -85f); moveTo(a.x, a.y)
            val c1 = o(0f, -88f); val b = o(13f, -85f); quadraticTo(c1.x, c1.y, b.x, b.y)
            val d = o(15f, -60f); lineTo(d.x, d.y)
            val e = o(hem, bottomY); lineTo(e.x, e.y)
            val c2 = o(0f, bottomY + if (look.dress) 4f else 1f); val f = o(-hem, bottomY); quadraticTo(c2.x, c2.y, f.x, f.y)
            val g = o(-15f, -60f); lineTo(g.x, g.y)
            close()
        }
        drawPath(torso, Brush.horizontalGradient(listOf(look.top.lighter(0.2f), look.top, look.top.darker(0.78f)), -hem * u, hem * u))
        if (look.dress) {
            line(look.top.darker(0.85f), o(-14f, -60f), o(14f, -60f), 1.6f * u)
            for (fx in listOf(-8f, 0f, 8f)) line(Color(0x1A000000), o(fx * 0.6f, -56f), o(fx, -32f), 1.2f * u)
        } else {
            val belt = if ("belt" in ex) Color(0xFF212121) else look.bottom.darker()
            drawRect(belt, o(-14.5f, -49f), Size(29 * u, 4 * u))
            drawRect(Color(0xFFBDBDBD), o(-2f, -48.6f), Size(4 * u, 3.2f * u))
        }
        if ("plaid" in ex) for (k in 0 until 4) {
            line(Color(0x33000000), o(-13f, -80f + k * 8), o(13f, -80f + k * 8), 1.4f * u)
            line(Color(0x22000000), o(-10f + k * 7, -84f), o(-10f + k * 7, -48f), 1.4f * u)
        }
        if ("buttons" in ex || "badge" in ex) {
            for (k in 0 until 3) drawCircle(Color(0x99FFFFFF), 0.9f * u, o(0f, -76f + k * 9))
            drawPath(Path().apply { val a = o(-6f, -85f); val b = o(0f, -79f); val c = o(6f, -85f); moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y) },
                Color.White, style = Stroke(1.4f * u))
        }
        if ("chefButtons" in ex) for (k in 0 until 3) {
            drawCircle(Color(0xFF9E9E9E), 1 * u, o(-4f, -78f + k * 8))
            drawCircle(Color(0xFF9E9E9E), 1 * u, o(4f, -78f + k * 8))
        }
        if ("tie" in ex) drawPath(poly(o(-1.6f, -84f), o(1.6f, -84f), o(2.4f, -64f), o(0f, -61f), o(-2.4f, -64f)), Color(0xFF1A237E))
        if ("reflect" in ex) {
            line(Color(0xFFFFEB3B), o(-14f, -62f), o(14f, -62f), 3 * u)
            line(Color(0xFFBDBDBD), o(-14f, -66f), o(14f, -66f), 1.2f * u)
        }
        if ("vest" in ex) {
            drawPath(poly(o(-14f, -84f), o(-5f, -84f), o(-3f, -50f), o(-14f, -50f)), Color(0xFFFF6D00))
            drawPath(poly(o(14f, -84f), o(5f, -84f), o(3f, -50f), o(14f, -50f)), Color(0xFFFF6D00))
            for (y in listOf(-70f, -60f)) {
                line(Color(0xFFE0E0E0), o(-14f, y), o(-4f, y), 2 * u)
                line(Color(0xFFE0E0E0), o(4f, y), o(14f, y), 2 * u)
            }
        }
        if ("overall" in ex) {
            drawRoundRect(look.bottom, o(-9f, -70f), Size(18 * u, 24 * u), CornerRadius(2 * u))
            line(look.bottom, o(-8f, -70f), o(-11f, -85f), 3 * u)
            line(look.bottom, o(8f, -70f), o(11f, -85f), 3 * u)
            drawCircle(Color(0xFFFFD54F), 1.1f * u, o(-7f, -68f))
            drawCircle(Color(0xFFFFD54F), 1.1f * u, o(7f, -68f))
            drawRect(look.bottom.darker(), o(-4f, -64f), Size(8 * u, 6 * u), style = Stroke(0.8f * u))
        }
        if ("apron" in ex) {
            drawRoundRect(Color(0xFFF5F5F5), o(-10f, -74f), Size(20 * u, 44 * u), CornerRadius(3 * u))
            line(Color(0xFFF5F5F5), o(-10f, -74f), o(-7f, -86f), 1.5f * u)
            line(Color(0xFFF5F5F5), o(10f, -74f), o(7f, -86f), 1.5f * u)
            drawRect(Color(0x22000000), o(-6f, -54f), Size(12 * u, 8 * u), style = Stroke(0.8f * u))
        }
        if ("coat" in ex) {
            // Halatul alb, deschis în față.
            drawPath(poly(o(-15f, -85f), o(-4f, -85f), o(-2f, -30f), o(-17f, -30f)), Color(0xFFFAFAFA))
            drawPath(poly(o(15f, -85f), o(4f, -85f), o(2f, -30f), o(17f, -30f)), Color(0xFFEEEEEE))
            drawPath(poly(o(-4f, -85f), o(-1f, -72f), o(-7f, -80f)), Color(0xFFE0E0E0))
            drawPath(poly(o(4f, -85f), o(1f, -72f), o(7f, -80f)), Color(0xFFD6D6D6))
            drawRect(Color(0xFFBDBDBD), o(7f, -70f), Size(6 * u, 6 * u), style = Stroke(0.8f * u))
            line(Color(0xFF1E88E5), o(9f, -72f), o(9f, -66f), 1 * u)
        }
        if ("stetho" in ex) {
            val path = Path().apply {
                val a = o(-6f, -85f); val c1 = o(-9f, -70f); val b = o(-2f, -64f)
                moveTo(a.x, a.y); quadraticTo(c1.x, c1.y, b.x, b.y)
                val a2 = o(6f, -85f); val c2 = o(9f, -70f); val b2 = o(2f, -64f)
                moveTo(a2.x, a2.y); quadraticTo(c2.x, c2.y, b2.x, b2.y)
            }
            drawPath(path, Color(0xFF455A64), style = Stroke(1.3f * u, cap = StrokeCap.Round))
            line(Color(0xFF455A64), o(0f, -64f), o(0f, -58f), 1.3f * u)
            drawCircle(Color(0xFFB0BEC5), 2.2f * u, o(0f, -56.5f))
            drawCircle(Color(0xFF78909C), 1.2f * u, o(0f, -56.5f))
        }
        if ("badge" in ex) {
            val c = o(-7f, -74f)
            val star = Path()
            for (k in 0 until 10) {
                val r = (if (k % 2 == 0) 3f else 1.3f) * u
                val a = -pi / 2 + k * pi / 5
                val pt = c + Offset(cos(a), sin(a)) * r
                if (k == 0) star.moveTo(pt.x, pt.y) else star.lineTo(pt.x, pt.y)
            }
            star.close()
            drawPath(star, Color(0xFFFFC107))
        }
        if ("wings" in ex) {
            line(Color(0xFFFFC107), o(-11f, -74f), o(-3f, -74f), 1.6f * u)
            drawCircle(Color(0xFFFFC107), 1.2f * u, o(-7f, -74f))
            for (s in listOf(7f, 9f)) line(Color(0xFFFFC107), o(s, -84f), o(s, -80f), 1 * u)
        }
        if ("bag" in ex) {
            line(Color(0xFF6D4C41), o(12f, -84f), o(-10f, -52f), 2.2f * u)
            drawRoundRect(Color(0xFF8D6E63), o(-18f, -56f), Size(14 * u, 14 * u), CornerRadius(2 * u))
            drawRect(Color(0xFF6D4C41), o(-18f, -56f), Size(14 * u, 5 * u))
            drawRect(Color(0xFFFFF8E1), o(-12.5f, -48f), Size(3 * u, 2.4f * u), style = Stroke(0.6f * u))
        }

        // Gâtul, cu umbra bărbiei.
        drawRect(look.skin.darker(0.92f), o(-3.6f, -91f), Size(7.2f * u, 7 * u))
        drawOval(Color(0x22000000), o(-4f, -89.5f), Size(8 * u, 3 * u))

        val head = o(0.5f, -100f)
        val faceRect = centered(head, 20 * u, 24 * u)

        // Părul din spate (lung, coc).
        if (look.style == "long") drawRoundRect(look.hair.darker(0.85f), o(-13f, -109f), Size(10 * u, 27 * u), CornerRadius(5 * u))
        if (look.style == "bun" && look.hat == null) {
            drawCircle(look.hair, 5.5f * u, o(-6f, -113f))
            drawCircle(look.hair.lighter(0.15f), 2 * u, o(-7f, -114.5f))
        }

        // Fața ovală, cu lumină din stânga sus.
        drawOval(
            Brush.radialGradient(
                0f to look.skin.lighter(0.18f), 0.55f to look.skin, 1f to look.skin.darker(0.88f),
                center = head + Offset(-2.5f * u, -4.2f * u), radius = 13 * u,
            ),
            faceRect.topLeft, faceRect.size,
        )
        // Urechea, cu interiorul mai închis.
        val ear = head + Offset(-9.2f * u, 0.5f * u)
        centered(ear, 4 * u, 6 * u).let { drawOval(look.skin.darker(0.94f), it.topLeft, it.size) }
        centered(ear + Offset(0.3f * u, 0f), 1.8f * u, 3.4f * u).let { drawOval(look.skin.darker(0.8f), it.topLeft, it.size) }

        // Părul de deasupra.
        val hairTop = centered(head + Offset(-0.5f * u, -5 * u), 22.5f * u, 17 * u)
        when (look.style) {
            "long" -> {
                arc(look.hair, 175f, 195f, true, hairTop)
                drawPath(Path().apply {
                    moveTo(head.x - 3 * u, head.y - 12 * u)
                    quadraticTo(head.x + 6 * u, head.y - 10 * u, head.x + 10 * u, head.y - 3 * u)
                    lineTo(head.x + 10.5f * u, head.y - 9 * u); close()
                }, look.hair)
                // Coada care se leagănă.
                val sway = sin(ts * 2f) * 2f
                drawOval(look.hair, o(-19f + sway * 0.3f, -106f), Size(7 * u, 19 * u))
            }
            "bun" -> {
                arc(look.hair, 180f, 180f, true, hairTop)
                drawPath(Path().apply {
                    moveTo(head.x - 6 * u, head.y - 12 * u)
                    quadraticTo(head.x + 5 * u, head.y - 12 * u, head.x + 10 * u, head.y - 4 * u)
                    lineTo(head.x + 10 * u, head.y - 9 * u); close()
                }, look.hair)
            }
            else -> {
                arc(look.hair, 168f, 204f, true, hairTop.deflate(0.3f * u))
                drawRect(look.hair, head + Offset(-10.2f * u, -6 * u), Size(2.8f * u, 7 * u))
            }
        }
        // Șuvițe: câteva linii mai deschise dau senzația de păr adevărat.
        for (k in 0 until 3) arc(look.hair.lighter(0.22f), 205f + k * 22, 30f, false, hairTop.deflate((1.5f + k) * u), 0.6f * u)

        // Barba nerasă.
        if (look.beard) arc(look.hair.copy(alpha = 0.18f), 15f, 150f, true, centered(head + Offset(0f, 4 * u), 18 * u, 14 * u))

        // Ochii: alb, iris colorat, pupilă, luciri, pleoapă, gene și sprâncene.
        val dark = Color(0xFF2B1B17)
        val closed = ((ts + 1.7f + sin(ts * 0.29f) * 1.1f) % 4.3f) < 0.12f
        val gaze = (if (p.flip) -gazeAt else gazeAt) * 0.55f
        for (exX in listOf(-3.4f, 4.6f)) {
            val e = head + Offset(exX * u, -1.2f * u)
            if (closed) {
                arc(dark, 20f, 140f, false, centered(e, 3.8f * u, 2 * u), 0.7f * u)
            } else {
                centered(e, 4.2f * u, 2.9f * u).let { drawOval(Color(0xFFFDFDFD), it.topLeft, it.size) }
                val iris = e + Offset((0.25f + gaze) * u, 0.1f * u)
                drawCircle(look.eyes, 1.3f * u, iris)
                drawCircle(dark, 0.7f * u, iris)
                drawCircle(Color.White, 0.35f * u, iris + Offset(0.45f * u, -0.45f * u))
                arc(dark, 190f, 160f, false, centered(e, 4.4f * u, 3.1f * u), 0.55f * u)
                if (look.lashes) {
                    line(dark, e + Offset(1.6f * u, -1.1f * u), e + Offset(2.6f * u, -1.9f * u), 0.45f * u)
                    line(dark, e + Offset(0.6f * u, -1.5f * u), e + Offset(1.2f * u, -2.4f * u), 0.45f * u)
                }
            }
            val brow = look.hair.darker(if (look.hair.luminance() > 0.5f) 0.7f else 1f)
            arc(brow, 200f, 140f, false, centered(e + Offset(0f, -2.6f * u), 4.6f * u, 2.2f * u), 0.8f * u)
        }
        if (look.glasses) {
            for (exX in listOf(-3.4f, 4.6f)) drawCircle(Color(0xFF5D4037), 2.8f * u, head + Offset(exX * u, -1.2f * u), style = Stroke(0.55f * u))
            line(Color(0xFF5D4037), head + Offset(-0.6f * u, -1.4f * u), head + Offset(1.8f * u, -1.4f * u), 0.55f * u)
        }
        // Nasul: o umbră pe o parte și nările.
        drawPath(Path().apply {
            moveTo(head.x + 1.4f * u, head.y - 0.5f * u)
            quadraticTo(head.x + 3.4f * u, head.y + 3.6f * u, head.x + 1.6f * u, head.y + 4.2f * u)
        }, look.skin.darker(0.78f), style = Stroke(0.65f * u, cap = StrokeCap.Round))
        drawCircle(look.skin.darker(0.7f), 0.45f * u, head + Offset(0.4f * u, 4.1f * u))
        drawCircle(look.skin.darker(0.7f), 0.45f * u, head + Offset(2.4f * u, 4.1f * u))
        // Obrajii.
        drawCircle(Color(0x33FF8A80), 2.4f * u, head + Offset(-5 * u, 3.4f * u))
        drawCircle(Color(0x33FF8A80), 2.4f * u, head + Offset(7 * u, 3.4f * u))
        // Gura: buza de sus mai închisă, buza de jos cu luciu.
        val mo = head + Offset(1 * u, 7.2f * u)
        val lip = if (look.lashes) Color(0xFFC2185B) else look.skin.darker(0.62f)
        when (p.face) {
            "wow" -> centered(mo, 3.4f * u, 3.8f * u).let {
                drawOval(Color(0xFF6D1F1F), it.topLeft, it.size)
                drawOval(lip, it.topLeft, it.size, style = Stroke(0.7f * u))
            }
            "calm" -> arc(lip, 20f, 140f, false, centered(mo - Offset(0f, 1 * u), 5 * u, 2.6f * u), 0.9f * u)
            else -> {
                val smile = Path().apply {
                    moveTo(mo.x - 3.2f * u, mo.y - 1 * u)
                    quadraticTo(mo.x, mo.y + 0.2f * u, mo.x + 3.2f * u, mo.y - 1 * u)
                    quadraticTo(mo.x, mo.y + 3 * u, mo.x - 3.2f * u, mo.y - 1 * u)
                    close()
                }
                drawPath(smile, Color(0xFF7B2B2B))
                centered(mo + Offset(0f, -0.1f * u), 4 * u, 0.9f * u).let { drawRect(Color(0xFFF5F5F5), it.topLeft, it.size) }
                drawPath(smile, lip, style = Stroke(0.6f * u))
            }
        }

        // Ce poartă pe cap.
        personHat(look.hat, head, u)

        val frontAngle = when (p.pose) {
            "wave" -> 2.5f + sin(ts * pi * 3f) * 0.35f
            "reach", "hold" -> 1.5f
            "carry" -> 2.7f
            "clap" -> 1.3f - sin(ts * 9f) * 0.25f
            "point" -> 2.0f
            "sit" -> 1.3f
            "walk" -> sin(ts * pi * 2.4f) * 0.4f + 0.15f
            else -> if (p.hold != null) 0.9f else 0.2f
        }
        val shoulderR = o(12f, -79f)
        val hand = personArm(shoulderR, frontAngle, u, look.top, look.skin, sleeves)
        if ("coat" in ex) line(Color(0xFFF5F5F5), shoulderR, shoulderR + Offset(sin(frontAngle), cos(frontAngle)) * (15 * u), 8 * u)
        p.hold?.let { ghiEmoji(m, it, hand + Offset(3 * u, -4 * u), 14 * u) }
    }
}

/** Un braț cu cot: mâneca, antebrațul și mâna cu degetul mare. Întoarce poziția mâinii. */
private fun DrawScope.personArm(shoulder: Offset, angle: Float, u: Float, sleeve: Color, skin: Color, longSleeve: Boolean): Offset {
    val elbow = shoulder + Offset(sin(angle), cos(angle)) * (15 * u)
    val a2 = angle * 0.92f
    val hand = elbow + Offset(sin(a2), cos(a2)) * (14 * u)
    line(sleeve, shoulder, elbow, 8 * u)
    val cuff = if (longSleeve) elbow + (hand - elbow) * 0.8f else elbow + (hand - elbow) * 0.12f
    line(sleeve, elbow, cuff, 7 * u)
    line(skin, cuff, hand, 5.6f * u)
    // Palma și degetul mare.
    withTransform({
        translate(hand.x, hand.y)
        rotate(-a2 * 180f / PI.toFloat(), Offset.Zero)
    }) {
        centered(Offset(0f, 1.2f * u), 6.4f * u, 7.4f * u).let { drawOval(skin, it.topLeft, it.size) }
        centered(Offset(3 * u, -0.6f * u), 2.4f * u, 4.2f * u).let { drawOval(skin.darker(0.95f), it.topLeft, it.size) }
        drawLine(skin.darker(0.85f), Offset(-1.6f * u, 3.6f * u), Offset(1.6f * u, 3.6f * u), 0.5f * u)
    }
    return hand
}

private fun DrawScope.personHat(hat: String?, head: Offset, u: Float) {
    fun h(x: Float, y: Float) = head + Offset(x * u, y * u)
    when (hat) {
        "fire" -> {
            // Casca de pompier: roșie, cu bor lat și scut în față.
            centered(h(-1f, -9f), 32 * u, 7 * u).let { drawOval(Color(0xFFB71C1C), it.topLeft, it.size) }
            val dome = centered(h(0f, -10f), 23 * u, 20 * u)
            drawArc(Brush.radialGradient(listOf(Color(0xFFEF5350), Color(0xFFC62828)), h(-4.6f, -15f), 14 * u), 180f, 180f, true, dome.topLeft, dome.size)
            drawLine(Color(0xFF8E0000), h(0f, -20f), h(0f, -10f), 1.2f * u)
            centered(h(7f, -14f), 6 * u, 7 * u).let { drawRoundRect(Color(0xFFFFD54F), it.topLeft, it.size, CornerRadius(1.5f * u)) }
        }
        "police", "pilot" -> {
            val police = hat == "police"
            centered(h(0f, -12f), 22 * u, 7 * u).let { drawRect(Color(0xFF1A237E), it.topLeft, it.size) }
            centered(h(0f, -16f), 25 * u, 6 * u).let { drawOval(if (police) Color(0xFF283593) else Color(0xFF1A237E), it.topLeft, it.size) }
            if (police) centered(h(0f, -10f), 22 * u, 2 * u).let { drawRect(Color(0xFF212121), it.topLeft, it.size) }
            else centered(h(0f, -11f), 22 * u, 1.6f * u).let { drawRect(Color(0xFFFFC107), it.topLeft, it.size) }
            drawPath(poly(h(2f, -9f), h(14f, -9f), h(12f, -6.5f), h(2f, -7.5f)), Color(0xFF111111))
            drawCircle(Color(0xFFFFC107), (if (police) 1.8f else 1.6f) * u, h(4f, if (police) -13f else -13.5f))
        }
        "post" -> {
            arc(Color(0xFF1565C0), 180f, 180f, true, centered(h(0f, -9f), 22 * u, 16 * u))
            drawPath(poly(h(4f, -9.5f), h(15f, -9f), h(13f, -6.5f), h(4f, -7.5f)), Color(0xFF0D47A1))
            drawCircle(Color(0xFFFFC107), 1.6f * u, h(1f, -13f))
        }
        "hard" -> {
            // Casca galbenă de constructor.
            val dome = centered(h(0f, -9f), 24 * u, 20 * u)
            drawArc(Brush.radialGradient(listOf(Color(0xFFFFF176), Color(0xFFFBC02D)), h(-4.8f, -14f), 14 * u), 180f, 180f, true, dome.topLeft, dome.size)
            centered(h(1f, -9f), 30 * u, 3 * u).let { drawRoundRect(Color(0xFFF9A825), it.topLeft, it.size, CornerRadius(1.5f * u)) }
            drawLine(Color(0xFFF9A825), h(0f, -19f), h(0f, -10f), 1.4f * u)
        }
        "straw" -> {
            centered(h(0f, -10f), 36 * u, 7 * u).let { drawOval(Color(0xFFE6C36A), it.topLeft, it.size) }
            arc(Color(0xFFEDD083), 180f, 180f, true, centered(h(0f, -11f), 20 * u, 16 * u))
            centered(h(0f, -12f), 20 * u, 2.4f * u).let { drawRect(Color(0xFFC62828), it.topLeft, it.size) }
            for (k in -2..2) drawLine(Color(0x33000000), h(k * 6f - 1, -9f), h(k * 6f + 1, -11f), 0.5f * u)
        }
        "chef" -> {
            centered(h(0f, -11f), 20 * u, 5 * u).let { drawRect(Color(0xFFF5F5F5), it.topLeft, it.size) }
            for (c in listOf(h(-6f, -20f), h(0f, -23f), h(6f, -20f), h(0f, -17f))) drawCircle(Color(0xFFFAFAFA), 6.5f * u, c)
            drawLine(Color(0xFFE0E0E0), h(-9f, -13f), h(9f, -13f), 0.8f * u)
        }
        "baker" -> {
            centered(h(0f, -12f), 22 * u, 8 * u).let { drawRoundRect(Color(0xFFFAFAFA), it.topLeft, it.size, CornerRadius(4 * u)) }
            drawLine(Color(0xFFE0E0E0), h(-10f, -9f), h(10f, -9f), 0.8f * u)
        }
    }
}
