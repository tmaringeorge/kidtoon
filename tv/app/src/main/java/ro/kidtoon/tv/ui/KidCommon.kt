package ro.kidtoon.tv.ui

import android.content.Context
import android.graphics.Bitmap
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Border
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.ArtStore
import ro.kidtoon.tv.data.GhiCharacter
import ro.kidtoon.tv.data.GhiPose
import ro.kidtoon.tv.data.Span
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale

/** O placă mare, colorată, cu un emoji: ce alege copilul cu telecomanda. Cea aleasă crește și are ramă albă. */
@Composable
fun KidTile(
    color: Color,
    emoji: String,
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    selected: Boolean = false,
    height: Int = 170,
    onLongClick: (() -> Unit)? = null,
) {
    Surface(
        onClick = onClick,
        onLongClick = onLongClick,
        modifier = modifier.fillMaxWidth().height(height.dp),
        shape = ClickableSurfaceDefaults.shape(CardShape),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = color,
            focusedContainerColor = color,
            contentColor = Color.White,
            focusedContentColor = Color.White,
        ),
        border = ClickableSurfaceDefaults.border(
            border = if (selected) Border(BorderStroke(4.dp, KidColors.Sun), shape = CardShape) else Border.None,
            focusedBorder = Border(BorderStroke(5.dp, Color.White), shape = CardShape),
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.07f),
    ) {
        Box(
            Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0x22FFFFFF), Color(0x22000000)))),
        ) {
            Column(
                Modifier.fillMaxSize().padding(14.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(emoji, fontSize = (height * 0.3f).sp)
                Text(
                    title, fontSize = 22.sp, fontWeight = FontWeight.Black, maxLines = 1,
                    overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                )
                if (subtitle != null) {
                    Text(
                        subtitle, fontSize = 14.sp, color = Color(0xE6FFFFFF), maxLines = 1,
                        overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}

/** Un buton mare, rotunjit, pentru telecomandă. */
@Composable
fun KidButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
    enabled: Boolean = true,
    color: Color? = null,
) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(56.dp),
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(18.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = color ?: if (primary) KidColors.AccentSoft else KidColors.Card,
            contentColor = KidColors.Text,
            focusedContainerColor = color ?: KidColors.Accent,
            focusedContentColor = KidColors.Text,
            disabledContainerColor = KidColors.Panel,
            disabledContentColor = KidColors.TextDim,
        ),
        border = ClickableSurfaceDefaults.border(
            focusedBorder = Border(BorderStroke(3.dp, Color.White), shape = RoundedCornerShape(18.dp)),
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.06f),
    ) {
        Box(Modifier.padding(horizontal = 22.dp).height(56.dp), contentAlignment = Alignment.Center) {
            Text(text, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
    }
}

/** O bulină de culoare din paletă; cea aleasă are inel alb. */
@Composable
fun ColorDot(color: Color, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(
        onClick = onClick,
        modifier = modifier.size(48.dp),
        shape = ClickableSurfaceDefaults.shape(CircleShape),
        colors = ClickableSurfaceDefaults.colors(containerColor = color, focusedContainerColor = color),
        border = ClickableSurfaceDefaults.border(
            border = if (selected) Border(BorderStroke(4.dp, KidColors.Sun), shape = CircleShape)
            else Border(BorderStroke(2.dp, Color(0x55FFFFFF)), shape = CircleShape),
            focusedBorder = Border(BorderStroke(5.dp, Color.White), shape = CircleShape),
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.25f),
    ) {}
}

@Composable
fun frameMillis(): Long {
    val ms by produceState(0L) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { value = it - start }
    }
    return ms
}

/** Prietenul copilului care face cu mâna (la Acasă și la alegerea personajului). */
@Composable
fun CharacterPreview(c: GhiCharacter, modifier: Modifier = Modifier, sky: Boolean = true) {
    previewGhiLook(c)
    val m = rememberTextMeasurer()
    val ms = frameMillis()
    Canvas(
        modifier.then(
            if (sky) Modifier.background(
                Brush.verticalGradient(0f to Color(0xFF8FD3FF), 0.72f to Color(0xFFD7F5FF), 0.73f to Color(0xFF9BE07A), 1f to Color(0xFF7BD66A)),
                RoundedCornerShape(28.dp),
            ) else Modifier,
        ),
    ) {
        val pose = GhiPose(
            pose = if ((ms / 4000) % 3 == 2L) "happy" else "wave", x = Span(0.5f, 0.5f), y = null, face = "happy",
            puff = null, hold = null, hat = null, think = null, flip = false, motion = null,
        )
        val ts = ms / 1000f
        drawGhi(pose, (ts % 4f) / 4f, ts, size.width / 2, size.height * 0.92f, size.height * 0.62f, m)
    }
}

/** Vocea românească a sistemului: spune numele culorilor, lucrurile atinse și poveștile. */
class KidVoice internal constructor() {
    internal var tts: TextToSpeech? = null

    fun say(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "kid")
    }
}

@Composable
fun rememberKidVoice(): KidVoice {
    val context = LocalContext.current
    val voice = remember { KidVoice() }
    DisposableEffect(Unit) {
        var engine: TextToSpeech? = null
        engine = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                engine?.language = Locale("ro", "RO")
                engine?.setSpeechRate(0.85f)
                voice.tts = engine
            }
        }
        onDispose {
            voice.tts = null
            engine?.shutdown()
        }
    }
    return voice
}

/** Lucrările din Atelier: în memoria aplicației, folderul „atelier”. */
fun artStore(context: Context) = ArtStore(File(context.filesDir, "atelier"))

/** Desenează o lucrare într-o imagine PNG (pentru Galerie). */
fun renderPng(width: Int, height: Int, density: Density, draw: DrawScope.() -> Unit): ByteArray {
    val bmp = ImageBitmap(width, height)
    val canvas = androidx.compose.ui.graphics.Canvas(bmp)
    CanvasDrawScope().draw(density, LayoutDirection.Ltr, canvas, Size(width.toFloat(), height.toFloat())) { draw() }
    val out = ByteArrayOutputStream()
    bmp.asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, out)
    return out.toByteArray()
}

/** Bara de sus din Atelier: titlul, un sfat pentru telecomandă și un mesaj scurt (de ex. „Am salvat!”). */
@Composable
fun AtelierHeader(title: String, hint: String, toast: String?, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, color = KidColors.Text, fontSize = 30.sp, fontWeight = FontWeight.Black)
        Box(Modifier.padding(start = 20.dp).weight(1f)) {
            Text(hint, color = KidColors.TextDim, fontSize = 14.sp, maxLines = 2)
        }
        if (toast != null) {
            Text(
                toast, color = Color.Black, fontSize = 18.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.background(KidColors.Sun, RoundedCornerShape(14.dp)).padding(horizontal = 16.dp, vertical = 8.dp),
            )
        }
    }
}

/** Rama foii de lucru: albă când copilul lucrează pe foaie, discretă când e în bara de unelte. */
fun Modifier.sheetFrame(active: Boolean) =
    border(if (active) 5.dp else 2.dp, if (active) Color.White else Color(0x55FFFFFF), RoundedCornerShape(18.dp))

/** Un mesaj care dispare singur. */
class Toast {
    var text by mutableStateOf<String?>(null)
    var nonce by mutableStateOf(0)
    fun show(t: String) { text = t; nonce++ }
}
