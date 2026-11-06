package ro.kidtoon.tv.ui

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.GhiBeat
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.GhiCharacter
import ro.kidtoon.tv.data.GhiCount
import ro.kidtoon.tv.data.GhiEpisode
import ro.kidtoon.tv.data.GhiPhase
import ro.kidtoon.tv.data.GhiPose
import ro.kidtoon.tv.data.GhiProp
import ro.kidtoon.tv.data.GhiSet
import ro.kidtoon.tv.data.GhiTimeline
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

private const val GTAU = (2 * PI).toFloat()

/** Un episod cu GHI: generic, povestea pe pași, apoi „Ce am învățat”. La final trece singur la următorul. */
@Composable
fun GhiAnimation(
    book: GhiBook, index: Int, onFinished: () -> Unit, modifier: Modifier = Modifier,
    quiz: GhiQuiz = remember { GhiQuiz() }, onSay: (String) -> Unit = {},
) {
    val ep = book.episodes[index.coerceIn(0, book.episodes.size - 1)]
    val done by rememberUpdatedState(onFinished)
    val say by rememberUpdatedState(onSay)
    val frame by produceState(0L, ep.id) {
        value = 0L
        val start = withFrameMillis { it }
        while (true) withFrameMillis { value = it - start }
    }
    if (quiz.episodeId != ep.id) quiz.reset(ep.id)
    val elapsed = frame + quiz.shift
    quiz.ep = ep
    quiz.ms = elapsed
    val total = GhiTimeline.durationMs(ep)
    LaunchedEffect(ep.id, elapsed >= total) { if (elapsed >= total) done() }
    val measurer = rememberTextMeasurer()
    val phase = GhiTimeline.phase(ep, elapsed)
    val step = phase as? GhiPhase.Step
    val askIndex = if (step != null && ep.beats[step.index].ask != null) step.index else -1
    if (quiz.askBeat != askIndex) { quiz.askBeat = askIndex; quiz.focus = 1 }
    val answered = step != null && quiz.answeredBeat == step.index
    val caption = when (phase) {
        is GhiPhase.Title -> ep.title
        is GhiPhase.End -> "Ce am învățat: ${ep.learn}"
        is GhiPhase.Step -> GhiTimeline.askCaption(
            ep.beats[phase.index], phase.local, answered = answered, wrong = elapsed - quiz.wrongAt < GhiTimeline.WRONG_MS,
        )
    }
    // Vocea povestește fiecare text nou.
    LaunchedEffect(caption) { say(caption) }

    Box(modifier.fillMaxSize().background(Color.Black)) {
        Canvas(Modifier.fillMaxSize()) { drawGhiFrame(book, ep, elapsed, measurer, answered, if (askIndex >= 0) quiz.focus else -1) }

        // Benzi negre sus și jos, ca la cinema.
        Box(Modifier.fillMaxWidth().fillMaxHeight(0.05f).background(Color.Black).align(Alignment.TopCenter))
        Box(Modifier.fillMaxWidth().fillMaxHeight(0.05f).background(Color.Black).align(Alignment.BottomCenter))

        when (phase) {
            is GhiPhase.Title -> {
                val a = (phase.local / 0.15f).coerceIn(0f, 1f) * ((1f - phase.local) / 0.2f).coerceIn(0f, 1f)
                Column(
                    Modifier.align(Alignment.Center).alpha(a)
                        .background(Color(0x99000000), RoundedCornerShape(28.dp)).padding(horizontal = 48.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("🎬  Episodul ${index + 1}", color = Color(0xFFFFE082), fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Text(ep.title, color = Color.White, fontSize = 54.sp, fontWeight = FontWeight.Black, style = shadowed)
                }
            }
            is GhiPhase.End -> {
                val a = (phase.local / 0.12f).coerceIn(0f, 1f) * ((1f - phase.local) / 0.1f).coerceIn(0f, 1f)
                Column(
                    Modifier.align(Alignment.Center).alpha(a).padding(horizontal = 80.dp)
                        .background(Color(0xF2FFFFFF), RoundedCornerShape(28.dp)).padding(horizontal = 40.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("⭐ Ce am învățat", color = Color(0xFFF57C00), fontSize = 28.sp, fontWeight = FontWeight.Black)
                    Text(ep.learn, color = Color(0xFF263238), fontSize = 34.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                }
            }
            is GhiPhase.Step -> Crossfade(
                targetState = caption,
                label = "ghi-caption",
                modifier = Modifier.align(Alignment.TopCenter).padding(top = 52.dp, start = 48.dp, end = 48.dp),
            ) { say ->
                Text(say, color = Color.White, fontSize = 42.sp, fontWeight = FontWeight.Black, style = shadowed, textAlign = TextAlign.Center)
            }
        }
    }
}

/**
 * Întrebările din episod pe TV: săgețile aleg un obiect, OK răspunde.
 * Câmpurile se citesc la fiecare cadru, deci nu trebuie să fie stare Compose.
 */
class GhiQuiz {
    var episodeId = ""
    var shift = 0L
    var answeredBeat = -1
    var wrongAt = Long.MIN_VALUE / 2
    var focus = 1
    var askBeat = -1
    var ep: GhiEpisode? = null
    var ms = 0L

    val asking get() = askBeat >= 0 && answeredBeat != askBeat

    fun reset(id: String) {
        episodeId = id; shift = 0; answeredBeat = -1; wrongAt = Long.MIN_VALUE / 2; focus = 1; askBeat = -1
    }

    fun move(d: Int) {
        val n = ep?.beats?.getOrNull(askBeat)?.props?.size ?: return
        if (n > 0) focus = (focus + d + n) % n
    }

    fun pick(i: Int = focus) {
        val e = ep ?: return
        val step = GhiTimeline.phase(e, ms) as? GhiPhase.Step ?: return
        val ask = e.beats[step.index].ask ?: return
        if (answeredBeat == step.index) return
        if (i == ask.answer) {
            answeredBeat = step.index
            shift += GhiTimeline.skipAfterAnswer(e, ms)
        } else {
            wrongAt = ms
        }
    }
}

/** GHI se bucură: aceeași poziție, dar sare, zâmbește și suflă steluțe. */
fun cheer(g: GhiPose) = g.copy(pose = "happy", face = "happy", puff = "stars")

/** Cercurile de la întrebări: auriu pe răspuns (găsit sau arătat de GHI), alb pe obiectul ales cu săgețile. */
internal fun DrawScope.drawAskRings(beat: GhiBeat, local: Float, ts: Float, answered: Boolean, focus: Int) {
    val ask = beat.ask ?: return
    beat.props.forEachIndexed { i, p ->
        val c = Offset(p.x.at(local) * size.width, p.y.at(local) * size.height)
        val r = p.size * size.minDimension * 0.85f
        if (i == ask.answer && (answered || local >= GhiTimeline.REVEAL)) {
            val pulse = 1f + 0.08f * sin(ts * GTAU * 1.2f)
            drawCircle(Color(0x55FFE082), r * 1.25f * pulse, c)
            drawCircle(Color(0xFFFFC107), r * pulse, c, style = Stroke(r * 0.12f))
            if (answered) for (k in 0 until 6) {
                val a = k * PI.toFloat() / 3 + ts * 1.5f
                drawCircle(Color(0xFFFFD54F), r * 0.1f, c + Offset(cos(a), sin(a)) * (r * 1.5f))
            }
        } else {
            drawCircle(Color(0x33FFFFFF), r, c)
        }
        if (i == focus) drawCircle(Color.White, r * 1.12f, c, style = Stroke(r * 0.1f))
    }
}

private val shadowed = TextStyle(shadow = Shadow(Color(0x99000000), Offset(2f, 3f), 8f))

private fun hex(c: Long) = Color(c.toInt())

internal fun DrawScope.ghiEmoji(m: TextMeasurer, e: String, c: Offset, px: Float, alpha: Float = 1f) {
    if (px < 2f || alpha <= 0.01f) return
    val l = m.measure(e, TextStyle(fontSize = px.toSp()))
    drawText(l, topLeft = Offset(c.x - l.size.width / 2f, c.y - l.size.height / 2f), alpha = alpha.coerceIn(0f, 1f))
}

internal fun DrawScope.ghiLabel(m: TextMeasurer, s: String, c: Offset, px: Float, color: Color = Color.White, alpha: Float = 1f) {
    if (px < 2f || alpha <= 0.01f) return
    val l = m.measure(s, TextStyle(fontSize = px.toSp(), color = color, fontWeight = FontWeight.Black, shadow = Shadow(Color(0x88000000), Offset(1f, 2f), 4f)))
    drawText(l, topLeft = Offset(c.x - l.size.width / 2f, c.y - l.size.height / 2f), alpha = alpha.coerceIn(0f, 1f))
}

/** Desenează un cadru: decorul, obiectele, numărătoarea și pe GHI, cu o cameră care se apropie încet. */
fun DrawScope.drawGhiFrame(book: GhiBook, ep: GhiEpisode, ms: Long, m: TextMeasurer, answered: Boolean = false, focus: Int = -1) {
    val phase = GhiTimeline.phase(ep, ms)
    // Mișcare lină, la fiecare cadru al ecranului.
    val ts = ms / 1000f
    val (bi, local, zoom) = when (phase) {
        is GhiPhase.Title -> Triple(0, 0f, 1.25f - 0.25f * GhiTimeline.ease(phase.local))
        is GhiPhase.Step -> Triple(phase.index, phase.local, GhiTimeline.camera(ep.beats[phase.index], phase.index).at(phase.local))
        is GhiPhase.End -> Triple(ep.beats.size - 1, 1f, 1f)
    }
    val beat = ep.beats[bi]
    val set = book.set(ep.set)
    val w = size.width
    val h = size.height
    val ask = if (phase is GhiPhase.Step) beat.ask else null
    // Când răspunsul e bun, GHI sare de bucurie.
    val g = if (ask != null && answered) cheer(beat.ghi) else beat.ghi
    val gx = g.x.at(local) * w
    val gy = (g.y?.at(local) ?: (set.horizon + (1 - set.horizon) * 0.55f)) * h
    val ghiH = h * 0.42f

    val pivot = Offset(gx, gy - ghiH * 0.5f)
    // Decorul se mișcă mai încet decât personajele (paralaxă), ca în filme.
    val backZoom = 1f + (zoom - 1f) * 0.5f
    withTransform({
        scale(backZoom, backZoom, pivot)
        translate((w / 2 - gx) * 0.03f, 0f)
    }) { drawSetBack(set, ts) }
    withTransform({ scale(zoom, zoom, pivot) }) {
        if (ask != null) drawAskRings(beat, local, ts, answered, focus)
        beat.props.filter { !it.front }.forEach { drawProp(it, local, ts, m) }
        beat.count?.let { drawCount(it, local, m) }
        // Privirea: GHI se uită la răspuns, la mami sau tati; părinții se uită la GHI.
        val target = when {
            ask != null && ask.answer < beat.props.size -> beat.props[ask.answer].x.at(local) * w
            beat.people.isNotEmpty() -> beat.people.first().x.at(local) * w
            else -> null
        }
        beat.people.forEach { pp ->
            val px = pp.x.at(local) * w
            drawPerson(
                pp, local, ts, px, (pp.y?.at(local) ?: (set.horizon + (1 - set.horizon) * 0.45f)) * h, h * 0.66f, m,
                gazeAt = ((gx - px) / (w * 0.15f)).coerceIn(-1f, 1f),
            )
        }
        drawGhi(g, local, ts, gx, gy, ghiH, m, look = target?.let { ((it - gx) / (w * 0.15f)).coerceIn(-1f, 1f) } ?: 0f)
        beat.props.filter { it.front }.forEach { drawProp(it, local, ts, m) }
        drawSetFront(set, ts)
    }
    // La o tăietură de cadru, o clipă de întuneric moale.
    if (phase is GhiPhase.Step && GhiTimeline.isCut(ep, phase.index) && phase.ms < 500) {
        drawRect(Color.Black.copy(alpha = 0.6f * (1f - phase.ms / 500f)))
    }
    // Vignetă: marginile puțin mai întunecate, ca într-un film.
    drawRect(Brush.radialGradient(listOf(Color.Transparent, Color(0x55000000)), Offset(w / 2, h / 2), maxOf(w, h) * 0.75f))
}

// ---------------- Decorurile ----------------

private val groundDecos = setOf("flowers", "lake", "reeds", "stripes", "goal", "rug", "path", "fence", "grass_edge", "counter", "bed", "lamp", "sink", "rails", "desk")
private val frontDecos = setOf("tub_front", "snowfall", "rain")

internal fun DrawScope.drawSetBack(set: GhiSet, ts: Float) {
    val w = size.width
    val h = size.height
    val hz = set.horizon * h
    drawRect(Brush.verticalGradient(set.sky.map(::hex), 0f, hz))
    set.deco.filter { it !in groundDecos && it !in frontDecos }.forEach { deco(it, set, ts) }
    // Pământul: mai deschis spre orizont, mai închis în față, ca în lumina adevărată.
    val ground = hex(set.ground)
    drawRect(
        Brush.verticalGradient(0f to lerp(ground, Color.White, 0.18f), 0.35f to ground, 1f to lerp(ground, Color.Black, 0.18f), startY = hz, endY = h),
        Offset(0f, hz), Size(w, h - hz),
    )
    // Ceață ușoară la orizont: ce e departe pare mai palid.
    drawRect(
        Brush.verticalGradient(listOf(Color.Transparent, Color(0x33FFFFFF), Color.Transparent), hz - h * 0.06f, hz + h * 0.02f),
        Offset(0f, hz - h * 0.06f), Size(w, h * 0.08f),
    )
    drawRect(Brush.verticalGradient(listOf(Color(0x22000000), Color.Transparent), hz, hz + h * 0.05f), Offset(0f, hz), Size(w, h * 0.05f))
    set.deco.filter { it in groundDecos }.forEach { deco(it, set, ts) }
}

internal fun DrawScope.drawSetFront(set: GhiSet, ts: Float) = set.deco.filter { it in frontDecos }.forEach { deco(it, set, ts) }

private fun DrawScope.cloud(c: Offset, r: Float, color: Color) {
    drawCircle(color, r, c)
    drawCircle(color, r * 0.8f, c + Offset(-r * 0.9f, r * 0.25f))
    drawCircle(color, r * 0.85f, c + Offset(r * 0.95f, r * 0.2f))
    drawCircle(color, r * 0.65f, c + Offset(r * 0.3f, -r * 0.55f))
}

private fun DrawScope.tri(a: Offset, b: Offset, c: Offset, color: Color) =
    drawPath(Path().apply { moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); close() }, color)

private fun DrawScope.deco(name: String, set: GhiSet, ts: Float) {
    val w = size.width
    val h = size.height
    val mm = size.minDimension
    val hz = set.horizon * h
    when (name) {
        "sun" -> {
            val c = Offset(w * 0.86f, h * 0.17f)
            rotate(ts * 6f, c) {
                for (i in 0 until 10) {
                    val a = i * GTAU / 10
                    drawLine(Color(0xFFFFD54F), c + Offset(cos(a), sin(a)) * (mm * 0.085f), c + Offset(cos(a), sin(a)) * (mm * 0.12f), strokeWidth = mm * 0.012f, cap = StrokeCap.Round)
                }
            }
            drawCircle(Color(0x55FFF59D), mm * 0.1f, c)
            drawCircle(Color(0xFFFFCA28), mm * 0.07f, c)
        }
        "clouds", "clouds_grey", "clouds_low" -> {
            val color = if (name == "clouds_grey") Color(0xFF90A4AE) else Color.White
            val n = if (name == "clouds_grey") 5 else 3
            for (i in 0 until n) {
                val speed = if (name == "clouds_low") 0.04f else 0.01f
                val x = (((i * 0.37f + ts * speed) % 1.2f) - 0.1f) * w
                val y = if (name == "clouds_low") h * (0.6f + i * 0.09f) else h * (0.1f + (i % 3) * 0.07f)
                cloud(Offset(x, y), mm * (0.045f + (i % 2) * 0.02f), color.copy(alpha = 0.92f))
            }
        }
        "hills", "hills_dark", "hills_snow" -> {
            val (a, b) = when (name) {
                "hills_dark" -> Color(0xFF1B5E20) to Color(0xFF2E7D32)
                "hills_snow" -> Color(0xFFE0E0E0) to Color(0xFFF5F5F5)
                else -> Color(0xFF7CB342) to Color(0xFF9CCC65)
            }
            drawOval(a, Offset(-w * 0.2f, hz - h * 0.12f), Size(w * 0.8f, h * 0.3f))
            drawOval(b, Offset(w * 0.4f, hz - h * 0.09f), Size(w * 0.9f, h * 0.26f))
        }
        "stars" -> for (i in 0 until 40) {
            val x = ((i * 0.618f) % 1f) * w
            val y = ((i * 0.377f + 0.05f) % 1f) * hz * 0.85f
            val tw = 0.5f + 0.5f * sin(ts * 2f + i)
            drawCircle(Color.White.copy(alpha = 0.3f + 0.7f * tw), mm * (0.003f + (i % 3) * 0.002f), Offset(x, y))
        }
        "moon" -> {
            val c = Offset(w * 0.8f, h * 0.2f)
            drawCircle(Color(0x33FFF59D), mm * 0.12f, c)
            drawCircle(Color(0xFFFFF59D), mm * 0.075f, c)
            drawCircle(Color(0x22000000), mm * 0.015f, c + Offset(-mm * 0.02f, mm * 0.01f))
            drawCircle(Color(0x22000000), mm * 0.01f, c + Offset(mm * 0.025f, -mm * 0.02f))
        }
        "window", "window_night" -> {
            val l = w * 0.1f
            val t = h * 0.16f
            val sz = Size(w * 0.2f, h * 0.3f)
            drawRoundRect(Color.White, Offset(l - 8f, t - 8f), Size(sz.width + 16f, sz.height + 16f), CornerRadius(10f))
            val night = name == "window_night"
            drawRect(if (night) Color(0xFF1A237E) else Color(0xFF81D4FA), Offset(l, t), sz)
            if (night) {
                drawCircle(Color(0xFFFFF59D), sz.width * 0.12f, Offset(l + sz.width * 0.7f, t + sz.height * 0.3f))
                for (i in 0 until 6) drawCircle(Color.White, 2.5f, Offset(l + sz.width * ((i * 0.37f) % 1f), t + sz.height * ((i * 0.53f) % 1f)))
            } else {
                cloud(Offset(l + sz.width * 0.4f, t + sz.height * 0.35f), sz.width * 0.1f, Color.White)
            }
            drawLine(Color.White, Offset(l + sz.width / 2, t), Offset(l + sz.width / 2, t + sz.height), 8f)
            drawLine(Color.White, Offset(l, t + sz.height / 2), Offset(l + sz.width, t + sz.height / 2), 8f)
            drawRect(Color(0xFFEF9A9A), Offset(l - w * 0.03f, t - 12f), Size(w * 0.04f, sz.height + 30f))
            drawRect(Color(0xFFEF9A9A), Offset(l + sz.width - w * 0.01f, t - 12f), Size(w * 0.04f, sz.height + 30f))
        }
        "frame" -> {
            drawRect(Color(0xFF8D6E63), Offset(w * 0.62f, h * 0.18f), Size(w * 0.16f, h * 0.2f))
            drawRect(Color(0xFFB3E5FC), Offset(w * 0.635f, h * 0.2f), Size(w * 0.13f, h * 0.16f))
            tri(Offset(w * 0.64f, h * 0.36f), Offset(w * 0.69f, h * 0.25f), Offset(w * 0.74f, h * 0.36f), Color(0xFF66BB6A))
            drawCircle(Color(0xFFFFCA28), h * 0.02f, Offset(w * 0.735f, h * 0.24f))
        }
        "board" -> {
            drawRoundRect(Color(0xFF6D4C41), Offset(w * 0.42f, h * 0.13f), Size(w * 0.4f, h * 0.3f), CornerRadius(12f))
            drawRect(Color(0xFF2E7D32), Offset(w * 0.435f, h * 0.15f), Size(w * 0.37f, h * 0.26f))
            for (i in 0 until 3) drawCircle(listOf(Color(0xFFFFEB3B), Color(0xFFFF8A80), Color(0xFF80D8FF))[i], h * 0.025f, Offset(w * (0.5f + i * 0.12f), h * 0.36f))
        }
        "garland" -> {
            val colors = listOf(Color(0xFFE53935), Color(0xFFFFB300), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA))
            for (i in 0 until 14) {
                val x = w * (i + 0.5f) / 14
                val y = h * 0.1f + sin(i / 13f * PI.toFloat()) * h * 0.06f
                tri(Offset(x - w * 0.025f, y), Offset(x + w * 0.025f, y), Offset(x, y + h * 0.07f), colors[i % colors.size])
            }
        }
        "balloons" -> {
            val colors = listOf(Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFB300))
            for (i in 0 until 3) {
                val c = Offset(w * (0.05f + i * 0.05f), h * (0.32f + (i % 2) * 0.06f) + sin(ts * 1.5f + i) * h * 0.01f)
                drawLine(Color(0xFF9E9E9E), c + Offset(0f, h * 0.05f), c + Offset(0f, h * 0.2f), 2f)
                drawOval(colors[i], c - Offset(w * 0.022f, h * 0.05f), Size(w * 0.044f, h * 0.1f))
            }
        }
        "curtain" -> {
            for (side in 0..1) {
                val l = if (side == 0) 0f else w * 0.84f
                drawRect(Color(0xFFB71C1C), Offset(l, 0f), Size(w * 0.16f, hz))
                for (k in 0 until 4) drawRect(Color(0x33000000), Offset(l + w * (0.02f + k * 0.04f), 0f), Size(w * 0.012f, hz))
            }
            drawRect(Color(0xFF8E0000), Offset(0f, 0f), Size(w, h * 0.08f))
        }
        "spotlight" -> {
            val a = 0.18f + 0.05f * sin(ts * 1.3f)
            drawPath(
                Path().apply { moveTo(w * 0.46f, 0f); lineTo(w * 0.52f, 0f); lineTo(w * 0.7f, hz + h * 0.12f); lineTo(w * 0.15f, hz + h * 0.12f); close() },
                Color(0xFFFFF59D).copy(alpha = a),
            )
        }
        "tiles" -> {
            val step = h * 0.08f
            var y = 0f
            while (y < hz) { drawLine(Color(0x55FFFFFF), Offset(0f, y), Offset(w, y), 2f); y += step }
            var x = 0f
            while (x < w) { drawLine(Color(0x55FFFFFF), Offset(x, 0f), Offset(x, hz), 2f); x += step }
        }
        "shelves" -> {
            val goods = listOf(Color(0xFFE57373), Color(0xFFFFD54F), Color(0xFF81C784), Color(0xFF64B5F6), Color(0xFFFFB74D), Color(0xFFBA68C8))
            for (r in 0 until 3) {
                val y = h * (0.22f + r * 0.18f)
                for (k in 0 until 8) {
                    val bh = h * (0.06f + (k * 7 + r * 3) % 4 * 0.012f)
                    drawRoundRect(goods[(k + r) % goods.size], Offset(w * (0.47f + k * 0.065f), y - bh), Size(w * 0.05f, bh), CornerRadius(6f))
                }
                drawRect(Color(0xFF8D6E63), Offset(w * 0.45f, y), Size(w * 0.55f, h * 0.02f))
            }
        }
        "barn" -> {
            val l = w * 0.7f
            val top = hz - h * 0.28f
            drawRect(Color(0xFFC62828), Offset(l, top + h * 0.08f), Size(w * 0.22f, h * 0.2f))
            tri(Offset(l - w * 0.02f, top + h * 0.08f), Offset(l + w * 0.11f, top - h * 0.02f), Offset(l + w * 0.24f, top + h * 0.08f), Color(0xFF8E0000))
            drawRect(Color.White, Offset(l + w * 0.08f, hz - h * 0.12f), Size(w * 0.06f, h * 0.12f), style = Stroke(5f))
            drawLine(Color.White, Offset(l + w * 0.08f, hz - h * 0.12f), Offset(l + w * 0.14f, hz), 5f)
            drawLine(Color.White, Offset(l + w * 0.14f, hz - h * 0.12f), Offset(l + w * 0.08f, hz), 5f)
        }
        "trees" -> for (i in 0 until 5) {
            val x = w * (0.08f + i * 0.22f)
            drawRect(Color(0xFF6D4C41), Offset(x - w * 0.008f, hz - h * 0.1f), Size(w * 0.016f, h * 0.1f))
            drawCircle(Color(0xFF558B2F), mm * 0.07f, Offset(x, hz - h * 0.14f))
            drawCircle(Color(0xFF689F38), mm * 0.05f, Offset(x + mm * 0.04f, hz - h * 0.11f))
        }
        "sea" -> {
            val top = hz - h * 0.14f
            drawRect(Color(0xFF29B6F6), Offset(0f, top), Size(w, hz - top))
            for (k in 0 until 3) {
                val y = top + (hz - top) * (0.25f + k * 0.25f)
                val path = Path().apply {
                    moveTo(0f, y)
                    var x = 0f
                    while (x <= w) { lineTo(x, y + sin(x / w * 12f + ts * 1.5f + k) * h * 0.006f); x += w / 40 }
                }
                drawPath(path, Color(0x88FFFFFF), style = Stroke(3f))
            }
        }
        "flowers" -> for (i in 0 until 12) {
            val x = ((i * 0.613f + 0.03f) % 1f) * w
            val y = hz + ((i * 0.41f) % 1f) * (h - hz) * 0.8f + h * 0.02f
            val c = listOf(Color(0xFFFFEB3B), Color(0xFFF06292), Color.White, Color(0xFFBA68C8))[i % 4]
            for (k in 0 until 5) drawCircle(c, mm * 0.008f, Offset(x + cos(k * GTAU / 5) * mm * 0.01f, y + sin(k * GTAU / 5) * mm * 0.01f))
            drawCircle(Color(0xFFFF9800), mm * 0.006f, Offset(x, y))
        }
        "lake" -> {
            drawOval(Color(0xFF4FC3F7), Offset(w * 0.5f, hz + h * 0.04f), Size(w * 0.6f, h * 0.27f))
            drawOval(Color(0xFF29B6F6), Offset(w * 0.56f, hz + h * 0.08f), Size(w * 0.46f, h * 0.18f))
            for (k in 0 until 3) {
                val r = ((ts * 0.3f + k / 3f) % 1f)
                drawOval(Color.White.copy(alpha = 0.5f * (1 - r)), Offset(w * 0.75f - r * w * 0.06f, hz + h * 0.16f - r * h * 0.02f), Size(r * w * 0.12f, r * h * 0.04f), style = Stroke(2f))
            }
        }
        "reeds" -> for (i in 0 until 7) {
            val x = w * (0.5f + i * 0.015f)
            val sway = sin(ts * 1.2f + i) * w * 0.004f
            drawLine(Color(0xFF558B2F), Offset(x, hz + h * 0.12f), Offset(x + sway, hz - h * 0.02f), 4f, cap = StrokeCap.Round)
            drawOval(Color(0xFF6D4C41), Offset(x + sway - 4f, hz - h * 0.04f), Size(8f, h * 0.03f))
        }
        "stripes" -> for (i in 0 until 8 step 2) drawRect(Color(0x1AFFFFFF), Offset(w * i / 8f, hz), Size(w / 8f, h - hz))
        "goal" -> {
            val l = w * 0.78f
            val t = hz - h * 0.12f
            val gw = w * 0.17f
            val gh = h * 0.22f
            for (k in 1 until 6) drawLine(Color(0x88FFFFFF), Offset(l + gw * k / 6, t), Offset(l + gw * k / 6, t + gh), 2f)
            for (k in 1 until 5) drawLine(Color(0x88FFFFFF), Offset(l, t + gh * k / 5), Offset(l + gw, t + gh * k / 5), 2f)
            drawLine(Color.White, Offset(l, t + gh), Offset(l, t), 8f)
            drawLine(Color.White, Offset(l, t), Offset(l + gw, t), 8f)
            drawLine(Color.White, Offset(l + gw, t), Offset(l + gw, t + gh), 8f)
        }
        "rug" -> drawOval(Color(0xFFE57373), Offset(w * 0.2f, hz + h * 0.06f), Size(w * 0.6f, h * 0.16f))
        "path" -> drawPath(Path().apply { moveTo(w * 0.45f, hz); lineTo(w * 0.55f, hz); lineTo(w * 0.75f, h); lineTo(w * 0.25f, h); close() }, Color(0xFFD7CCC8))
        "fence" -> {
            drawRect(Color(0xFFBCAAA4), Offset(0f, hz - h * 0.05f), Size(w, h * 0.012f))
            var x = 0f
            while (x < w) { drawRect(Color(0xFFD7CCC8), Offset(x, hz - h * 0.08f), Size(w * 0.012f, h * 0.09f)); x += w * 0.04f }
        }
        "grass_edge" -> drawRect(Color(0xFF7CB342), Offset(0f, hz - h * 0.01f), Size(w, h * 0.025f))
        "counter" -> {
            drawRect(Color(0xFF8D6E63), Offset(w * 0.55f, hz - h * 0.14f), Size(w * 0.45f, h * 0.14f))
            drawRect(Color(0xFFECEFF1), Offset(w * 0.54f, hz - h * 0.16f), Size(w * 0.46f, h * 0.025f))
        }
        "bed" -> {
            drawRoundRect(Color(0xFF8D6E63), Offset(w * 0.24f, h * 0.55f), Size(w * 0.04f, h * 0.31f), CornerRadius(8f))
            drawRoundRect(Color(0xFFFFFFFF), Offset(w * 0.26f, h * 0.7f), Size(w * 0.44f, h * 0.06f), CornerRadius(12f))
            drawRoundRect(Color(0xFF5C6BC0), Offset(w * 0.4f, h * 0.71f), Size(w * 0.3f, h * 0.12f), CornerRadius(16f))
            drawRoundRect(Color(0xFF6D4C41), Offset(w * 0.26f, h * 0.8f), Size(w * 0.44f, h * 0.06f), CornerRadius(6f))
        }
        "lamp" -> {
            val c = Offset(w * 0.82f, hz - h * 0.12f)
            drawCircle(Color(0x33FFE082), mm * 0.16f, c)
            drawRect(Color(0xFF6D4C41), Offset(w * 0.77f, hz - h * 0.05f), Size(w * 0.1f, h * 0.05f))
            drawLine(Color(0xFF6D4C41), Offset(c.x, hz - h * 0.05f), Offset(c.x, c.y), 5f)
            tri(Offset(c.x - mm * 0.05f, c.y + mm * 0.02f), Offset(c.x + mm * 0.05f, c.y + mm * 0.02f), Offset(c.x, c.y - mm * 0.05f), Color(0xFFFFE082))
        }
        "sink" -> {
            drawRoundRect(Color(0xFFB0BEC5), Offset(w * 0.68f, h * 0.15f), Size(w * 0.18f, h * 0.25f), CornerRadius(14f))
            drawRoundRect(Color(0xFFE1F5FE), Offset(w * 0.69f, h * 0.165f), Size(w * 0.16f, h * 0.22f), CornerRadius(12f))
            drawRoundRect(Color.White, Offset(w * 0.66f, hz - h * 0.2f), Size(w * 0.22f, h * 0.08f), CornerRadius(20f))
            drawRect(Color(0xFFECEFF1), Offset(w * 0.755f, hz - h * 0.12f), Size(w * 0.03f, h * 0.12f))
        }
        "rails" -> {
            val y1 = hz + h * 0.05f
            val y2 = hz + h * 0.1f
            var x = 0f
            while (x < w) { drawRect(Color(0xFF8D6E63), Offset(x, y1 - h * 0.005f), Size(w * 0.015f, y2 - y1 + h * 0.01f)); x += w * 0.04f }
            drawLine(Color(0xFF607D8B), Offset(0f, y1), Offset(w, y1), h * 0.008f)
            drawLine(Color(0xFF607D8B), Offset(0f, y2), Offset(w, y2), h * 0.008f)
        }
        "desk" -> {
            // Masa de lucru cu monitorul și tastatura.
            drawRect(Color(0xFF8D6E63), Offset(w * 0.68f, hz - h * 0.02f), Size(w * 0.28f, h * 0.025f))
            drawRect(Color(0xFF6D4C41), Offset(w * 0.7f, hz), Size(w * 0.02f, h * 0.14f))
            drawRect(Color(0xFF6D4C41), Offset(w * 0.92f, hz), Size(w * 0.02f, h * 0.14f))
            drawRoundRect(Color(0xFF263238), Offset(w * 0.72f, hz - h * 0.2f), Size(w * 0.18f, h * 0.15f), CornerRadius(8f))
            drawRect(Brush.linearGradient(listOf(Color(0xFF4FC3F7), Color(0xFF7E57C2))), Offset(w * 0.73f, hz - h * 0.19f), Size(w * 0.16f, h * 0.13f))
            drawRect(Color(0xFF455A64), Offset(w * 0.8f, hz - h * 0.05f), Size(w * 0.02f, h * 0.03f))
            drawRoundRect(Color(0xFFCFD8DC), Offset(w * 0.73f, hz - h * 0.03f), Size(w * 0.12f, h * 0.012f), CornerRadius(3f))
        }
        "tub_front" -> {
            val l = w * 0.32f
            val t = h * 0.74f
            drawRoundRect(Color.White, Offset(l, t), Size(w * 0.36f, h * 0.17f), CornerRadius(40f))
            drawRoundRect(Color(0xFFCFD8DC), Offset(l, t + h * 0.12f), Size(w * 0.36f, h * 0.05f), CornerRadius(30f))
            for (k in 0 until 9) drawCircle(Color.White, mm * (0.025f + (k % 3) * 0.008f), Offset(l + w * 0.36f * (k + 0.5f) / 9, t + sin(ts * 2f + k) * 3f))
            drawCircle(Color(0xFF90A4AE), mm * 0.015f, Offset(l + w * 0.05f, t + h * 0.19f))
            drawCircle(Color(0xFF90A4AE), mm * 0.015f, Offset(l + w * 0.31f, t + h * 0.19f))
        }
        "snowfall" -> for (i in 0 until 50) {
            val x = ((i * 0.618f) % 1f) * w + sin(ts + i) * w * 0.01f
            val y = (((i * 0.29f) + ts * 0.05f * (1 + i % 3)) % 1f) * h
            drawCircle(Color.White.copy(alpha = 0.9f), mm * (0.004f + (i % 3) * 0.003f), Offset(x, y))
        }
        "rain" -> for (i in 0 until 60) {
            val x = ((i * 0.618f) % 1f) * w
            val y = (((i * 0.31f) + ts * 0.6f) % 1f) * h
            drawLine(Color(0xAA81D4FA), Offset(x, y), Offset(x - w * 0.004f, y + h * 0.03f), 3f, cap = StrokeCap.Round)
        }
    }
}

// ---------------- Obiecte și numărătoare ----------------

private fun DrawScope.drawProp(p: GhiProp, local: Float, ts: Float, m: TextMeasurer) {
    if (local < p.appear || local > p.vanish) return
    val a = ((local - p.appear) / 0.05f).coerceIn(0f, 1f) * if (p.vanish < 1f) ((p.vanish - local) / 0.05f).coerceIn(0f, 1f) else 1f
    val w = size.width
    val h = size.height
    var x = p.x.at(local) * w
    var y = p.y.at(local) * h
    var px = p.size * size.minDimension
    var rot = 0f
    when (p.motion) {
        "bob" -> y += sin(ts * GTAU * 0.6f) * h * 0.01f
        "swim" -> y += sin(ts * GTAU) * h * 0.008f
        "hop" -> y -= abs(sin(ts * PI.toFloat() * 1.5f)) * h * 0.03f
        "float" -> { x += sin(ts * 1.5f) * w * 0.01f; y += sin(ts * 1.1f) * h * 0.01f }
        "pulse" -> px *= 1 + 0.08f * sin(ts * GTAU)
        "beat" -> px *= 1 + 0.2f * abs(sin(ts * PI.toFloat() * 2.2f))
        "grow" -> px *= GhiTimeline.ease(local / 0.5f)
        "spin" -> rot = ts * 180f
        "wiggle" -> rot = sin(ts * GTAU * 1.5f) * 10f
    }
    rotate(rot, Offset(x, y)) { ghiEmoji(m, p.emoji, Offset(x, y), px, a) }
}

private fun DrawScope.drawCount(c: GhiCount, local: Float, m: TextMeasurer) {
    val n = c.items.size
    val shown = GhiTimeline.counted(n, local)
    val px = c.size * size.minDimension
    for (i in 0 until shown) {
        val start = 0.1f + i * 0.75f / n
        val pop = GhiTimeline.ease((local - start) / 0.04f)
        val fx = if (n == 1) (c.x.from + c.x.to) / 2 else c.x.from + (c.x.to - c.x.from) * i / (n - 1)
        val center = Offset(fx * size.width, c.y * size.height)
        val item = c.items[i]
        if (item.length == 1 && item[0].isLetter()) {
            ghiLabel(m, item, center, px * 1.2f * pop, listOf(Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFFB300))[i % 4])
        } else {
            ghiEmoji(m, item, center, px * pop)
        }
        ghiLabel(m, "${i + 1}", center - Offset(0f, px * 0.95f), px * 0.45f, Color(0xFFFFF59D), pop)
        c.labels.getOrNull(i)?.let { ghiLabel(m, it, center + Offset(0f, px * 0.95f), px * 0.32f, Color.White, pop) }
    }
}

