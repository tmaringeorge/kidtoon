package ro.kidtoon.tv.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import ro.kidtoon.tv.data.Presets
import ro.kidtoon.tv.data.RadioBackground
import ro.kidtoon.tv.data.KidContent
import ro.kidtoon.tv.data.RadioMode
import ro.kidtoon.tv.data.ScreenCare
import ro.kidtoon.tv.data.Repository
import ro.kidtoon.tv.data.GhiStudio
import ro.kidtoon.tv.data.GhiCharacter
import ro.kidtoon.tv.data.KidFilter
import ro.kidtoon.tv.data.ParentPin
import ro.kidtoon.tv.data.GhiPose
import ro.kidtoon.tv.data.Span

@Composable
fun SettingsScreen(state: UiState, vm: MainViewModel) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 64.dp, vertical = 36.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text("🔒 Setări pentru părinți", color = KidColors.Text, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text(
                "${state.channels.size} posturi pentru copil (din ${state.allChannels.size} încărcate)" +
                    (if (state.filteredOut > 0) " · ${state.filteredOut} intrări ascunse (surse neautorizate)" else "") +
                    (if (state.epg.isEmpty) " · fără ghid TV" else " · ghid TV activ"),
                color = KidColors.TextDim, fontSize = 15.sp,
            )
        }
        item { ActionButton("Actualizează acum toate sursele", primary = true) { vm.refreshSources() } }

        item { Section("Ce vede copilul la Desene TV") }
        item {
            ToggleRow(
                title = "Doar posturi pentru copii",
                subtitle = "Arată numai categoriile ${KidFilter.label}. Oprit: toate posturile din liste.",
                enabled = state.kidsOnly,
                onToggle = { vm.setKidsOnly(!state.kidsOnly) },
                onDelete = null,
            )
        }
        item { HiddenChannels(state, vm) }

        item { Section("PIN pentru părinți") }
        item { PinSettings(state, vm) }

        item { Section("Liste de posturi (M3U)") }
        item {
            ToggleRow(
                title = Repository.BUILT_IN_NAME,
                subtitle = "Lista inclusă în aplicație (comună cu telefonul)",
                enabled = state.builtInEnabled,
                onToggle = { vm.setBuiltIn(!state.builtInEnabled) },
                onDelete = null,
            )
        }
        items(state.playlists, key = { it.url }) { p ->
            ToggleRow(p.name, p.url, p.enabled, onToggle = { vm.togglePlaylist(p) }, onDelete = { vm.removePlaylist(p) })
        }
        item {
            AddField(
                label = "Adaugă listă M3U (link http/https)",
                placeholder = "https://exemplu.ro/lista.m3u",
                onAdd = { url -> vm.addPlaylist(nameFromUrl(url), url) },
            )
        }
        item { Text("Sugestii (liste publice iptv-org, posturi cu acces liber):", color = KidColors.TextDim, fontSize = 15.sp) }
        items(Presets.playlists, key = { "preset-" + it.url }) { p ->
            val added = state.playlists.any { it.url == p.url }
            ActionButton(if (added) "✓ ${p.name}" else "+ ${p.name}", enabled = !added) { vm.addPlaylist(p.name, p.url) }
        }

        item { Section("Radio") }
        item {
            Text("Mod radio: Copil (animații) sau Adult (ecran simplu, cu postul și melodia):", color = KidColors.TextDim, fontSize = 15.sp)
        }
        item {
            Row {
                RadioMode.entries.forEach { m ->
                    val selected = state.radioMode == m
                    ActionButton((if (selected) "✓ " else "") + m.label, primary = selected) { vm.setRadioMode(m) }
                    Spacer(Modifier.width(10.dp))
                }
            }
        }
        item {
            Text("Ce vede copilul în radio (0 sau butonul roșu le schimbă direct din radio):", color = KidColors.TextDim, fontSize = 15.sp)
        }
        item {
            Row {
                KidContent.entries.forEach { c ->
                    val selected = state.kidContent == c
                    ActionButton((if (selected) "✓ " else "") + c.label, primary = selected) { vm.setKidContent(c) }
                    Spacer(Modifier.width(10.dp))
                }
            }
        }
        item {
            Text(
                "Ecran sănătos: pauză de clipit la 5 minute, oprire după 3 episoade la rând și odihnă după o sesiune de:",
                color = KidColors.TextDim, fontSize = 15.sp,
            )
        }
        item {
            Row {
                ScreenCare.LIMITS.forEach { min ->
                    val selected = state.sessionLimit == min
                    ActionButton((if (selected) "✓ " else "") + ScreenCare.limitLabel(min), primary = selected) { vm.setSessionLimit(min) }
                    Spacer(Modifier.width(10.dp))
                }
            }
        }
        item {
            Text("Animația din modul Copil (se păstrează pentru data viitoare):", color = KidColors.TextDim, fontSize = 15.sp)
        }
        items(RadioBackground.entries.chunked(4), key = { "bg-" + it.first().name }) { row ->
            Row {
                row.forEach { bg ->
                    val selected = state.radioBackground == bg
                    ActionButton((if (selected) "✓ " else "") + bg.label, primary = selected) { vm.setRadioBackground(bg) }
                    Spacer(Modifier.width(10.dp))
                }
            }
        }
        item {
            Text(
                "„Toate pe rând” schimbă desenul la fiecare 2 minute și nu repetă aceeași imagine timp de o oră. " +
                    "În radio, ◀ ▶ schimbă animația și Meniu comută Copil / Adult. " +
                    "Radioul merge și în fundal: apasă Home și ascultă mai departe.",
                color = KidColors.TextDim, fontSize = 14.sp,
            )
        }

        item { Section("Ghid TV (XMLTV)") }
        items(state.epgUrls, key = { "epg-$it" }) { url ->
            ToggleRow(nameFromUrl(url), url, enabled = true, onToggle = null, onDelete = { vm.removeEpg(url) })
        }
        item {
            AddField(
                label = "Adaugă ghid TV (link XMLTV .xml sau .xml.gz)",
                placeholder = "https://exemplu.ro/ghid.xml.gz",
                onAdd = vm::addEpg,
            )
        }
        items(Presets.epg, key = { "epgp-$it" }) { url ->
            val added = url in state.epgUrls
            ActionButton(if (added) "✓ Ghid TV România (epgshare01)" else "+ Ghid TV România (epgshare01)", enabled = !added) { vm.addEpg(url) }
        }

        item { Section("Prietenul copilului (numele din povești)") }
        item { CharacterSettings(vm) }

        item { Section("Studio: povești făcute pe telefon") }
        item { StudioReceiver(vm) }

        if (state.errors.isNotEmpty()) {
            item { Section("Erori la ultima actualizare") }
            items(state.errors) { Text(it, color = KidColors.Live, fontSize = 14.sp) }
        }

        item { Section("Despre") }
        item {
            Text(
                "KidToon redă doar stream-uri publice, oferite gratuit de televiziuni. Poți adăuga liste proprii " +
                    "(de exemplu de la furnizorul tău de IPTV cu abonament). Intrările din surse cunoscute ca " +
                    "retransmisii neautorizate sunt ascunse automat. Aplicația nu are reclame și nu trimite date despre copil.\n\n" +
                    "Telecomandă: OK = pornește, ține apăsat OK = preferat, ◀ în player = lista de posturi, " +
                    "▲▼ = schimbă postul, cifre = număr post. Înapoi = meniul copilului.",
                color = KidColors.TextDim, fontSize = 15.sp, lineHeight = 22.sp,
            )
        }
    }
}

