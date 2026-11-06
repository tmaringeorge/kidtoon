package ro.kidtoon.tv.ui

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.RadioBackground
import ro.kidtoon.tv.ui.KidsTimeline.Shape
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

private const val TAU = (2 * PI).toFloat()

/** Animatiile pentru copii din playerul radio (o scena anume sau toate pe rand). */
@Composable
fun KidsAnimation(mode: RadioBackground, modifier: Modifier = Modifier) {
    val elapsed by produceState(0L) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { value = it - start }
    }
    val frame = KidsTimeline.frame(elapsed, mode)
    val measurer = rememberTextMeasurer()

    Box(modifier.fillMaxSize()) {
        Crossfade(
            targetState = frame.segment to frame.scene,
            animationSpec = tween(1500),
            label = "scene",
        ) { (_, scene) ->
            Canvas(Modifier.fillMaxSize()) {
                val f = KidsTimeline.frame(elapsed, mode)
                when (scene) {
                    RadioBackground.OCEAN -> drawOcean(f.t, f.variant, measurer)
                    RadioBackground.FARM -> drawFarm(f.t, f.variant, measurer)
                    RadioBackground.BALLOONS -> drawBalloons(f.t, f.variant)
                    RadioBackground.TRAIN -> drawTrain(f.t, f.variant, measurer)
                    RadioBackground.SHAPES -> drawShapes(f.t, f.variant)
                    RadioBackground.FOOTBALL -> drawFootball(f.t, f.variant)
                    RadioBackground.SORCOVA -> drawSorcova(f.t, f.variant)
                    RadioBackground.SANTA -> drawSanta(f.t, f.variant, measurer)
                    RadioBackground.DINOS -> drawDinos(f.t, measurer)
                    RadioBackground.FIREFIGHTERS -> drawFirefighters(f.t, measurer)
                    RadioBackground.DOCTOR -> drawDoctor(f.t, f.variant, measurer)
                    RadioBackground.ZOO -> drawZoo(f.t, f.variant, measurer)
                    RadioBackground.TREES -> drawTrees(f.t, measurer)
                    else -> drawSkyScene(f.t, measurer)
                }
            }
        }

        Crossfade(
            targetState = KidsTimeline.caption(frame),
            label = "caption",
            modifier = Modifier.align(Alignment.TopCenter).padding(top = 36.dp),
        ) { caption ->
            Text(
                caption,
                color = Color.White,
                fontSize = 46.sp,
                fontWeight = FontWeight.Black,
                style = TextStyle(shadow = Shadow(Color(0x88000000), Offset(2f, 3f), 8f)),
            )
        }
    }
}

private fun kc(c: KidsTimeline.KidColor) = Color(c.argb)

private fun fade(x: Float, edge: Float = 0.12f) = (x / edge).coerceIn(0f, 1f) * ((1f - x) / edge).coerceIn(0f, 1f)

private fun DrawScope.drawEmoji(m: TextMeasurer, emoji: String, center: Offset, sizePx: Float, alpha: Float = 1f) {
    val layout = m.measure(emoji, TextStyle(fontSize = sizePx.toSp(), color = Color.Black.copy(alpha = alpha)))
    drawText(layout, topLeft = Offset(center.x - layout.size.width / 2f, center.y - layout.size.height / 2f), alpha = alpha)
}

private fun DrawScope.drawLabel(m: TextMeasurer, text: String, center: Offset, sizePx: Float, color: Color = Color.White) {
    val layout = m.measure(
        text,
        TextStyle(fontSize = sizePx.toSp(), color = color, fontWeight = FontWeight.Black, shadow = Shadow(Color(0x66000000), Offset(1f, 2f), 4f)),
    )
    drawText(layout, topLeft = Offset(center.x - layout.size.width / 2f, center.y - layout.size.height / 2f))
}

// ---------------- Ocean ----------------

private fun DrawScope.drawOcean(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF4FC3F7), Color(0xFF0277BD), Color(0xFF01579B))))
    // Raze de lumina care se misca incet.
    for (i in 0 until 4) {
        val x = w * (0.1f + i * 0.27f) + sin(t * TAU + i) * w * 0.02f
        val ray = Path().apply {
            moveTo(x - w * 0.03f, 0f); lineTo(x + w * 0.03f, 0f); lineTo(x + w * 0.09f, h * 0.8f); lineTo(x - w * 0.01f, h * 0.8f); close()
        }
        drawPath(ray, Color.White.copy(alpha = 0.06f))
    }
    // Nisip.
    val sandTop = h * 0.86f
    drawPath(Path().apply {
        moveTo(0f, h); lineTo(0f, sandTop)
        quadraticTo(w * 0.25f, sandTop - h * 0.04f, w * 0.5f, sandTop)
        quadraticTo(w * 0.75f, sandTop + h * 0.04f, w, sandTop - h * 0.01f)
        lineTo(w, h); close()
    }, Color(0xFFFFE0A3))
    // Alge care se leagana.
    for (i in 0 until 5) {
        val baseX = w * (0.08f + i * 0.21f)
        val sway = sin(t * TAU * 3 + i * 1.3f) * w * 0.025f
        val tall = h * (0.22f + (i % 3) * 0.06f)
        val weed = Path().apply {
            moveTo(baseX, sandTop + h * 0.02f)
            quadraticTo(baseX - sway, sandTop - tall * 0.5f, baseX + sway, sandTop - tall)
        }
        drawPath(weed, Color(0xFF2E7D32), style = Stroke(width = w * 0.012f, cap = StrokeCap.Round))
    }
    // Bule.
    for (i in 0 until 9) {
        val p = (t * 3f + i * 0.137f) % 1f
        val x = w * (0.05f + (i * 0.113f) % 0.9f) + sin(p * TAU * 2 + i) * w * 0.01f
        val y = sandTop - p * sandTop
        drawCircle(Color.White.copy(alpha = 0.5f * (1f - p)), radius = h * (0.008f + (i % 3) * 0.004f), center = Offset(x, y), style = Stroke(width = 2.dp.toPx()))
    }
    // Pestii.
    val r = size.minDimension * 0.07f
    for (i in 0 until KidsTimeline.fishVisible(t)) {
        val start = KidsTimeline.FISH_START + i * KidsTimeline.FISH_STEP
        val alpha = ((t - start) / 0.03f).coerceIn(0f, 1f) * ((1f - t) / 0.06f).coerceIn(0f, 1f)
        val x = (((t - start) * 0.55f + i * 0.19f + 0.05f) % 1.25f - 0.12f) * w
        val y = h * (0.30f + i * 0.11f) + sin(t * TAU * 4 + i) * h * 0.012f
        drawFish(Offset(x, y), r, kc(KidsTimeline.fishColor(variant, i)), alpha)
        drawLabel(m, "${i + 1}", Offset(x, y - r * 1.15f), r * 0.6f, Color.White.copy(alpha = alpha))
    }
}

