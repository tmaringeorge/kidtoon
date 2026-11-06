package ro.kidtoon.tv.ui

import android.app.Application
import java.io.File
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import ro.kidtoon.tv.data.Categories
import ro.kidtoon.tv.data.Channel
import ro.kidtoon.tv.data.Epg
import ro.kidtoon.tv.data.PlaylistSource
import ro.kidtoon.tv.data.RadioBackground
import ro.kidtoon.tv.data.GhiBook
import ro.kidtoon.tv.data.GhiCharacter
import ro.kidtoon.tv.data.GhiStudio
import ro.kidtoon.tv.data.StudioPack
import ro.kidtoon.tv.data.GhiTimeline
import ro.kidtoon.tv.data.KidContent
import ro.kidtoon.tv.data.KidFilter
import ro.kidtoon.tv.data.ParentPin
import ro.kidtoon.tv.data.ScreenCare
import ro.kidtoon.tv.data.RadioMode
import ro.kidtoon.tv.data.RadioSort
import ro.kidtoon.tv.data.RadioRepository
import ro.kidtoon.tv.data.RadioStation
import ro.kidtoon.tv.data.Prefs
import ro.kidtoon.tv.data.Repository

data class UiState(
    val loading: Boolean = true,
    val channels: List<Channel> = emptyList(),
    val categories: List<String> = listOf(Categories.ALL),
    val selectedCategory: String = Categories.ALL,
    val favorites: Set<String> = emptySet(),
    val recents: List<String> = emptyList(),
    val epg: Epg = Epg.EMPTY,
    val epgLoading: Boolean = false,
    val errors: List<String> = emptyList(),
    val filteredOut: Int = 0,
    val now: Long = System.currentTimeMillis(),
    val playlists: List<PlaylistSource> = emptyList(),
    val builtInEnabled: Boolean = true,
    val epgUrls: List<String> = emptyList(),
    val radioStations: List<RadioStation> = emptyList(),
    val radioLoading: Boolean = false,
    val radioError: String? = null,
    val radioFavorites: Set<String> = emptySet(),
    val radioBackground: RadioBackground = RadioBackground.ALL,
    val radioMode: RadioMode = RadioMode.KID,
    val kidContent: KidContent = KidContent.ANIMATIONS,
    val sessionLimit: Int = ScreenCare.DEFAULT_LIMIT,
    val touchScene: Int = 0,
    val ghiEpisode: Int = 0,
    val radioSort: RadioSort = RadioSort.POPULAR,
    /** Toate posturile încărcate, înainte de filtrul pentru copii (pentru Setări). */
    val allChannels: List<Channel> = emptyList(),
    val kidsOnly: Boolean = true,
    val hiddenChannels: Set<String> = emptySet(),
    val characterChosen: Boolean = false,
    val parentPin: String = "",
) {
    val visibleChannels: List<Channel>
        get() = channelsIn(selectedCategory)

    fun channelsIn(category: String): List<Channel> = when (category) {
        Categories.ALL -> channels
        Categories.FAVORITES -> channels.filter { it.key in favorites }
        Categories.RECENT -> recents.mapNotNull { k -> channels.firstOrNull { it.key == k } }
        Categories.OTHER -> channels.filter { it.categories.isEmpty() }
        else -> channels.filter { category in it.categories }
    }

    fun numberOf(channel: Channel): Int = channels.indexOf(channel) + 1
}

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = Prefs(app)
    val repository = Repository(app, prefs)
    private val radioRepository = RadioRepository(app, repository.http)

    private val _state = MutableStateFlow(
        UiState(
            favorites = prefs.favorites,
            recents = prefs.recents,
            playlists = prefs.playlists,
            builtInEnabled = prefs.builtInEnabled,
            epgUrls = prefs.epgUrls,
            radioFavorites = prefs.radioFavorites,
            radioBackground = prefs.radioBackground,
            radioMode = prefs.radioMode,
            kidContent = prefs.kidContent,
            sessionLimit = prefs.sessionLimit,
            touchScene = prefs.touchScene,
            ghiEpisode = prefs.ghiEpisode,
            radioSort = prefs.radioSort,
            kidsOnly = prefs.kidsOnly,
            hiddenChannels = prefs.hiddenChannels,
            characterChosen = prefs.characterChosen,
            parentPin = prefs.parentPin,
        )
    )
    val state: StateFlow<UiState> = _state

    private var loadJob: Job? = null

    init {
        reload()
        // Ceas pentru "acum ruleaza" si bara de progres.
        viewModelScope.launch {
            while (true) {
                delay(30_000)
                _state.update { it.copy(now = System.currentTimeMillis()) }
            }
        }
    }

    /** Forteaza re-descarcarea listelor si a ghidului TV (ignora cache-ul). */
    fun refreshSources() {
        repository.clearCache()
        reload()
        if (_state.value.radioStations.isNotEmpty()) loadRadio(force = true)
    }

    fun reload() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _state.update { it.copy(loading = true) }
            val res = repository.loadChannels()
            _state.update { s ->
                val kids = KidFilter.apply(res.channels, s.kidsOnly, s.hiddenChannels)
                s.copy(
                    loading = false,
                    allChannels = res.channels,
                    channels = kids,
                    categories = buildCategories(kids),
                    selectedCategory = s.selectedCategory.takeIf { it in buildCategories(kids) }
                        ?: Categories.ALL,
                    errors = res.errors,
                    filteredOut = res.filteredOut,
                    epgLoading = true,
                )
            }
            val epg = repository.loadEpg((prefs.epgUrls + res.epgUrlsFromPlaylists).distinct())
            _state.update { it.copy(epg = epg, epgLoading = false, now = System.currentTimeMillis()) }
        }
    }

    private fun buildCategories(channels: List<Channel>): List<String> {
        val counts = channels.flatMap { it.categories }.groupingBy { it }.eachCount()
        val sorted = counts.entries.sortedByDescending { it.value }.map { it.key }
        return buildList {
            add(Categories.ALL)
            add(Categories.FAVORITES)
            add(Categories.RECENT)
            addAll(sorted)
            if (channels.any { it.categories.isEmpty() }) add(Categories.OTHER)
        }
    }

    /** Aplică din nou filtrul pentru copii (după o schimbare din Setări), fără să descarce listele. */
    private fun refilter() = _state.update { s ->
        val kids = KidFilter.apply(s.allChannels, s.kidsOnly, s.hiddenChannels)
        val cats = buildCategories(kids)
        s.copy(channels = kids, categories = cats, selectedCategory = s.selectedCategory.takeIf { it in cats } ?: Categories.ALL)
    }

    fun setKidsOnly(v: Boolean) {
        prefs.kidsOnly = v
        _state.update { it.copy(kidsOnly = v) }
        refilter()
    }

    fun toggleHidden(ch: Channel) {
        val h = _state.value.hiddenChannels.toMutableSet()
        if (!h.add(ch.key)) h.remove(ch.key)
        prefs.hiddenChannels = h
        _state.update { it.copy(hiddenChannels = h) }
        refilter()
    }

    /** PIN gol = fără PIN (rămâne întrebarea cu înmulțirea). */
    fun setParentPin(pin: String) {
        if (pin.isNotEmpty() && !ParentPin.isValid(pin)) return
        prefs.parentPin = pin
        _state.update { it.copy(parentPin = pin) }
    }

    /** Prima pornire: copilul și-a ales prietenul. */
    fun chooseCharacter(c: GhiCharacter) {
        changeGhiCharacter(c)
        prefs.characterChosen = true
        _state.update { it.copy(characterChosen = true) }
    }

    fun selectCategory(c: String) = _state.update { it.copy(selectedCategory = c) }

    fun toggleFavorite(ch: Channel) {
        val fav = _state.value.favorites.toMutableSet()
        if (!fav.add(ch.key)) fav.remove(ch.key)
        prefs.favorites = fav
        _state.update { it.copy(favorites = fav) }
    }

    fun markWatched(ch: Channel) {
        val rec = listOf(ch.key) + _state.value.recents.filter { it != ch.key }
        prefs.recents = rec
        prefs.lastChannel = ch.key
        _state.update { it.copy(recents = rec.take(20)) }
    }

    fun lastChannel(): Channel? = prefs.lastChannel?.let { k -> _state.value.channels.firstOrNull { it.key == k } }

    // ---- Radio ----
    private var radioJob: Job? = null

    fun loadRadio(force: Boolean = false) {
        if (!force && (_state.value.radioStations.isNotEmpty() || radioJob?.isActive == true)) return
        radioJob = viewModelScope.launch {
            _state.update { it.copy(radioLoading = true, radioError = null) }
            val res = runCatching { radioRepository.load(force) }
            _state.update {
                it.copy(
                    radioLoading = false,
                    radioStations = res.getOrDefault(it.radioStations),
                    radioError = res.exceptionOrNull()?.message,
                )
            }
        }
    }

    fun toggleRadioFavorite(st: RadioStation) {
        val fav = _state.value.radioFavorites.toMutableSet()
        if (!fav.add(st.id)) fav.remove(st.id)
        prefs.radioFavorites = fav
        _state.update { it.copy(radioFavorites = fav) }
    }

    fun setRadioBackground(bg: RadioBackground) {
        prefs.radioBackground = bg
        _state.update { it.copy(radioBackground = bg) }
    }

    fun setRadioSort(sort: RadioSort) {
        prefs.radioSort = sort
        _state.update { it.copy(radioSort = sort) }
    }

    /** Sagetile din player: alta animatie, fara drum prin Setari. */
    fun nextRadioBackground() = setRadioBackground(_state.value.radioBackground.next())
    fun previousRadioBackground() = setRadioBackground(_state.value.radioBackground.previous())

    fun setRadioMode(mode: RadioMode) {
        prefs.radioMode = mode
        _state.update { it.copy(radioMode = mode) }
    }

    fun toggleRadioMode() = setRadioMode(_state.value.radioMode.toggled())

    /** Episoadele cu GHI din aplicație (fișier comun cu telefonul), ca text: numele se pune la afișare. */
    private val baseGhi: String? by lazy {
        runCatching { app.assets.open("episodes.json").bufferedReader().use { it.readText() } }.getOrNull()
    }

    /** Ce a trimis telefonul din Studio, păstrat în memoria TV-ului. */
    private val studioFile = File(app.filesDir, "ghi_studio.json")
    private var studioText: String? = null

    /** Episoadele din aplicație, apoi cele făcute pe telefon. Se schimbă când vin episoade noi. */
    var ghiBook: GhiBook? by mutableStateOf(null)
        private set

    var studio: StudioPack by mutableStateOf(StudioPack.EMPTY)
        private set

    /** Numele lui GHI, băiat sau fată și costumașul (dinozaur, balaur cu 7 capete, leu, ursuleț). */
    var ghiCharacter: GhiCharacter by mutableStateOf(prefs.ghiCharacter)
        private set

    private fun applyGhi() {
        val c = ghiCharacter
        applyGhiLook(c)
        val text = studioText
        val pack = text?.let { runCatching { GhiStudio.parse(c.personalize(it)) }.getOrNull() } ?: StudioPack.EMPTY
        setStudioPeople(pack.people)
        studio = pack
        ghiBook = baseGhi?.let { raw -> runCatching { GhiStudio.merge(GhiBook.parse(c.personalize(raw)), pack) }.getOrNull() }
    }

    fun changeGhiCharacter(c: GhiCharacter) {
        val clean = c.copy(name = GhiCharacter.clean(c.name))
        prefs.ghiCharacter = clean
        ghiCharacter = clean
        applyGhi()
    }

    /** Telefonul a trimis episoade (și, de obicei, personajul): le păstrăm și le punem în listă. Rulează pe orice fir. */
    fun receiveStudio(text: String, pack: StudioPack) {
        val tmp = File(studioFile.path + ".tmp")
        tmp.writeText(text)
        tmp.renameTo(studioFile)
        viewModelScope.launch {
            studioText = text
            val c = pack.character
            if (c != null) changeGhiCharacter(c) else applyGhi()
        }
    }

    fun clearStudio() {
        studioFile.delete()
        studioText = null
        applyGhi()
        setGhiEpisode(_state.value.ghiEpisode)
    }

    init {
        // După ce sunt gata câmpurile de mai sus: episoadele primite data trecută de pe telefon.
        studioText = runCatching { studioFile.takeIf { it.exists() }?.readText() }.getOrNull()
        applyGhi()
    }

    fun setKidContent(c: KidContent) {
        prefs.kidContent = c
        _state.update { it.copy(kidContent = c) }
    }

    fun cycleKidContent() = setKidContent(_state.value.kidContent.next())

    fun setSessionLimit(min: Int) {
        prefs.sessionLimit = min
        _state.update { it.copy(sessionLimit = min) }
    }

    fun setTouchScene(index: Int) {
        val n = ghiBook?.touch?.size?.takeIf { it > 0 } ?: return
        val i = ((index % n) + n) % n
        prefs.touchScene = i
        _state.update { it.copy(touchScene = i) }
    }

    fun nextTouchScene() = setTouchScene(_state.value.touchScene + 1)
    fun previousTouchScene() = setTouchScene(_state.value.touchScene - 1)

    fun setGhiEpisode(index: Int) {
        val n = ghiBook?.episodes?.size ?: return
        val i = ((index % n) + n) % n
        prefs.ghiEpisode = i
        _state.update { it.copy(ghiEpisode = i) }
    }

    fun nextGhiEpisode() = ghiBook?.let { setGhiEpisode(GhiTimeline.next(_state.value.ghiEpisode, it.episodes.size)) }
    fun previousGhiEpisode() = ghiBook?.let { setGhiEpisode(GhiTimeline.previous(_state.value.ghiEpisode, it.episodes.size)) }

    // ---- Setari ----
    fun addPlaylist(name: String, url: String) {
        val list = prefs.playlists.filter { it.url != url } + PlaylistSource(name.ifBlank { url }, url.trim())
        prefs.playlists = list
        _state.update { it.copy(playlists = list) }
        reload()
    }

    fun removePlaylist(src: PlaylistSource) {
        val list = prefs.playlists.filter { it.url != src.url }
        prefs.playlists = list
        _state.update { it.copy(playlists = list) }
        reload()
    }

    fun togglePlaylist(src: PlaylistSource) {
        val list = prefs.playlists.map { if (it.url == src.url) it.copy(enabled = !it.enabled) else it }
        prefs.playlists = list
        _state.update { it.copy(playlists = list) }
        reload()
    }

    fun setBuiltIn(enabled: Boolean) {
        prefs.builtInEnabled = enabled
        _state.update { it.copy(builtInEnabled = enabled) }
        reload()
    }

    fun addEpg(url: String) {
        val list = (prefs.epgUrls + url.trim()).distinct()
        prefs.epgUrls = list
        _state.update { it.copy(epgUrls = list) }
        reload()
    }

    fun removeEpg(url: String) {
        val list = prefs.epgUrls - url
        prefs.epgUrls = list
        _state.update { it.copy(epgUrls = list) }
        reload()
    }
}
