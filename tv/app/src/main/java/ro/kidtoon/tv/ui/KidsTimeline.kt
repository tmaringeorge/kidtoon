package ro.kidtoon.tv.ui

import ro.kidtoon.tv.data.RadioBackground
import kotlin.math.floor
import kotlin.math.min

/**
 * Logica (fara desen) pentru animatiile pentru copii din playerul radio.
 *
 * Fiecare scena are un ciclu de un minut. In modul "toate pe rand" o scena tine
 * doua minute, apoi vine alta; ordinea se roteste dupa fiecare tura, iar culorile,
 * animalele si fructele se schimba la fiecare minut, asa ca imaginea nu se repeta
 * timp de o ora. Totul e lent, fara sclipiri.
 */
object KidsTimeline {
    const val CYCLE_MS = 60_000L
    const val CYCLES_PER_SCENE = 2

    val ROTATION = listOf(
        RadioBackground.SKY, RadioBackground.OCEAN, RadioBackground.FARM,
        RadioBackground.BALLOONS, RadioBackground.TRAIN, RadioBackground.SHAPES,
        RadioBackground.FOOTBALL, RadioBackground.SORCOVA, RadioBackground.SANTA,
        RadioBackground.DINOS, RadioBackground.FIREFIGHTERS, RadioBackground.DOCTOR,
        RadioBackground.ZOO, RadioBackground.TREES,
    )

    /** Ce se deseneaza acum: scena, pozitia in ciclu (0..1) si varianta (minutul). */
    data class Frame(val scene: RadioBackground, val t: Float, val variant: Int, val segment: Int)

    fun frame(elapsedMs: Long, mode: RadioBackground): Frame {
        val cycle = (elapsedMs / CYCLE_MS).toInt()
        val t = (elapsedMs % CYCLE_MS) / CYCLE_MS.toFloat()
        if (mode != RadioBackground.ALL) return Frame(mode, t, cycle, 0)
        val segment = cycle / CYCLES_PER_SCENE
        val round = segment / ROTATION.size
        return Frame(ROTATION[(segment + round) % ROTATION.size], t, cycle, segment)
    }

    // ---- Date comune ----
    class KidColor(val masc: String, val fem: String, val argb: Long)

    val COLORS = listOf(
        KidColor("roșu", "roșie", 0xFFE53935),
        KidColor("galben", "galbenă", 0xFFFDD835),
        KidColor("albastru", "albastră", 0xFF1E88E5),
        KidColor("verde", "verde", 0xFF43A047),
        KidColor("portocaliu", "portocalie", 0xFFFB8C00),
        KidColor("mov", "mov", 0xFF8E24AA),
        KidColor("roz", "roz", 0xFFF06292),
        KidColor("alb", "albă", 0xFFFFFFFF),
    )

    class Animal(val name: String, val emoji: String, val sound: String)

    val ANIMALS = listOf(
        Animal("Vaca", "🐄", "Muu!"),
        Animal("Oaia", "🐑", "Beee!"),
        Animal("Rața", "🦆", "Mac-mac!"),
        Animal("Cățelul", "🐶", "Ham-ham!"),
        Animal("Pisica", "🐱", "Miau!"),
        Animal("Purcelul", "🐷", "Oinc-oinc!"),
        Animal("Calul", "🐴", "Ihaha!"),
        Animal("Găina", "🐔", "Cot-cot!"),
        Animal("Capra", "🐐", "Meee!"),
        Animal("Cocoșul", "🐓", "Cucurigu!"),
    )

    class Fruit(val emoji: String, val one: String, val many: String)

    val FRUITS = listOf(
        Fruit("🍎", "un măr", "mere"),
        Fruit("🍐", "o pară", "pere"),
        Fruit("🍊", "o portocală", "portocale"),
        Fruit("🍌", "o banană", "banane"),
        Fruit("🍓", "o căpșună", "căpșuni"),
    )