private fun DrawScope.drawFish(c: Offset, r: Float, color: Color, alpha: Float) {
    val tail = Path().apply {
        moveTo(c.x - r * 0.8f, c.y); lineTo(c.x - r * 1.5f, c.y - r * 0.6f); lineTo(c.x - r * 1.5f, c.y + r * 0.6f); close()
    }
    drawPath(tail, color.copy(alpha = alpha))
    drawOval(color.copy(alpha = alpha), topLeft = Offset(c.x - r, c.y - r * 0.62f), size = Size(r * 2f, r * 1.24f))
    drawCircle(Color.White.copy(alpha = alpha), r * 0.2f, Offset(c.x + r * 0.5f, c.y - r * 0.15f))
    drawCircle(Color(0xFF263238).copy(alpha = alpha), r * 0.1f, Offset(c.x + r * 0.55f, c.y - r * 0.15f))
    drawArc(
        Color(0xFF263238).copy(alpha = alpha), startAngle = 20f, sweepAngle = 100f, useCenter = false,
        topLeft = Offset(c.x + r * 0.45f, c.y), size = Size(r * 0.35f, r * 0.25f), style = Stroke(width = r * 0.06f),
    )
}

// ---------------- Ferma ----------------

private fun DrawScope.drawFarm(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF81D4FA), Color(0xFFE1F5FE))))
    drawSun(Offset(w * 0.88f, h * 0.2f), size.minDimension * 0.07f, t * 0.3f)
    drawCloud(Offset(w * (0.2f + 0.1f * sin(t * TAU)), h * 0.18f), size.minDimension * 0.05f, Color.White)
    val ground = h * 0.62f
    drawHill(ground, w * 0.6f, h * 0.06f, Color(0xFF8BC34A))
    // Hambarul.
    val bx = w * 0.06f
    val bw = w * 0.2f
    val bTop = ground - h * 0.18f
    drawRect(Color(0xFFC62828), topLeft = Offset(bx, bTop), size = Size(bw, h * 0.26f))
    drawPath(Path().apply { moveTo(bx - bw * 0.08f, bTop); lineTo(bx + bw / 2, bTop - h * 0.13f); lineTo(bx + bw * 1.08f, bTop); close() }, Color(0xFF8D2A1F))
    val door = Rect(Offset(bx + bw * 0.3f, bTop + h * 0.09f), Size(bw * 0.4f, h * 0.17f))
    drawRect(Color(0xFFFFF8E1), door.topLeft, door.size, style = Stroke(width = w * 0.005f))
    drawLine(Color(0xFFFFF8E1), door.topLeft, door.bottomRight, strokeWidth = w * 0.005f)
    drawLine(Color(0xFFFFF8E1), door.topRight, door.bottomLeft, strokeWidth = w * 0.005f)
    // Gardul.
    val fenceY = ground + h * 0.06f
    val brown = Color(0xFFA1887F)
    drawLine(brown, Offset(w * 0.3f, fenceY), Offset(w, fenceY), strokeWidth = h * 0.012f)
    drawLine(brown, Offset(w * 0.3f, fenceY + h * 0.05f), Offset(w, fenceY + h * 0.05f), strokeWidth = h * 0.012f)
    var x = w * 0.32f
    while (x < w) {
        drawRoundRect(brown, Offset(x, fenceY - h * 0.04f), Size(w * 0.012f, h * 0.12f), CornerRadius(w * 0.006f))
        x += w * 0.06f
    }
    // Animalul de acum, cu o mica topaiala si balonul cu sunetul lui.
    val slot = KidsTimeline.farmSlot(t)
    val local = t * 5 - slot
    val a = KidsTimeline.animal(variant, slot)
    val alpha = fade(local)
    val hop = abs(sin(local * PI.toFloat() * 4)) * h * 0.025f
    val c = Offset(w * 0.58f, h * 0.7f - hop)
    drawEmoji(m, a.emoji, c, size.minDimension * 0.3f, alpha)
    if (local > 0.3f) {
        val bubble = Offset(w * 0.8f, h * 0.42f)
        val ba = alpha * ((local - 0.3f) / 0.08f).coerceIn(0f, 1f)
        drawRoundRect(Color.White.copy(alpha = ba), Offset(bubble.x - w * 0.12f, bubble.y - h * 0.07f), Size(w * 0.24f, h * 0.14f), CornerRadius(h * 0.07f))
        drawPath(Path().apply {
            moveTo(bubble.x - w * 0.08f, bubble.y + h * 0.05f); lineTo(bubble.x - w * 0.13f, bubble.y + h * 0.14f); lineTo(bubble.x - w * 0.03f, bubble.y + h * 0.06f); close()
        }, Color.White.copy(alpha = ba))
        drawLabel(m, a.sound, bubble, h * 0.06f, Color(0xFF5D4037).copy(alpha = ba))
    }
}

// ---------------- Baloane ----------------