// ---------------- GHI ----------------

/** Culorile costumașului: blana (sau solzii), burtica, țepii sau coama. */
private class Fur(val main: Color, val dark: Color, val light: Color, val belly: Color, val spike: Color, val horn: Color, val feet: Color)

private val FURS = mapOf(
    "dragon" to Fur(Color(0xFF7CB342), Color(0xFF558B2F), Color(0xFFA5D66B), Color(0xFFDCEDC8), Color(0xFFFFB74D), Color(0xFFFFF3E0), Color(0xFF33691E)),
    "balaur" to Fur(Color(0xFFE0553A), Color(0xFFB23A22), Color(0xFFFF8A65), Color(0xFFFFE0B2), Color(0xFFFFD54F), Color(0xFFFFF3E0), Color(0xFF7F2412)),
    "leu" to Fur(Color(0xFFF2B33D), Color(0xFFC98A1E), Color(0xFFFFD27A), Color(0xFFFFF1D0), Color(0xFFB5651D), Color(0xFFFFF3E0), Color(0xFF8D5A14)),
    "urs" to Fur(Color(0xFF8D6E63), Color(0xFF6D4C41), Color(0xFFAC8F84), Color(0xFFE6D5CB), Color(0xFF5D4037), Color(0xFFFFF3E0), Color(0xFF4E342E)),
)