/** Numele lui GHI, băiat sau fată și costumașul, cu desenul care se schimbă pe loc. */
@Composable
private fun CharacterSettings(vm: MainViewModel) {
    val c = vm.ghiCharacter
    val m = rememberTextMeasurer()
    var name by remember(c.name) { mutableStateOf(c.name) }
    var focused by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        // Desenul se reface când se schimbă personajul.
        key(c) {
            Canvas(Modifier.width(170.dp).height(190.dp).background(Color(0xFFE3F2FD), RoundedCornerShape(16.dp))) {
                val pose = GhiPose(
                    pose = "wave", x = Span(0.5f, 0.5f), y = null, face = "happy", puff = null,
                    hold = null, hat = null, think = null, flip = false, motion = null,
                )
                drawGhi(pose, 0.3f, 1.2f, size.width / 2, size.height * 0.94f, size.height * 0.55f, m)
            }
        }
        Spacer(Modifier.width(24.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                c.personalize("Poveștile spun: „GHI e {fericit|fericită}! Mami {îl|o} îmbrățișează.”"),
                color = KidColors.TextDim, fontSize = 15.sp,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.width(260.dp).height(48.dp)
                        .background(KidColors.Card, RoundedCornerShape(12.dp))
                        .border(2.dp, if (focused) KidColors.Accent else Color.Transparent, RoundedCornerShape(12.dp))
                        .padding(horizontal = 16.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    BasicTextField(
                        value = name,
                        onValueChange = { name = it.take(16) },
                        singleLine = true,
                        textStyle = TextStyle(color = KidColors.Text, fontSize = 18.sp),
                        cursorBrush = SolidColor(KidColors.Accent),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { vm.changeGhiCharacter(c.copy(name = name)) }),
                        modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                    )
                }
                Spacer(Modifier.width(10.dp))
                ActionButton("Păstrează numele", primary = name.trim() != c.name, enabled = name.isNotBlank()) {
                    vm.changeGhiCharacter(c.copy(name = name))
                }
            }
            Row {
                ActionButton((if (!c.girl) "✓ " else "") + "Băiat", primary = !c.girl) { vm.changeGhiCharacter(c.copy(girl = false)) }
                Spacer(Modifier.width(10.dp))
                ActionButton((if (c.girl) "✓ " else "") + "Fată (cu fundiță)", primary = c.girl) { vm.changeGhiCharacter(c.copy(girl = true)) }
            }
            Row {
                GhiCharacter.AVATARS.forEach { (id, label) ->
                    val selected = c.avatar == id
                    ActionButton((if (selected) "✓ " else "") + label, primary = selected) { vm.changeGhiCharacter(c.copy(avatar = id)) }
                    Spacer(Modifier.width(10.dp))
                }
            }
        }
    }
}

