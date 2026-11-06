package ro.kidtoon.tv.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import ro.kidtoon.tv.data.Categories
import ro.kidtoon.tv.data.Channel
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.GhiCharacter
import ro.kidtoon.tv.data.buildTemplates

/** Secțiunile din meniul lateral: copilul e în prim plan, radioul și setările sunt la final. */
enum class Section(val emoji: String, val label: String) {
    HOME("🏠", "Acasă"),
    STORIES("🎬", "Povești"),
    TOUCH("👆", "Atinge și învață"),
    ATELIER("🎨", "Atelier"),
    TV("📺", "Desene TV"),
}

/** Ce poate deschide copilul din meniu. */
class HomeActions(
    val onStory: (Int) -> Unit,
    val onTouch: (Int) -> Unit,
    val onColoring: (Int) -> Unit,
    val onDrawing: () -> Unit,
    val onBuilder: (Int) -> Unit,
    val onGallery: () -> Unit,
    val onEditCharacter: () -> Unit,
    val onPlay: (List<Channel>, Int) -> Unit,
    val onToggleFavorite: (Channel) -> Unit,
    val onSelectCategory: (String) -> Unit,
    val onResume: () -> Unit,
    val onOpenRadio: () -> Unit,
    val onOpenParents: () -> Unit,
)

private val tileColors = listOf(KidColors.Purple, KidColors.Pink, KidColors.Orange, KidColors.Green, KidColors.Blue, KidColors.Teal, KidColors.Red, KidColors.Yellow)