/** Cum e GHI acum: costumașul și dacă e fată (are fundiță). Se schimbă din Setări. */
@Volatile private var ghiAvatar = "dragon"
@Volatile private var ghiGirl = false

/** Numele ales de copil, pentru textele din ecrane (poveștile îl au deja în text). */
var ghiName by mutableStateOf("GHI")
    private set

fun applyGhiLook(c: GhiCharacter) {
    previewGhiLook(c)
    ghiName = c.name
}

/** Doar desenul (costumașul, fundița), fără nume: pentru previzualizarea din „Prietenul meu”. */
internal fun previewGhiLook(c: GhiCharacter) {
    ghiAvatar = c.avatar
    ghiGirl = c.girl
}

private val fur get() = FURS[ghiAvatar] ?: FURS.getValue("dragon")
private val Green get() = fur.main
private val GreenDark get() = fur.dark
private val GreenLight get() = fur.light
private val Belly get() = fur.belly
private val Spike get() = fur.spike
private val Horn get() = fur.horn
private val Skin = Color(0xFFFFDDBF)

private fun darker(c: Color, f: Float = 0.8f) = Color(c.red * f, c.green * f, c.blue * f, c.alpha)

internal fun DrawScope.drawGhi(g: GhiPose, local: Float, ts: Float, gx: Float, gy: Float, height: Float, m: TextMeasurer, look: Float = 0f) {
    val u = height / 100f
    val sitting = g.pose == "sit" || g.pose == "sleep"
    var lift = when (g.pose) {
        "jump" -> abs(sin(ts * PI.toFloat() * 1.2f)) * 22f
        "happy" -> abs(sin(ts * PI.toFloat() * 2f)) * 7f
        "walk" -> abs(sin(ts * PI.toFloat() * 3f)) * 3f
        else -> 0f
    }
    if (sitting) lift = -10f
    val breathe = sin(ts * PI.toFloat()) * 0.8f
    val swingX = if (g.motion == "swing") sin(ts * 1.6f) * 14f else 0f
    // Dansul, sau o mică legănare când stă, ca să nu pară încremenit.
    val sway = when (g.pose) {
        "dance" -> sin(ts * PI.toFloat() * 2f) * 10f
        "stand" -> sin(ts * 0.9f) * 1.6f
        else -> 0f
    }

    if (g.motion == "swing") {
        drawLine(Color(0xFF6D4C41), Offset(gx + swingX * u * 0.3f - 22 * u, gy - height * 1.4f), Offset(gx + swingX * u - 22 * u, gy - 2 * u), 3 * u)
        drawLine(Color(0xFF6D4C41), Offset(gx + swingX * u * 0.3f + 22 * u, gy - height * 1.4f), Offset(gx + swingX * u + 22 * u, gy - 2 * u), 3 * u)
        drawRoundRect(Color(0xFF8D6E63), Offset(gx + swingX * u - 26 * u, gy - 3 * u), Size(52 * u, 6 * u), CornerRadius(2 * u))
    }

    // Umbra pe pământ.
    drawOval(Color(0x33000000), Offset(gx - 26 * u, gy - 3 * u), Size(52 * u, 7 * u))

    withTransform({
        translate(gx + swingX * u, gy - lift * u)
        if (g.flip) scale(-1f, 1f, Offset.Zero)
        rotate(sway, Offset(0f, 0f))
    }) {
        fun p(x: Float, y: Float) = Offset(x * u, y * u)

        // Coada cu țepi, dă din ea.
        val wag = sin(ts * GTAU * 0.8f) * 6f
        val tail = Path().apply {
            moveTo(-14 * u, -22 * u)
            quadraticTo(-40 * u, -14 * u + wag * u * 0.5f, -50 * u, -30 * u + wag * u)
        }
        when (ghiAvatar) {
            // Ursulețul: o codiță mică și rotundă.
            "urs" -> {
                drawCircle(GreenDark, 7 * u, p(-27f, -20f + wag * 0.2f))
                drawCircle(Green, 5.5f * u, p(-27f, -20f + wag * 0.2f))
            }
            // Leul: coadă subțire cu un smoc la capăt.
            "leu" -> {
                drawPath(tail, GreenDark, style = Stroke(6 * u, cap = StrokeCap.Round))
                drawPath(tail, Green, style = Stroke(4 * u, cap = StrokeCap.Round))
                drawCircle(Spike, 6 * u, p(-50f, -31f + wag))
                drawCircle(darker(Spike), 3 * u, p(-52f, -33f + wag))
            }
            else -> {
                drawPath(tail, GreenDark, style = Stroke(12 * u, cap = StrokeCap.Round))
                drawPath(tail, Green, style = Stroke(8 * u, cap = StrokeCap.Round))
                tri(p(-54f, -30f + wag), p(-46f, -34f + wag), p(-52f, -42f + wag), Spike)
            }
        }

        // Aripioarele.
        val flap = if (g.pose == "fly") sin(ts * GTAU * 2f) * 25f else sin(ts * GTAU * 0.5f) * 6f
        // Leul și ursulețul au aripioare doar când zboară (ca în povești).
        if (ghiAvatar == "dragon" || ghiAvatar == "balaur" || g.pose == "fly") {
            rotate(-20f - flap, p(-12f, -46f)) {
                drawPath(Path().apply {
                    moveTo(-12 * u, -46 * u); quadraticTo(-36 * u, -66 * u, -40 * u, -48 * u); quadraticTo(-30 * u, -50 * u, -26 * u, -40 * u); close()
                }, GreenLight)
            }
        }

        // Brațul din spate.
        val backArm = when (g.pose) { "happy", "fly" -> -2.6f; "dance" -> -2.2f + sin(ts * 6f) * 0.3f; else -> -0.35f }
        arm(Offset(-15 * u, (-44f + breathe) * u), backArm, u)

        // Picioarele.
        if (sitting) {
            drawRoundRect(GreenDark, p(-4f, -14f), Size(26 * u, 12 * u), CornerRadius(6 * u))
            drawRoundRect(Green, p(0f, -12f), Size(24 * u, 12 * u), CornerRadius(6 * u))
        } else {
            val step = if (g.pose == "walk") sin(ts * GTAU * 1.5f) * 6f else 0f
            val kick = if (g.pose == "kick" && local in 0.25f..0.5f) 35f else 0f
            drawRoundRect(GreenDark, p(-16f - step, -18f), Size(13 * u, 18 * u), CornerRadius(6 * u))
            rotate(-kick, p(8f, -18f)) { drawRoundRect(Green, p(2f + step, -18f), Size(13 * u, 18 * u), CornerRadius(6 * u)) }
            drawOval(fur.feet, p(-18f - step, -4f), Size(16 * u, 6 * u))
            drawOval(fur.feet, p(1f + step, -4f), Size(16 * u, 6 * u))
        }

        // Corpul și burtica.
        drawOval(GreenDark, p(-23f, -58f + breathe), Size(46 * u, 46 * u))
        drawOval(Brush.radialGradient(listOf(GreenLight, Green, GreenDark), p(-8f, -46f + breathe), 34 * u), p(-21f, -56f + breathe), Size(42 * u, 42 * u))
        drawOval(Belly, p(-11f, -50f + breathe), Size(26 * u, 32 * u))
        for (k in 0 until 3) drawLine(Color(0x33558B2F), p(-8f, -42f + k * 8f + breathe), p(12f, -42f + k * 8f + breathe), 1.5f * u)

        // Capul: glugă de dragon cu coarne și țepi, fața de bebeluș.
        val hc = p(0f, -76f + breathe)
        val tilt = if (g.pose == "sleep") 14f else 0f
        rotate(tilt, hc) {
            hood(hc, ts, u)
            drawCircle(GreenDark, 29 * u, hc)
            drawCircle(Brush.radialGradient(listOf(GreenLight, Green, GreenDark), hc + p(-9f, -9f), 38 * u), 27 * u, hc)
            val fc = p(4f, -72f + breathe)
            drawCircle(Brush.radialGradient(listOf(Color(0xFFFFE8D6), Skin, Color(0xFFF2C29E)), fc + p(-5f, -6f), 24 * u), 19 * u, fc)
            // Umbra glugii pe frunte.
            drawArc(Color(0x22000000), 200f, 140f, false, fc - p(17f, 19f), Size(34 * u, 20 * u), style = Stroke(3 * u))
            // Bucla de păr.
            drawArc(Color(0xFF6D4C41), 200f, 200f, false, fc + p(-6f, -24f), Size(12 * u, 10 * u), style = Stroke(3 * u, cap = StrokeCap.Round))
            face(g.face, fc, ts, u, if (g.flip) -look else look)
            if (ghiAvatar == "leu" || ghiAvatar == "urs") ears(hc, u)
            if (ghiGirl && g.hat == null) bow(p(17f, -99f + breathe), u)
            hat(g.hat, hc, u)
        }

        // Brațul din față, cu ce ține GHI în mână.
        val frontArm = when (g.pose) {
            "happy", "fly" -> 2.6f
            "wave" -> 2.4f + sin(ts * GTAU * 1.5f) * 0.4f
            "reach" -> 1.6f
            "dance" -> 2.2f + sin(ts * 6f + 1f) * 0.3f
            else -> if (g.hold != null) 0.9f else 0.35f
        }
        val hand = arm(Offset(15 * u, (-44f + breathe) * u), frontArm, u)
        g.hold?.let { ghiEmoji(m, it, hand + Offset(4 * u, -6 * u), 18 * u) }

        // Bulă de gând.
        g.think?.let {
            drawCircle(Color.White, 4 * u, p(24f, -100f))
            drawCircle(Color.White, 6 * u, p(32f, -110f))
            drawCircle(Color.White, 16 * u, p(46f, -128f))
            ghiEmoji(m, it, p(46f, -128f), 18 * u)
        }

        g.puff?.let { puff(it, p(14f, -64f + breathe), ts, u, m) }
    }
}

