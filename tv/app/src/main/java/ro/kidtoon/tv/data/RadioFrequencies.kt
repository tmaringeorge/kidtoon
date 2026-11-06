package ro.kidtoon.tv.data

import java.text.Normalizer

/**
 * Frecventele FM din Bucuresti pentru posturile mari (sursa: Wikipedia, „Media in Bucharest”).
 * radio-browser.info nu are frecventa, iar posturile nationale emit pe alte frecvente in alte orase.
 */
object RadioFrequencies {
    private val BUCHAREST = mapOf(
        "trinitas" to 88.5, "zu" to 89.0, "dancefm" to 89.5, "magicfm" to 90.8, "nationalfm" to 91.7,
        "vibefm" to 92.1, "urbanfm" to 92.7, "rfi" to 93.5, "voceaevangheliei" to 94.2, "guerrilla" to 94.8,
        "kissfm" to 96.1, "goldfm" to 96.9, "digifm" to 97.9, "virginradio" to 100.2, "rockfm" to 100.6,
        "romaniacultural" to 101.3, "romanticfm" to 101.9, "profm" to 102.8, "seven" to 103.4,
        "digi24fm" to 103.8, "romaniamuzical" to 104.8, "romaniaactualitati" to 105.3, "sporttotalfm" to 105.8,
        "3fm" to 106.2, "europafm" to 106.7,
    )

    /** Cheia unui nume: fara diacritice, spatii, „Radio” in fata, „Romania/Bucuresti” sau frecventa la coada. */
    fun key(name: String): String {
        var k = Normalizer.normalize(name.lowercase(), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .replace(Regex("[^a-z0-9]"), "")
        repeat(2) {
            for (suffix in listOf("bucuresti", "romania", "live")) k = k.removeSuffix(suffix)
            k = k.replace(Regex("\\d{3,4}$"), "") // „kissfm961”, „dancefm895bucuresti”
        }
        k = k.removePrefix("radio")
        return k
    }

    /** Frecventa in Bucuresti (MHz) sau null daca postul nu e in lista. */
    fun bucharest(name: String): Double? = BUCHAREST[key(name)]

    fun label(mhz: Double): String = String.format(java.util.Locale.ROOT, "%.1f FM", mhz)
}

/** Ordinea listei de radiouri. */
enum class RadioSort(val label: String) {
    POPULAR("Populare"), ALPHA("A–Z"), FREQUENCY("Frecvență");

    fun apply(list: List<RadioStation>): List<RadioStation> = when (this) {
        POPULAR -> list // vine deja ordonata dupa popularitate
        ALPHA -> {
            val collator = java.text.Collator.getInstance(java.util.Locale("ro"))
            list.sortedWith { a, b -> collator.compare(a.name.trim(), b.name.trim()) }
        }
        FREQUENCY -> list.sortedWith(
            compareBy<RadioStation> { RadioFrequencies.bucharest(it.name) ?: Double.MAX_VALUE }
                .thenBy { it.name.lowercase() }
        )
    }
}
