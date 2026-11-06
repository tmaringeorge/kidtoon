package ro.kidtoon.tv.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import kotlinx.coroutines.delay
import ro.kidtoon.tv.data.ArtStore
import ro.kidtoon.tv.data.ColoringNav
import ro.kidtoon.tv.data.DpadCursor
import ro.kidtoon.tv.data.KidPalette
import ro.kidtoon.tv.data.Piece
import ro.kidtoon.tv.data.PieceShape
import ro.kidtoon.tv.data.buildBackgrounds
import ro.kidtoon.tv.data.buildTemplates
import ro.kidtoon.tv.data.kidStickers
import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

private fun paletteColor(i: Int) = Color(KidPalette.colors[i].toInt())

private fun isCenter(k: Key) = k == Key.DirectionCenter || k == Key.Enter || k == Key.NumPadEnter

/** Paleta în două coloane, cu vocea care spune culoarea. */
@Composable
private fun Palette(selected: Int, onPick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        (0 until KidPalette.size).chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { i -> ColorDot(paletteColor(i), selected == i, onClick = { onPick(i) }) }
            }
        }
    }
}

@Composable
private fun rememberToast(): Toast {
    val t = remember { Toast() }
    LaunchedEffect(t.nonce) { if (t.text != null) { delay(2500); t.text = null } }
    return t
}

/** Pulsul ramei de pe zona aleasă. */
@Composable
private fun pulse(): Float {
    val ms = frameMillis()
    return 0.5f + 0.5f * sin(ms / 250f)
}

// ======================= Colorează =======================

private fun DrawScope.drawColoring(page: ColoringPage, fills: List<Long?>, focus: Int, glow: Float) {
    val s = size.minDimension / ColoringPage.SIZE
    val ox = (size.width - ColoringPage.SIZE * s) / 2
    val oy = (size.height - ColoringPage.SIZE * s) / 2
    withTransform({ translate(ox, oy); scale(s, s, Offset.Zero) }) {
        page.regions.forEachIndexed { i, r ->
            drawPath(r.path, fills.getOrNull(i)?.let { Color(it.toInt()) } ?: Color.White)
        }
        page.regions.forEach { r -> drawPath(r.path, Color(0xFF2B2B2B), style = Stroke(width = 0.7f, join = StrokeJoin.Round)) }
        page.regions.getOrNull(focus)?.let { r ->
            drawPath(r.path, Color.White.copy(alpha = 0.25f + 0.25f * glow))
            drawPath(r.path, KidColors.Accent, style = Stroke(width = 2.2f, join = StrokeJoin.Round))
            drawPath(
                r.path, Color.White,
                style = Stroke(width = 1.1f, join = StrokeJoin.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 1.5f), glow * 3.5f)),
            )
        }
    }
}

