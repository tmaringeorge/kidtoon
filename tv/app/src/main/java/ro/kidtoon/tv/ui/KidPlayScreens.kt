package ro.kidtoon.tv.ui

import android.os.SystemClock
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import kotlinx.coroutines.delay
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.GhiTouchLayout
import ro.kidtoon.tv.data.ScreenCare

private fun KeyEvent.isCenter() = key == Key.DirectionCenter || key == Key.Enter || key == Key.NumPadEnter

/**
 * Ecran sănătos, fără radio: numără timpul petrecut la povești, pune pauza de clipit,
 * apoi odihna lungă. Părintele ține OK apăsat 3 secunde ca să continue.
 */
private class KidCare {
    var activeMs by mutableLongStateOf(0L)
    var episodesInRow by mutableIntStateOf(0)
    var okDownAt = 0L
    fun unlock() { activeMs = 0L; episodesInRow = 0 }
}

@Composable
private fun rememberKidCare(limit: Int): Pair<KidCare, ScreenCare.State> {
    val care = remember { KidCare() }
    val state = ScreenCare.state(care.activeMs, limit, care.episodesInRow)
    val resting = state == ScreenCare.State.Rest
    LaunchedEffect(resting) {
        if (resting) return@LaunchedEffect
        var last = withFrameMillis { it }
        while (true) withFrameMillis { now -> care.activeMs += now - last; last = now }
    }
    return care to state
}

/** Seara, ecranul devine mai cald și mai întunecat. */
@Composable
private fun EveningDim() {
    var evening by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        while (true) {
            val c = java.util.Calendar.getInstance()
            evening = ScreenCare.eveningDim(c.get(java.util.Calendar.HOUR_OF_DAY), c.get(java.util.Calendar.MINUTE))
            delay(60_000)
        }
    }
    if (evening > 0f) Box(Modifier.fillMaxSize().background(Color(0xFF2A1400).copy(alpha = evening)))
}

/** Ține ecranul aprins cât copilul se uită. */
@Composable
private fun KeepScreenOn() {
    val view = LocalView.current
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
}

@Composable
private fun Hint(text: String, visible: Boolean, modifier: Modifier = Modifier) {
    AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut(), modifier = modifier) {
        Box(
            Modifier.fillMaxWidth()
                .background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xCC000000))))
                .padding(start = 48.dp, end = 48.dp, top = 40.dp, bottom = 24.dp),
        ) {
            Text(text, color = Color(0xDDFFFFFF), fontSize = 16.sp)
        }
    }
}

/**
 * O poveste cu prietenul copilului, pe tot ecranul, fără radio.
 * ◀ ▶ alt episod, OK răspunde la întrebări, Înapoi iese. La final trece singur la următoarea.
 */
@Composable
fun StoryScreen(
    book: GhiBook,
    index: Int,
    sessionLimit: Int,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
) {
    KeepScreenOn()
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val voice = rememberKidVoice()
    val quiz = remember { GhiQuiz() }
    val (care, state) = rememberKidCare(sessionLimit)
    val resting = state == ScreenCare.State.Rest
    var hintNonce by remember { mutableIntStateOf(0) }
    var hint by remember { mutableStateOf(true) }
    LaunchedEffect(hintNonce) { hint = true; delay(6000); hint = false }

    Box(
        Modifier.fillMaxSize().background(Color.Black)
            .focusRequester(focus).focusable()
            .onPreviewKeyEvent { ev ->
                if (ev.isCenter() && resting) {
                    if (ev.type == KeyEventType.KeyDown) {
                        val now = SystemClock.elapsedRealtime()
                        if (ev.nativeKeyEvent.repeatCount == 0) care.okDownAt = now
                        else if (now - care.okDownAt >= ScreenCare.UNLOCK_HOLD_MS) care.unlock()
                    }
                    return@onPreviewKeyEvent true
                }
                if (ev.isCenter()) {
                    if (ev.type == KeyEventType.KeyUp) { if (quiz.asking) quiz.pick() else hintNonce++ }
                    return@onPreviewKeyEvent true
                }
                if (ev.type != KeyEventType.KeyDown || resting) return@onPreviewKeyEvent false
                when (ev.key) {
                    Key.DirectionLeft -> { if (quiz.asking) quiz.move(-1) else onPrevious(); hintNonce++; true }
                    Key.DirectionRight -> { if (quiz.asking) quiz.move(1) else onNext(); hintNonce++; true }
                    Key.DirectionUp, Key.DirectionDown -> { hintNonce++; true }
                    else -> false
                }
            },
    ) {
        if (resting) {
            GhiRest("Părinte: ține apăsat OK 3 secunde ca să continuați.", radio = false)
        } else {
            GhiAnimation(
                book, index, onFinished = { care.episodesInRow++; onNext() }, quiz = quiz, onSay = { voice.say(it) },
            )
        }
        (state as? ScreenCare.State.Blink)?.let { GhiBlinkOverlay(it.ms) }
        EveningDim()
        val ep = book.episodes[index.coerceIn(0, book.episodes.size - 1)]
        Hint(
            "Episodul ${index + 1} din ${book.episodes.size}: ${ep.title}   ·   ◀ ▶ altă poveste   ·   OK alege răspunsul   ·   Înapoi: meniul",
            hint && !resting, Modifier.align(Alignment.BottomCenter),
        )
    }
}

