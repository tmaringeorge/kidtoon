package ro.kidtoon.tv.ui

import android.content.ComponentName
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.produceState
import androidx.compose.runtime.withFrameMillis
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import android.speech.tts.TextToSpeech
import java.util.Locale
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.GhiTouchLayout
import ro.kidtoon.tv.data.KidContent
import ro.kidtoon.tv.data.ScreenCare
import ro.kidtoon.tv.data.NowPlaying
import ro.kidtoon.tv.data.RadioFrequencies
import ro.kidtoon.tv.data.RadioMode
import ro.kidtoon.tv.data.RadioSort
import ro.kidtoon.tv.data.RadioStation
import ro.kidtoon.tv.playback.RadioService

@Composable
fun RadioScreen(
    state: UiState,
    onLoad: () -> Unit,
    onRetry: () -> Unit,
    onPlay: (List<RadioStation>, Int) -> Unit,
    onToggleFavorite: (RadioStation) -> Unit,
    onSort: (RadioSort) -> Unit,
) {
    var favoritesOnly by remember { mutableStateOf(false) }
    val firstFocus = remember { FocusRequester() }
    val stations = state.radioSort.apply(
        if (favoritesOnly) state.radioStations.filter { it.id in state.radioFavorites } else state.radioStations
    )

    LaunchedEffect(Unit) { onLoad() }

    Column(Modifier.fillMaxSize().padding(horizontal = 48.dp, vertical = 28.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Radio", color = KidColors.Text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(14.dp))
            Text("${stations.size} posturi", color = KidColors.TextDim, fontSize = 16.sp)
            Spacer(Modifier.weight(1f))
            FilterChip("Toate", !favoritesOnly, Modifier.focusRequester(firstFocus)) { favoritesOnly = false }
            Spacer(Modifier.width(10.dp))
            FilterChip("Favorite", favoritesOnly) { favoritesOnly = true }
            Spacer(Modifier.width(24.dp))
            RadioSort.entries.forEach { sort ->
                FilterChip(sort.label, state.radioSort == sort) { onSort(sort) }
                Spacer(Modifier.width(10.dp))
            }
        }
        Spacer(Modifier.height(18.dp))

        when {
            state.radioLoading && state.radioStations.isEmpty() -> CenterText("Se încarcă posturile de radio…")
            state.radioError != null && state.radioStations.isEmpty() -> Column(
                Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(state.radioError, color = KidColors.TextDim, fontSize = 18.sp)
                Spacer(Modifier.height(14.dp))
                FilterChip("Încearcă din nou", true, onClick = onRetry)
            }
            stations.isEmpty() -> CenterText(
                if (favoritesOnly) "Nu ai radiouri favorite.\nȚine apăsat OK pe un post ca să-l adaugi." else "Nu am găsit posturi."
            )
            else -> LazyVerticalGrid(
                columns = GridCells.Fixed(5),
                contentPadding = PaddingValues(4.dp, 8.dp, 4.dp, 32.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                itemsIndexed(stations, key = { _, s -> s.id }) { i, st ->
                    RadioCard(
                        station = st,
                        favorite = st.id in state.radioFavorites,
                        onClick = { onPlay(stations, i) },
                        onLongClick = { onToggleFavorite(st) },
                    )
                }
            }
        }
    }
    LaunchedEffect(Unit) { runCatching { firstFocus.requestFocus() } }
}

@Composable
private fun CenterText(text: String) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(text, color = KidColors.TextDim, fontSize = 20.sp, lineHeight = 30.sp)
    }
}

@Composable
private fun FilterChip(label: String, selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = modifier.height(44.dp),
        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(22.dp)),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = if (selected) KidColors.AccentSoft else KidColors.Card,
            contentColor = if (selected) KidColors.Accent else KidColors.Text,
            focusedContainerColor = KidColors.Accent,
            focusedContentColor = KidColors.Text,
        ),
    ) {
        Box(Modifier.padding(horizontal = 20.dp).height(44.dp), contentAlignment = Alignment.Center) {
            Text(label, fontSize = 16.sp)
        }
    }
}