private fun DrawScope.drawBalloons(t: Float, variant: Int) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF90CAF9), Color(0xFFFFF3E0))))
    for (i in 0 until 3) {
        val cx = (((t * 0.8f) + i * 0.37f) % 1.3f - 0.15f) * w
        drawCloud(Offset(cx, h * (0.2f + i * 0.14f)), size.minDimension * 0.05f, Color.White.copy(alpha = 0.85f))
    }
    drawHill(h * 0.86f, w * 0.4f, h * 0.05f, Color(0xFF9CCC65))
    val r = size.minDimension * 0.08f
    for (i in 0 until 5) {
        val p = (t - (KidsTimeline.BALLOON_START + i * KidsTimeline.BALLOON_STEP)) / KidsTimeline.BALLOON_RISE
        if (p < 0f || p > 1f) continue
        val x = w * (0.14f + i * 0.18f) + sin(p * TAU * 1.5f + i) * w * 0.02f
        val y = h * 1.1f - p * h * 1.4f
        val color = kc(KidsTimeline.balloonColor(variant, i))
        val string = Path().apply {
            moveTo(x, y + r * 1.2f)
            quadraticTo(x - r * 0.3f, y + r * 1.8f, x + r * 0.1f, y + r * 2.6f)
        }
        drawPath(string, Color(0xFF616161), style = Stroke(width = 2.dp.toPx()))
        drawPath(Path().apply { moveTo(x, y + r * 1.1f); lineTo(x - r * 0.15f, y + r * 1.32f); lineTo(x + r * 0.15f, y + r * 1.32f); close() }, color)
        drawOval(color, topLeft = Offset(x - r, y - r * 1.2f), size = Size(r * 2f, r * 2.4f))
        drawOval(Color.White.copy(alpha = 0.45f), topLeft = Offset(x - r * 0.55f, y - r * 0.85f), size = Size(r * 0.35f, r * 0.6f))
        if (color == Color.White) drawOval(Color(0x33000000), topLeft = Offset(x - r, y - r * 1.2f), size = Size(r * 2f, r * 2.4f), style = Stroke(1.5.dp.toPx()))
    }
}

// ---------------- Tren ----------------

private fun DrawScope.drawTrain(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF64B5F6), Color(0xFFE3F2FD))))
    drawSun(Offset(w * 0.12f, h * 0.2f), size.minDimension * 0.06f, t * 0.3f)
    drawHill(h * 0.6f, w * 0.7f, h * 0.1f, Color(0xFFAED581))
    drawHill(h * 0.68f, w * 0.25f, h * 0.08f, Color(0xFF8BC34A))
    // Copaci in departare care trec incet (parca mergem cu trenul).
    for (i in 0 until 7) {
        val x = ((i / 7f) - t * 0.6f).mod(1f) * w * 1.2f - w * 0.1f
        val baseY = h * 0.72f
        drawLine(Color(0xFF6D4C41), Offset(x, baseY), Offset(x, baseY - h * 0.05f), strokeWidth = w * 0.006f)
        drawCircle(Color(0xFF558B2F), h * 0.035f, Offset(x, baseY - h * 0.07f))
    }
    // Sinele.
    val rail = h * 0.8f
    drawRect(Color(0xFF7CB342), topLeft = Offset(0f, rail - h * 0.02f), size = Size(w, h - rail + h * 0.02f))
    var sx = 0f
    while (sx < w) {
        drawRect(Color(0xFF795548), topLeft = Offset(sx, rail + h * 0.005f), size = Size(w * 0.02f, h * 0.03f))
        sx += w * 0.05f
    }
    drawLine(Color(0xFF616161), Offset(0f, rail + h * 0.01f), Offset(w, rail + h * 0.01f), strokeWidth = h * 0.008f)

    val car = w / KidsTimeline.SCREEN_CARS
    val front = KidsTimeline.trainFront(t) * car
    val carH = car * 0.5f
    val top = rail - carH - car * 0.12f
    val fruit = KidsTimeline.fruit(variant)
    for (k in 0..5) {
        val right = front - k * car
        val left = right - car * 0.94f
        if (right < 0f || left > w) continue
        val wheelR = car * 0.1f
        if (k == 0) {
            // Locomotiva cu cos si fum.
            drawRoundRect(Color(0xFFD32F2F), Offset(left, top), Size(car * 0.94f, carH), CornerRadius(car * 0.06f))
            drawRect(Color(0xFFB71C1C), Offset(left, top - carH * 0.6f), Size(car * 0.4f, carH * 0.6f))
            drawRect(Color(0xFFBBDEFB), Offset(left + car * 0.08f, top - carH * 0.45f), Size(car * 0.24f, carH * 0.3f))
            drawRect(Color(0xFF424242), Offset(right - car * 0.3f, top - carH * 0.5f), Size(car * 0.14f, carH * 0.5f))
            for (j in 0 until 3) {
                val p = (t * 6f + j / 3f) % 1f
                drawCircle(
                    Color.White.copy(alpha = 0.7f * (1f - p)),
                    radius = car * (0.06f + p * 0.1f),
                    center = Offset(right - car * 0.23f - p * car * 0.5f, top - carH * 0.6f - p * car * 0.6f),
                )
            }
            drawCircle(Color(0xFFFFEB3B), car * 0.05f, Offset(right - car * 0.02f, top + carH * 0.45f))
        } else {
            val color = kc(KidsTimeline.COLORS[(k + variant) % 7])
            drawRoundRect(color, Offset(left, top), Size(car * 0.94f, carH), CornerRadius(car * 0.06f))
            // Fructele: vagonul k duce k fructe.
            val fs = car * 0.16f
            for (j in 0 until k) {
                val fx = left + car * 0.47f + (j - (k - 1) / 2f) * fs * 0.95f
                drawEmoji(m, fruit.emoji, Offset(fx, top - fs * 0.45f), fs)
            }
            drawCircle(Color.White, carH * 0.3f, Offset(left + car * 0.47f, top + carH * 0.5f))
            drawLabel(m, "$k", Offset(left + car * 0.47f, top + carH * 0.5f), carH * 0.38f, Color(0xFF37474F))
        }
        // Cupla si rotile (se invart incet).
        drawLine(Color(0xFF424242), Offset(left - car * 0.06f, top + carH * 0.75f), Offset(left, top + carH * 0.75f), strokeWidth = car * 0.03f)
        for (wx in listOf(left + car * 0.22f, left + car * 0.72f)) {
            val c = Offset(wx, rail - wheelR * 0.2f)
            drawCircle(Color(0xFF37474F), wheelR, c)
            rotate(degrees = front / wheelR * 57.3f, pivot = c) {
                drawLine(Color(0xFFB0BEC5), Offset(c.x - wheelR * 0.8f, c.y), Offset(c.x + wheelR * 0.8f, c.y), strokeWidth = wheelR * 0.2f)
            }
        }
    }
}

// ---------------- Forme ----------------