    enum class Shape(val label: String, val feminine: Boolean) {
        CIRCLE("Cercul", false), SQUARE("Pătratul", false), TRIANGLE("Triunghiul", false),
        STAR("Steaua", true), HEART("Inima", true),
    }

    private val femNumbers = listOf("", "o", "două", "trei", "patru", "cinci")

    // ---- Ocean: pestii apar unul cate unul ----
    const val FISH_START = 0.10f
    const val FISH_STEP = 0.14f
    fun fishVisible(t: Float): Int = if (t < FISH_START) 0 else min(5, ((t - FISH_START) / FISH_STEP).toInt() + 1)
    fun fishColor(variant: Int, i: Int) = COLORS[(variant * 3 + i) % 7] // fara alb in apa
    private val fishWords = listOf("un pește", "doi pești", "trei pești", "patru pești", "cinci pești")

    // ---- Ferma: cinci animale pe minut ----
    fun farmSlot(t: Float): Int = min(4, (t * 5).toInt())
    fun animal(variant: Int, slot: Int) = ANIMALS[(variant * 3 + slot) % ANIMALS.size]

    // ---- Baloane: urca pe rand ----
    const val BALLOON_START = 0.03f
    const val BALLOON_STEP = 0.15f
    const val BALLOON_RISE = 0.36f
    fun balloonColor(variant: Int, i: Int) = COLORS[(variant * 5 + i) % COLORS.size]
    fun balloonsLaunched(t: Float): Int =
        if (t < BALLOON_START) 0 else min(5, ((t - BALLOON_START) / BALLOON_STEP).toInt() + 1)

    // ---- Tren: locomotiva + 5 vagoane, vagonul k duce k fructe ----
    /** Latimea ecranului in "vagoane" si lungimea trenului (locomotiva + 5 vagoane). */
    const val SCREEN_CARS = 6.25f
    const val TRAIN_CARS = 6f
    fun trainProgress(t: Float): Float = ((t - 0.05f) / 0.9f).coerceIn(0f, 1f)
    /** Pozitia botului locomotivei, in vagoane de la marginea stanga. */
    fun trainFront(t: Float): Float = trainProgress(t) * (SCREEN_CARS + TRAIN_CARS)
    /** Ce vagon e acum in mijlocul ecranului: -1 = inca nu a venit, 0 = locomotiva, 6 = a plecat. */
    fun carAtCenter(t: Float): Int = floor(trainFront(t) - SCREEN_CARS / 2).toInt().coerceIn(-1, 6)
    fun fruit(variant: Int) = FRUITS[variant % FRUITS.size]

    // ---- Forme: cinci forme pe minut ----
    fun shapeSlot(t: Float): Int = min(4, (t * 5).toInt())
    fun shape(variant: Int, slot: Int) = Shape.entries[(variant + slot) % Shape.entries.size]
    fun shapeColor(variant: Int, slot: Int) = COLORS[(variant * 2 + slot) % COLORS.size]

    // ---- Fotbal: cinci suturi pe minut, fiecare e gol ----
    const val KICK_AT = 0.15f
    const val GOAL_AT = 0.6f
    fun kickSlot(t: Float): Int = min(4, (t * 5).toInt())
    fun kickLocal(t: Float): Float = t * 5 - kickSlot(t)
    fun goals(t: Float): Int = kickSlot(t) + if (kickLocal(t) >= GOAL_AT) 1 else 0
    private val goalWords = listOf("un gol", "două goluri", "trei goluri", "patru goluri", "cinci goluri")

    // ---- Sorcova: un vers la fiecare 12 secunde ----
    val SORCOVA_VERSES = listOf(
        "Sorcova, vesela,", "Să trăiți, să-mbătrâniți,", "Ca un măr, ca un păr,",
        "Ca un fir de trandafir!", "La anul și la mulți ani!",
    )
    fun verse(t: Float): Int = min(4, (t * 5).toInt())

