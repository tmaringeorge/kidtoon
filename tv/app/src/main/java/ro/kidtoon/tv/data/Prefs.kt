package ro.kidtoon.tv.data

import android.content.Context
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Setarile: liste M3U, ghid TV, favorite, recente, prietenul copilului si regulile parintilor. */
class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("kidtoon", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    var playlists: List<PlaylistSource>
        get() = sp.getString("playlists", null)
            ?.let { runCatching { json.decodeFromString<List<PlaylistSource>>(it) }.getOrNull() }
            ?: listOf(Presets.kids)
        set(value) = sp.edit().putString("playlists", json.encodeToString(value)).apply()

    /** Lista oficiala inclusa in aplicatie poate fi ascunsa daca utilizatorul are propria lista. */
    var builtInEnabled: Boolean
        get() = sp.getBoolean("builtin", true)
        set(value) = sp.edit().putBoolean("builtin", value).apply()

    var epgUrls: List<String>
        get() = sp.getString("epg", null)?.split('\n')?.filter { it.isNotBlank() } ?: emptyList()
        set(value) = sp.edit().putString("epg", value.joinToString("\n")).apply()

    var favorites: Set<String>
        get() = sp.getStringSet("fav", emptySet())!!.toSet()
        set(value) = sp.edit().putStringSet("fav", value).apply()

    var recents: List<String>
        get() = sp.getString("recent", null)?.split('\n')?.filter { it.isNotBlank() } ?: emptyList()
        set(value) = sp.edit().putString("recent", value.take(20).joinToString("\n")).apply()

    var radioFavorites: Set<String>
        get() = sp.getStringSet("radioFav", emptySet())!!.toSet()
        set(value) = sp.edit().putStringSet("radioFav", value).apply()

    /**
     * Fundalul din playerul radio. Cheia veche "radioBg" stia doar SKY/BLACK; cine avea
     * ecran negru il pastreaza, ceilalti primesc toate animatiile pe rand.
     */
    var radioBackground: RadioBackground
        get() = runCatching { RadioBackground.valueOf(sp.getString("radioBg2", null)!!) }.getOrDefault(RadioBackground.ALL)
        set(value) = sp.edit().putString("radioBg2", value.name).apply()

    /** Copil sau Adult. Cine alesese inainte „ecran negru” porneste in modul Adult. */
    var radioMode: RadioMode
        get() = runCatching { RadioMode.valueOf(sp.getString("radioMode", null)!!) }.getOrElse {
            val black = sp.getString("radioBg2", null) == "BLACK" ||
                (sp.getString("radioBg2", null) == null && sp.getString("radioBg", null) == "BLACK")
            if (black) RadioMode.ADULT else RadioMode.KID
        }
        set(value) = sp.edit().putString("radioMode", value.name).apply()

    /** Ce vede copilul: animații, episoade cu GHI sau „Atinge și învață” (vechiul ghiOn devine GHI). */
    var kidContent: KidContent
        get() = runCatching { KidContent.valueOf(sp.getString("kidContent", null)!!) }
            .getOrElse { if (sp.getBoolean("ghiOn", false)) KidContent.GHI else KidContent.ANIMATIONS }
        set(value) = sp.edit().putString("kidContent", value.name).apply()

    /** Minutele unei sesiuni înainte de pauza lungă (0 = fără limită). */
    var sessionLimit: Int
        get() = sp.getInt("sessionLimit", ScreenCare.DEFAULT_LIMIT)
        set(value) = sp.edit().putInt("sessionLimit", value).apply()

    var touchScene: Int
        get() = sp.getInt("touchScene", 0)
        set(value) = sp.edit().putInt("touchScene", value).apply()

    /** Numele lui GHI, băiat sau fată și costumașul. */
    var ghiCharacter: GhiCharacter
        get() = GhiCharacter.decode(sp.getString("ghiCharacter", null))
        set(v) = sp.edit().putString("ghiCharacter", v.encode()).apply()

    var ghiEpisode: Int
        get() = sp.getInt("ghiEpisode", 0)
        set(value) = sp.edit().putInt("ghiEpisode", value).apply()

    var radioSort: RadioSort
        get() = runCatching { RadioSort.valueOf(sp.getString("radioSort", null)!!) }.getOrDefault(RadioSort.POPULAR)
        set(value) = sp.edit().putString("radioSort", value.name).apply()

    /** Copilul și-a ales prietenul (numele, costumașul) la prima pornire. */
    var characterChosen: Boolean
        get() = sp.getBoolean("characterChosen", false)
        set(value) = sp.edit().putBoolean("characterChosen", value).apply()

    /** La „Desene TV” apar doar posturile pentru copii. */
    var kidsOnly: Boolean
        get() = sp.getBoolean("kidsOnly", true)
        set(value) = sp.edit().putBoolean("kidsOnly", value).apply()

    /** Posturile ascunse de părinte. */
    var hiddenChannels: Set<String>
        get() = sp.getStringSet("hidden", emptySet())!!.toSet()
        set(value) = sp.edit().putStringSet("hidden", value).apply()

    /** PIN-ul părinților (gol = întrebarea cu înmulțirea). */
    var parentPin: String
        get() = sp.getString("parentPin", "") ?: ""
        set(value) = sp.edit().putString("parentPin", value).apply()

    var lastChannel: String?
        get() = sp.getString("last", null)
        set(value) = sp.edit().putString("last", value).apply()
}
