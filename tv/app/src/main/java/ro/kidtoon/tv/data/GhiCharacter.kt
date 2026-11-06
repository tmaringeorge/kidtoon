package ro.kidtoon.tv.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject

/**
 * Cum e GHI pentru copilul vostru: numele, băiat sau fată și ce costumaș poartă.
 * Poveștile au „GHI”, {băiat|fată} și {dragonul}; aici se aleg cuvintele potrivite (la fel ca pe telefon).
 */
data class GhiCharacter(val name: String = "GHI", val girl: Boolean = false, val avatar: String = "dragon") {

    val isDefault get() = name == "GHI" && !girl && avatar == "dragon"

    /** Textul poveștii (sau tot fișierul JSON) cu numele, băiat/fată și animalul alese. */
    fun personalize(text: String): String {
        val words = (NOUNS[avatar] ?: NOUNS.getValue("dragon")).let { if (girl) it.second else it.first }
        return PAIR.replace(text) { m -> if (girl) m.groupValues[2] else m.groupValues[1] }
            .let { t ->
                NOUN.replace(t) { m ->
                    when (m.groupValues[1]) { "un_dragon" -> words[0]; "dragonul" -> words[1]; else -> words[2] }
                }
            }
            .replace("GHI", name)
    }

    fun encode(): String = Json.encodeToString(JsonObject.serializer(), toJson())

    fun toJson() = JsonObject(mapOf("name" to JsonPrimitive(name), "girl" to JsonPrimitive(girl), "avatar" to JsonPrimitive(avatar)))

    companion object {
        val AVATARS = linkedMapOf(
            "dragon" to "Dinozaurul verde (ca acum)",
            "balaur" to "Balaurul cu 7 capete",
            "leu" to "Leul",
            "urs" to "Ursulețul",
        )

        private val NOUNS = mapOf(
            "dragon" to (listOf("un dragon", "dragonul", "Dragonii") to listOf("o dragoniță", "dragonița", "Dragonițele")),
            "balaur" to (listOf("un balaur", "balaurul", "Balaurii") to listOf("o bălăuriță", "bălăurița", "Bălăurițele")),
            "leu" to (listOf("un leu", "leul", "Leii") to listOf("o leoaică", "leoaica", "Leoaicele")),
            "urs" to (listOf("un ursuleț", "ursulețul", "Urșii") to listOf("o ursuliță", "ursulița", "Ursulițele")),
        )

        private val PAIR = Regex("""\{([^{}|"\\]*)\|([^{}|"\\]*)\}""")
        private val NOUN = Regex("""\{(un_dragon|dragonul|Dragonii)\}""")

        /** Un nume scurt, fără semne care ar strica fișierul poveștilor. */
        fun clean(s: String): String {
            val t = s.replace(Regex("""["\\{}|<>]"""), "").replace(Regex("""\s+"""), " ").trim()
            if (t.isEmpty()) return "GHI"
            return if (t.length > 16) t.substring(0, 16).trim() else t
        }

        fun fromJson(e: JsonElement?): GhiCharacter? = runCatching {
            val o = e!!.jsonObject
            GhiCharacter(
                name = clean((o["name"] as? JsonPrimitive)?.content ?: "GHI"),
                girl = (o["girl"] as? JsonPrimitive)?.booleanOrNull ?: false,
                avatar = (o["avatar"] as? JsonPrimitive)?.content?.takeIf { it in AVATARS } ?: "dragon",
            )
        }.getOrNull()

        fun decode(s: String?): GhiCharacter =
            s?.let { runCatching { fromJson(Json.parseToJsonElement(it)) }.getOrNull() } ?: GhiCharacter()
    }
}