    // ---- Mos Craciun: sania trece pe cer si lasa cinci cadouri sub brad ----
    const val GIFT_FIRST = 0.15f
    const val GIFT_STEP = 0.13f
    const val GIFT_FALL = 0.06f
    fun sleighProgress(t: Float): Float = ((t - 0.05f) / 0.8f).coerceIn(0f, 1f)
    fun giftsLanded(t: Float): Int = (0 until 5).count { t >= GIFT_FIRST + it * GIFT_STEP + GIFT_FALL }
    private val giftWords = listOf("un cadou", "două cadouri", "trei cadouri", "patru cadouri", "cinci cadouri")

    // ---- Dinozauri: apar unul cate unul si se plimba ----
    fun dinosVisible(t: Float): Int = fishVisible(t)
    private val dinoWords = listOf("un dinozaur", "doi dinozauri", "trei dinozauri", "patru dinozauri", "cinci dinozauri")

    // ---- Pompierii: o poveste in patru parti ----
    /** 0 = arde putin, 1 = vine masina, 2 = sting focul, 3 = gata. */
    fun firePhase(t: Float): Int = when {
        t < 0.2f -> 0
        t < 0.45f -> 1
        t < 0.8f -> 2
        else -> 3
    }
    /** Cat de mare e focul (1 = cat la inceput, 0 = stins). */
    fun fireSize(t: Float): Float = when {
        t < 0.5f -> 1f
        t < 0.78f -> 1f - (t - 0.5f) / 0.28f
        else -> 0f
    }
    /** Pozitia masinii: 0 = in afara ecranului (stanga), 1 = langa casa. */
    fun truckArrive(t: Float): Float = ((t - 0.2f) / 0.22f).coerceIn(0f, 1f)

    // ---- La doctor: pacientul se loveste, e consultat, primeste plasture, e sanatos ----
    class Patient(val name: String, val emoji: String)
    val PATIENTS = listOf(
        Patient("Ursulețul", "🧸"), Patient("Cățelul", "🐶"), Patient("Iepurașul", "🐰"), Patient("Puiul", "🐥"),
    )
    fun patient(variant: Int) = PATIENTS[variant % PATIENTS.size]
    fun doctorStep(t: Float): Int = min(3, (t * 4).toInt())

    // ---- Zoo: cinci animale pe minut ----
    class ZooAnimal(val emoji: String, val caption: String)
    val ZOO = listOf(
        ZooAnimal("🦁", "Leul face Rrrr!"), ZooAnimal("🐘", "Elefantul face Tuuu!"),
        ZooAnimal("🦒", "Girafa are gâtul lung"), ZooAnimal("🐒", "Maimuța face U-u-a-a!"),
        ZooAnimal("🦓", "Zebra are dungi"), ZooAnimal("🐻", "Ursul face Mmm!"),
        ZooAnimal("🐧", "Pinguinul merge legănat"), ZooAnimal("🐯", "Tigrul face Rrrr!"),
        ZooAnimal("🐊", "Crocodilul face Clap-clap!"), ZooAnimal("🦛", "Hipopotamul cască gura"),
    )
    fun zooSlot(t: Float): Int = min(4, (t * 5).toInt())
    fun zooAnimal(variant: Int, slot: Int) = ZOO[(variant * 3 + slot) % ZOO.size]

    // ---- Plantam copaci: cinci copaci pe minut ----
    fun treeSlot(t: Float): Int = min(4, (t * 5).toInt())
    fun treeLocal(t: Float): Float = t * 5 - treeSlot(t)
    /** Cat de crescut e copacul de acum (0 = samanta, 1 = copac mare). */
    fun treeGrowth(t: Float): Float = ((treeLocal(t) - 0.45f) / 0.35f).coerceIn(0f, 1f)
    private val treeWords = listOf("un copac", "doi copaci", "trei copaci", "patru copaci", "cinci copaci")

