package ro.kidtoon.tv.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/** Ce se vede pe ecran cat se asculta radio. */
enum class RadioBackground(val label: String) {
    ALL("Toate animațiile, pe rând"),
    SKY("Cer cu soare, lună și stele"),
    OCEAN("Peștișori în mare"),
    FARM("Animalele de la fermă"),
    BALLOONS("Baloane colorate"),
    TRAIN("Trenulețul cu fructe"),
    SHAPES("Forme și culori"),
    FOOTBALL("Fotbal"),
    SORCOVA("Sorcova"),
    SANTA("Moș Crăciun"),
    DINOS("Dinozauri"),
    FIREFIGHTERS("Pompierii"),
    DOCTOR("La doctor"),
    ZOO("Animale de la zoo"),
    TREES("Plantăm copaci");

    /** Sagetile din player: urmatoarea / precedenta animatie, in cerc. */
    fun next(): RadioBackground = entries[(ordinal + 1) % entries.size]
    fun previous(): RadioBackground = entries[(ordinal - 1 + entries.size) % entries.size]
}

/** Modul radioului: Copil (animatii) sau Adult (ecran simplu, cu postul si melodia). */
/** Ce vede copilul în modul Copil: animațiile, episoadele cu GHI sau „Atinge și învață”. */
enum class KidContent(val label: String) {
    ANIMATIONS("Animații"),
    GHI("Povești"),
    TOUCH("Atinge și învață");

    fun next(): KidContent = entries[(ordinal + 1) % entries.size]
}

enum class RadioMode(val label: String) {
    KID("Copil"), ADULT("Adult");

    fun toggled(): RadioMode = if (this == KID) ADULT else KID
}

/** Un post de radio din radio-browser.info. */
@Serializable
data class RadioStation(
    @SerialName("stationuuid") val id: String,
    val name: String,
    val url: String = "",
    @SerialName("url_resolved") val urlResolved: String = "",
    val favicon: String = "",
    val tags: String = "",
    val state: String = "",
    val codec: String = "",
    val bitrate: Int = 0,
) {
    val streamUrl: String get() = urlResolved.ifBlank { url }
    val logo: String? get() = favicon.takeIf { it.startsWith("http") }
    val tagList: List<String> get() = tags.split(',').map { it.trim() }.filter { it.isNotEmpty() }.take(3)
}

object RadioParser {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; explicitNulls = false }

    fun parse(body: String): List<RadioStation> =
        json.decodeFromString<List<RadioStation>>(body)
            .filter { it.streamUrl.startsWith("http") && it.name.isNotBlank() }
            .map { it.copy(name = it.name.trim()) }
            // Acelasi post apare uneori de mai multe ori; lista vine ordonata dupa popularitate.
            .distinctBy { it.name.lowercase().replace(Regex("[^a-z0-9]"), "") }
}