/** Ce e în spatele glugii: țepi și coarne (dragon), încă 6 căpșoare (balaur) sau coama (leu). */
private fun DrawScope.hood(hc: Offset, ts: Float, u: Float) {
    fun p(x: Float, y: Float) = Offset(x * u, y * u)
    when (ghiAvatar) {
        "balaur" -> {
            // Balaurul cu 7 capete: glugă cu coarne și încă 6 căpșoare pe gâturi, fiecare cu ochii lui.
            val angles = floatArrayOf(-168f, -140f, -112f, -68f, -40f, -12f)
            for (k in angles.indices) {
                val a = angles[k] * PI.toFloat() / 180f
                val bob = sin(ts * 2.2f + k * 1.3f) * 2.2f
                val dir = Offset(cos(a), sin(a))
                val head = hc + dir * (44 * u) + Offset(0f, bob * u)
                val neck = hc + dir * (12 * u)
                drawLine(GreenDark, neck, head, 8 * u, cap = StrokeCap.Round)
                drawLine(Green, neck, head, 5.5f * u, cap = StrokeCap.Round)
                tri(head + p(-6f, -6f), head + p(-8f, -15f), head + p(-1f, -8f), Horn)
                tri(head + p(1f, -8f), head + p(8f, -15f), head + p(6f, -6f), Horn)
                drawCircle(GreenDark, 9.5f * u, head)
                drawCircle(Brush.radialGradient(listOf(GreenLight, Green, GreenDark), head + p(-3f, -3f), 12 * u), 8.5f * u, head)
                drawOval(Belly, head + p(-4.5f, 1f), Size(9 * u, 5 * u))
                // Clipesc pe rând, nu toate odată.
                val blink = ((ts * 0.7f + k * 0.37f) % 4f) < 0.12f
                for (ex in floatArrayOf(-3.2f, 3.2f)) {
                    val e = head + p(ex, -1.5f)
                    if (blink) {
                        drawLine(Color(0xFF3E2723), e - p(1.8f, 0f), e + p(1.8f, 0f), 1 * u)
                    } else {
                        drawCircle(Color.White, 2.2f * u, e)
                        drawCircle(Color(0xFF3E2723), 1.3f * u, e + p(0.3f, 0.3f))
                        drawCircle(Color.White, 0.5f * u, e + p(-0.4f, -0.5f))
                    }
                }
                drawArc(Color(0xFF6D2B1A), 11f, 157f, false, head + p(-2.5f, 1.3f), Size(5 * u, 3.4f * u), style = Stroke(0.9f * u))
            }
            tri(hc + p(-10f, -22f), hc + p(-14f, -38f), hc + p(-2f, -24f), Horn)
            tri(hc + p(8f, -24f), hc + p(16f, -38f), hc + p(18f, -20f), Horn)
        }
        "leu" -> {
            // Coama: un cerc de smocuri, mai închise spre margine.
            for (k in 0 until 14) {
                val a = k / 14f * GTAU + sin(ts * 0.8f) * 0.03f
                drawCircle(darker(Spike, 0.85f), 10 * u, hc + Offset(cos(a), sin(a)) * (30 * u))
            }
            for (k in 0 until 14) {
                val a = (k + 0.5f) / 14f * GTAU
                drawCircle(Spike, 8 * u, hc + Offset(cos(a), sin(a)) * (27 * u))
            }
        }
        "urs" -> Unit
        else -> {
            tri(hc + p(-22f, -16f), hc + p(-14f, -26f), hc + p(-8f, -20f), Spike)
            tri(hc + p(-27f, -4f), hc + p(-36f, -8f), hc + p(-26f, 6f), Spike)
            tri(hc + p(-10f, -22f), hc + p(-14f, -38f), hc + p(-2f, -24f), Horn)
            tri(hc + p(8f, -24f), hc + p(16f, -38f), hc + p(18f, -20f), Horn)
        }
    }
}