private fun DrawScope.drawShapes(t: Float, variant: Int) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF283593), Color(0xFF5C6BC0))))
    val slot = KidsTimeline.shapeSlot(t)
    val local = t * 5 - slot
    // Formele de mai devreme raman mici, jos.
    for (j in 0 until slot) {
        val c = Offset(w * (0.2f + j * 0.15f), h * 0.86f)
        drawKidShape(KidsTimeline.shape(variant, j), c, size.minDimension * 0.06f, kc(KidsTimeline.shapeColor(variant, j)))
    }
    val alpha = fade(local, 0.1f)
    val grow = 0.7f + 0.3f * (local / 0.15f).coerceIn(0f, 1f)
    val c = Offset(w / 2f, h * 0.5f)
    scale(grow, pivot = c) {
        rotate(degrees = sin(local * TAU) * 8f, pivot = c) {
            drawKidShape(KidsTimeline.shape(variant, slot), c, size.minDimension * 0.2f, kc(KidsTimeline.shapeColor(variant, slot)).copy(alpha = alpha))
        }
    }
}

private fun DrawScope.drawKidShape(shape: Shape, c: Offset, r: Float, color: Color) {
    when (shape) {
        Shape.CIRCLE -> drawCircle(color, r, c)
        Shape.SQUARE -> drawRoundRect(color, Offset(c.x - r * 0.9f, c.y - r * 0.9f), Size(r * 1.8f, r * 1.8f), CornerRadius(r * 0.1f))
        Shape.TRIANGLE -> drawPath(Path().apply {
            moveTo(c.x, c.y - r); lineTo(c.x + r * 1.05f, c.y + r * 0.8f); lineTo(c.x - r * 1.05f, c.y + r * 0.8f); close()
        }, color)
        Shape.STAR -> drawPath(starPath(c, r * 1.1f), color)
        Shape.HEART -> drawPath(Path().apply {
            moveTo(c.x, c.y + r * 0.9f)
            cubicTo(c.x - r * 1.6f, c.y - r * 0.1f, c.x - r * 0.8f, c.y - r * 1.3f, c.x, c.y - r * 0.45f)
            cubicTo(c.x + r * 0.8f, c.y - r * 1.3f, c.x + r * 1.6f, c.y - r * 0.1f, c.x, c.y + r * 0.9f)
            close()
        }, color)
    }
}

// ---------------- Fotbal ----------------

private fun DrawScope.drawBall(c: Offset, r: Float, spin: Float) {
    drawCircle(Color.White, r, c)
    drawCircle(Color(0xFF263238), r, c, style = Stroke(width = r * 0.08f))
    rotate(spin, pivot = c) {
        drawPath(Path().apply {
            for (i in 0 until 5) {
                val a = -PI.toFloat() / 2 + i * TAU / 5
                val p = Offset(c.x + kotlin.math.cos(a) * r * 0.38f, c.y + sin(a) * r * 0.38f)
                if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y)
            }
            close()
        }, Color(0xFF263238))
        for (i in 0 until 5) {
            val a = -PI.toFloat() / 2 + i * TAU / 5
            drawLine(
                Color(0xFF263238),
                Offset(c.x + kotlin.math.cos(a) * r * 0.38f, c.y + sin(a) * r * 0.38f),
                Offset(c.x + kotlin.math.cos(a) * r, c.y + sin(a) * r),
                strokeWidth = r * 0.07f,
            )
        }
    }
}

private fun DrawScope.drawFootball(t: Float, variant: Int) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF64B5F6), Color(0xFFBBDEFB))), size = Size(w, h * 0.45f))
    // Tribuna cu suporteri (puncte colorate care se leagana usor).
    drawRect(Color(0xFF546E7A), topLeft = Offset(0f, h * 0.3f), size = Size(w, h * 0.15f))
    for (i in 0 until 40) {
        val x = w * (i + 0.5f) / 40f
        val y = h * (0.34f + (i % 3) * 0.035f) - abs(sin(t * TAU * 6 + i)) * h * 0.008f
        drawCircle(kc(KidsTimeline.COLORS[(i + variant) % 8]), h * 0.012f, Offset(x, y))
    }
    // Gazonul in dungi.
    for (i in 0 until 8) {
        drawRect(
            if (i % 2 == 0) Color(0xFF43A047) else Color(0xFF388E3C),
            topLeft = Offset(0f, h * 0.45f + i * h * 0.07f), size = Size(w, h * 0.07f),
        )
    }
    val lineColor = Color.White.copy(alpha = 0.8f)
    drawLine(lineColor, Offset(w * 0.5f, h * 0.45f), Offset(w * 0.5f, h), strokeWidth = h * 0.006f)
    drawCircle(lineColor, h * 0.12f, Offset(w * 0.5f, h * 0.72f), style = Stroke(h * 0.006f))
    // Poarta din dreapta, cu plasa.
    val goalL = w * 0.78f
    val goalR = w * 0.95f
    val goalTop = h * 0.5f
    val goalBottom = h * 0.8f
    for (i in 1 until 8) {
        val x = goalL + (goalR - goalL) * i / 8f
        drawLine(Color.White.copy(alpha = 0.5f), Offset(x, goalTop), Offset(x, goalBottom), strokeWidth = 1.5f)
    }
    for (i in 1 until 6) {
        val y = goalTop + (goalBottom - goalTop) * i / 6f
        drawLine(Color.White.copy(alpha = 0.5f), Offset(goalL, y), Offset(goalR, y), strokeWidth = 1.5f)
    }
    val post = h * 0.014f
    drawLine(Color.White, Offset(goalL, goalBottom), Offset(goalL, goalTop), strokeWidth = post)
    drawLine(Color.White, Offset(goalL, goalTop), Offset(goalR, goalTop), strokeWidth = post)
    drawLine(Color.White, Offset(goalR, goalTop), Offset(goalR, goalBottom), strokeWidth = post)
    val r = size.minDimension * 0.045f
    // Golurile de pana acum stau in plasa.
    val scored = KidsTimeline.goals(t) - if (KidsTimeline.kickLocal(t) >= KidsTimeline.GOAL_AT) 1 else 0
    for (i in 0 until scored) drawBall(Offset(goalL + r * 1.3f + i * r * 1.6f, goalBottom - r), r * 0.7f, 0f)
    // Mingea de acum: sta, zboara in arc spre poarta, apoi ramane in plasa.
    val local = KidsTimeline.kickLocal(t)
    val start = Offset(w * 0.25f, h * 0.82f)
    val end = Offset(w * 0.86f, h * 0.68f)
    val p = ((local - KidsTimeline.KICK_AT) / (KidsTimeline.GOAL_AT - KidsTimeline.KICK_AT)).coerceIn(0f, 1f)
    val arc = h * (0.18f + (variant % 3) * 0.06f)
    val ball = Offset(start.x + (end.x - start.x) * p, start.y + (end.y - start.y) * p - sin(p * PI.toFloat()) * arc)
    val alpha = ((1f - local) / 0.08f).coerceIn(0f, 1f)
    drawCircle(Color.Black.copy(alpha = 0.18f * alpha), r * 0.9f, Offset(ball.x, start.y + r * 0.9f + (end.y - start.y) * p))
    if (alpha > 0f) drawBall(ball, r, p * 720f)
}