    fun caption(f: Frame): String = when (f.scene) {
        RadioBackground.OCEAN -> {
            val n = fishVisible(f.t)
            when {
                f.t >= 0.86f -> "Pa-pa, peștișori!"
                n == 0 -> "Hai în mare!"
                else -> "$n · ${fishWords[n - 1]}"
            }
        }
        RadioBackground.FARM -> animal(f.variant, farmSlot(f.t)).let { "${it.name} face ${it.sound}" }
        RadioBackground.BALLOONS -> {
            val n = balloonsLaunched(f.t)
            if (n == 0) "Baloane colorate!" else "Balonul ${balloonColor(f.variant, n - 1).masc}"
        }
        RadioBackground.TRAIN -> when (val k = carAtCenter(f.t)) {
            -1 -> "Ciu-ciu! Vine trenul!"
            0 -> "Locomotiva face: tu-tuuu!"
            6 -> "Pa-pa, trenule!"
            else -> fruit(f.variant).let { "$k · " + if (k == 1) it.one else "${femNumbers[k]} ${it.many}" }
        }
        RadioBackground.SHAPES -> {
            val slot = shapeSlot(f.t)
            val s = shape(f.variant, slot)
            val c = shapeColor(f.variant, slot)
            "${s.label} ${if (s.feminine) c.fem else c.masc}"
        }
        RadioBackground.FOOTBALL -> {
            val g = goals(f.t)
            if (kickLocal(f.t) >= GOAL_AT) "Gooool! $g · ${goalWords[g - 1]}" else "Hai, șutează!"
        }
        RadioBackground.SORCOVA -> SORCOVA_VERSES[verse(f.t)]
        RadioBackground.SANTA -> {
            val n = giftsLanded(f.t)
            when {
                f.t >= 0.9f -> "Crăciun fericit!"
                n == 0 -> "Ho-ho-ho! Vine Moș Crăciun!"
                else -> "$n · ${giftWords[n - 1]}"
            }
        }
        RadioBackground.DINOS -> {
            val n = dinosVisible(f.t)
            when {
                f.t >= 0.86f -> "Pa-pa, dinozauri!"
                n == 0 -> "Hai la dinozauri!"
                else -> "$n · ${dinoWords[n - 1]}"
            }
        }
        RadioBackground.FIREFIGHTERS -> when (firePhase(f.t)) {
            0 -> "Iese fum! Sunăm la pompieri"
            1 -> "Nino-nino! Vin pompierii!"
            2 -> "Pompierii sting focul cu apă"
            else -> "Bravo, pompierilor!"
        }
        RadioBackground.DOCTOR -> patient(f.variant).name.let { p ->
            when (doctorStep(f.t)) {
                0 -> "$p s-a lovit la lăbuță"
                1 -> "Doctorița îl ascultă: bum-bum"
                2 -> "Îi pune un plasture"
                else -> "$p e sănătos! Mulțumim!"
            }
        }
        RadioBackground.ZOO -> zooAnimal(f.variant, zooSlot(f.t)).caption
        RadioBackground.TREES -> {
            val local = treeLocal(f.t)
            val n = treeSlot(f.t) + 1
            when {
                local < 0.25f -> "Săpăm o groapă"
                local < 0.45f -> "Punem sămânța și udăm"
                local < 0.8f -> "Copacul crește…"
                else -> "$n · ${treeWords[n - 1]}"
            }
        }
        else -> SkyTimeline.caption(f.t)
    }
}

/** Temporizatorul de somn din playerul radio: oprit -> 30 -> 60 -> 90 -> oprit. */
object SleepTimer {
    val OPTIONS = listOf(30, 60, 90)

    /** Urmatoarea valoare dupa cate minute au mai ramas (0 = oprit). */
    fun next(leftMin: Int): Int = OPTIONS.firstOrNull { it > leftMin } ?: 0

    fun hint(leftMin: Int): String = when (val n = next(leftMin)) {
        0 -> "fără oprire"
        else -> "oprire după $n min"
    }
}
