package ro.kidtoon.tv

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import ro.kidtoon.tv.data.Channel
import ro.kidtoon.tv.data.RadioStation
import ro.kidtoon.tv.ui.BuilderScreen
import ro.kidtoon.tv.ui.ColoringScreen
import ro.kidtoon.tv.ui.DrawingScreen
import ro.kidtoon.tv.ui.GalleryScreen
import ro.kidtoon.tv.ui.HomeActions
import ro.kidtoon.tv.ui.HomeScreen
import ro.kidtoon.tv.ui.KidColors
import ro.kidtoon.tv.ui.KidTheme
import ro.kidtoon.tv.ui.MainViewModel
import ro.kidtoon.tv.ui.ParentGateScreen
import ro.kidtoon.tv.ui.PlayerScreen
import ro.kidtoon.tv.ui.RadioPlayerScreen
import ro.kidtoon.tv.ui.RadioScreen
import ro.kidtoon.tv.ui.Section
import ro.kidtoon.tv.ui.SettingsScreen
import ro.kidtoon.tv.ui.StoryScreen
import ro.kidtoon.tv.ui.TouchScreen
import ro.kidtoon.tv.ui.WelcomeScreen
import ro.kidtoon.tv.ui.applyGhiLook
import ro.kidtoon.tv.ui.coloringPages

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { KidTheme { KidToonApp() } }
    }
}

private sealed interface Screen {
    data object Home : Screen
    data object EditCharacter : Screen
    data object ParentGate : Screen
    data object Settings : Screen
    data class Player(val list: List<Channel>, val index: Int) : Screen
    data object Radio : Screen
    data class RadioPlayer(val list: List<RadioStation>, val index: Int) : Screen
    data object Story : Screen
    data object Touch : Screen
    data class Coloring(val page: Int) : Screen
    data object Drawing : Screen
    data class Builder(val template: Int) : Screen
    data object Gallery : Screen
}

/**
 * Același drum ca în aplicația de TV de la care pornim (meniu lateral, grilă, player, radio, setări),
 * dar copilul e în prim plan: Acasă, Povești, Atinge, Atelier, Desene TV. Radioul nu e obligatoriu,
 * iar setările sunt după poarta pentru părinți.
 */
@Composable
private fun KidToonApp(vm: MainViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    var screen by remember { mutableStateOf<Screen>(Screen.Home) }
    var section by remember { mutableStateOf(Section.HOME) }
    val book = vm.ghiBook

    BackHandler(enabled = state.characterChosen && (screen != Screen.Home || section != Section.HOME)) {
        screen = when (screen) {
            Screen.Home -> { section = Section.HOME; Screen.Home }
            is Screen.RadioPlayer -> Screen.Radio
            Screen.EditCharacter -> { applyGhiLook(vm.ghiCharacter); Screen.Home }
            else -> Screen.Home
        }
    }

    Box(Modifier.fillMaxSize().background(KidColors.Background)) {
        if (!state.characterChosen) {
            WelcomeScreen(vm.ghiCharacter, editing = false, onDone = vm::chooseCharacter)
            return@Box
        }
        when (val s = screen) {
            Screen.Home -> HomeScreen(
                state = state,
                section = section,
                onSection = { section = it },
                book = book,
                character = vm.ghiCharacter,
                lastChannel = vm.lastChannel(),
                actions = HomeActions(
                    onStory = { vm.setGhiEpisode(it); screen = Screen.Story },
                    onTouch = { vm.setTouchScene(it); screen = Screen.Touch },
                    onColoring = { screen = Screen.Coloring(it) },
                    onDrawing = { screen = Screen.Drawing },
                    onBuilder = { screen = Screen.Builder(it) },
                    onGallery = { screen = Screen.Gallery },
                    onEditCharacter = { screen = Screen.EditCharacter },
                    onPlay = { list, index -> screen = Screen.Player(list, index) },
                    onToggleFavorite = vm::toggleFavorite,
                    onSelectCategory = vm::selectCategory,
                    onResume = {
                        vm.lastChannel()?.let { ch -> screen = Screen.Player(state.channels, state.channels.indexOf(ch)) }
                    },
                    onOpenRadio = { screen = Screen.Radio },
                    onOpenParents = { screen = Screen.ParentGate },
                ),
            )
            Screen.EditCharacter -> WelcomeScreen(vm.ghiCharacter, editing = true) {
                vm.changeGhiCharacter(it)
                screen = Screen.Home
            }
            Screen.ParentGate -> ParentGateScreen(state.parentPin) { screen = Screen.Settings }
            Screen.Settings -> SettingsScreen(state = state, vm = vm)
            Screen.Story -> if (book != null && book.episodes.isNotEmpty()) StoryScreen(
                book, state.ghiEpisode, state.sessionLimit,
                onNext = { vm.nextGhiEpisode() }, onPrevious = { vm.previousGhiEpisode() },
            ) else LaunchedEffect(Unit) { screen = Screen.Home }
            Screen.Touch -> if (book != null && book.touch.isNotEmpty()) TouchScreen(
                book, state.touchScene, state.sessionLimit,
                onNext = vm::nextTouchScene, onPrevious = vm::previousTouchScene,
            ) else LaunchedEffect(Unit) { screen = Screen.Home }
            is Screen.Coloring -> ColoringScreen(coloringPages[s.page.coerceIn(0, coloringPages.size - 1)])
            Screen.Drawing -> DrawingScreen()
            is Screen.Builder -> BuilderScreen(s.template)
            Screen.Gallery -> GalleryScreen()
            Screen.Radio -> RadioScreen(
                state = state,
                onLoad = { vm.loadRadio() },
                onRetry = { vm.loadRadio(force = true) },
                onPlay = { list, index -> screen = Screen.RadioPlayer(list, index) },
                onToggleFavorite = vm::toggleRadioFavorite,
                onSort = vm::setRadioSort,
            )
            is Screen.RadioPlayer -> RadioPlayerScreen(
                initialList = s.list,
                initialIndex = s.index,
                state = state,
                onToggleFavorite = vm::toggleRadioFavorite,
                onNextBackground = vm::nextRadioBackground,
                onPreviousBackground = vm::previousRadioBackground,
                onToggleMode = vm::toggleRadioMode,
                ghiBook = book,
                onCycleContent = vm::cycleKidContent,
                onNextTouch = vm::nextTouchScene,
                onPreviousTouch = vm::previousTouchScene,
                onNextGhi = { vm.nextGhiEpisode() },
                onPreviousGhi = { vm.previousGhiEpisode() },
                onExit = { screen = Screen.Radio },
            )
            is Screen.Player -> PlayerScreen(
                initialList = s.list,
                initialIndex = s.index,
                state = state,
                httpClient = vm.repository.http,
                onWatched = vm::markWatched,
                onToggleFavorite = vm::toggleFavorite,
                onExit = { screen = Screen.Home },
            )
        }
    }
}