// ---------------- Sorcova ----------------

private fun DrawScope.drawSorcova(t: Float, variant: Int) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF7986CB))))
    drawSnow(t, Color.White)
    drawHill(h * 0.86f, w * 0.5f, h * 0.05f, Color(0xFFE8EAF6))
    // Sorcova se leagana usor, ca atunci cand se ureaza.
    val base = Offset(w * 0.5f, h * 0.95f)
    val stickLen = h * 0.5f
    rotate(degrees = sin(t * TAU * 5) * 14f, pivot = base) {
        val top = Offset(base.x, base.y - stickLen)
        drawLine(Color(0xFF8D6E63), base, top, strokeWidth = w * 0.014f, cap = StrokeCap.Round)
        // Panglici.
        for (i in 0 until 5) {
            val c = kc(KidsTimeline.COLORS[(i + variant) % 7])
            val sway = sin(t * TAU * 5 + i) * w * 0.02f
            val x0 = top.x + (i - 2) * w * 0.02f
            drawPath(Path().apply {
                moveTo(x0, top.y + h * 0.02f)
                quadraticTo(x0 + sway, top.y + h * 0.15f, x0 - sway, top.y + h * 0.26f)
            }, c, style = Stroke(width = w * 0.008f, cap = StrokeCap.Round))
        }
        // Florile de hartie.
        val flowerR = size.minDimension * 0.05f
        val spots = listOf(
            Offset(0f, -2.2f), Offset(-1.3f, -1.5f), Offset(1.3f, -1.5f), Offset(-1.9f, -0.2f),
            Offset(1.9f, -0.2f), Offset(-0.7f, -0.4f), Offset(0.7f, -0.4f), Offset(0f, -1.2f),
        )
        spots.forEachIndexed { i, o ->
            val c = Offset(top.x + o.x * flowerR, top.y + o.y * flowerR)
            val color = kc(KidsTimeline.COLORS[(i * 3 + variant) % 8])
            for (k in 0 until 6) {
                val a = k * TAU / 6 + t * 2f
                drawCircle(color, flowerR * 0.42f, Offset(c.x + kotlin.math.cos(a) * flowerR * 0.45f, c.y + sin(a) * flowerR * 0.45f))
            }
            drawCircle(Color(0xFFFFF59D), flowerR * 0.3f, c)
        }
    }
}

private fun DrawScope.drawSnow(t: Float, color: Color) {
    val w = size.width
    val h = size.height
    for (i in 0 until 40) {
        val speed = 0.6f + (i % 4) * 0.2f
        val p = (t * speed * 2f + i * 0.0731f) % 1f
        val x = w * ((i * 0.137f) % 1f) + sin(p * TAU * 2 + i) * w * 0.015f
        drawCircle(color.copy(alpha = 0.85f), h * (0.004f + (i % 3) * 0.002f), Offset(x, p * h))
    }
}

// ---------------- Mos Craciun ----------------

private fun DrawScope.drawGift(c: Offset, s: Float, color: Color) {
    drawRect(color, topLeft = Offset(c.x - s / 2, c.y - s / 2), size = Size(s, s))
    drawRect(Color(0xFFFFEB3B), topLeft = Offset(c.x - s * 0.08f, c.y - s / 2), size = Size(s * 0.16f, s))
    drawRect(Color(0xFFFFEB3B), topLeft = Offset(c.x - s / 2, c.y - s * 0.08f), size = Size(s, s * 0.16f))
    drawCircle(Color(0xFFFFEB3B), s * 0.14f, Offset(c.x - s * 0.12f, c.y - s * 0.56f))
    drawCircle(Color(0xFFFFEB3B), s * 0.14f, Offset(c.x + s * 0.12f, c.y - s * 0.56f))
}

