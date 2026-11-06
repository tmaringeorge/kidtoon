package ro.kidtoon.tv.ui

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

private val DayTop = Color(0xFF6EC6FF)
private val DayBottom = Color(0xFFD8F1FF)
private val NightTop = Color(0xFF0B1240)
private val NightBottom = Color(0xFF2B3A7A)
private val Sun = Color(0xFFFFD54F)
private val SunRay = Color(0xFFFFB300)
private val Moon = Color(0xFFFFF4C2)
private val Star = Color(0xFFFFE57F)
private val HillDay = Color(0xFF7CC576)
private val HillNight = Color(0xFF1E4D3A)
private val HillDay2 = Color(0xFF5DAE5A)
private val HillNight2 = Color(0xFF173D2E)

// Pozitiile stelelor (fractiuni din latime / inaltime).
private val starPositions = listOf(
    Offset(0.18f, 0.20f), Offset(0.34f, 0.12f), Offset(0.50f, 0.24f), Offset(0.66f, 0.14f), Offset(0.80f, 0.26f),
)

/** Scena "cer cu soare, luna si stele"; t = pozitia in ciclul de un minut. */
internal fun DrawScope.drawSkyScene(t: Float, measurer: TextMeasurer) {
    val d = SkyTimeline.dayness(t)
    drawRect(Brush.verticalGradient(listOf(lerp(NightTop, DayTop, d), lerp(NightBottom, DayBottom, d))))
    val horizon = size.height * 0.78f

    // Soarele: rasare in stanga, trece pe cer si apune in dreapta.
    if (t < SkyTimeline.SUN_END) {
        val p = t / SkyTimeline.SUN_END
        val center = Offset(
            x = size.width * (0.12f + 0.76f * p),
            y = horizon - sin(p * PI).toFloat() * size.height * 0.55f,
        )
        drawSun(center, size.minDimension * 0.09f, t)
    }

    // Norii trec incet ziua.
    if (d > 0f) {
        for (i in 0 until 3) {
            val x = (((t * 1.6f) + i * 0.4f) % 1.3f - 0.15f) * size.width
            val y = size.height * (0.16f + i * 0.09f)
            drawCloud(Offset(x, y), size.minDimension * 0.06f, Color.White.copy(alpha = 0.9f * d))
        }
    }

    // Luna urca in dreapta sus noaptea.
    if (t >= SkyTimeline.MOON_START) {
        val p = ((t - SkyTimeline.MOON_START) / 0.12f).coerceAtMost(1f)
        val center = Offset(size.width * 0.86f, horizon - sin(p * PI / 2).toFloat() * size.height * 0.62f)
        drawMoon(center, size.minDimension * 0.075f, alpha = 1f - d)
    }

    // Stelele apar una cate una, cu numarul sub ele.
    val visible = SkyTimeline.starsVisible(t)
    for (i in 0 until visible) {
        val appearT = SkyTimeline.FIRST_STAR + i * SkyTimeline.STAR_STEP
        val fadeIn = ((t - appearT) / 0.02f).coerceIn(0f, 1f)
        val twinkle = 1f + 0.06f * sin((t * 60f + i) * 2f).toFloat()
        val pos = Offset(starPositions[i].x * size.width, starPositions[i].y * size.height)
        val r = size.minDimension * 0.045f * twinkle * (0.6f + 0.4f * fadeIn)
        drawPath(starPath(pos, r), Star.copy(alpha = fadeIn * (1f - d)))
        val label = measurer.measure(
            "${i + 1}",
            TextStyle(color = Color.White.copy(alpha = fadeIn * (1f - d)), fontSize = 26.sp, fontWeight = FontWeight.Bold),
        )
        drawText(label, topLeft = Offset(pos.x - label.size.width / 2f, pos.y + r * 1.1f))
    }

    // Dealuri.
    drawHill(horizon - size.height * 0.02f, size.width * 0.3f, size.height * 0.16f, lerp(HillNight2, HillDay2, d))
    drawHill(horizon + size.height * 0.02f, size.width * 0.75f, size.height * 0.14f, lerp(HillNight, HillDay, d))
}

internal fun DrawScope.drawSun(c: Offset, r: Float, t: Float) {
    rotate(degrees = t * 360f, pivot = c) {
        for (i in 0 until 12) {
            val a = i * PI.toFloat() / 6f
            drawLine(
                SunRay,
                start = Offset(c.x + cos(a) * r * 1.25f, c.y + sin(a) * r * 1.25f),
                end = Offset(c.x + cos(a) * r * 1.6f, c.y + sin(a) * r * 1.6f),
                strokeWidth = r * 0.12f,
            )
        }
    }
    drawCircle(Sun, r, c)
    // Fata zambitoare.
    val eye = Color(0xFF6D4C41)
    drawCircle(eye, r * 0.09f, Offset(c.x - r * 0.35f, c.y - r * 0.2f))
    drawCircle(eye, r * 0.09f, Offset(c.x + r * 0.35f, c.y - r * 0.2f))
    drawArc(
        eye, startAngle = 20f, sweepAngle = 140f, useCenter = false,
        topLeft = Offset(c.x - r * 0.45f, c.y - r * 0.3f), size = Size(r * 0.9f, r * 0.8f),
        style = Stroke(width = r * 0.08f),
    )
}

internal fun DrawScope.drawCloud(c: Offset, r: Float, color: Color) {
    drawCircle(color, r, c)
    drawCircle(color, r * 0.8f, Offset(c.x - r * 1.1f, c.y + r * 0.25f))
    drawCircle(color, r * 0.9f, Offset(c.x + r * 1.1f, c.y + r * 0.2f))
    drawCircle(color, r * 0.7f, Offset(c.x + r * 0.2f, c.y + r * 0.45f))
}

private fun DrawScope.drawMoon(c: Offset, r: Float, alpha: Float) {
    val full = Path().apply { addOval(androidx.compose.ui.geometry.Rect(c, r)) }
    val cut = Path().apply { addOval(androidx.compose.ui.geometry.Rect(Offset(c.x + r * 0.45f, c.y - r * 0.2f), r * 0.9f)) }
    val crescent = Path().apply { op(full, cut, PathOperation.Difference) }
    drawPath(crescent, Moon.copy(alpha = alpha))
}

internal fun starPath(c: Offset, r: Float): Path = Path().apply {
    for (i in 0 until 10) {
        val rad = if (i % 2 == 0) r else r * 0.45f
        val a = -PI / 2 + i * PI / 5
        val p = Offset(c.x + (cos(a) * rad).toFloat(), c.y + (sin(a) * rad).toFloat())
        if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
    }
    close()
}

internal fun DrawScope.drawHill(top: Float, centerX: Float, height: Float, color: Color) {
    val path = Path().apply {
        moveTo(0f, size.height)
        lineTo(0f, top + height)
        quadraticTo(centerX, top - height, size.width, top + height * 0.6f)
        lineTo(size.width, size.height)
        close()
    }
    drawPath(path, color)
}