/** Colorat cu telecomanda: săgețile mută rama pe altă zonă, OK o umple cu culoarea aleasă. */
@Composable
fun ColoringScreen(page: ColoringPage) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val voice = rememberKidVoice()
    val toast = rememberToast()
    val fills = remember(page.id) { mutableStateListOf<Long?>().apply { repeat(page.regions.size) { add(null) } } }
    val history = remember(page.id) { mutableStateListOf<Pair<Int, Long?>>() }
    var focus by remember(page.id) { mutableIntStateOf(page.regions.size / 2) }
    var color by remember { mutableIntStateOf(0) }
    var onSheet by remember { mutableStateOf(true) }
    val sheet = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { sheet.requestFocus() } }
    val glow = pulse()

    fun fill() {
        history += focus to fills[focus]
        fills[focus] = KidPalette.colors[color]
        voice.say("${page.regions[focus].name.ifEmpty { "Am colorat" }} ${KidPalette.names[color]}")
    }

    Column(Modifier.fillMaxSize()) {
        AtelierHeader(
            "${page.emoji} ${page.title}",
            "Săgețile aleg zona, OK o colorează. ▶ la margine: culorile și butoanele.",
            toast.text,
        )
        Row(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 32.dp, vertical = 8.dp)) {
            Box(
                Modifier.fillMaxHeight().aspectRatio(1f).clip(RoundedCornerShape(18.dp)).sheetFrame(onSheet)
                    .onFocusChanged { onSheet = it.isFocused }
                    .focusRequester(sheet).focusable()
                    .onPreviewKeyEvent { ev ->
                        if (isCenter(ev.key)) { if (ev.type == KeyEventType.KeyUp) fill(); return@onPreviewKeyEvent true }
                        if (ev.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        val (dx, dy) = when (ev.key) {
                            Key.DirectionLeft -> -1 to 0
                            Key.DirectionRight -> 1 to 0
                            Key.DirectionUp -> 0 to -1
                            Key.DirectionDown -> 0 to 1
                            else -> return@onPreviewKeyEvent false
                        }
                        val next = ColoringNav.neighbor(page.centers, focus, dx, dy)
                        if (next < 0) return@onPreviewKeyEvent dx != 1 // la marginea din dreapta, trece la paletă
                        focus = next
                        true
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) { drawColoring(page, fills, if (onSheet) focus else -1, glow) }
            }
            Spacer(Modifier.width(28.dp))
            Column(Modifier.fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Palette(color) { color = it; voice.say(KidPalette.names[it]) }
                Spacer(Modifier.height(4.dp))
                KidButton("↩️ Înapoi un pas", onClick = {
                    history.removeLastOrNull()?.let { (i, old) -> fills[i] = old }
                }, enabled = history.isNotEmpty())
                KidButton("🗑️ Șterge tot", onClick = {
                    for (i in fills.indices) fills[i] = null
                    history.clear()
                })
                KidButton("💾 Salvează", primary = true, onClick = {
                    val png = renderPng(1200, 1200, density) {
                        drawRect(Color.White)
                        drawColoring(page, fills, -1, 0f)
                    }
                    artStore(context).save("colorat", png)
                    toast.show("Am salvat în Galerie! ⭐")
                    voice.say("Bravo! Am pus desenul în galerie.")
                })
            }
        }
    }
}

// ======================= Desenează =======================

private class Line(val color: Long, val width: Float, val points: MutableList<Offset>)
private class Stamp(val emoji: String, val at: Offset, val size: Float)

private enum class DrawTool(val label: String) { PEN("✏️ Creion"), ERASER("🧽 Radieră"), STAMP("⭐ Ștampilă") }

private fun DrawScope.drawSheet(items: List<Any>, m: TextMeasurer) {
    drawRect(Color.White)
    val d = size.minDimension
    for (it in items) {
        when (it) {
            is Line -> {
                val pts = it.points.map { p -> Offset(p.x * size.width, p.y * size.height) }
                val c = Color(it.color.toInt())
                if (pts.size == 1) drawCircle(c, it.width * d / 2, pts[0])
                else {
                    val path = Path().apply { moveTo(pts[0].x, pts[0].y); pts.drop(1).forEach { p -> lineTo(p.x, p.y) } }
                    drawPath(path, c, style = Stroke(width = it.width * d, cap = StrokeCap.Round, join = StrokeJoin.Round))
                }
            }
            is Stamp -> ghiEmoji(m, it.emoji, Offset(it.at.x * size.width, it.at.y * size.height), it.size * d)
        }
    }
}

/**
 * Desen liber cu telecomanda: săgețile mută creionul (tot mai repede cât le ții apăsate),
 * OK pune creionul pe foaie sau îl ridică; cu ștampila, OK pune un abțibild.
 */