/** „Primește episoade de pe telefon”: arată adresa și codul, apoi așteaptă telefonul. */
@Composable
private fun StudioReceiver(vm: MainViewModel) {
    var open by remember { mutableStateOf(false) }
    val pack = vm.studio
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            if (pack.episodes.isEmpty()) "Pe telefon, în KidToon: 🔒 Părinți → Studio. Faci povești și personaje, apoi „Trimite pe TV”."
            else "Pe TV sunt ${pack.episodes.size} episoade din Studio: " + pack.episodes.joinToString(", ") { it.title },
            color = KidColors.TextDim, fontSize = 15.sp,
        )
        Row {
            ActionButton(if (open) "Închide primirea" else "Primește episoade de pe telefon", primary = !open) { open = !open }
            if (pack.episodes.isNotEmpty() || pack.people.isNotEmpty()) {
                Spacer(Modifier.width(10.dp))
                ActionButton("Șterge episoadele primite") { vm.clearStudio() }
            }
        }
        if (open) {
            val code = remember { GhiStudio.newCode() }
            var status by remember { mutableStateOf("Pornesc…") }
            val address = remember { StudioServer.localAddress() }
            val server = remember {
                StudioServer(code, onReceived = { text, p -> vm.receiveStudio(text, p) }, onStatus = { status = it })
            }
            DisposableEffect(server) {
                val t = Thread({ server.run() }, "ghi-studio").apply { isDaemon = true; start() }
                onDispose {
                    server.stop()
                    t.interrupt()
                }
            }
            Column(
                Modifier.fillMaxWidth().background(KidColors.Card, RoundedCornerShape(16.dp)).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (address == null) {
                    Text("TV-ul nu e conectat la rețeaua de acasă (Wi-Fi sau cablu).", color = KidColors.Live, fontSize = 18.sp)
                } else {
                    Text("Scrie pe telefon:", color = KidColors.TextDim, fontSize = 16.sp)
                    Text("Adresa:  $address", color = KidColors.Text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                    Text("Codul:  $code", color = KidColors.Text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
                }
                Text(status, color = KidColors.TextDim, fontSize = 16.sp)
            }
        }
    }
}

/** Posturile ascunse de părinte: o listă cu toate posturile, fiecare cu Ascuns / Vizibil. */
@Composable
private fun HiddenChannels(state: UiState, vm: MainViewModel) {
    var open by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ActionButton(
            (if (open) "Închide lista" else "Ascunde posturi anume") +
                (if (state.hiddenChannels.isNotEmpty()) " (${state.hiddenChannels.size} ascunse)" else ""),
        ) { open = !open }
        if (open) {
            val list = if (state.kidsOnly) state.allChannels.filter { KidFilter.isForKids(it) } else state.allChannels
            if (list.isEmpty()) Text("Nu sunt posturi încărcate.", color = KidColors.TextDim, fontSize = 15.sp)
            list.take(300).forEach { ch ->
                val hidden = ch.key in state.hiddenChannels
                Row(
                    Modifier.fillMaxWidth().background(KidColors.Card, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(ch.name, color = if (hidden) KidColors.TextDim else KidColors.Text, fontSize = 16.sp, modifier = Modifier.weight(1f))
                    ActionButton(if (hidden) "Ascuns" else "Vizibil", primary = !hidden) { vm.toggleHidden(ch) }
                }
            }
        }
    }
}

