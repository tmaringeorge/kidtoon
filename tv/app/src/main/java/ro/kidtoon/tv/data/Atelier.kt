package ro.kidtoon.tv.data

import java.io.File
import java.util.Calendar
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/** Paleta Atelierului (ca pe telefon): culori vii, ușor de deosebit, plus alb și negru. ARGB. */
object KidPalette {
    val colors = longArrayOf(
        0xFFFF3B30, // roșu
        0xFFFF9500, // portocaliu
        0xFFFFCC00, // galben
        0xFF34C759, // verde
        0xFF00C7BE, // turcoaz
        0xFF32ADE6, // albastru deschis
        0xFF007AFF, // albastru
        0xFFAF52DE, // mov
        0xFFFF2D92, // roz
        0xFFA2845E, // maro
        0xFFFFD1B3, // piele
        0xFF8E8E93, // gri
        0xFF000000, // negru
        0xFFFFFFFF, // alb
    )

    /** Numele culorilor, pentru vocea care le spune. */
    val names = listOf(
        "roșu", "portocaliu", "galben", "verde", "turcoaz", "albastru deschis", "albastru",
        "mov", "roz", "maro", "culoarea pielii", "gri", "negru", "alb",
    )

    val size get() = colors.size
}

/** Abțibildurile din „Construiește” și ștampilele din „Desenează”. */
val kidStickers = listOf(
    "⭐", "❤️", "🌸", "🌳", "☀️", "☁️", "🌈", "🐶", "🐱", "🐰", "🦋", "🐞",
    "🐟", "🦖", "🚗", "🚂", "✈️", "🎈", "🍎", "🏰", "👑", "🎁", "🚀", "🌙",
)

/**
 * Telecomanda în Atelier: cursorul (0..1 pe foaie) se mișcă puțin la o apăsare
 * și tot mai repede cât ții săgeata apăsată.
 */
object DpadCursor {
    const val STEP = 0.01f
    const val MAX_STEP = 0.05f

    fun step(repeat: Int) = (STEP * (1 + repeat / 3f)).coerceAtMost(MAX_STEP)

    fun move(x: Float, y: Float, dx: Int, dy: Int, repeat: Int): Pair<Float, Float> {
        val s = step(repeat)
        return (x + dx * s).coerceIn(0f, 1f) to (y + dy * s).coerceIn(0f, 1f)
    }
}

/** Colorat cu telecomanda: următoarea zonă în direcția săgeții, după centrele zonelor. */
object ColoringNav {
    /** [centers] sunt (x, y) pe pagină; dx, dy sunt -1, 0 sau 1. Întoarce -1 la margine. */
    fun neighbor(centers: List<Pair<Float, Float>>, from: Int, dx: Int, dy: Int): Int {
        if (from !in centers.indices) return centers.lastIndex
        val (cx, cy) = centers[from]
        var best = -1
        var bestScore = Float.MAX_VALUE
        for (i in centers.indices) {
            if (i == from) continue
            val ddx = centers[i].first - cx
            val ddy = centers[i].second - cy
            val along = ddx * dx + ddy * dy
            if (along <= 0.5f) continue
            val across = abs(ddx * dy) + abs(ddy * dx)
            val score = along + across * 2
            if (score < bestScore) { bestScore = score; best = i }
        }
        return best
    }
}

// ---------------- Construiește ----------------

enum class PieceShape(val emoji: String, val label: String) {
    SQUARE("🟥", "Pătrat"), RECT("▬", "Dreptunghi"), CIRCLE("🔴", "Cerc"), TRIANGLE("🔺", "Triunghi"),
    STAR("⭐", "Stea"), HEART("❤️", "Inimă"), HALF("◗", "Semicerc"), HEXAGON("⬢", "Hexagon"), EMOJI("🙂", "Abțibild"),
}

/**
 * O piesă din „Construiește”: o formă colorată sau un abțibild,
 * cu poziția (0..1 din foaie), mărimea (din latura mică) și rotirea (radiani).
 */