@Composable
fun HomeScreen(
    state: UiState,
    section: Section,
    onSection: (Section) -> Unit,
    book: GhiBook?,
    character: GhiCharacter,
    lastChannel: Channel?,
    actions: HomeActions,
) {
    val contentFocus = remember { FocusRequester() }
    var drawerOpen by remember { mutableStateOf(false) }
    // Ca în androidtv: îngust (doar iconițele) și se lărgește doar cât e ales cu telecomanda.
    val drawerWidth by animateDpAsState(if (drawerOpen) 280.dp else 76.dp, label = "drawer")

    // După ce alegi o secțiune, focusul trece pe conținut și meniul se strânge.
    // Grila își compune plăcile abia la măsurare, deci mai încercăm câteva cadre.
    LaunchedEffect(section, state.loading) {
        repeat(20) {
            withFrameNanos { }
            if (runCatching { contentFocus.requestFocus() }.isSuccess) {
                delay(60)
                return@LaunchedEffect
            }
        }
    }

    Row(Modifier.fillMaxSize()) {
        // ---------------- Meniul lateral ----------------
        Column(
            Modifier.width(drawerWidth).fillMaxHeight().background(KidColors.Panel)
                .onFocusChanged { if (!it.hasFocus) drawerOpen = false }
                .padding(vertical = 20.dp, horizontal = 10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(Modifier.padding(start = 10.dp, bottom = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("🧸", fontSize = 34.sp)
                if (drawerOpen) {
                    Spacer(Modifier.width(12.dp))
                    Text("KidToon", color = KidColors.Sun, fontSize = 26.sp, fontWeight = FontWeight.Black)
                }
            }
            Section.entries.forEach { s ->
                DrawerItem(
                    s.emoji, if (s == Section.STORIES) "Povești cu ${character.name}" else s.label, s == section, drawerOpen,
                    onClick = { drawerOpen = false; onSection(s) }, onFocused = { drawerOpen = true },
                )
            }
            Spacer(Modifier.weight(1f))
            DrawerItem("🎵", "Radio cu animații", false, drawerOpen, actions.onOpenRadio, onFocused = { drawerOpen = true })
            DrawerItem("🔒", "Părinți", false, drawerOpen, actions.onOpenParents, onFocused = { drawerOpen = true })
        }

        // ---------------- Conținutul ----------------
        Box(Modifier.weight(1f).fillMaxHeight().padding(start = 32.dp, end = 32.dp, top = 24.dp)) {
            when (section) {
                Section.HOME -> HomeSection(state, book, character, contentFocus, actions, onSection)
                Section.STORIES -> StoriesSection(state, book, character, contentFocus, actions)
                Section.TOUCH -> TouchSection(book, contentFocus, actions)
                Section.ATELIER -> AtelierSection(contentFocus, actions)
                Section.TV -> TvSection(state, lastChannel, contentFocus, actions)
            }
        }
    }
}

@Composable
private fun Grid(content: LazyGridScope.() -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(4),
        contentPadding = PaddingValues(top = 8.dp, bottom = 40.dp, start = 8.dp, end = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(22.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
        content = content,
    )
}

private fun LazyGridScope.header(text: String, sub: String? = null) {
    item(span = { GridItemSpan(maxLineSpan) }) {
        Column {
            Text(text, color = KidColors.Text, fontSize = 32.sp, fontWeight = FontWeight.Black)
            if (sub != null) Text(sub, color = KidColors.TextDim, fontSize = 16.sp)
        }
    }
}

@Composable
private fun HomeSection(
    state: UiState, book: GhiBook?, c: GhiCharacter, focus: FocusRequester, a: HomeActions, onSection: (Section) -> Unit,
) {
    val ep = book?.episodes?.takeIf { it.isNotEmpty() }?.let { state.ghiEpisode.coerceIn(0, it.size - 1) }
    class T(val color: Color, val emoji: String, val title: String, val sub: String?, val go: () -> Unit)
    val tiles = buildList {
        if (ep != null) add(T(KidColors.Pink, "▶️", "Continuă povestea", book!!.episodes[ep].title) { a.onStory(ep) })
        add(T(KidColors.Purple, "🎬", "Povești cu ${c.name}", null) { onSection(Section.STORIES) })
        add(T(KidColors.Orange, "👆", "Atinge și învață", null) { onSection(Section.TOUCH) })
        add(T(KidColors.Green, "🖍️", "Colorează", null) { onSection(Section.ATELIER) })
        add(T(KidColors.Yellow, "✏️", "Desenează", null) { a.onDrawing() })
        add(T(KidColors.Red, "🧱", "Construiește", null) { a.onBuilder(0) })
        add(T(KidColors.Blue, "📺", "Desene TV", null) { onSection(Section.TV) })
        add(T(KidColors.Teal, "🎵", "Radio cu animații", null) { a.onOpenRadio() })
    }
    Grid {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Row(
                Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(28.dp)).background(Color(0xFFD7F5FF)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CharacterPreview(c, Modifier.width(300.dp).fillMaxHeight())
                Column(Modifier.weight(1f).padding(start = 12.dp, end = 24.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("Bună! Eu sunt ${c.name}!", color = Color(0xFF3A2A7A), fontSize = 40.sp, fontWeight = FontWeight.Black)
                    Text("Ce facem azi?", color = Color(0xFF3A2A7A), fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    KidButton("✏️ Prietenul meu", onClick = a.onEditCharacter, color = KidColors.Purple)
                }
                Text(formatTime(state.now), color = Color(0xFF3A2A7A), fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(24.dp).align(Alignment.Top))
            }
        }
        itemsIndexed(tiles) { i, t ->
            KidTile(t.color, t.emoji, t.title, t.go, subtitle = t.sub, modifier = if (i == 0) Modifier.focusRequester(focus) else Modifier)
        }
    }
}

@Composable
private fun StoriesSection(state: UiState, book: GhiBook?, c: GhiCharacter, focus: FocusRequester, a: HomeActions) {
    val eps = book?.episodes.orEmpty()
    if (eps.isEmpty()) { Empty("Poveștile nu s-au putut încărca.", focus); return }
    Grid {
        header("🎬 Povești cu ${c.name}", "OK pornește povestea. În poveste: ◀ ▶ altă poveste, OK răspunde la întrebări.")
        itemsIndexed(eps) { i, ep ->
            KidTile(
                tileColors[i % tileColors.size], if (i == state.ghiEpisode) "▶️" else "🎬", ep.title, { a.onStory(i) },
                subtitle = "Episodul ${i + 1}", selected = i == state.ghiEpisode,
                modifier = if (i == 0) Modifier.focusRequester(focus) else Modifier,
            )
        }
    }
}

@Composable
private fun TouchSection(book: GhiBook?, focus: FocusRequester, a: HomeActions) {
    val scenes = book?.touch.orEmpty()
    if (scenes.isEmpty()) { Empty("Scenele nu s-au putut încărca.", focus); return }
    Grid {
        header("👆 Atinge și învață", "Alegi cu săgețile, OK atinge, iar prietenul tău spune ce este.")
        itemsIndexed(scenes) { i, sc ->
            KidTile(
                tileColors[(i + 2) % tileColors.size], sc.items.firstOrNull()?.emoji ?: "👆", sc.title, { a.onTouch(i) },
                subtitle = sc.items.take(4).joinToString(" ") { it.emoji },
                modifier = if (i == 0) Modifier.focusRequester(focus) else Modifier,
            )
        }
    }
}

@Composable
private fun AtelierSection(focus: FocusRequester, a: HomeActions) {
    Grid {
        header("🎨 Atelier", "Colorează, desenează și construiește cu telecomanda. Ce salvezi ajunge în Galerie.")
        item { KidTile(KidColors.Yellow, "✏️", "Desenează", a.onDrawing, modifier = Modifier.focusRequester(focus)) }
        item { KidTile(KidColors.Teal, "🖼️", "Galeria mea", a.onGallery) }
        header("🖍️ Colorează")
        itemsIndexed(coloringPages) { i, p ->
            Surface(
                onClick = { a.onColoring(i) },
                modifier = Modifier.fillMaxWidth().height(170.dp),
                shape = ClickableSurfaceDefaults.shape(CardShape),
                colors = ClickableSurfaceDefaults.colors(containerColor = Color.White, focusedContainerColor = Color.White),
                border = focusBorder(),
                scale = ClickableSurfaceDefaults.scale(focusedScale = 1.07f),
            ) {
                Box(Modifier.fillMaxSize()) {
                    ColoringThumb(p, Modifier.fillMaxSize().padding(10.dp))
                    Text(
                        "${p.emoji} ${p.title}", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Black,
                        modifier = Modifier.align(Alignment.BottomStart).padding(8.dp)
                            .background(Color(0xAA2E2370), RoundedCornerShape(10.dp)).padding(horizontal = 10.dp, vertical = 4.dp),
                    )
                }
            }
        }
        header("🧱 Construiește", "Pornește de la o idee sau de la o foaie goală.")
        itemsIndexed(buildTemplates) { i, t ->
            KidTile(tileColors[(i + 4) % tileColors.size], t.emoji, t.title, { a.onBuilder(i) })
        }
    }
}

private fun categoryEmoji(c: String) = when (c) {
    Categories.ALL -> "🌈"
    Categories.FAVORITES -> "⭐"
    Categories.RECENT -> "🕒"
    "Copii" -> "🧸"
    "Educație" -> "📚"
    "Familie" -> "👨‍👩‍👧"
    else -> "📺"
}

@Composable
private fun TvSection(state: UiState, lastChannel: Channel?, focus: FocusRequester, a: HomeActions) {
    val channels = state.visibleChannels
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text("📺 Desene TV", color = KidColors.Text, fontSize = 32.sp, fontWeight = FontWeight.Black)
            Spacer(Modifier.width(14.dp))
            Text("${channels.size} posturi", color = KidColors.TextDim, fontSize = 16.sp)
            Spacer(Modifier.weight(1f))
            Text(
                when {
                    state.loading -> "Se încarcă desenele…"
                    state.epgLoading -> "Se încarcă ghidul TV…"
                    else -> ""
                },
                color = KidColors.TextDim, fontSize = 14.sp,
            )
        }
        Spacer(Modifier.height(10.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(vertical = 6.dp, horizontal = 4.dp)) {
            if (lastChannel != null) item { KidButton("▶️ Continuă: ${lastChannel.name}", onClick = a.onResume, color = KidColors.Pink) }
            itemsIndexed(state.categories) { _, cat ->
                val sel = cat == state.selectedCategory
                KidButton((if (sel) "✓ " else "") + "${categoryEmoji(cat)} $cat", onClick = { a.onSelectCategory(cat) }, primary = sel)
            }
        }
        Spacer(Modifier.height(8.dp))
        when {
            state.loading && state.channels.isEmpty() -> Empty("Se încarcă desenele…", focus)
            channels.isEmpty() -> Empty(
                when (state.selectedCategory) {
                    Categories.FAVORITES -> "Nu ai desene preferate încă.\nȚine apăsat OK pe un post ca să-l pui la ⭐."
                    Categories.RECENT -> "Nu te-ai uitat încă la niciun post."
                    else -> "Nu sunt desene încă.\nRoagă un părinte să adauge posturi din 🔒 Părinți."
                },
                focus,
            )
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                contentPadding = PaddingValues(top = 8.dp, bottom = 32.dp, start = 4.dp, end = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                itemsIndexed(channels, key = { _, c -> c.key }) { index, ch ->
                    ChannelCard(
                        channel = ch,
                        number = state.numberOf(ch),
                        state = state,
                        onClick = { a.onPlay(channels, index) },
                        onLongClick = { a.onToggleFavorite(ch) },
                        modifier = if (index == 0) Modifier.focusRequester(focus) else Modifier,
                    )
                }
            }
        }
    }
}

/** Un mesaj pe ecran gol; are și un buton, ca focusul să nu se piardă. */
@Composable
private fun Empty(text: String, focus: FocusRequester) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("🧸", fontSize = 72.sp)
            Text(text, color = KidColors.TextDim, fontSize = 22.sp, lineHeight = 32.sp)
            Box(Modifier.size(1.dp).focusRequester(focus).focusable())
        }
    }
}