/** „Atinge și învață” pe tot ecranul: săgețile aleg, OK atinge, la capete trece la altă scenă. */
@Composable
fun TouchScreen(
    book: GhiBook,
    sceneIndex: Int,
    sessionLimit: Int,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
) {
    KeepScreenOn()
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val voice = rememberKidVoice()
    val scene = book.touch[sceneIndex.coerceIn(0, book.touch.size - 1)]
    var touchFocus by remember { mutableIntStateOf(0) }
    var tapped by remember { mutableIntStateOf(-1) }
    var tappedAt by remember { mutableLongStateOf(0L) }
    LaunchedEffect(scene.id) { touchFocus = 0; tapped = -1; voice.say(scene.title) }
    val (care, state) = rememberKidCare(sessionLimit)
    val resting = state == ScreenCare.State.Rest
    var hintNonce by remember { mutableIntStateOf(0) }
    var hint by remember { mutableStateOf(true) }
    LaunchedEffect(hintNonce) { hint = true; delay(6000); hint = false }

    fun touch(i: Int) {
        tapped = i
        tappedAt = SystemClock.elapsedRealtime()
        touchFocus = i
        voice.say(scene.items[i].say)
    }

    Box(
        Modifier.fillMaxSize().background(Color.Black)
            .focusRequester(focus).focusable()
            .onPreviewKeyEvent { ev ->
                if (ev.isCenter() && resting) {
                    if (ev.type == KeyEventType.KeyDown) {
                        val now = SystemClock.elapsedRealtime()
                        if (ev.nativeKeyEvent.repeatCount == 0) care.okDownAt = now
                        else if (now - care.okDownAt >= ScreenCare.UNLOCK_HOLD_MS) care.unlock()
                    }
                    return@onPreviewKeyEvent true
                }
                if (ev.isCenter()) {
                    if (ev.type == KeyEventType.KeyUp) touch(touchFocus)
                    return@onPreviewKeyEvent true
                }
                if (ev.type != KeyEventType.KeyDown || resting) return@onPreviewKeyEvent false
                val n = scene.items.size
                hintNonce++
                when (ev.key) {
                    Key.DirectionLeft -> { if (touchFocus == 0) onPrevious() else touchFocus = GhiTouchLayout.move(touchFocus, n, -1, 0); true }
                    Key.DirectionRight -> { if (touchFocus == n - 1) onNext() else touchFocus = GhiTouchLayout.move(touchFocus, n, 1, 0); true }
                    Key.DirectionUp -> { touchFocus = GhiTouchLayout.move(touchFocus, n, 0, -1); true }
                    Key.DirectionDown -> { touchFocus = GhiTouchLayout.move(touchFocus, n, 0, 1); true }
                    else -> false
                }
            },
    ) {
        if (resting) GhiRest("Părinte: ține apăsat OK 3 secunde ca să continuați.", radio = false)
        else GhiTouch(book, scene, touchFocus, tapped, tappedAt, onTap = { touch(it) })
        (state as? ScreenCare.State.Blink)?.let { GhiBlinkOverlay(it.ms) }
        EveningDim()
        Hint(
            "${scene.title}   ·   săgețile aleg, OK atinge   ·   la capete: altă scenă   ·   Înapoi: meniul",
            hint && !resting, Modifier.align(Alignment.BottomCenter),
        )
    }
}
