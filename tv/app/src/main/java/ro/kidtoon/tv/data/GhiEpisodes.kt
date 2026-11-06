package ro.kidtoon.tv.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.floatOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Episoadele cu GHI, bebelușul-dragon. Povestea stă în `episodes.json` (comun cu telefonul),
 * iar aici sunt doar modelul și cronometrul: generic de început, pașii poveștii, „Ce am învățat”.
 */

/** Un interval de la..la, care se parcurge pe durata unui pas (sau o valoare fixă). */
data class Span(val from: Float, val to: Float) {
    fun at(x: Float) = from + (to - from) * GhiTimeline.ease(x)
    companion object {
        fun of(e: JsonElement?, default: Float): Span = when (e) {
            is JsonArray -> Span(e[0].jsonPrimitive.floatOrNull ?: default, e[1].jsonPrimitive.floatOrNull ?: default)
            is JsonPrimitive -> (e.floatOrNull ?: default).let { Span(it, it) }
            else -> Span(default, default)
        }
    }
}

data class GhiSet(val sky: List<Long>, val ground: Long, val horizon: Float, val deco: List<String>)

data class GhiPose(
    val pose: String, val x: Span, val y: Span?, val face: String, val puff: String?,
    val hold: String?, val hat: String?, val think: String?, val flip: Boolean, val motion: String?,
)

data class GhiProp(
    val emoji: String, val x: Span, val y: Span, val size: Float, val motion: String,
    val appear: Float, val vanish: Float, val front: Boolean,
)

/** Mami sau tati, desenați lângă GHI. */
data class GhiPerson(
    val who: String, val x: Span, val y: Span?, val pose: String, val face: String, val hold: String?, val flip: Boolean,
)

/** O întrebare în episod: „Care e mingea? Arată cu degetul!”. [answer] e obiectul corect din props. */
data class GhiAsk(val answer: Int, val yes: String, val no: String, val hint: String)

data class GhiCount(val items: List<String>, val labels: List<String>, val y: Float, val size: Float, val x: Span)

data class GhiBeat(
    val say: String, val sec: Int, val ghi: GhiPose, val props: List<GhiProp>, val count: GhiCount?, val cam: Span?,
    val people: List<GhiPerson> = emptyList(),
    val ask: GhiAsk? = null,
)

data class GhiEpisode(val id: String, val title: String, val set: String, val learn: String, val beats: List<GhiBeat>)

/** „Atinge și învață”: o scenă cu lucruri pe care copilul le atinge, iar GHI spune ce sunt. */
data class GhiTouchItem(val emoji: String, val name: String, val say: String)

data class GhiTouchScene(val id: String, val title: String, val set: String, val items: List<GhiTouchItem>)

data class GhiBook(val sets: Map<String, GhiSet>, val episodes: List<GhiEpisode>, val touch: List<GhiTouchScene> = emptyList()) {
    fun set(name: String) = sets[name] ?: sets.values.first()

