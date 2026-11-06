package ro.kidtoon.tv.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.ParentQuestion

/**
 * Poarta pentru părinți (înainte de Setări): o înmulțire cu patru variante sau,
 * dacă părintele a pus un PIN, cele 4 cifre (din butoane sau din cifrele telecomenzii).
 */
@Composable
fun ParentGateScreen(pin: String, onPass: () -> Unit) {
    val first = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }
    var wrong by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.background(KidColors.Panel, RoundedCornerShape(32.dp)).padding(48.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("🔒 Doar pentru părinți", color = KidColors.Sun, fontSize = 34.sp, fontWeight = FontWeight.Black)
            if (pin.isEmpty()) {
                var question by remember { mutableStateOf(ParentQuestion.random()) }
                val choices = remember(question) { question.choices() }
                Text(question.text, color = KidColors.Text, fontSize = 44.sp, fontWeight = FontWeight.Black)
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    choices.forEachIndexed { i, n ->
                        KidButton(
                            "$n", modifier = (if (i == 0) Modifier.focusRequester(first) else Modifier).width(120.dp),
                            onClick = {
                                if (question.check(n)) onPass() else { wrong = true; question = ParentQuestion.random() }
                            },
                        )
                    }
                }
            } else {
                var typed by remember { mutableStateOf("") }
                var tries by remember { mutableIntStateOf(0) }
                fun digit(d: Int) {
                    if (typed.length >= 4) return
                    typed += d
                    if (typed.length == 4) {
                        if (typed == pin) onPass() else { wrong = true; tries++; typed = "" }
                    }
                }
                Text("Scrie PIN-ul", color = KidColors.Text, fontSize = 32.sp, fontWeight = FontWeight.Bold)
                Text(
                    (0 until 4).joinToString("  ") { if (it < typed.length) "●" else "○" },
                    color = KidColors.Text, fontSize = 40.sp,
                )
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.onPreviewKeyEvent { ev ->
                        // Cifrele de pe telecomandă merg direct.
                        val code = ev.nativeKeyEvent.keyCode
                        val d = when (code) {
                            in android.view.KeyEvent.KEYCODE_0..android.view.KeyEvent.KEYCODE_9 -> code - android.view.KeyEvent.KEYCODE_0
                            in android.view.KeyEvent.KEYCODE_NUMPAD_0..android.view.KeyEvent.KEYCODE_NUMPAD_9 -> code - android.view.KeyEvent.KEYCODE_NUMPAD_0
                            else -> -1
                        }
                        if (d < 0) return@onPreviewKeyEvent false
                        if (ev.type == KeyEventType.KeyDown) digit(d)
                        true
                    },
                ) {
                    listOf(listOf(1, 2, 3), listOf(4, 5, 6), listOf(7, 8, 9), listOf(-1, 0, -2)).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            row.forEach { d ->
                                when (d) {
                                    -1 -> Spacer(Modifier.width(96.dp))
                                    -2 -> KidButton("⌫", modifier = Modifier.width(96.dp), onClick = { typed = typed.dropLast(1) })
                                    else -> KidButton(
                                        "$d", modifier = (if (d == 1) Modifier.focusRequester(first) else Modifier).width(96.dp),
                                        onClick = { digit(d) },
                                    )
                                }
                            }
                        }
                    }
                }
                if (tries >= 3) Text("Ai uitat PIN-ul? Șterge datele aplicației din Setările televizorului (Aplicații → KidToon).", color = KidColors.TextDim, fontSize = 14.sp)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                if (wrong) "Nu e bine. Mai încearcă!" else "Copiii: apăsați Înapoi ca să vă întoarceți la joacă.",
                color = if (wrong) KidColors.Live else KidColors.TextDim, fontSize = 18.sp,
            )
        }
    }
}