@Composable
fun DrawingScreen() {
    val context = LocalContext.current
    val density = LocalDensity.current
    val voice = rememberKidVoice()
    val toast = rememberToast()
    val m = rememberTextMeasurer()
    val items = remember { mutableStateListOf<Any>() }
    var x by remember { mutableFloatStateOf(0.5f) }
    var y by remember { mutableFloatStateOf(0.5f) }
    var penDown by remember { mutableStateOf(false) }
    var tool by remember { mutableStateOf(DrawTool.PEN) }
    var color by remember { mutableIntStateOf(6) }
    var thick by remember { mutableStateOf(false) }
    var sticker by remember { mutableIntStateOf(0) }
    var onSheet by remember { mutableStateOf(true) }
    var tick by remember { mutableIntStateOf(0) } // redesenează când crește linia
    val sheet = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { sheet.requestFocus() } }

    fun startLine() {
        val c = if (tool == DrawTool.ERASER) 0xFFFFFFFF else KidPalette.colors[color]
        val w = (if (thick) 0.03f else 0.012f) * (if (tool == DrawTool.ERASER) 2.5f else 1f)
        items += Line(c, w, mutableListOf(Offset(x, y)))
    }

    Column(Modifier.fillMaxSize()) {
        AtelierHeader(
            "✏️ Desenează",
            if (tool == DrawTool.STAMP) "Săgețile mută ștampila, OK o pune. ▶ la margine: unelte."
            else if (penDown) "Creionul desenează! Mută-l cu săgețile. OK îl ridică."
            else "Săgețile mută creionul, OK îl pune pe foaie. ▶ la margine: culori și unelte.",
            toast.text,
        )
        Row(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 32.dp, vertical = 8.dp)) {
            Box(
                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(18.dp)).sheetFrame(onSheet)
                    .onFocusChanged { onSheet = it.isFocused; if (!it.isFocused) penDown = false }
                    .focusRequester(sheet).focusable()
                    .onPreviewKeyEvent { ev ->
                        if (isCenter(ev.key)) {
                            if (ev.type == KeyEventType.KeyUp) {
                                if (tool == DrawTool.STAMP) {
                                    items += Stamp(kidStickers[sticker], Offset(x, y), if (thick) 0.16f else 0.1f)
                                } else {
                                    penDown = !penDown
                                    if (penDown) startLine()
                                }
                            }
                            return@onPreviewKeyEvent true
                        }
                        if (ev.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        val (dx, dy) = when (ev.key) {
                            Key.DirectionLeft -> -1 to 0
                            Key.DirectionRight -> 1 to 0
                            Key.DirectionUp -> 0 to -1
                            Key.DirectionDown -> 0 to 1
                            else -> return@onPreviewKeyEvent false
                        }
                        // La marginea din dreapta, cu creionul ridicat, trecem la unelte.
                        if (dx == 1 && x >= 1f && !penDown) return@onPreviewKeyEvent false
                        val (nx, ny) = DpadCursor.move(x, y, dx, dy, ev.nativeKeyEvent.repeatCount)
                        x = nx; y = ny
                        if (penDown) { (items.lastOrNull() as? Line)?.points?.add(Offset(x, y)); tick++ }
                        true
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    if (tick < 0) return@Canvas
                    drawSheet(items, m)
                    val c = Offset(x * size.width, y * size.height)
                    if (tool == DrawTool.STAMP) {
                        ghiEmoji(m, kidStickers[sticker], c, (if (thick) 0.16f else 0.1f) * size.minDimension, alpha = 0.6f)
                    }
                    val ring = if (tool == DrawTool.ERASER) Color.Gray else paletteColor(color)
                    drawCircle(ring, if (penDown) 16f else 12f, c)
                    drawCircle(Color.White, if (penDown) 16f else 12f, c, style = Stroke(4f))
                    drawCircle(Color.Black, 20f, c, style = Stroke(2f))
                }
            }
            Spacer(Modifier.width(24.dp))
            Column(Modifier.fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Palette(color) { color = it; if (tool == DrawTool.ERASER) tool = DrawTool.PEN; voice.say(KidPalette.names[it]) }
                DrawTool.entries.forEach { t ->
                    KidButton(
                        (if (tool == t) "✓ " else "") + t.label + (if (t == DrawTool.STAMP) " ${kidStickers[sticker]}" else ""),
                        primary = tool == t,
                        onClick = {
                            // A doua apăsare pe ștampilă alege alt abțibild.
                            if (t == DrawTool.STAMP && tool == DrawTool.STAMP) sticker = (sticker + 1) % kidStickers.size
                            tool = t
                        },
                    )
                }
                KidButton(if (thick) "✓ Gros" else "Subțire → Gros", onClick = { thick = !thick })
                KidButton("↩️ Înapoi un pas", onClick = { items.removeLastOrNull(); penDown = false }, enabled = items.isNotEmpty())
                KidButton("🗑️ Șterge tot", onClick = { items.clear(); penDown = false })
                KidButton("💾 Salvează", primary = true, onClick = {
                    val png = renderPng(1600, 900, density) { drawSheet(items, m) }
                    artStore(context).save("desen", png)
                    toast.show("Am salvat în Galerie! ⭐")
                    voice.say("Ce desen frumos! L-am pus în galerie.")
                })
            }
        }
    }
}