/** Urechiușe rotunde pe glugă (leu și ursuleț). */
private fun DrawScope.ears(hc: Offset, u: Float) {
    val big = if (ghiAvatar == "urs") 9f else 7f
    for (x in floatArrayOf(-19f, 19f)) {
        val c = hc + Offset(x * u, -21 * u)
        drawCircle(GreenDark, (big + 1.5f) * u, c)
        drawCircle(Green, big * u, c)
        drawCircle(Belly, big * 0.55f * u, c + Offset(0f, 1 * u))
    }
}

/** Fundița fetiței, prinsă pe glugă. */
private fun DrawScope.bow(c: Offset, u: Float) {
    val pink = Color(0xFFEC407A)
    val pinkDark = Color(0xFFC2185B)
    for (s in floatArrayOf(-1f, 1f)) {
        val path = Path().apply {
            moveTo(c.x, c.y)
            quadraticTo(c.x + s * 6 * u, c.y - 9 * u, c.x + s * 11 * u, c.y - 4 * u)
            quadraticTo(c.x + s * 12 * u, c.y + 3 * u, c.x + s * 10 * u, c.y + 7 * u)
            quadraticTo(c.x + s * 5 * u, c.y + 6 * u, c.x, c.y)
            close()
        }
        drawPath(path, pink)
        drawPath(path, pinkDark, style = Stroke(0.8f * u))
    }
    drawCircle(pinkDark, 3 * u, c)
    drawCircle(Color(0x88FFFFFF), 1 * u, c + Offset(-0.8f * u, -0.8f * u))
}