private fun DrawScope.drawSanta(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF0D1B4C), Color(0xFF283E8C))))
    for (i in 0 until 14) {
        val pos = Offset(w * ((i * 0.193f + 0.05f) % 1f), h * (0.05f + (i * 0.071f) % 0.35f))
        drawPath(starPath(pos, h * 0.008f * (1f + 0.15f * sin(t * TAU * 3 + i))), Color(0xFFFFF59D))
    }
    drawCircle(Color(0xFFFFF4C2), size.minDimension * 0.06f, Offset(w * 0.85f, h * 0.15f))
    drawSnow(t, Color.White)
    // Zapada si casute cu lumina la geam.
    val ground = h * 0.8f
    drawHill(ground, w * 0.4f, h * 0.04f, Color(0xFFF5F5F5))
    for (i in 0 until 3) {
        val hx = w * (0.08f + i * 0.17f)
        val hw = w * 0.12f
        val hTop = ground - h * 0.1f
        drawRect(Color(0xFF8D6E63), topLeft = Offset(hx, hTop), size = Size(hw, h * 0.12f))
        drawPath(Path().apply { moveTo(hx - hw * 0.1f, hTop); lineTo(hx + hw / 2, hTop - h * 0.07f); lineTo(hx + hw * 1.1f, hTop); close() }, Color.White)
        drawRect(Color(0xFFFFD54F), topLeft = Offset(hx + hw * 0.35f, hTop + h * 0.03f), size = Size(hw * 0.3f, h * 0.04f))
    }
    // Bradul, cu cadourile adunate dedesubt.
    val treeX = w * 0.8f
    val treeBase = ground + h * 0.02f
    for (k in 0 until 3) {
        val tw = w * (0.16f - k * 0.035f)
        val ty = treeBase - h * (0.06f + k * 0.08f)
        drawPath(Path().apply { moveTo(treeX - tw / 2, ty); lineTo(treeX, ty - h * 0.14f); lineTo(treeX + tw / 2, ty); close() }, Color(0xFF2E7D32))
    }
    drawPath(starPath(Offset(treeX, treeBase - h * 0.36f), h * 0.025f), Color(0xFFFFD54F))
    // Beculete care se aprind incet pe rand.
    for (k in 0 until 9) {
        val lx = treeX + ((k % 3) - 1) * w * 0.035f * (1.2f - (k / 3) * 0.3f)
        val ly = treeBase - h * (0.08f + (k / 3) * 0.08f)
        val on = 0.5f + 0.5f * sin(t * TAU * 3 + k * 1.7f)
        drawCircle(kc(KidsTimeline.COLORS[k % 7]).copy(alpha = 0.4f + 0.6f * on), h * 0.009f, Offset(lx, ly))
    }
    val giftS = size.minDimension * 0.06f
    val pile = { i: Int -> Offset(treeX + (i - 2) * giftS * 1.15f, treeBase + giftS * 0.1f) }
    // Sania trece pe cer si lasa cate un cadou.
    val sp = KidsTimeline.sleighProgress(t)
    // Merge de la dreapta la stanga, cu renii in fata.
    val sleigh = Offset(w * 1.2f - sp * w * 1.4f, h * 0.3f + sin(sp * TAU) * h * 0.04f)
    for (i in 0 until 5) {
        val drop = KidsTimeline.GIFT_FIRST + i * KidsTimeline.GIFT_STEP
        if (t < drop) continue
        val color = kc(KidsTimeline.COLORS[(i * 2 + variant) % 7])
        val q = ((t - drop) / KidsTimeline.GIFT_FALL).coerceIn(0f, 1f)
        val from = Offset(w * 1.2f - KidsTimeline.sleighProgress(drop) * w * 1.4f, h * 0.36f)
        val to = pile(i)
        val fade = ((1f - t) / 0.05f).coerceIn(0f, 1f)
        drawGift(Offset(from.x + (to.x - from.x) * q, from.y + (to.y - from.y) * q * q), giftS, color.copy(alpha = fade))
    }
    if (sp in 0.001f..0.999f) drawEmoji(m, "🦌🦌🛷🎅", sleigh, size.minDimension * 0.09f)
}

// ---------------- Dinozauri ----------------

private fun DrawScope.drawPalm(base: Offset, h: Float, t: Float) {
    val top = Offset(base.x + h * 0.08f, base.y - h)
    drawPath(Path().apply {
        moveTo(base.x, base.y); quadraticTo(base.x + h * 0.15f, base.y - h * 0.5f, top.x, top.y)
    }, Color(0xFF795548), style = Stroke(width = h * 0.07f, cap = StrokeCap.Round))
    for (i in 0 until 6) {
        val a = -PI.toFloat() + i * PI.toFloat() / 5f + sin(t * TAU * 2 + i) * 0.06f
        val end = Offset(top.x + kotlin.math.cos(a) * h * 0.45f, top.y + sin(a) * h * 0.25f + h * 0.12f)
        drawPath(Path().apply {
            moveTo(top.x, top.y); quadraticTo((top.x + end.x) / 2, top.y - h * 0.12f, end.x, end.y)
        }, Color(0xFF2E7D32), style = Stroke(width = h * 0.05f, cap = StrokeCap.Round))
    }
}

private fun DrawScope.drawDinos(t: Float, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFFFFB74D), Color(0xFFFFE0B2), Color(0xFFFFF3E0))))
    // Vulcanul, cu fum care urca incet (fara foc).
    val vBase = h * 0.66f
    drawPath(Path().apply {
        moveTo(w * 0.55f, vBase); lineTo(w * 0.68f, h * 0.3f); lineTo(w * 0.76f, h * 0.3f); lineTo(w * 0.9f, vBase); close()
    }, Color(0xFF6D4C41))
    for (i in 0 until 4) {
        val p = (t * 2f + i / 4f) % 1f
        drawCircle(Color(0xFF9E9E9E).copy(alpha = 0.6f * (1f - p)), h * (0.03f + p * 0.05f), Offset(w * 0.72f + p * w * 0.05f, h * 0.28f - p * h * 0.22f))
    }
    drawHill(h * 0.64f, w * 0.3f, h * 0.05f, Color(0xFF9CCC65))
    drawRect(Color(0xFF8BC34A), topLeft = Offset(0f, h * 0.72f), size = Size(w, h * 0.28f))
    drawPalm(Offset(w * 0.08f, h * 0.78f), h * 0.32f, t)
    drawPalm(Offset(w * 0.95f, h * 0.8f), h * 0.26f, t + 0.3f)
    // Dinozaurii trec pe rand, fiecare cu numarul lui.
    val emojis = listOf("🦕", "🦖", "🦕", "🦖", "🦕")
    for (i in 0 until KidsTimeline.dinosVisible(t)) {
        val start = KidsTimeline.FISH_START + i * KidsTimeline.FISH_STEP
        val alpha = ((t - start) / 0.03f).coerceIn(0f, 1f) * ((1f - t) / 0.06f).coerceIn(0f, 1f)
        val x = w * 1.1f - (((t - start) * 0.5f + i * 0.17f) % 1.25f) * w
        val y = h * (0.74f + (i % 2) * 0.1f) - abs(sin((t - start) * TAU * 6)) * h * 0.01f
        val sz = size.minDimension * (0.16f + (i % 2) * 0.05f)
        drawEmoji(m, emojis[i], Offset(x, y), sz, alpha)
        drawLabel(m, "${i + 1}", Offset(x, y - sz * 0.75f), sz * 0.3f, Color.White.copy(alpha = alpha))
    }
}

// ---------------- Pompierii ----------------