/** PIN-ul de 4 cifre; fără PIN, poarta pune o înmulțire. */
@Composable
private fun PinSettings(state: UiState, vm: MainViewModel) {
    var pin by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            if (state.parentPin.isEmpty()) "Acum: la 🔒 Părinți apare o înmulțire. Poți pune un PIN de 4 cifre în loc."
            else "Acum: setările cer PIN-ul de 4 cifre.",
            color = KidColors.TextDim, fontSize = 15.sp,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.width(200.dp).height(48.dp)
                    .background(KidColors.Card, RoundedCornerShape(12.dp))
                    .border(2.dp, if (focused) KidColors.Accent else Color.Transparent, RoundedCornerShape(12.dp))
                    .padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (pin.isEmpty()) Text("4 cifre", color = KidColors.TextDim, fontSize = 16.sp)
                BasicTextField(
                    value = pin,
                    onValueChange = { v -> pin = v.filter { it.isDigit() }.take(4) },
                    singleLine = true,
                    textStyle = TextStyle(color = KidColors.Text, fontSize = 18.sp),
                    cursorBrush = SolidColor(KidColors.Accent),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
                    modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                )
            }
            Spacer(Modifier.width(10.dp))
            ActionButton("Pune PIN-ul", primary = true, enabled = ParentPin.isValid(pin)) { vm.setParentPin(pin); pin = "" }
            if (state.parentPin.isNotEmpty()) {
                Spacer(Modifier.width(10.dp))
                ActionButton("Scoate PIN-ul") { vm.setParentPin("") }
            }
        }
    }
}

private fun nameFromUrl(url: String): String =
    runCatching { java.net.URI(url).host?.removePrefix("www.") }.getOrNull() ?: url

@Composable
private fun Section(title: String) {
    Text(title, color = KidColors.Accent, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 18.dp))
}

@Composable
private fun ActionButton(text: String, primary: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.height(48.dp),
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(12.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = if (primary) KidColors.AccentSoft else KidColors.Card,
            contentColor = KidColors.Text,
            focusedContainerColor = KidColors.Accent,
            focusedContentColor = KidColors.Text,
            disabledContainerColor = KidColors.Panel,
            disabledContentColor = KidColors.TextDim,
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.03f),
    ) {
        Box(Modifier.padding(horizontal = 22.dp).height(48.dp), contentAlignment = Alignment.CenterStart) {
            Text(text, fontSize = 16.sp)
        }
    }
}

@Composable
private fun ToggleRow(title: String, subtitle: String, enabled: Boolean, onToggle: (() -> Unit)?, onDelete: (() -> Unit)?) {
    Row(
        Modifier.fillMaxWidth().background(KidColors.Card, RoundedCornerShape(14.dp)).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = KidColors.Text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = KidColors.TextDim, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (onToggle != null) {
            ActionButton(if (enabled) "Activă" else "Oprită", primary = enabled, onClick = onToggle)
            Spacer(Modifier.width(10.dp))
        }
        if (onDelete != null) ActionButton("Șterge", onClick = onDelete)
    }
}

@Composable
private fun AddField(label: String, placeholder: String, onAdd: (String) -> Unit) {
    var text by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    val submit = {
        val t = text.trim()
        if (t.startsWith("http://") || t.startsWith("https://")) { onAdd(t); text = "" }
    }
    Column {
        Text(label, color = KidColors.TextDim, fontSize = 15.sp)
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.weight(1f).height(48.dp)
                    .background(KidColors.Card, RoundedCornerShape(12.dp))
                    .border(2.dp, if (focused) KidColors.Accent else Color.Transparent, RoundedCornerShape(12.dp))
                    .padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (text.isEmpty()) Text(placeholder, color = KidColors.TextDim, fontSize = 16.sp)
                BasicTextField(
                    value = text,
                    onValueChange = { text = it },
                    singleLine = true,
                    textStyle = TextStyle(color = KidColors.Text, fontSize = 16.sp),
                    cursorBrush = SolidColor(KidColors.Accent),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { submit() }),
                    modifier = Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                )
            }
            Spacer(Modifier.width(10.dp))
            ActionButton("Adaugă", primary = true) { submit() }
        }
    }
}