@Composable
private fun StationLogo(station: RadioStation, modifier: Modifier) {
    Box(modifier.background(KidColors.LogoBox), contentAlignment = Alignment.Center) {
        Text(station.name.take(2).uppercase(), fontSize = 28.sp, fontWeight = FontWeight.Black, color = KidColors.TextDim)
        if (station.logo != null) AsyncImage(
            model = station.logo, contentDescription = null, contentScale = ContentScale.Fit,
            modifier = Modifier.fillMaxSize().padding(14.dp),
        )
    }
}

@Composable
private fun RadioCard(station: RadioStation, favorite: Boolean, onClick: () -> Unit, onLongClick: () -> Unit) {
    Surface(
        onClick = onClick,
        onLongClick = onLongClick,
        modifier = Modifier.fillMaxWidth().height(160.dp),
        shape = ClickableSurfaceDefaults.shape(CardShape),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = KidColors.Card, focusedContainerColor = KidColors.CardFocused,
            contentColor = KidColors.Text, focusedContentColor = KidColors.Text,
        ),
        border = focusBorder(),
        scale = ClickableSurfaceDefaults.scale(focusedScale = 1.06f),
    ) {
        Column(Modifier.fillMaxSize()) {
            Box {
                StationLogo(station, Modifier.fillMaxWidth().height(96.dp))
                if (favorite) Icon(
                    Icons.Filled.Star, contentDescription = "Favorit", tint = KidColors.Accent,
                    modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(20.dp),
                )
            }
            Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                Text(station.name, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(
                    listOfNotNull(
                        RadioFrequencies.bucharest(station.name)?.let(RadioFrequencies::label),
                        station.tagList.joinToString(" · ").ifBlank { null },
                    ).joinToString(" · ").ifBlank { "Radio" },
                    fontSize = 12.sp, color = KidColors.TextDim, maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
fun RadioPlayerScreen(
    initialList: List<RadioStation>,
    initialIndex: Int,
    state: UiState,
    onToggleFavorite: (RadioStation) -> Unit,
    onNextBackground: () -> Unit,
    onPreviousBackground: () -> Unit,
    onToggleMode: () -> Unit,
    ghiBook: GhiBook?,
    onCycleContent: () -> Unit,
    onNextTouch: () -> Unit,
    onPreviousTouch: () -> Unit,
    onNextGhi: () -> Unit,
    onPreviousGhi: () -> Unit,
    onExit: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val list = initialList
    var index by remember { mutableIntStateOf(initialIndex.coerceIn(0, (list.size - 1).coerceAtLeast(0))) }
    val station = list.getOrNull(index) ?: run { onExit(); return }

    var infoVisible by remember { mutableStateOf(true) }
    var infoNonce by remember { mutableIntStateOf(0) }
    var buffering by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    // Ce canta acum (melodia sau emisiunea), daca postul trimite asta in stream.
    var nowPlaying by remember { mutableStateOf<String?>(null) }
    val stationName by rememberUpdatedState(station.name)
    val focus = remember { FocusRequester() }

    // Radioul ruleaza in RadioService, ca sa mearga si in fundal; aici doar il controlam.
    var player by remember { mutableStateOf<MediaController?>(null) }
    DisposableEffect(Unit) {
        val token = SessionToken(context, ComponentName(context, RadioService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener({ player = runCatching { future.get() }.getOrNull() }, ContextCompat.getMainExecutor(context))
        onDispose {
            // Iesirea din ecranul radio (inapoi) opreste radioul; Home il lasa sa cante.
            player?.run { stop(); clearMediaItems() }
            MediaController.releaseFuture(future)
        }
    }
    DisposableEffect(player) {
        val p = player ?: return@DisposableEffect onDispose { }
        view.keepScreenOn = true
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                buffering = playbackState == Player.STATE_BUFFERING
                if (playbackState == Player.STATE_READY) error = null
            }
            override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
                val title = NowPlaying.clean(mediaMetadata.title?.toString(), stationName)
                if (title != nowPlaying) {
                    nowPlaying = title
                    if (title != null) { infoVisible = true; infoNonce++ }
                }
            }
            override fun onPlayerError(e: PlaybackException) {
                buffering = false
                error = "Postul nu răspunde acum. Încearcă altul cu ▲ ▼."
            }
        }
        p.addListener(listener)
        onDispose {
            view.keepScreenOn = false
            p.removeListener(listener)
        }
    }

    LaunchedEffect(station.id, player) {
        val p = player ?: return@LaunchedEffect
        error = null
        buffering = true
        nowPlaying = null
        val hls = station.streamUrl.contains(".m3u8", true) || station.codec.contains("HLS", true)
        val uri = Uri.parse(station.streamUrl)
        val item = MediaItem.Builder()
            .setMediaId(station.id)
            .setUri(uri)
            .setRequestMetadata(
                MediaItem.RequestMetadata.Builder()
                    .setMediaUri(uri)
                    .setExtras(Bundle().apply { if (hls) putString(RadioService.KEY_MIME, MimeTypes.APPLICATION_M3U8) })
                    .build()
            )
            .setMediaMetadata(
                // Fara titlu fix: titlul vine din stream (ICY StreamTitle), cu melodia sau emisiunea.
                MediaMetadata.Builder()
                    .setArtist(station.name)
                    .setStation(station.name)
                    .setArtworkUri(station.logo?.let(Uri::parse))
                    .build()
            )
            .build()
        p.setMediaItem(item)
        p.prepare()
        p.play()
        infoVisible = true
        infoNonce++
    }
    LaunchedEffect(infoNonce, infoVisible) { if (infoVisible) { delay(7000); infoVisible = false } }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    // Temporizator de somn: opreste radioul dupa 30/60/90 de minute.
    var sleepEndsAt by remember { mutableLongStateOf(0L) }
    var sleepLeftMin by remember { mutableIntStateOf(0) }
    LaunchedEffect(sleepEndsAt) {
        if (sleepEndsAt == 0L) { sleepLeftMin = 0; return@LaunchedEffect }
        while (true) {
            val left = sleepEndsAt - SystemClock.elapsedRealtime()
            if (left <= 0) {
                player?.pause()
                sleepEndsAt = 0L
                break
            }
            sleepLeftMin = ((left + 59_999) / 60_000).toInt()
            delay(minOf(left, 20_000L))
        }
    }
    fun cycleSleep() {
        val next = SleepTimer.next(sleepLeftMin)
        sleepEndsAt = if (next == 0) 0L else SystemClock.elapsedRealtime() + next * 60_000L
        sleepLeftMin = next
        infoVisible = true
        infoNonce++
    }

    val kid = state.radioMode == RadioMode.KID
    // Ce vede copilul: animatii, episoade cu GHI sau „Atinge si invata”.
    val content = if (kid && ghiBook != null) state.kidContent else KidContent.ANIMATIONS
    val ghi = content == KidContent.GHI && ghiBook!!.episodes.isNotEmpty()
    val touch = content == KidContent.TOUCH && ghiBook!!.touch.isNotEmpty()
    val touchScene = if (touch) ghiBook!!.touch[state.touchScene.coerceIn(0, ghiBook.touch.size - 1)] else null
    var touchFocus by remember { mutableIntStateOf(0) }
    var tapped by remember { mutableIntStateOf(-1) }
    var tappedAt by remember { mutableLongStateOf(0L) }
    LaunchedEffect(touchScene?.id) { touchFocus = 0; tapped = -1 }

    // Ecran sanatos: timpul petrecut in modul Copil, pauza de clipit, odihna dupa limita.
    var activeMs by remember { mutableLongStateOf(0L) }
    var episodesInRow by remember { mutableIntStateOf(0) }
    val care = if (kid) ScreenCare.state(activeMs, state.sessionLimit, episodesInRow) else ScreenCare.State.Play
    val resting = care == ScreenCare.State.Rest
    LaunchedEffect(kid, resting) {
        if (!kid || resting) return@LaunchedEffect
        var last = withFrameMillis { it }
        while (true) withFrameMillis { now -> activeMs += now - last; last = now }
    }
    fun unlock() { activeMs = 0L; episodesInRow = 0 }
    var okDownAt by remember { mutableLongStateOf(0L) }
    var evening by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        while (true) {
            val c = java.util.Calendar.getInstance()
            evening = ScreenCare.eveningDim(c.get(java.util.Calendar.HOUR_OF_DAY), c.get(java.util.Calendar.MINUTE))
            delay(60_000)
        }
    }

    // Vocea care spune ce a atins copilul (vocea romaneasca a sistemului).
    var tts by remember { mutableStateOf<TextToSpeech?>(null) }
    DisposableEffect(Unit) {
        var engine: TextToSpeech? = null
        engine = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                engine?.language = Locale("ro", "RO")
                engine?.setSpeechRate(0.85f)
                tts = engine
            }
        }
        onDispose { engine?.shutdown() }
    }
    val scope = rememberCoroutineScope()
    fun touchItem(i: Int) {
        val sc = touchScene ?: return
        tapped = i
        tappedAt = SystemClock.elapsedRealtime()
        touchFocus = i
        tts?.speak(sc.items[i].say, TextToSpeech.QUEUE_FLUSH, null, "ghi")
        // Radioul se aude mai incet cat vorbeste GHI.
        scope.launch { player?.volume = 0.25f; delay(2500); player?.volume = 1f }
    }

    // Vocea care povestește episoadele cu GHI.
    var duck by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    fun say(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "ghi-ep")
        duck?.cancel()
        duck = scope.launch { player?.volume = 0.25f; delay(1200L + text.length * 75L); player?.volume = 1f }
    }
    val quiz = remember { GhiQuiz() }

    fun zap(d: Int) { if (list.isNotEmpty()) index = (index + d + list.size) % list.size }
    var okLongPressed by remember { mutableStateOf(false) }

    Box(
        Modifier.fillMaxSize().background(Color.Black)
            .focusRequester(focus).focusable()
            .onPreviewKeyEvent { ev ->
                val center = ev.key == Key.DirectionCenter || ev.key == Key.Enter || ev.key == Key.NumPadEnter
                if (center && resting) {
                    // Parintele tine OK apasat 3 secunde ca sa continue dupa odihna.
                    if (ev.type == KeyEventType.KeyDown) {
                        val now = SystemClock.elapsedRealtime()
                        if (ev.nativeKeyEvent.repeatCount == 0) okDownAt = now
                        else if (now - okDownAt >= ScreenCare.UNLOCK_HOLD_MS) unlock()
                    }
                    return@onPreviewKeyEvent true
                }
                // La o întrebare din episod, OK alege obiectul încercuit.
                if (center && ghi && quiz.asking) {
                    if (ev.type == KeyEventType.KeyUp) quiz.pick()
                    return@onPreviewKeyEvent true
                }
                if (center && touch) {
                    if (ev.type == KeyEventType.KeyUp) touchItem(touchFocus)
                    return@onPreviewKeyEvent true
                }
                if (center) {
                    // Apasare scurta pe OK = info; tinut apasat = temporizator de somn.
                    if (ev.type == KeyEventType.KeyDown && ev.nativeKeyEvent.repeatCount > 0 && !okLongPressed) {
                        okLongPressed = true
                        cycleSleep()
                    } else if (ev.type == KeyEventType.KeyUp) {
                        if (!okLongPressed) { infoVisible = !infoVisible; infoNonce++ }
                        okLongPressed = false
                    }
                    return@onPreviewKeyEvent true
                }
                if (ev.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                // Butonul rosu de pe telecomanda (nu are constanta in Compose).
                if (ev.nativeKeyEvent.keyCode == android.view.KeyEvent.KEYCODE_PROG_RED) {
                    if (kid && !resting) onCycleContent()
                    infoVisible = true; infoNonce++
                    return@onPreviewKeyEvent true
                }
                // In „Atinge si invata” sagetile muta alegerea; la capete trec la alta scena.
                if (touch && !resting && touchScene != null) {
                    val n = touchScene.items.size
                    val moved = when (ev.key) {
                        Key.DirectionLeft -> { if (touchFocus == 0) onPreviousTouch() else touchFocus = GhiTouchLayout.move(touchFocus, n, -1, 0); true }
                        Key.DirectionRight -> { if (touchFocus == n - 1) onNextTouch() else touchFocus = GhiTouchLayout.move(touchFocus, n, 1, 0); true }
                        Key.DirectionUp -> { touchFocus = GhiTouchLayout.move(touchFocus, n, 0, -1); true }
                        Key.DirectionDown -> { touchFocus = GhiTouchLayout.move(touchFocus, n, 0, 1); true }
                        else -> false
                    }
                    if (moved) return@onPreviewKeyEvent true
                }
                // La o întrebare, ◀ ▶ mută cercul alb între obiecte.
                if (ghi && !resting && quiz.asking && (ev.key == Key.DirectionLeft || ev.key == Key.DirectionRight)) {
                    quiz.move(if (ev.key == Key.DirectionRight) 1 else -1)
                    return@onPreviewKeyEvent true
                }
                when (ev.key) {
                    Key.DirectionUp, Key.ChannelUp -> { zap(-1); true }
                    Key.DirectionDown, Key.ChannelDown -> { zap(1); true }
                    // Copil: ◀ ▶ schimba animatia. Adult: ▶ favorit.
                    // In episoadele cu GHI, ◀ ▶ trec la episodul anterior / urmator.
                    Key.DirectionRight -> {
                        if (resting) Unit else if (ghi) onNextGhi() else if (kid) onNextBackground() else onToggleFavorite(station)
                        infoVisible = true; infoNonce++; true
                    }
                    Key.DirectionLeft -> {
                        if (resting) Unit else if (ghi) onPreviousGhi() else if (kid) onPreviousBackground()
                        infoVisible = true; infoNonce++; true
                    }
                    // Butonul 🎬 GHI: tasta 0 sau butonul rosu de pe telecomanda.
                    Key.Zero, Key.NumPad0 -> {
                        if (kid && !resting) onCycleContent()
                        infoVisible = true; infoNonce++; true
                    }
                    Key.Menu, Key.Info -> { onToggleMode(); infoVisible = true; infoNonce++; true }
                    Key.MediaPlayPause, Key.MediaPause, Key.MediaPlay -> {
                        player?.let { if (it.isPlaying) it.pause() else it.play() }; true
                    }
                    else -> false
                }
            },
    ) {
        when {
            !kid -> AdultRadio(station, nowPlaying, buffering, error)
            resting -> GhiRest("Părinte: ține apăsat OK 3 secunde ca să continuați.")
            ghi -> GhiAnimation(
                ghiBook!!, state.ghiEpisode, onFinished = { episodesInRow++; onNextGhi() }, quiz = quiz, onSay = { say(it) },
            )
            touch -> GhiTouch(ghiBook!!, touchScene!!, touchFocus, tapped, tappedAt, onTap = { touchItem(it) })
            else -> KidsAnimation(state.radioBackground)
        }
        (care as? ScreenCare.State.Blink)?.let { GhiBlinkOverlay(it.ms) }
        // Seara, ecranul devine mai cald si mai intunecat.
        if (evening > 0f) Box(Modifier.fillMaxSize().background(Color(0xFF2A1400).copy(alpha = evening)))

        AnimatedVisibility(
            visible = infoVisible || (kid && error != null),
            enter = fadeIn(), exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Row(
                Modifier.fillMaxWidth()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xCC000000))))
                    .padding(start = 48.dp, end = 48.dp, top = 48.dp, bottom = 32.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StationLogo(station, Modifier.size(width = 120.dp, height = 80.dp).clip(RoundedCornerShape(12.dp)))
                Spacer(Modifier.width(20.dp))
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(station.name, color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold)
                        RadioFrequencies.bucharest(station.name)?.let {
                            Spacer(Modifier.width(12.dp))
                            Text(RadioFrequencies.label(it), color = Color(0xCCFFFFFF), fontSize = 18.sp)
                        }
                        if (station.id in state.radioFavorites) {
                            Spacer(Modifier.width(10.dp))
                            Icon(Icons.Filled.Star, contentDescription = null, tint = KidColors.Accent, modifier = Modifier.size(22.dp))
                        }
                    }
                    nowPlaying?.let {
                        Text(
                            "♪ $it", color = KidColors.Accent, fontSize = 18.sp, fontWeight = FontWeight.SemiBold,
                            maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Text(
                        (error ?: if (buffering) "Se conectează…" else station.tagList.joinToString(" · ").ifBlank { "În direct" }) +
                            (if (sleepLeftMin > 0) "   ·   se oprește în $sleepLeftMin min" else ""),
                        color = Color(0xDDFFFFFF), fontSize = 16.sp,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        (if (resting) "$ghiName se odihnește. Ține OK apăsat 3 secunde ca să continuați"
                        else if (ghi) "▲▼ alt post   ◀ ▶ alt episod (acum: ${ghiBook!!.episodes[state.ghiEpisode.coerceIn(0, ghiBook.episodes.size - 1)].title})   0 / roșu: ${content.next().label}"
                        else if (touch) "Săgețile aleg, OK atinge (scena: ${touchScene!!.title})   0 / roșu: ${content.next().label}"
                        else if (kid) "▲▼ alt post   ◀ ▶ animația (acum: ${state.radioBackground.label})" + (if (ghiBook != null) "   0 / roșu: ${content.next().label}" else "")
                        else "▲▼ alt post   ▶ favorit") +
                            "   Meniu: mod ${state.radioMode.toggled().label}   OK ascunde/arată   ține OK apăsat: " +
                            SleepTimer.hint(sleepLeftMin),
                        color = Color(0x99FFFFFF), fontSize = 12.sp,
                    )
                }
                if (kid && ghiBook != null) {
                    Spacer(Modifier.width(16.dp))
                    // Butonul cu film: arată că episoadele cu GHI pornesc cu 0 sau cu butonul roșu.
                    Column(
                        Modifier.clip(RoundedCornerShape(16.dp))
                            .background(if (ghi || touch) KidColors.Accent else Color(0x33FFFFFF))
                            .padding(horizontal = 18.dp, vertical = 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(if (touch) "👆" else "🎬", fontSize = 30.sp)
                        Text(if (touch) "Atinge" else ghiName, color = if (ghi || touch) Color.Black else Color.White, fontSize = 16.sp, fontWeight = FontWeight.Black)
                        Text("0 / roșu", color = if (ghi || touch) Color(0xAA000000) else Color(0x99FFFFFF), fontSize = 11.sp)
                    }
                }
            }
        }
    }
}