// ======================= Construiește =======================

private fun hexagon(cx: Float, cy: Float, r: Float) = Path().apply {
    for (i in 0 until 6) {
        val a = PI / 6 + i * PI / 3
        val px = cx + r * cos(a).toFloat()
        val py = cy + r * sin(a).toFloat()
        if (i == 0) moveTo(px, py) else lineTo(px, py)
    }
    close()
}

private fun DrawScope.drawPiece(p: Piece, m: TextMeasurer) {
    val d = size.minDimension
    val c = Offset(p.x * size.width, p.y * size.height)
    val s = p.size * d
    val (ax, ay) = p.aspect
    val w = s * ax
    val h = s * ay
    val color = Color(p.color.toInt())
    val edge = Color(0x55000000)
    rotateRad(p.angle, c) {
        when (p.shape) {
            PieceShape.SQUARE, PieceShape.RECT -> {
                drawRect(color, Offset(c.x - w / 2, c.y - h / 2), Size(w, h))
                drawRect(edge, Offset(c.x - w / 2, c.y - h / 2), Size(w, h), style = Stroke(3f))
            }
            PieceShape.CIRCLE -> {
                drawCircle(color, s / 2, c)
                drawCircle(edge, s / 2, c, style = Stroke(3f))
            }
            PieceShape.TRIANGLE -> {
                val t = Path().apply { moveTo(c.x, c.y - h / 2); lineTo(c.x + w / 2, c.y + h / 2); lineTo(c.x - w / 2, c.y + h / 2); close() }
                drawPath(t, color); drawPath(t, edge, style = Stroke(3f))
            }
            PieceShape.STAR -> {
                val t = starPath(c.x, c.y, s / 2)
                drawPath(t, color); drawPath(t, edge, style = Stroke(3f))
            }
            PieceShape.HEART -> {
                val t = heartPath(c.x, c.y + s * 0.05f, s / 2)
                drawPath(t, color); drawPath(t, edge, style = Stroke(3f))
            }
            PieceShape.HALF -> {
                drawArc(color, 180f, 180f, true, Offset(c.x - w / 2, c.y - h / 2), Size(w, w))
                drawArc(edge, 180f, 180f, true, Offset(c.x - w / 2, c.y - h / 2), Size(w, w), style = Stroke(3f))
            }
            PieceShape.HEXAGON -> {
                val t = hexagon(c.x, c.y, s / 2)
                drawPath(t, color); drawPath(t, edge, style = Stroke(3f))
            }
            PieceShape.EMOJI -> ghiEmoji(m, p.emoji, c, s * 0.8f)
        }
    }
}

private fun DrawScope.drawBuild(pieces: List<Piece>, background: Int, m: TextMeasurer, selected: Int, grabbing: Boolean) {
    val bg = buildBackgrounds[background].second
    drawRect(Brush.verticalGradient(0f to Color(bg[0].toInt()), 0.72f to Color(bg[1].toInt())))
    drawRect(Color(bg[2].toInt()), Offset(0f, size.height * 0.72f), Size(size.width, size.height * 0.28f))
    pieces.forEach { drawPiece(it, m) }
    pieces.getOrNull(selected)?.let { p ->
        val d = size.minDimension
        val (ax, ay) = p.aspect
        val r = maxOf(ax, ay) * p.size * d / 2 + 10f
        val c = Offset(p.x * size.width, p.y * size.height)
        drawRect(
            if (grabbing) KidColors.Sun else Color.White, Offset(c.x - r, c.y - r), Size(r * 2, r * 2),
            style = Stroke(5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(18f, 10f))),
        )
    }
}

/**
 * Construiește cu piese: săgețile aleg piesa, OK o „prinde” și săgețile o mută, OK o lasă.
 * În dreapta: forme noi, culori, mai mare / mai mic, rotește, fundal, salvează.
 */