/** Un braț: umărul, unghiul (0 = în jos, pozitiv = în față). Întoarce poziția mâinii. */
private fun DrawScope.arm(shoulder: Offset, angle: Float, u: Float): Offset {
    val hand = shoulder + Offset(sin(angle), cos(angle)) * (18 * u)
    drawLine(GreenDark, shoulder, hand, 11 * u, cap = StrokeCap.Round)
    drawLine(Green, shoulder, hand, 8 * u, cap = StrokeCap.Round)
    drawCircle(Skin, 4.5f * u, hand)
    return hand
}

/** [look] -1..1: încotro se uită ochii (stânga / dreapta). */
private fun DrawScope.face(face: String, c: Offset, ts: Float, u: Float, look: Float = 0f) {
    val dark = Color(0xFF3E2723)
    val eyeL = c + Offset(-6 * u, -2 * u)
    val eyeR = c + Offset(8 * u, -2 * u)
    // Clipește la intervale puțin diferite, ca un copil adevărat.
    val blink = ((ts + sin(ts * 0.37f) * 1.3f) % 3.7f) < 0.14f
    val closed = face == "sleepy" || blink
    if (closed) {
        for (e in listOf(eyeL, eyeR)) drawArc(dark, 0f, 180f, false, e - Offset(3.5f * u, 2 * u), Size(7 * u, 4 * u), style = Stroke(1.6f * u, cap = StrokeCap.Round))
    } else {
        val r = if (face == "wow") 3.8f * u else 3.2f * u
        for (e in listOf(eyeL, eyeR)) {
            // Ochi cu alb, iris căprui, pupilă și două luciri.
            drawCircle(Color.White, r * 1.15f, e)
            val iris = e + Offset(r * (0.1f + 0.3f * look), 0f)
            drawCircle(Color(0xFF6D4C41), r * 0.85f, iris)
            drawCircle(dark, r * 0.5f, iris)
            drawCircle(Color.White, r * 0.3f, iris + Offset(r * 0.3f, -r * 0.35f))
            drawCircle(Color.White.copy(alpha = 0.7f), r * 0.14f, iris + Offset(-r * 0.35f, r * 0.35f))
            drawArc(dark, 200f, 140f, false, e - Offset(r * 1.15f, r * 1.15f), Size(r * 2.3f, r * 2.3f), style = Stroke(0.9f * u, cap = StrokeCap.Round))
        }
    }
    drawCircle(Color(0x66FF8A80), 3.5f * u, c + Offset(-11 * u, 5 * u))
    drawCircle(Color(0x66FF8A80), 3.5f * u, c + Offset(13 * u, 5 * u))
    val mc = c + Offset(1 * u, 8 * u)
    when (face) {
        "wow" -> drawOval(Color(0xFF8D3B3B), mc - Offset(3 * u, 3.5f * u), Size(6 * u, 7 * u))
        "sleepy" -> drawOval(Color(0xFF8D3B3B), mc - Offset(2 * u, 2 * u), Size(4 * u, 4 * u))
        "sad" -> {
            drawArc(dark, 200f, 140f, false, mc - Offset(5 * u, 0f), Size(10 * u, 7 * u), style = Stroke(1.6f * u, cap = StrokeCap.Round))
            drawOval(Color(0xFF4FC3F7), eyeR + Offset(-1.5f * u, 4 * u), Size(3 * u, 5 * u))
        }
        "calm" -> drawArc(dark, 20f, 140f, false, mc - Offset(4 * u, 3 * u), Size(8 * u, 5 * u), style = Stroke(1.6f * u, cap = StrokeCap.Round))
        else -> {
            drawArc(Color(0xFF8D3B3B), 0f, 180f, true, mc - Offset(5.5f * u, 4 * u), Size(11 * u, 8 * u))
            drawArc(Color(0xFFFF8A80), 30f, 120f, true, mc - Offset(3.5f * u, 1 * u), Size(7 * u, 5 * u))
        }
    }
}