    companion object {
        fun parse(text: String): GhiBook {
            val root = Json.parseToJsonElement(text).jsonObject
            val sets = root["sets"]!!.jsonObject.mapValues { (_, v) ->
                val o = v.jsonObject
                GhiSet(
                    sky = o["sky"]!!.jsonArray.map { color(it.jsonPrimitive.content) },
                    ground = color(o.str("ground") ?: "#8BC34A"),
                    horizon = o.num("horizon") ?: 0.72f,
                    deco = o["deco"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                )
            }
            val episodes = episodes(root["episodes"]!!.jsonArray)
            val touch = root["touch"]?.jsonArray?.map { t ->
                val o = t.jsonObject
                GhiTouchScene(
                    id = o.str("id")!!, title = o.str("title")!!, set = o.str("set")!!,
                    items = o["items"]!!.jsonArray.map { i ->
                        val q = i.jsonObject
                        GhiTouchItem(q.str("e")!!, q.str("name")!!, q.str("say") ?: q.str("name")!!)
                    },
                )
            } ?: emptyList()
            return GhiBook(sets, episodes, touch)
        }

        /** Episoadele dintr-o listă JSON: cele din aplicație sau cele venite din Studio de pe telefon. */
        fun episodes(list: JsonArray): List<GhiEpisode> = list.map { e ->
            val o = e.jsonObject
            GhiEpisode(
                id = o.str("id")!!, title = o.str("title")!!, set = o.str("set")!!, learn = o.str("learn") ?: "",
                beats = o["beats"]!!.jsonArray.map { beat(it.jsonObject) },
            )
        }

        private fun beat(o: JsonObject): GhiBeat {
            val g = o["ghi"]!!.jsonObject
            return GhiBeat(
                say = o.str("say") ?: "",
                sec = (o.num("sec") ?: 10f).toInt(),
                ghi = GhiPose(
                    pose = g.str("pose") ?: "stand", x = Span.of(g["x"], 0.35f), y = g["y"]?.let { Span.of(it, 0f) },
                    face = g.str("face") ?: "happy", puff = g.str("puff"), hold = g.str("hold"), hat = g.str("hat"),
                    think = g.str("think"), flip = g["flip"]?.jsonPrimitive?.booleanOrNull ?: false, motion = g.str("m"),
                ),
                props = o["props"]?.jsonArray?.map { p ->
                    val q = p.jsonObject
                    GhiProp(
                        emoji = q.str("e")!!, x = Span.of(q["x"], 0.5f), y = Span.of(q["y"], 0.5f),
                        size = q.num("s") ?: 0.12f, motion = q.str("m") ?: "none",
                        appear = q.num("in") ?: 0f, vanish = q.num("out") ?: 1f,
                        front = q["front"]?.jsonPrimitive?.booleanOrNull ?: false,
                    )
                } ?: emptyList(),
                count = o["count"]?.jsonObject?.let { c ->
                    GhiCount(
                        items = c["items"]!!.jsonArray.map { it.jsonPrimitive.content },
                        labels = c["labels"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList(),
                        y = c.num("y") ?: 0.3f, size = c.num("s") ?: 0.1f, x = Span.of(c["x"], 0.5f),
                    )
                },
                cam = o["cam"]?.let { Span.of(it, 1f) },
                people = o["people"]?.jsonArray?.map { p ->
                    val q = p.jsonObject
                    GhiPerson(
                        who = q.str("who") ?: "mami", x = Span.of(q["x"], 0.6f), y = q["y"]?.let { Span.of(it, 0f) },
                        pose = q.str("pose") ?: "stand", face = q.str("face") ?: "happy", hold = q.str("hold"),
                        flip = q["flip"]?.jsonPrimitive?.booleanOrNull ?: true,
                    )
                } ?: emptyList(),
                ask = o["ask"]?.jsonObject?.let { a ->
                    GhiAsk(
                        answer = (a.num("answer") ?: 0f).toInt(), yes = a.str("yes") ?: "Bravo!",
                        no = a.str("no") ?: "Mai caută puțin!", hint = a.str("hint") ?: "Uite aici!",
                    )
                },
            )
        }

        private fun JsonObject.str(k: String) = (this[k] as? JsonPrimitive)?.content
        private fun JsonObject.num(k: String) = (this[k] as? JsonPrimitive)?.floatOrNull

        fun color(hex: String): Long = 0xFF000000 or hex.removePrefix("#").toLong(16)
    }
}

/** Unde suntem într-un episod: genericul, un pas al poveștii sau finalul. */
sealed interface GhiPhase {
    data class Title(val local: Float) : GhiPhase
    data class Step(val index: Int, val local: Float, val ms: Long) : GhiPhase
    data class End(val local: Float) : GhiPhase
}

object GhiTimeline {
    const val TITLE_MS = 4_000L
    const val END_MS = 7_000L
    /** Mișcare „pe cadre”, ca la desenele pentru cei mici: 10 cadre pe secundă. */
    const val FPS = 10

    fun durationMs(ep: GhiEpisode) = TITLE_MS + ep.beats.sumOf { it.sec * 1000L } + END_MS

    fun phase(ep: GhiEpisode, ms: Long): GhiPhase {
        if (ms < TITLE_MS) return GhiPhase.Title(ms / TITLE_MS.toFloat())
        var left = ms - TITLE_MS
        ep.beats.forEachIndexed { i, b ->
            val len = b.sec * 1000L
            if (left < len) return GhiPhase.Step(i, left / len.toFloat(), left)
            left -= len
        }
        return GhiPhase.End((left / END_MS.toFloat()).coerceAtMost(1f))
    }

    fun caption(ep: GhiEpisode, ms: Long): String = when (val p = phase(ep, ms)) {
        is GhiPhase.Title -> ep.title
        is GhiPhase.Step -> ep.beats[p.index].say
        is GhiPhase.End -> "Ce am învățat: ${ep.learn}"
    }

    /** Timpul rotunjit la cadru (10 pe secundă), ca mișcările să fie calme și ușor de urmărit. */
    fun quantize(ms: Long) = ms - ms % (1000L / FPS)

    fun ease(x: Float): Float { val c = x.coerceIn(0f, 1f); return c * c * (3 - 2 * c) }

    /** Câte obiecte se văd deja când numărăm: apar pe rând, unul câte unul. */
    fun counted(n: Int, local: Float): Int = (0 until n).count { local >= 0.1f + it * 0.75f / n }

    /** Zoom lent (aproape / departe) dacă pasul nu cere altceva. */
    fun camera(beat: GhiBeat, index: Int) = beat.cam ?: if (index % 2 == 0) Span(1f, 1.07f) else Span(1.07f, 1f)

    /** Tăietură de cadru: GHI apare în alt loc decât la finalul pasului de dinainte. */
    fun isCut(ep: GhiEpisode, index: Int): Boolean =
        index > 0 && kotlin.math.abs(ep.beats[index].ghi.x.from - ep.beats[index - 1].ghi.x.to) > 0.1f

    /** La o întrebare: după cât din pas arată GHI singur răspunsul, dacă nu a ales nimeni. */
    const val REVEAL = 0.6f
    /** După un răspuns bun, ne mai bucurăm atât și trecem mai departe. */
    const val ANSWER_HOLD_MS = 3_500L
    /** Cât arată „Mai caută puțin!” după o alegere greșită. */
    const val WRONG_MS = 1_800L

    fun beatStartMs(ep: GhiEpisode, index: Int): Long = TITLE_MS + ep.beats.take(index).sumOf { it.sec * 1000L }

    /** Textul unei întrebări, după ce s-a întâmplat: bravo, mai caută, uite aici, sau întrebarea. */
    fun askCaption(beat: GhiBeat, local: Float, answered: Boolean = false, wrong: Boolean = false): String {
        val a = beat.ask ?: return beat.say
        return when {
            answered -> a.yes
            wrong -> a.no
            local >= REVEAL -> a.hint
            else -> beat.say
        }
    }

    /** Ce obiect e sub deget la o întrebare (coordonate 0..1), sau -1. [radius] e relativ la lățime. */
    fun askHit(beat: GhiBeat, local: Float, fx: Float, fy: Float, aspect: Float, radius: Float = 0.13f): Int {
        if (beat.ask == null) return -1
        var best = -1
        var bestD = Float.MAX_VALUE
        beat.props.forEachIndexed { i, p ->
            val dx = fx - p.x.at(local)
            val dy = (fy - p.y.at(local)) * aspect
            val d = dx * dx + dy * dy
            if (d < radius * radius && d < bestD) { best = i; bestD = d }
        }
        return best
    }

    /** Cu cât sărim înainte după un răspuns bun, ca pasul să se termine peste [ANSWER_HOLD_MS]. */
    fun skipAfterAnswer(ep: GhiEpisode, ms: Long): Long {
        val p = phase(ep, ms) as? GhiPhase.Step ?: return 0
        val left = ep.beats[p.index].sec * 1000L - p.ms
        return (left - ANSWER_HOLD_MS).coerceAtLeast(0)
    }

    fun next(i: Int, n: Int) = (i + 1) % n
    fun previous(i: Int, n: Int) = (i - 1 + n) % n
}

/** Așezarea lucrurilor în „Atinge și învață”: 4 pe rând, GHI stă în stânga jos. */
object GhiTouchLayout {
    const val COLS = 4

    fun x(i: Int) = 0.33f + (i % COLS) * 0.19f
    fun y(i: Int) = 0.36f + (i / COLS) * 0.3f

    /** Ce lucru e sub deget (coordonate relative 0..1), sau -1. `radius` e relativ la lățime. */
    fun hit(n: Int, fx: Float, fy: Float, aspect: Float, radius: Float = 0.09f): Int {
        var best = -1
        var bestD = Float.MAX_VALUE
        for (i in 0 until n) {
            val dx = fx - x(i)
            val dy = (fy - y(i)) / aspect
            val d = dx * dx + dy * dy
            if (d < radius * radius && d < bestD) { best = i; bestD = d }
        }
        return best
    }

    /** Mutarea cu săgețile pe TV: stânga/dreapta pe rând, sus/jos între rânduri. */
    fun move(i: Int, n: Int, dx: Int, dy: Int): Int {
        val j = i + dx + dy * COLS
        return if (j in 0 until n) j else i
    }
}

/**
 * Ecran sănătos pentru cei mici: pauză de clipit la 5 minute, odihnă după limita sesiunii
 * (sau după 3 episoade la rând) și culori mai calde seara.
 */
object ScreenCare {
    const val BLINK_EVERY_MS = 5 * 60_000L
    const val BLINK_MS = 25_000L
    const val LOOK_AWAY_AT_MS = 9_000L
    const val MAX_EPISODES = 3
    const val UNLOCK_HOLD_MS = 3_000L
    val LIMITS = listOf(15, 20, 30, 0)
    const val DEFAULT_LIMIT = 20

    sealed interface State {
        data object Play : State
        data class Blink(val ms: Long) : State
        data object Rest : State
    }

    fun state(activeMs: Long, limitMin: Int, episodesInRow: Int): State = when {
        (limitMin > 0 && activeMs >= limitMin * 60_000L) || episodesInRow >= MAX_EPISODES -> State.Rest
        activeMs >= BLINK_EVERY_MS && activeMs % BLINK_EVERY_MS < BLINK_MS -> State.Blink(activeMs % BLINK_EVERY_MS)
        else -> State.Play
    }

    fun blinkCaption(ms: Long) =
        if (ms < LOOK_AWAY_AT_MS) "Hai să clipim împreună!" else "Acum uită-te departe, pe fereastră…"

    /** Trei clipiri lente, cât GHI ne arată cum. */
    fun eyesClosed(ms: Long) = ms < LOOK_AWAY_AT_MS && (ms % 3_000L) in 1_200L until 2_200L

    /** Cât de cald/întunecat devine ecranul seara: 0 până la 19:00, apoi crește până la 0,3 la 21:00. */
    fun eveningDim(hour: Int, minute: Int): Float {
        val h = hour + minute / 60f
        return when {
            h < 6f -> 0.3f
            h < 19f -> 0f
            else -> ((h - 19f) / 2f).coerceIn(0f, 1f) * 0.3f
        }
    }

    fun limitLabel(min: Int) = if (min == 0) "Fără limită" else "$min min"
}
