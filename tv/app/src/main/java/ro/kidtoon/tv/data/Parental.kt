package ro.kidtoon.tv.data

import kotlin.random.Random

/**
 * O întrebare pentru părinți („Cât face 7 × 8?”), ușor de rezolvat de un adult,
 * greu pentru un copil mic. Se răspunde din butoane mari, cu telecomanda.
 */
class ParentQuestion(val a: Int, val b: Int) {
    val answer get() = a * b
    val text get() = "Cât face $a × $b?"

    /** Patru variante, una corectă, amestecate. */
    fun choices(rnd: Random = Random.Default): List<Int> {
        val set = linkedSetOf(answer)
        val near = mutableListOf(answer + a, answer - b, answer + 1 + rnd.nextInt(4), answer - 2 - rnd.nextInt(5), answer + 10)
        near.shuffle(rnd)
        for (n in near) {
            if (set.size >= 4) break
            if (n > 0) set += n
        }
        return set.toMutableList().apply { shuffle(rnd) }
    }

    fun check(value: Int) = value == answer

    companion object {
        fun random(rnd: Random = Random.Default) = ParentQuestion(3 + rnd.nextInt(7), 4 + rnd.nextInt(6))
    }
}

/** Codul PIN al părinților: 4 cifre. Gol = doar întrebarea de mai sus. */
object ParentPin {
    fun isValid(pin: String) = Regex("""^\d{4}$""").matches(pin)
}

/** Ce posturi vede copilul la „Desene TV”. */
object KidFilter {
    /** Categoriile potrivite pentru copii (deja traduse în română de parserul M3U). */
    val kidCategories = setOf("Copii", "Educație", "Familie")

    fun isForKids(c: Channel) = c.categories.any { it in kidCategories }

    /** [kidsOnly] păstrează doar desenele și educativele; [hidden] sunt posturile ascunse de părinte. */
    fun apply(all: List<Channel>, kidsOnly: Boolean, hidden: Set<String> = emptySet()) =
        all.filter { it.key !in hidden && (!kidsOnly || isForKids(it)) }

    val label get() = kidCategories.joinToString(", ")
}
