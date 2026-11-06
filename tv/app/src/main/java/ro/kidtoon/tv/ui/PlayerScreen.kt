package ro.kidtoon.tv.ui

import android.view.ViewGroup
import androidx.activity.compose.BackHandler
import androidx.annotation.OptIn
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import coil.compose.AsyncImage
import kotlinx.coroutines.delay
import okhttp3.OkHttpClient
import ro.kidtoon.tv.data.Channel
import ro.kidtoon.tv.data.Repository

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(
    initialList: List<Channel>,
    initialIndex: Int,
    state: UiState,
    httpClient: OkHttpClient,
    onWatched: (Channel) -> Unit,
    onToggleFavorite: (Channel) -> Unit,
    onExit: () -> Unit,
) {
    val context = LocalContext.current
    var list by remember { mutableStateOf(initialList) }
    var index by remember { mutableIntStateOf(initialIndex.coerceIn(0, (initialList.size - 1).coerceAtLeast(0))) }
    val channel = list.getOrNull(index) ?: run { onExit(); return }

    var infoVisible by remember { mutableStateOf(true) }
    var infoNonce by remember { mutableIntStateOf(0) }
    var listOpen by remember { mutableStateOf(false) }
    var buffering by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var digits by remember { mutableStateOf("") }

    val rootFocus = remember { FocusRequester() }

    val player = remember {
        ExoPlayer.Builder(context).build().apply { playWhenReady = true }
    }
    DisposableEffect(player) {
        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                buffering = playbackState == Player.STATE_BUFFERING
                if (playbackState == Player.STATE_READY) error = null
            }
            override fun onPlayerError(e: PlaybackException) {
                buffering = false
                error = when (e.errorCode) {
                    PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                        "Postul nu este disponibil acum (poate fi restricționat geografic sau oprit temporar)."
                    PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
                    PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                        "Nu mă pot conecta la server. Verifică internetul."
                    else -> "Nu pot reda acest post (${e.errorCodeName})."
                }
            }
        }
        player.addListener(listener)
        onDispose {
            player.removeListener(listener)
            player.release()
        }
    }

    // Porneste postul curent ori de cate ori se schimba.
    LaunchedEffect(channel.key) {
        error = null
        buffering = true
        val dataSource = OkHttpDataSource.Factory(httpClient)
            .setUserAgent(channel.userAgent ?: Repository.USER_AGENT)
            .apply { channel.referrer?.let { setDefaultRequestProperties(mapOf("Referer" to it)) } }
        val item = MediaItem.Builder()
            .setUri(channel.url)
            .apply { if (channel.url.contains(".m3u8", ignoreCase = true)) setMimeType(MimeTypes.APPLICATION_M3U8) }
            .build()
        player.setMediaSource(DefaultMediaSourceFactory(dataSource).createMediaSource(item))
        player.prepare()
        player.play()
        onWatched(channel)
        infoVisible = true
        infoNonce++
    }

    // Ascunde bannerul de informatii dupa cateva secunde.
    LaunchedEffect(infoNonce, infoVisible) {
        if (infoVisible) { delay(6000); infoVisible = false }
    }

    // Selectare post dupa numar (tastele 0-9 de pe telecomanda).
    LaunchedEffect(digits) {
        if (digits.isNotEmpty()) {
            delay(1500)
            val n = digits.toIntOrNull()
            digits = ""
            if (n != null && n in 1..state.channels.size) {
                list = state.channels
                index = n - 1
            }
        }
    }

    LaunchedEffect(listOpen) { if (!listOpen) runCatching { rootFocus.requestFocus() } }

    BackHandler(enabled = listOpen || infoVisible) {
        if (listOpen) listOpen = false else infoVisible = false
    }

    fun zap(delta: Int) {
        if (list.isEmpty()) return
        index = (index + delta + list.size) % list.size
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(rootFocus)
            .focusable()
            .onPreviewKeyEvent { ev ->
                if (listOpen || ev.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (ev.key) {
                    Key.DirectionUp, Key.ChannelUp -> { zap(-1); true }
                    Key.DirectionDown, Key.ChannelDown -> { zap(1); true }
                    Key.DirectionLeft -> { listOpen = true; true }
                    Key.DirectionRight, Key.Menu -> { onToggleFavorite(channel); infoVisible = true; infoNonce++; true }
                    Key.DirectionCenter, Key.Enter, Key.NumPadEnter -> {
                        infoVisible = !infoVisible; infoNonce++; true
                    }
                    else -> {
                        val d = digitOf(ev.key)
                        if (d != null && digits.length < 4) { digits += d; true } else false
                    }
                }
            },
    ) {
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                    useController = false
                    isFocusable = false
                    resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
                    keepScreenOn = true
                    this.player = player
                }
            },
            modifier = Modifier.fillMaxSize(),
        )

        if (buffering && error == null) {
            Text(
                "Se încarcă…", color = KidColors.Text, fontSize = 20.sp,
                modifier = Modifier.align(Alignment.Center).clip(RoundedCornerShape(10.dp))
                    .background(Color(0x99000000)).padding(horizontal = 22.dp, vertical = 12.dp),
            )
        }
        error?.let {
            Column(
                Modifier.align(Alignment.Center).clip(RoundedCornerShape(16.dp))
                    .background(Color(0xCC111827)).padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(it, color = KidColors.Text, fontSize = 20.sp)
                Spacer(Modifier.height(10.dp))
                Text("▲ ▼ pentru alt post  ·  ◀ lista de posturi", color = KidColors.TextDim, fontSize = 15.sp)
            }
        }

        if (digits.isNotEmpty()) {
            Text(
                digits, color = KidColors.Text, fontSize = 56.sp, fontWeight = FontWeight.Black,
                modifier = Modifier.align(Alignment.TopEnd).padding(36.dp),
            )
        }

        AnimatedVisibility(
            visible = infoVisible && !listOpen,
            enter = fadeIn(), exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            InfoBanner(channel, state)
        }

        AnimatedVisibility(
            visible = listOpen,
            enter = slideInHorizontally { -it } + fadeIn(),
            exit = slideOutHorizontally { -it } + fadeOut(),
            modifier = Modifier.align(Alignment.CenterStart),
        ) {
            ChannelSideList(
                list = list,
                current = index,
                state = state,
                onPick = { i -> index = i; listOpen = false },
            )
        }
    }
}