@Composable
fun BuilderScreen(template: Int) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val voice = rememberKidVoice()
    val toast = rememberToast()
    val m = rememberTextMeasurer()
    val start = buildTemplates[template.coerceIn(0, buildTemplates.size - 1)]
    val pieces = remember { mutableStateListOf<Piece>().apply { addAll(start.make()) } }
    var background by remember { mutableIntStateOf(start.background) }
    var selected by remember { mutableIntStateOf(pieces.lastIndex) }
    var grabbing by remember { mutableStateOf(false) }
    var color by remember { mutableIntStateOf(0) }
    var sticker by remember { mutableIntStateOf(0) }
    var onSheet by remember { mutableStateOf(true) }
    val sheet = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { sheet.requestFocus() } }

    fun edit(f: (Piece) -> Piece) { pieces.getOrNull(selected)?.let { pieces[selected] = f(it) } }
    fun add(p: Piece) {
        pieces += p
        selected = pieces.lastIndex
        grabbing = true
        voice.say("O piesă nouă! Mut-o cu săgețile.")
        runCatching { sheet.requestFocus() }
    }

    Column(Modifier.fillMaxSize()) {
        AtelierHeader(
            "🧱 Construiește: ${start.title}",
            if (grabbing) "Săgețile mută piesa. OK o lasă jos."
            else "Săgețile aleg piesa, OK o prinde ca s-o muți. ▶ la margine: piese noi, culori și butoane.",
            toast.text,
        )
        Row(Modifier.weight(1f).fillMaxWidth().padding(horizontal = 32.dp, vertical = 8.dp)) {
            Box(
                Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(18.dp)).sheetFrame(onSheet)
                    .onFocusChanged { onSheet = it.isFocused; if (!it.isFocused) grabbing = false }
                    .focusRequester(sheet).focusable()
                    .onPreviewKeyEvent { ev ->
                        if (isCenter(ev.key)) {
                            if (ev.type == KeyEventType.KeyUp && selected in pieces.indices) grabbing = !grabbing
                            return@onPreviewKeyEvent true
                        }
                        if (ev.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        val (dx, dy) = when (ev.key) {
                            Key.DirectionLeft -> -1 to 0
                            Key.DirectionRight -> 1 to 0
                            Key.DirectionUp -> 0 to -1
                            Key.DirectionDown -> 0 to 1
                            else -> return@onPreviewKeyEvent false
                        }
                        if (grabbing) {
                            val step = DpadCursor.step(ev.nativeKeyEvent.repeatCount)
                            edit { it.moveBy(dx * step, dy * step) }
                            return@onPreviewKeyEvent true
                        }
                        val next = ColoringNav.neighbor(pieces.map { it.x * 100 to it.y * 100 }, selected, dx, dy)
                        if (next < 0) return@onPreviewKeyEvent dx != 1
                        selected = next
                        true
                    },
            ) {
                Canvas(Modifier.fillMaxSize()) { drawBuild(pieces, background, m, if (onSheet) selected else -1, grabbing) }
            }
            Spacer(Modifier.width(24.dp))
            Column(Modifier.fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Piese noi", color = KidColors.Sun, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                PieceShape.entries.filter { it != PieceShape.EMOJI }.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { sh ->
                            KidButton(sh.emoji, onClick = { add(Piece(sh, KidPalette.colors[color], x = 0.5f, y = 0.45f)) })
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    KidButton("+ ${kidStickers[sticker]}", onClick = {
                        add(Piece(PieceShape.EMOJI, emoji = kidStickers[sticker], x = 0.5f, y = 0.45f, size = 0.16f))
                    })
                    KidButton("Alt abțibild", onClick = { sticker = (sticker + 1) % kidStickers.size })
                }
                Text("Culoarea piesei", color = KidColors.Sun, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                Palette(color) { i ->
                    color = i
                    edit { if (it.shape == PieceShape.EMOJI) it else it.copy(color = KidPalette.colors[i]) }
                    voice.say(KidPalette.names[i])
                }
                Text("Piesa aleasă", color = KidColors.Sun, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                val has = selected in pieces.indices
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    KidButton("➕ Mai mare", onClick = { edit { it.scaleBy(1.2f) } }, enabled = has)
                    KidButton("➖ Mai mică", onClick = { edit { it.scaleBy(1 / 1.2f) } }, enabled = has)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    KidButton("🔄 Rotește", onClick = { edit { it.rotateBy((PI / 8).toFloat()) } }, enabled = has)
                    KidButton("📄 Copie", onClick = { pieces.getOrNull(selected)?.let { add(it.moveBy(0.04f, 0.04f)) } }, enabled = has)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    KidButton("⬆️ În față", onClick = {
                        if (has) { val p = pieces.removeAt(selected); pieces += p; selected = pieces.lastIndex }
                    }, enabled = has)
                    KidButton("❌ Scoate", onClick = {
                        if (has) { pieces.removeAt(selected); selected = pieces.lastIndex; grabbing = false }
                    }, enabled = has)
                }
                KidButton("🖼️ Fundal: ${buildBackgrounds[background].first}", onClick = { background = (background + 1) % buildBackgrounds.size })
                KidButton("🗑️ Șterge tot", onClick = { pieces.clear(); selected = -1; grabbing = false })
                KidButton("💾 Salvează", primary = true, onClick = {
                    val png = renderPng(1600, 900, density) { drawBuild(pieces, background, m, -1, false) }
                    artStore(context).save("construit", png)
                    toast.show("Am salvat în Galerie! ⭐")
                    voice.say("Ce construcție frumoasă! Am pus-o în galerie.")
                })
            }
        }
    }
}