private fun DrawScope.hat(hat: String?, hc: Offset, u: Float) {
    when (hat) {
        "party" -> {
            val base = hc + Offset(4 * u, -24 * u)
            tri(base + Offset(-12 * u, 0f), base + Offset(12 * u, 0f), base + Offset(2 * u, -30 * u), Color(0xFFE91E63))
            drawLine(Color(0xFFFFEB3B), base + Offset(-7 * u, -8 * u), base + Offset(8 * u, -10 * u), 2.5f * u)
            drawLine(Color(0xFFFFEB3B), base + Offset(-3 * u, -18 * u), base + Offset(5 * u, -19 * u), 2.5f * u)
            drawCircle(Color(0xFFFFEB3B), 4 * u, base + Offset(2 * u, -31 * u))
        }
        "helmet" -> {
            drawArc(Color(0xFF1E88E5), 180f, 180f, true, hc - Offset(30 * u, 32 * u), Size(60 * u, 44 * u))
            drawLine(Color.White, hc + Offset(-2 * u, -30 * u), hc + Offset(-2 * u, -12 * u), 3 * u)
        }
        "beanie" -> {
            drawArc(Color(0xFFE53935), 180f, 180f, true, hc - Offset(29 * u, 30 * u), Size(58 * u, 40 * u))
            drawRect(Color.White, hc + Offset(-29 * u, -12 * u), Size(58 * u, 6 * u))
            drawCircle(Color.White, 6 * u, hc + Offset(0f, -32 * u))
        }
    }
}