data class Piece(
    val shape: PieceShape,
    val color: Long = KidPalette.colors[0],
    val emoji: String = "",
    val x: Float = 0.5f,
    val y: Float = 0.5f,
    val size: Float = 0.18f,
    val angle: Float = 0f,
) {
    fun moveBy(dx: Float, dy: Float) = copy(x = (x + dx).coerceIn(0f, 1f), y = (y + dy).coerceIn(0f, 1f))

    fun scaleBy(f: Float) = copy(size = (size * f).coerceIn(MIN_SIZE, MAX_SIZE))

    fun rotateBy(a: Float) = copy(angle = angle + a)

    /** Lățimea și înălțimea relativă (dreptunghiul și semicercul sunt mai late). */
    val aspect: Pair<Float, Float>
        get() = when (shape) {
            PieceShape.RECT -> 1.6f to 0.8f
            PieceShape.HALF -> 1.0f to 0.5f
            else -> 1f to 1f
        }

    /** E punctul (0..1) pe piesă? [ratio] = înălțime / lățime a foii. */
    fun contains(px: Float, py: Float, ratio: Float): Boolean {
        val w = if (ratio < 1) 1 / ratio else 1f
        val h = if (ratio < 1) 1f else ratio
        val lx = (px - x) * w
        val ly = (py - y) * h
        val c = cos(-angle)
        val s = sin(-angle)
        val rx = lx * c - ly * s
        val ry = lx * s + ly * c
        val (ax, ay) = aspect
        return abs(rx) <= size * ax / 2 + 0.01f && abs(ry) <= size * ay / 2 + 0.01f
    }

    companion object {
        const val MIN_SIZE = 0.05f
        const val MAX_SIZE = 0.9f
    }
}

/** Idei de început în „Construiește”: o căsuță, un robot, un tren, o rachetă. */
class BuildTemplate(val title: String, val emoji: String, val background: Int, val make: () -> List<Piece>)

private fun p(i: Int) = KidPalette.colors[i]
private const val UP = 1.5708f

val buildTemplates = listOf(
    BuildTemplate("Foaie goală", "📄", 0) { emptyList() },
    BuildTemplate("Căsuța", "🏠", 0) {
        listOf(
            Piece(PieceShape.SQUARE, p(2), x = 0.5f, y = 0.62f, size = 0.34f),
            Piece(PieceShape.TRIANGLE, p(0), x = 0.5f, y = 0.31f, size = 0.36f),
            Piece(PieceShape.RECT, p(9), x = 0.5f, y = 0.7f, size = 0.1f, angle = UP),
            Piece(PieceShape.SQUARE, p(5), x = 0.44f, y = 0.6f, size = 0.08f),
            Piece(PieceShape.SQUARE, p(5), x = 0.56f, y = 0.6f, size = 0.08f),
            Piece(PieceShape.EMOJI, emoji = "🌳", x = 0.82f, y = 0.62f, size = 0.26f),
            Piece(PieceShape.EMOJI, emoji = "☀️", x = 0.14f, y = 0.16f, size = 0.16f),
        )
    },
    BuildTemplate("Robotul", "🤖", 2) {
        listOf(
            Piece(PieceShape.SQUARE, p(11), x = 0.5f, y = 0.3f, size = 0.2f),
            Piece(PieceShape.CIRCLE, p(2), x = 0.45f, y = 0.28f, size = 0.05f),
            Piece(PieceShape.CIRCLE, p(2), x = 0.55f, y = 0.28f, size = 0.05f),
            Piece(PieceShape.RECT, p(6), x = 0.5f, y = 0.56f, size = 0.24f, angle = UP),
            Piece(PieceShape.RECT, p(11), x = 0.4f, y = 0.5f, size = 0.14f),
            Piece(PieceShape.RECT, p(11), x = 0.6f, y = 0.5f, size = 0.14f),
            Piece(PieceShape.RECT, p(12), x = 0.44f, y = 0.84f, size = 0.12f, angle = UP),
            Piece(PieceShape.RECT, p(12), x = 0.56f, y = 0.84f, size = 0.12f, angle = UP),
            Piece(PieceShape.STAR, p(0), x = 0.5f, y = 0.16f, size = 0.08f),
        )
    },
    BuildTemplate("Trenulețul", "🚂", 0) {
        listOf(
            Piece(PieceShape.RECT, p(0), x = 0.25f, y = 0.62f, size = 0.2f),
            Piece(PieceShape.SQUARE, p(6), x = 0.2f, y = 0.47f, size = 0.12f),
            Piece(PieceShape.RECT, p(3), x = 0.52f, y = 0.62f, size = 0.18f),
            Piece(PieceShape.RECT, p(2), x = 0.77f, y = 0.62f, size = 0.18f),
        ) + listOf(0.18f, 0.32f, 0.46f, 0.58f, 0.71f, 0.83f).map {
            Piece(PieceShape.CIRCLE, p(12), x = it, y = 0.75f, size = 0.08f)
        } + Piece(PieceShape.EMOJI, emoji = "☁️", x = 0.3f, y = 0.3f, size = 0.12f)
    },
    BuildTemplate("Racheta", "🚀", 2) {
        listOf(
            Piece(PieceShape.RECT, p(13), x = 0.5f, y = 0.55f, size = 0.36f, angle = UP),
            Piece(PieceShape.TRIANGLE, p(0), x = 0.5f, y = 0.2f, size = 0.29f),
            Piece(PieceShape.CIRCLE, p(5), x = 0.5f, y = 0.45f, size = 0.09f),
            Piece(PieceShape.TRIANGLE, p(0), x = 0.4f, y = 0.74f, size = 0.12f, angle = -0.5f),
            Piece(PieceShape.TRIANGLE, p(0), x = 0.6f, y = 0.74f, size = 0.12f, angle = 0.5f),
            Piece(PieceShape.EMOJI, emoji = "🔥", x = 0.5f, y = 0.86f, size = 0.12f, angle = 3.1416f),
            Piece(PieceShape.EMOJI, emoji = "🌙", x = 0.82f, y = 0.18f, size = 0.14f),
            Piece(PieceShape.STAR, p(2), x = 0.18f, y = 0.24f, size = 0.07f),
        )
    },
)