// ======================= Galeria =======================

/** Galeria: lucrările salvate, cele mai noi primele. OK deschide, apoi se poate șterge. */
@Composable
fun GalleryScreen() {
    val context = LocalContext.current
    val store = remember { artStore(context) }
    var files by remember { mutableStateOf(store.list()) }
    var open by remember { mutableStateOf<File?>(null) }
    val first = remember { FocusRequester() }

    val current = open
    if (current != null) {
        val bmp = remember(current) { runCatching { BitmapFactory.decodeFile(current.path)?.asImageBitmap() }.getOrNull() }
        val back = remember { FocusRequester() }
        LaunchedEffect(current) { runCatching { back.requestFocus() } }
        Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                if (bmp != null) Image(bmp, contentDescription = null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(18.dp)))
            }
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                KidButton("◀ Înapoi la galerie", onClick = { open = null }, modifier = Modifier.focusRequester(back))
                KidButton("🗑️ Șterge lucrarea", onClick = { store.delete(current); files = store.list(); open = null })
            }
        }
        return
    }

    LaunchedEffect(files.size) { runCatching { first.requestFocus() } }
    Column(Modifier.fillMaxSize().padding(horizontal = 40.dp, vertical = 24.dp)) {
        Text("🖼️ Galeria mea", color = KidColors.Text, fontSize = 32.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(12.dp))
        if (files.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    "Încă nu ai salvat nimic.\nColorează, desenează sau construiește, apoi apasă 💾 Salvează.",
                    color = KidColors.TextDim, fontSize = 22.sp, lineHeight = 32.sp,
                )
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                contentPadding = PaddingValues(8.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                items(files, key = { it.path }) { f ->
                    val thumb = remember(f) {
                        runCatching {
                            BitmapFactory.decodeFile(f.path, BitmapFactory.Options().apply { inSampleSize = 4 })?.asImageBitmap()
                        }.getOrNull()
                    }
                    androidx.tv.material3.Surface(
                        onClick = { open = f },
                        modifier = (if (f == files.first()) Modifier.focusRequester(first) else Modifier).fillMaxWidth().height(200.dp),
                        shape = androidx.tv.material3.ClickableSurfaceDefaults.shape(CardShape),
                        colors = androidx.tv.material3.ClickableSurfaceDefaults.colors(containerColor = KidColors.Card, focusedContainerColor = KidColors.CardFocused),
                        border = focusBorder(),
                        scale = androidx.tv.material3.ClickableSurfaceDefaults.scale(focusedScale = 1.07f),
                    ) {
                        Column(Modifier.fillMaxSize()) {
                            Box(Modifier.weight(1f).fillMaxWidth().background(Color.White)) {
                                if (thumb != null) Image(thumb, contentDescription = null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
                            }
                            Text(ArtStore.kindOf(f), color = KidColors.Text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(10.dp))
                        }
                    }
                }
            }
        }
    }
}

/** Planșa ca imagine mică, pentru plăcile din Atelier. */
@Composable
fun ColoringThumb(page: ColoringPage, modifier: Modifier = Modifier) {
    Canvas(modifier) { drawColoring(page, emptyList(), -1, 0f) }
}