private fun DrawScope.puff(kind: String, origin: Offset, ts: Float, u: Float, m: TextMeasurer) {
    for (i in 0 until 6) {
        val q = ((ts * 0.45f + i / 6f) % 1f)
        val pos = origin + Offset((q * 26 + sin(q * 6 + i) * 4) * u, -q * 46 * u)
        val a = 1f - q
        when (kind) {
            "steam" -> drawCircle(Color.White.copy(alpha = 0.7f * a), (3 + q * 6) * u, pos)
            "bubbles" -> {
                drawCircle(Color(0xFFB3E5FC).copy(alpha = a), (2.5f + q * 4) * u, pos, style = Stroke(1.2f * u))
                drawCircle(Color.White.copy(alpha = a), 0.8f * u, pos + Offset(-1.2f * u, -1.2f * u))
            }
            "stars" -> {
                val r = (3 + q * 3) * u
                val path = Path()
                for (k in 0 until 8) {
                    val ang = k * PI.toFloat() / 4 - PI.toFloat() / 2
                    val rr = if (k % 2 == 0) r else r * 0.4f
                    val pt = pos + Offset(cos(ang) * rr, sin(ang) * rr)
                    if (k == 0) path.moveTo(pt.x, pt.y) else path.lineTo(pt.x, pt.y)
                }
                path.close()
                drawPath(path, Color(0xFFFFD54F).copy(alpha = a))
            }
            "hearts" -> ghiEmoji(m, "💗", pos, (6 + q * 4) * u, a)
            "notes" -> ghiEmoji(m, if (i % 2 == 0) "🎵" else "🎶", pos, (7 + q * 3) * u, a)
            "zzz" -> ghiLabel(m, "z", pos, (6 + q * 8) * u, Color.White, a)
        }
    }
}