private fun DrawScope.drawFlame(c: Offset, r: Float, t: Float, k: Int) {
    if (r <= 1f) return
    val wobble = 1f + 0.08f * sin(t * TAU * 8 + k)
    val outer = Path().apply {
        moveTo(c.x - r * 0.6f, c.y)
        quadraticTo(c.x - r * 0.7f, c.y - r * 1.1f * wobble, c.x, c.y - r * 1.8f * wobble)
        quadraticTo(c.x + r * 0.7f, c.y - r * 1.1f * wobble, c.x + r * 0.6f, c.y)
        close()
    }
    drawPath(outer, Color(0xFFFF7043))
    val inner = Path().apply {
        moveTo(c.x - r * 0.3f, c.y)
        quadraticTo(c.x - r * 0.35f, c.y - r * 0.6f, c.x, c.y - r * 1.0f * wobble)
        quadraticTo(c.x + r * 0.35f, c.y - r * 0.6f, c.x + r * 0.3f, c.y)
        close()
    }
    drawPath(inner, Color(0xFFFFD54F))
}

private fun DrawScope.drawFirefighters(t: Float, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF90CAF9), Color(0xFFE3F2FD))))
    drawCloud(Offset(w * 0.2f, h * 0.18f), size.minDimension * 0.05f, Color.White)
    val ground = h * 0.78f
    drawRect(Color(0xFF9E9E9E), topLeft = Offset(0f, ground), size = Size(w, h - ground))
    var dash = 0f
    while (dash < w) { drawRect(Color.White, Offset(dash, ground + h * 0.1f), Size(w * 0.05f, h * 0.012f)); dash += w * 0.1f }
    // Casa.
    val hx = w * 0.6f
    val hw = w * 0.26f
    val hTop = ground - h * 0.3f
    drawRect(Color(0xFFFFCC80), topLeft = Offset(hx, hTop), size = Size(hw, h * 0.3f))
    drawPath(Path().apply { moveTo(hx - hw * 0.08f, hTop); lineTo(hx + hw / 2, hTop - h * 0.14f); lineTo(hx + hw * 1.08f, hTop); close() }, Color(0xFFD84315))
    drawRect(Color(0xFF8D6E63), topLeft = Offset(hx + hw * 0.4f, ground - h * 0.13f), size = Size(hw * 0.2f, h * 0.13f))
    val win1 = Offset(hx + hw * 0.12f, hTop + h * 0.05f)
    val win2 = Offset(hx + hw * 0.66f, hTop + h * 0.05f)
    drawRect(Color(0xFFB3E5FC), win1, Size(hw * 0.22f, h * 0.08f))
    drawRect(Color(0xFFB3E5FC), win2, Size(hw * 0.22f, h * 0.08f))
    // Fum si flacari mici pe acoperis (se micsoreaza cand vine apa).
    val fs = KidsTimeline.fireSize(t)
    for (i in 0 until 3) {
        val p = (t * 3f + i / 3f) % 1f
        drawCircle(Color(0xFF757575).copy(alpha = 0.5f * fs * (1f - p)), h * (0.025f + p * 0.04f), Offset(hx + hw * 0.7f + p * w * 0.04f, hTop - h * 0.1f - p * h * 0.25f))
    }
    drawFlame(Offset(hx + hw * 0.62f, hTop - h * 0.03f), h * 0.05f * fs, t, 0)
    drawFlame(Offset(hx + hw * 0.78f, hTop + h * 0.0f), h * 0.04f * fs, t, 1)
    // Masina de pompieri vine din stanga.
    val arrive = KidsTimeline.truckArrive(t)
    val eased = 1f - (1f - arrive) * (1f - arrive)
    val truck = Offset(-w * 0.2f + eased * w * 0.55f, ground - h * 0.07f)
    val truckSize = size.minDimension * 0.28f
    if (t >= 0.2f) {
        drawEmoji(m, "🚒", truck, truckSize)
        drawEmoji(m, "🧑‍🚒", Offset(truck.x + truckSize * 0.55f, ground - h * 0.08f), truckSize * 0.45f)
    }
    // Apa: un arc de picaturi spre foc.
    if (KidsTimeline.firePhase(t) == 2) {
        val from = Offset(truck.x + truckSize * 0.7f, ground - h * 0.14f)
        val to = Offset(hx + hw * 0.7f, hTop)
        for (i in 0 until 14) {
            val q = ((i / 14f) + t * 6f) % 1f
            val pos = Offset(from.x + (to.x - from.x) * q, from.y + (to.y - from.y) * q - sin(q * PI.toFloat()) * h * 0.18f)
            drawCircle(Color(0xFF29B6F6).copy(alpha = 0.85f), h * 0.009f, pos)
        }
    }
    if (KidsTimeline.firePhase(t) == 3) drawLabel(m, "👍", Offset(hx + hw / 2, hTop - h * 0.2f), h * 0.08f)
}

// ---------------- La doctor ----------------

private fun DrawScope.drawDoctor(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFFE0F7FA), Color(0xFFB2EBF2))))
    // Cabinetul: dulap cu cruce si pat.
    drawRoundRect(Color.White, Offset(w * 0.08f, h * 0.3f), Size(w * 0.16f, h * 0.36f), CornerRadius(h * 0.02f))
    drawRect(Color(0xFFE53935), Offset(w * 0.145f, h * 0.38f), Size(w * 0.03f, h * 0.1f))
    drawRect(Color(0xFFE53935), Offset(w * 0.115f, h * 0.415f), Size(w * 0.09f, h * 0.03f))
    drawRect(Color(0xFF80DEEA), topLeft = Offset(0f, h * 0.8f), size = Size(w, h * 0.2f))
    drawRoundRect(Color(0xFFFFFFFF), Offset(w * 0.38f, h * 0.62f), Size(w * 0.36f, h * 0.08f), CornerRadius(h * 0.02f))
    drawRect(Color(0xFF90A4AE), Offset(w * 0.4f, h * 0.7f), Size(w * 0.015f, h * 0.1f))
    drawRect(Color(0xFF90A4AE), Offset(w * 0.71f, h * 0.7f), Size(w * 0.015f, h * 0.1f))
    val step = KidsTimeline.doctorStep(t)
    val p = KidsTimeline.patient(variant)
    val ps = size.minDimension * 0.24f
    val patientC = Offset(w * 0.56f, h * 0.52f)
    val bounce = if (step == 3) abs(sin(t * TAU * 6)) * h * 0.03f else 0f
    drawEmoji(m, p.emoji, Offset(patientC.x, patientC.y - bounce), ps)
    drawEmoji(m, "👩‍⚕️", Offset(w * 0.84f, h * 0.55f), size.minDimension * 0.26f)
    when (step) {
        0 -> drawEmoji(m, "😢", Offset(patientC.x + ps * 0.55f, patientC.y - ps * 0.5f), ps * 0.3f)
        1 -> {
            val beat = 1f + 0.18f * abs(sin(t * TAU * 10))
            drawEmoji(m, "🩺", Offset(w * 0.72f, h * 0.5f), ps * 0.4f)
            drawEmoji(m, "❤️", Offset(patientC.x, patientC.y - ps * 0.75f), ps * 0.28f * beat)
        }
        2 -> drawEmoji(m, "🩹", Offset(patientC.x - ps * 0.3f, patientC.y + ps * 0.15f), ps * 0.35f)
        else -> {
            drawEmoji(m, "🩹", Offset(patientC.x - ps * 0.3f, patientC.y + ps * 0.15f - bounce), ps * 0.35f)
            for (i in 0 until 4) {
                val q = (t * 4f + i / 4f) % 1f
                drawEmoji(m, "💖", Offset(patientC.x + (i - 1.5f) * ps * 0.4f, patientC.y - ps * 0.6f - q * h * 0.25f), ps * 0.2f, 1f - q)
            }
        }
    }
}

