package ro.kidtoon.tv.ui

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.GhiPose
import ro.kidtoon.tv.data.GhiTouchLayout
import ro.kidtoon.tv.data.GhiTouchScene
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.ScreenCare
import ro.kidtoon.tv.data.Span
import kotlin.math.abs
import kotlin.math.sin

private val captionStyle = TextStyle(shadow = Shadow(Color(0x99000000), Offset(2f, 3f), 8f))

@Composable
private fun frameClock(): Long {
    val ms by produceState(0L) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { value = it - start }
    }
    return ms
}

private fun pose(pose: String, x: Float, face: String, puff: String? = null, y: Float? = null) =
    GhiPose(pose, Span(x, x), y?.let { Span(it, it) }, face, puff, null, null, null, false, null)

/**
 * „Atinge și învață”: copilul atinge un lucru (sau îl alege cu săgețile și OK pe TV),
 * lucrul sare, apare numele, iar [onTap] spune cu voce ce este.
 */
@Composable
fun GhiTouch(
    book: GhiBook,
    scene: GhiTouchScene,
    focus: Int?,
    tapped: Int,
    tappedAt: Long,
    onTap: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val ms = frameClock()
    val m = rememberTextMeasurer()
    val now = android.os.SystemClock.elapsedRealtime()
    val since = if (tapped >= 0) now - tappedAt else Long.MAX_VALUE
    val n = scene.items.size

    Box(
        modifier.fillMaxSize().background(Color.Black).pointerInput(scene.id) {
            detectTapGestures { p ->
                val i = GhiTouchLayout.hit(n, p.x / size.width, p.y / size.height, size.height.toFloat() / size.width)
                if (i >= 0) onTap(i)
            }
        },
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val ts = quantSec(ms)
            val set = book.set(scene.set)
            drawSetBack(set, ts)
            val px = size.minDimension * 0.15f
            scene.items.forEachIndexed { i, item ->
                val c = Offset(GhiTouchLayout.x(i) * size.width, GhiTouchLayout.y(i) * size.height)
                val bounce = if (i == tapped && since < 1200) abs(sin(since / 1200f * Math.PI.toFloat() * 3)) * (1 - since / 1200f) else 0f
                val breathe = 1f + 0.03f * sin(ts * 1.5f + i)
                // Un cerc deschis în spate, ca lucrurile să se vadă bine pe orice decor.
                drawCircle(Color(0x55FFFFFF), px * 0.75f, c)
                if (focus == i) drawCircle(Color(0xFFFFD54F), px * 0.82f, c, style = Stroke(px * 0.08f))
                val center = c - Offset(0f, bounce * px * 0.4f)
                val sizePx = px * (breathe + bounce * 0.3f)
                if (item.emoji.length <= 2 && item.emoji.all { it.isLetterOrDigit() }) {
                    ghiLabel(m, item.emoji, center, sizePx, Color(0xFF1E88E5))
                } else {
                    ghiEmoji(m, item.emoji, center, sizePx)
                }
                if (i == tapped) ghiLabel(m, item.name, c + Offset(0f, px * 0.95f), px * 0.3f)
            }
            drawSetFront(set, ts)
            // GHI în colțul din stânga, se bucură când atingi ceva.
            val happy = since < 2500
            drawGhi(
                pose(if (happy) "happy" else "stand", 0.13f, if (happy) "wow" else "happy", if (happy) "stars" else null, 0.94f),
                0f, ts, size.width * 0.13f, size.height * 0.94f, size.height * 0.34f, m,
            )
        }
        val caption = if (tapped >= 0 && since < 6000) scene.items[tapped].say else "${scene.title}: atinge ceva!"
        Crossfade(caption, label = "touch-caption", modifier = Modifier.align(Alignment.TopCenter).padding(top = 40.dp, start = 48.dp, end = 48.dp)) {
            Text(it, color = Color.White, fontSize = 44.sp, fontWeight = FontWeight.Black, style = captionStyle, textAlign = TextAlign.Center)
        }
    }
}

private fun quantSec(ms: Long) = ro.kidtoon.tv.data.GhiTimeline.quantize(ms) / 1000f

/** Pauza de clipit: GHI clipește încet de trei ori, apoi ne roagă să ne uităm departe. */
@Composable
fun GhiBlinkOverlay(ms: Long, modifier: Modifier = Modifier) {
    val m = rememberTextMeasurer()
    val lookAway = ms >= ScreenCare.LOOK_AWAY_AT_MS
    val fadeIn = (ms / 1500f).coerceIn(0f, 1f)
    val fadeOut = ((ScreenCare.BLINK_MS - ms) / 1500f).coerceIn(0f, 1f)
    val a = fadeIn * fadeOut
    Box(modifier.fillMaxSize().background(Color.Black.copy(alpha = (if (lookAway) 0.85f else 0.6f) * a))) {
        if (!lookAway) {
            Canvas(Modifier.fillMaxSize()) {
                drawGhi(
                    pose("stand", 0.5f, if (ScreenCare.eyesClosed(ms)) "sleepy" else "calm", y = 0.86f),
                    0f, 0f, size.width / 2, size.height * 0.86f, size.height * 0.55f, m,
                )
            }
        }
        Column(
            Modifier.align(if (lookAway) Alignment.Center else Alignment.TopCenter).padding(top = 48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (lookAway) Text("🪟", fontSize = 80.sp)
            Text(
                ScreenCare.blinkCaption(ms), color = Color.White.copy(alpha = a), fontSize = 46.sp,
                fontWeight = FontWeight.Black, style = captionStyle, textAlign = TextAlign.Center,
            )
        }
    }
}

/** Odihna după sesiune: ecran liniștit, prietenul doarme, radioul merge mai departe doar cu sunet. */
@Composable
fun GhiRest(hint: String, modifier: Modifier = Modifier, radio: Boolean = true) {
    val ms = frameClock()
    val m = rememberTextMeasurer()
    Box(modifier.fillMaxSize().background(Color(0xFF0B1026))) {
        Canvas(Modifier.fillMaxSize()) {
            val ts = quantSec(ms)
            drawGhi(pose("sleep", 0.5f, "sleepy", "zzz", 0.8f), 0f, ts, size.width / 2, size.height * 0.8f, size.height * 0.4f, m)
        }
        Column(
            Modifier.align(Alignment.TopCenter).padding(top = 56.dp)
                .background(Color(0x22FFFFFF), RoundedCornerShape(24.dp)).padding(horizontal = 32.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("$ghiName a obosit și se odihnește 💤", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Black)
            Text(if (radio) "Hai să ne jucăm altceva! Radioul cântă mai departe." else "Hai să ne jucăm altceva, departe de ecran!", color = Color(0xCCFFFFFF), fontSize = 24.sp)
            Text(hint, color = Color(0x88FFFFFF), fontSize = 14.sp)
        }
    }
}