/** Modul Adult: ecran linistit, cu postul, frecventa si ce canta acum. */
@Composable
private fun AdultRadio(station: RadioStation, nowPlaying: String?, buffering: Boolean, error: String?) {
    val bars by produceState(0L) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { value = it - start }
    }
    Box(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFF141A2E), Color(0xFF0B0F1A)))),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            StationLogo(station, Modifier.size(width = 260.dp, height = 170.dp).clip(RoundedCornerShape(24.dp)))
            Spacer(Modifier.height(28.dp))
            Text(station.name, color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Bold)
            RadioFrequencies.bucharest(station.name)?.let {
                Text(RadioFrequencies.label(it), color = KidColors.TextDim, fontSize = 22.sp)
            }
            Spacer(Modifier.height(18.dp))
            Text(
                error ?: nowPlaying?.let { "♪ $it" } ?: if (buffering) "Se conectează…" else "În direct",
                color = if (nowPlaying != null && error == null) KidColors.Accent else KidColors.TextDim,
                fontSize = 26.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(28.dp))
            // Un egalizator discret, doar ca semn ca radioul merge.
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (i in 0 until 12) {
                    val v = if (buffering || error != null) 0.15f
                    else 0.25f + 0.75f * kotlin.math.abs(kotlin.math.sin(bars / 1000f * (1.3f + i * 0.37f) + i))
                    Box(Modifier.width(8.dp).height((40 * v).dp).clip(RoundedCornerShape(3.dp)).background(KidColors.Accent.copy(alpha = 0.8f)))
                }
            }
        }
    }
}