@Composable
private fun DrawerItem(
    emoji: String,
    label: String,
    selected: Boolean,
    expanded: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onFocused: () -> Unit = {},
) {
    Surface(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().height(56.dp).onFocusChanged { if (it.isFocused) onFocused() },
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(18.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = if (selected) KidColors.AccentSoft else KidColors.Panel,
            contentColor = if (selected) KidColors.Text else KidColors.TextDim,
            focusedContainerColor = KidColors.Accent,
            focusedContentColor = KidColors.Text,
        ),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.04f),
    ) {
        Row(Modifier.fillMaxSize().padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(36.dp), contentAlignment = Alignment.Center) { Text(emoji, fontSize = 26.sp) }
            if (expanded) {
                Spacer(Modifier.width(14.dp))
                Text(label, fontSize = 19.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
fun ChannelCard(
    channel: Channel,
    number: Int,
    state: UiState,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val (now, _) = state.epg.nowAndNext(channel, state.now)
    val isFav = channel.key in state.favorites
    val color = tileColors[channel.name.length % 4]
    Surface(
        onClick = onClick,
        onLongClick = onLongClick,
        modifier = modifier.fillMaxWidth().height(190.dp),
        shape = ClickableSurfaceDefaults.shape(CardShape),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = color,
            focusedContainerColor = color,
            contentColor = KidColors.Text,
            focusedContentColor = KidColors.Text,
        ),
        border = focusBorder(),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.07f),
    ) {
        Column(Modifier.fillMaxSize().padding(10.dp)) {
            Box(Modifier.fillMaxWidth().height(110.dp).clip(RoundedCornerShape(16.dp)).background(Color(0x33FFFFFF))) {
                if (channel.logo != null) {
                    AsyncImage(
                        model = channel.logo,
                        contentDescription = channel.name,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 12.dp),
                    )
                } else {
                    Text(
                        channel.name.take(2).uppercase(),
                        fontSize = 36.sp, fontWeight = FontWeight.Black,
                        modifier = Modifier.align(Alignment.Center),
                    )
                }
                Text("$number", fontSize = 13.sp, color = Color(0xCCFFFFFF), modifier = Modifier.align(Alignment.TopStart).padding(8.dp))
                if (isFav) Icon(
                    Icons.Filled.Star, contentDescription = "Preferat", tint = KidColors.Sun,
                    modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(24.dp),
                )
            }
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).clip(CircleShape).background(KidColors.Live))
                Spacer(Modifier.width(6.dp))
                Text(channel.name, fontSize = 18.sp, fontWeight = FontWeight.Black, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(
                now?.title ?: channel.categories.firstOrNull() ?: "În direct",
                fontSize = 13.sp, color = Color(0xE6FFFFFF), maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            if (now != null) {
                Spacer(Modifier.height(4.dp))
                ProgressBar(now.progress(state.now))
            }
        }
    }
}

@Composable
fun ProgressBar(fraction: Float, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(5.dp).clip(RoundedCornerShape(3.dp)).background(Color(0x33FFFFFF))) {
        Box(Modifier.fillMaxWidth(fraction).fillMaxHeight().background(Color.White))
    }
}