// ---------------- Zoo ----------------

private fun DrawScope.drawZoo(t: Float, variant: Int, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFFFFE082), Color(0xFFFFF8E1))))
    drawSun(Offset(w * 0.86f, h * 0.18f), size.minDimension * 0.07f, t * 0.3f)
    drawHill(h * 0.6f, w * 0.5f, h * 0.05f, Color(0xFFDCE775))
    drawRect(Color(0xFFC0CA33), topLeft = Offset(0f, h * 0.7f), size = Size(w, h * 0.3f))
    // Un salcam de savana.
    drawLine(Color(0xFF6D4C41), Offset(w * 0.15f, h * 0.72f), Offset(w * 0.17f, h * 0.42f), strokeWidth = w * 0.015f)
    drawOval(Color(0xFF689F38), Offset(w * 0.04f, h * 0.34f), Size(w * 0.26f, h * 0.1f))
    // Animalul de acum vine incet si saluta.
    val slot = KidsTimeline.zooSlot(t)
    val local = t * 5 - slot
    val a = KidsTimeline.zooAnimal(variant, slot)
    val alpha = fade(local)
    val x = w * (0.62f - 0.08f * (1f - (local / 0.2f).coerceIn(0f, 1f)))
    val hop = abs(sin(local * PI.toFloat() * 3)) * h * 0.015f
    drawEmoji(m, a.emoji, Offset(x, h * 0.66f - hop), size.minDimension * 0.34f, alpha)
    // Cei de dinainte stau mici, in rand, pe iarba.
    for (j in 0 until slot) drawEmoji(m, KidsTimeline.zooAnimal(variant, j).emoji, Offset(w * (0.3f + j * 0.1f), h * 0.9f), size.minDimension * 0.08f)
}

// ---------------- Plantam copaci ----------------

private fun DrawScope.drawTree(base: Offset, h: Float, growth: Float) {
    if (growth <= 0f) return
    val th = h * growth
    drawLine(Color(0xFF795548), base, Offset(base.x, base.y - th * 0.55f), strokeWidth = h * 0.08f * growth.coerceAtLeast(0.3f), cap = StrokeCap.Round)
    val c = Offset(base.x, base.y - th * 0.7f)
    val r = h * 0.28f * growth
    drawCircle(Color(0xFF388E3C), r, c)
    drawCircle(Color(0xFF43A047), r * 0.8f, Offset(c.x - r * 0.6f, c.y + r * 0.2f))
    drawCircle(Color(0xFF43A047), r * 0.8f, Offset(c.x + r * 0.6f, c.y + r * 0.2f))
    drawCircle(Color(0xFF66BB6A), r * 0.6f, Offset(c.x, c.y - r * 0.4f))
}

private fun DrawScope.drawTrees(t: Float, m: TextMeasurer) {
    val w = size.width
    val h = size.height
    drawRect(Brush.verticalGradient(listOf(Color(0xFF81D4FA), Color(0xFFE1F5FE))))
    drawSun(Offset(w * 0.12f, h * 0.18f), size.minDimension * 0.07f, t * 0.3f)
    drawCloud(Offset(w * (0.6f + 0.1f * sin(t * TAU)), h * 0.16f), size.minDimension * 0.05f, Color.White)
    val ground = h * 0.78f
    drawRect(Color(0xFF8D6E63), topLeft = Offset(0f, ground), size = Size(w, h - ground))
    drawRect(Color(0xFF7CB342), topLeft = Offset(0f, ground - h * 0.02f), size = Size(w, h * 0.03f))
    val slot = KidsTimeline.treeSlot(t)
    val local = KidsTimeline.treeLocal(t)
    val spot = { i: Int -> Offset(w * (0.14f + i * 0.18f), ground) }
    val treeH = h * 0.42f
    for (j in 0 until slot) drawTree(spot(j), treeH, 1f)
    val here = spot(slot)
    // Groapa, samanta, apa, apoi copacul creste.
    if (local < 0.45f) drawOval(Color(0xFF5D4037), Offset(here.x - w * 0.04f, ground - h * 0.01f), Size(w * 0.08f, h * 0.03f))
    if (local < 0.25f) drawEmoji(m, "🧑‍🌾", Offset(here.x + w * 0.07f, ground - h * 0.08f), size.minDimension * 0.16f)
    if (local in 0.25f..0.45f) {
        drawEmoji(m, "🌱", Offset(here.x, ground - h * 0.04f), size.minDimension * 0.08f)
        for (i in 0 until 6) {
            val q = ((i / 6f) + t * 10f) % 1f
            drawCircle(Color(0xFF29B6F6), h * 0.008f, Offset(here.x - w * 0.02f + i * w * 0.008f, ground - h * 0.2f + q * h * 0.16f))
        }
        drawEmoji(m, "🚿", Offset(here.x + w * 0.02f, ground - h * 0.24f), size.minDimension * 0.1f)
    }
    drawTree(here, treeH, KidsTimeline.treeGrowth(t))
    if (local >= 0.8f) drawEmoji(m, "🐦", Offset(here.x + w * 0.03f, ground - treeH * 0.95f + sin(t * TAU * 8) * h * 0.01f), size.minDimension * 0.07f)
}