/** Fundalurile din „Construiește”: numele și trei culori (sus, mijloc, jos). */
val buildBackgrounds = listOf(
    "Afară" to longArrayOf(0xFF8FD3FF, 0xFFD7F5FF, 0xFF7BD66A),
    "Marea" to longArrayOf(0xFF4FC3F7, 0xFF0288D1, 0xFFFFE0A3),
    "Spațiul" to longArrayOf(0xFF0B1033, 0xFF2A1B5C, 0xFF3A2A7A),
    "Foaie albă" to longArrayOf(0xFFFFFFFF, 0xFFFFFFFF, 0xFFF2F2F2),
)

// ---------------- Galeria ----------------

/** Lucrările copilului, salvate ca imagini PNG în memoria TV-ului. */
class ArtStore(private val dir: File) {

    private fun ensure() = dir.apply { mkdirs() }

    fun save(kind: String, png: ByteArray, at: Calendar = Calendar.getInstance()): File {
        val f = File(ensure(), fileName(kind, at))
        val tmp = File(f.path + ".tmp")
        tmp.writeBytes(png)
        tmp.renameTo(f)
        return f
    }

    /** Cele mai noi primele. */
    fun list(): List<File> =
        (ensure().listFiles() ?: emptyArray()).filter { it.isFile && it.name.endsWith(".png") }
            .sortedByDescending { stamp(it) }

    fun delete(f: File) = f.delete()

    companion object {
        private fun two(n: Int) = n.toString().padStart(2, '0')

        fun fileName(kind: String, t: Calendar): String =
            "${kind}_${t.get(Calendar.YEAR)}${two(t.get(Calendar.MONTH) + 1)}${two(t.get(Calendar.DAY_OF_MONTH))}_" +
                "${two(t.get(Calendar.HOUR_OF_DAY))}${two(t.get(Calendar.MINUTE))}${two(t.get(Calendar.SECOND))}.png"

        /** Data din numele fișierului („desen_20260102_030405.png” → „20260102_030405”). */
        fun stamp(f: File): String {
            val i = f.name.indexOf('_')
            return if (i < 0) f.name else f.name.substring(i + 1)
        }

        fun kindOf(f: File): String = when (f.name.substringBefore('_')) {
            "colorat" -> "🖍️ Colorat"
            "desen" -> "✏️ Desen"
            "construit" -> "🧱 Construit"
            else -> "🎨"
        }
    }
}