private fun digitOf(key: Key): Char? = when (key) {
    Key.Zero, Key.NumPad0 -> '0'
    Key.One, Key.NumPad1 -> '1'
    Key.Two, Key.NumPad2 -> '2'
    Key.Three, Key.NumPad3 -> '3'
    Key.Four, Key.NumPad4 -> '4'
    Key.Five, Key.NumPad5 -> '5'
    Key.Six, Key.NumPad6 -> '6'
    Key.Seven, Key.NumPad7 -> '7'
    Key.Eight, Key.NumPad8 -> '8'
    Key.Nine, Key.NumPad9 -> '9'
    else -> null
}

@Composable
private fun InfoBanner(channel: Channel, state: UiState) {
    val (now, next) = state.epg.nowAndNext(channel, state.now)
    Box(
        Modifier.fillMaxWidth().background(
            Brush.verticalGradient(listOf(Color.Transparent, Color(0xE6000000)))
        ).padding(start = 48.dp, end = 48.dp, top = 60.dp, bottom = 36.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(width = 150.dp, height = 90.dp).clip(RoundedCornerShape(12.dp)).background(KidColors.LogoBox),
                contentAlignment = Alignment.Center,
            ) {
                if (channel.logo != null) AsyncImage(
                    model = channel.logo, contentDescription = null, contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize().padding(14.dp),
                ) else Text(channel.name.take(2).uppercase(), fontSize = 30.sp, color = KidColors.TextDim)
            }
            Spacer(Modifier.width(24.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("${state.numberOf(channel)}", color = KidColors.Accent, fontSize = 26.sp, fontWeight = FontWeight.Black)
                    Spacer(Modifier.width(12.dp))
                    Text(channel.name, color = KidColors.Text, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                    if (channel.key in state.favorites) {
                        Spacer(Modifier.width(10.dp))
                        Icon(Icons.Filled.Star, contentDescription = null, tint = KidColors.Accent, modifier = Modifier.size(24.dp))
                    }
                    Spacer(Modifier.weight(1f))
                    Text(formatTime(state.now), color = KidColors.Text, fontSize = 24.sp)
                }
                Spacer(Modifier.height(6.dp))
                if (now != null) {
                    Text(
                        "Acum: ${now.title}", color = KidColors.Text, fontSize = 18.sp,
                        maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(6.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(formatTime(now.start), color = KidColors.TextDim, fontSize = 13.sp)
                        Spacer(Modifier.width(10.dp))
                        ProgressBar(now.progress(state.now), Modifier.weight(1f))
                        Spacer(Modifier.width(10.dp))
                        Text(formatTime(now.stop), color = KidColors.TextDim, fontSize = 13.sp)
                    }
                } else {
                    Text(
                        channel.categories.joinToString(" · ").ifBlank { "În direct" } + "  ·  " + channel.sourceName,
                        color = KidColors.TextDim, fontSize = 16.sp,
                    )
                }
                if (next != null) {
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Urmează ${formatTime(next.start)}: ${next.title}", color = KidColors.TextDim, fontSize = 15.sp,
                        maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    "▲▼ schimbă postul   ◀ lista de posturi   ▶ favorit   0-9 număr post",
                    color = Color(0x99FFFFFF), fontSize = 12.sp,
                )
            }
        }
    }
}

@Composable
private fun ChannelSideList(list: List<Channel>, current: Int, state: UiState, onPick: (Int) -> Unit) {
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = (current - 3).coerceAtLeast(0))
    val currentFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        delay(80)
        runCatching { currentFocus.requestFocus() }
    }
    Column(
        Modifier.width(440.dp).fillMaxHeight().background(Color(0xF00B0F1A)).padding(vertical = 24.dp, horizontal = 16.dp),
    ) {
        Text(state.selectedCategory, color = KidColors.Text, fontSize = 22.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 8.dp, bottom = 12.dp))
        LazyColumn(state = listState, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            itemsIndexed(list, key = { _, c -> c.key }) { i, ch ->
                val (now, _) = state.epg.nowAndNext(ch, state.now)
                Surface(
                    onClick = { onPick(i) },
                    modifier = Modifier.fillMaxWidth().height(64.dp)
                        .then(if (i == current) Modifier.focusRequester(currentFocus) else Modifier),
                    shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(10.dp)),
                    colors = ClickableSurfaceDefaults.colors(
                        containerColor = if (i == current) KidColors.AccentSoft else Color.Transparent,
                        contentColor = KidColors.Text,
                        focusedContainerColor = KidColors.Accent,
                        focusedContentColor = KidColors.Text,
                    ),
                    scale = ClickableSurfaceDefaults.scale(focusedScale = 1.0f),
                ) {
                    Row(Modifier.fillMaxSize().padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("${state.numberOf(ch)}", fontSize = 14.sp, modifier = Modifier.width(36.dp))
                        Box(Modifier.size(width = 64.dp, height = 40.dp), contentAlignment = Alignment.Center) {
                            if (ch.logo != null) AsyncImage(model = ch.logo, contentDescription = null,
                                contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(ch.name, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (now != null) Text(now.title, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                color = Color(0xCCFFFFFF))
                        }
                    }
                }
            }
        }
    }
}
