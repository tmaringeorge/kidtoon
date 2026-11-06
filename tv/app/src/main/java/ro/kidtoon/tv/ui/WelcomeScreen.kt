package ro.kidtoon.tv.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.GhiCharacter

/** Sugestiile de nume și costumașele, ca pe telefon. */
val nameSuggestions = listOf("Bubu", "Dino", "Tita", "Mimi", "Zuzu", "Leo", "Pufi", "Ghi")

val costumes = listOf(
    Triple("dragon", "🦖", "Dinozaur") to KidColors.Green,
    Triple("balaur", "🐉", "Balaur") to KidColors.Teal,
    Triple("leu", "🦁", "Leu") to KidColors.Orange,
    Triple("urs", "🧸", "Ursuleț") to KidColors.Pink,
)

/**
 * Prima pornire (și „Prietenul meu” de la Acasă): copilul își alege prietenul din povești.
 * Numele ales apare peste tot în aplicație și în toate poveștile.
 */
@Composable
fun WelcomeScreen(start: GhiCharacter, editing: Boolean, onDone: (GhiCharacter) -> Unit) {
    var c by remember { mutableStateOf(if (editing) start else start.copy(name = "")) }
    var focused by remember { mutableStateOf(false) }
    val first = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }
    val name = c.name.trim()
    val ready = name.isNotEmpty()
    val done = { if (ready) onDone(c.copy(name = GhiCharacter.clean(name))) }

    Row(Modifier.fillMaxSize().padding(40.dp)) {
        Box(Modifier.weight(1f).fillMaxHeight()) {
            CharacterPreview(c.copy(name = name.ifEmpty { "?" }), Modifier.fillMaxSize())
            Text(
                if (name.isEmpty()) "Salut! Cum mă cheamă?" else "Salut! Eu sunt $name!",
                color = Color(0xFF3A2A7A), fontSize = 34.sp, fontWeight = FontWeight.Black,
                modifier = Modifier.align(Alignment.TopCenter).padding(20.dp),
            )
        }
        Spacer(Modifier.width(32.dp))
        Column(
            Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (!editing) Text("Bun venit în KidToon!", color = KidColors.Sun, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Title("1. Alege un nume")
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                nameSuggestions.take(4).forEachIndexed { i, s ->
                    KidButton(
                        (if (name == s) "✓ " else "") + s, primary = name == s,
                        modifier = if (i == 0) Modifier.focusRequester(first) else Modifier,
                        onClick = { c = c.copy(name = s) },
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                nameSuggestions.drop(4).forEach { s ->
                    KidButton((if (name == s) "✓ " else "") + s, primary = name == s, onClick = { c = c.copy(name = s) })
                }
            }
            Text("…sau scrie alt nume:", color = KidColors.TextDim, fontSize = 15.sp)
            Box(
                Modifier.fillMaxWidth().height(56.dp)
                    .background(KidColors.Card, RoundedCornerShape(16.dp))
                    .border(3.dp, if (focused) Color.White else Color.Transparent, RoundedCornerShape(16.dp))
                    .padding(horizontal = 18.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (c.name.isEmpty()) Text("Scrie numele", color = KidColors.TextDim, fontSize = 20.sp)
                BasicTextField(
                    value = c.name,
                    onValueChange = { c = c.copy(name = it.take(16)) },
                    singleLine = true,
                    textStyle = TextStyle(color = KidColors.Text, fontSize = 22.sp, fontWeight = FontWeight.Bold),
                    cursorBrush = SolidColor(KidColors.Sun),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { done() }),
                    modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                )
            }
            Title("2. Ce costumaș poartă?")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                costumes.forEach { (info, color) ->
                    val (id, emoji, label) = info
                    KidTile(
                        color = color, emoji = emoji, title = label, height = 120,
                        selected = c.avatar == id, onClick = { c = c.copy(avatar = id) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
            Title("3. Băiat sau fată?")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                KidTile(KidColors.Blue, "👦", "Băiat", { c = c.copy(girl = false) }, Modifier.weight(1f), selected = !c.girl, height = 100)
                KidTile(KidColors.Pink, "👧", "Fată", { c = c.copy(girl = true) }, Modifier.weight(1f), selected = c.girl, height = 100)
            }
            Spacer(Modifier.height(8.dp))
            KidButton(
                if (!ready) "Alege întâi un nume" else if (editing) "Gata!" else "🚀 Hai să ne jucăm cu $name!",
                onClick = { done() }, enabled = ready, primary = true, color = if (ready) KidColors.Green else null,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun Title(t: String) {
    Text(t, color = KidColors.Sun, fontSize = 24.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(top = 8.dp))
}
