package ro.kidtoon.tv.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

/**
 * Studio: personajele și episoadele făcute de părinte pe telefon. Telefonul le trimite prin Wi-Fi-ul
 * de acasă, TV-ul le păstrează într-un fișier și le pune în listă după episoadele din aplicație.
 */
data class StudioPerson(
    val id: String, val name: String,
    val skin: Long, val hair: Long, val top: Long, val bottom: Long, val shoes: Long,
    val style: String = "short", val dress: Boolean = false, val hat: String? = null,
    val beard: Boolean = false, val glasses: Boolean = false,
)

data class StudioPack(val people: List<StudioPerson>, val episodes: List<GhiEpisode>, val character: GhiCharacter? = null) {
    val isEmpty get() = people.isEmpty() && episodes.isEmpty()

    companion object {
        val EMPTY = StudioPack(emptyList(), emptyList())
    }
}

/** Răspunsul pentru telefon: cod HTTP și textul (numărul de episoade primite, sau de ce nu). */
data class StudioReply(val status: Int, val body: String, val pack: StudioPack? = null)

object GhiStudio {
    const val PORT = 8765
    const val MAX_BODY = 2_000_000
    const val PREFIX = "studio_"

    private val STYLES = setOf("short", "long", "bun")

    /** Citește ce a trimis telefonul. Aruncă excepție dacă fișierul nu e bun. */
    fun parse(text: String): StudioPack {
        val root = Json.parseToJsonElement(text).jsonObject
        val people = root["people"]?.jsonArray?.map { e ->
            val o = e.jsonObject
            StudioPerson(
                id = o.str("id")!!, name = o.str("name") ?: "Prieten",
                skin = hex(o.str("skin"), 0xFFF2C6A0), hair = hex(o.str("hair"), 0xFF5D4037),
                top = hex(o.str("top"), 0xFF42A5F5), bottom = hex(o.str("bottom"), 0xFF455A64),
                shoes = hex(o.str("shoes"), 0xFF4E342E),
                style = o.str("style")?.takeIf { it in STYLES } ?: "short",
                dress = o.bool("dress"), hat = o.str("hat"), beard = o.bool("beard"), glasses = o.bool("glasses"),
            )
        } ?: emptyList()
        // Doar episoadele Studio: nu pot înlocui episoadele din aplicație.
        val episodes = GhiBook.episodes(root["episodes"]?.jsonArray ?: kotlinx.serialization.json.JsonArray(emptyList()))
            .filter { it.id.startsWith(PREFIX) && it.beats.isNotEmpty() }
            .distinctBy { it.id }
        return StudioPack(people, episodes, GhiCharacter.fromJson(root["character"]))
    }

    /** Cartea completă: episoadele din aplicație, apoi cele din Studio (decor necunoscut → primul decor). */
    fun merge(base: GhiBook, pack: StudioPack): GhiBook {
        val extra = pack.episodes.map { if (it.set in base.sets) it else it.copy(set = base.sets.keys.first()) }
        return base.copy(episodes = base.episodes.filterNot { it.id.startsWith(PREFIX) } + extra)
    }

    /** Un cod de 4 cifre, nou la fiecare deschidere a ecranului. */
    fun newCode(random: kotlin.random.Random = kotlin.random.Random.Default) = (1000 + random.nextInt(9000)).toString()

    /**
     * Ce răspundem la o cerere: doar POST /ghi, cu codul corect în antetul X-Ghi-Code.
     * `headers` are numele cu litere mici.
     */
    fun handle(requestLine: String, headers: Map<String, String>, body: String, code: String): StudioReply {
        val parts = requestLine.trim().split(" ")
        if (parts.size < 2 || parts[0] != "POST" || parts[1].substringBefore('?') != "/ghi") return StudioReply(404, "nu")
        if (headers["x-ghi-code"]?.trim() != code) return StudioReply(403, "cod greșit")
        val pack = runCatching { parse(body) }.getOrNull() ?: return StudioReply(400, "fișier stricat")
        return StudioReply(200, pack.episodes.size.toString(), pack)
    }

    private fun hex(s: String?, fallback: Long): Long =
        s?.removePrefix("#")?.takeIf { it.length == 6 }?.toLongOrNull(16)?.let { 0xFF000000 or it } ?: fallback

    private fun JsonObject.str(k: String) = (this[k] as? JsonPrimitive)?.content
    private fun JsonObject.bool(k: String) = (this[k] as? JsonPrimitive)?.booleanOrNull ?: false
}
