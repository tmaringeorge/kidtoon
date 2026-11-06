import 'dart:math';

import '../data/radio.dart';
import 'sky_animation.dart';

/// Logica (fără desen) pentru animațiile pentru copii din playerul radio.
///
/// Fiecare scenă are un ciclu de un minut. În modul „toate pe rând” o scenă ține
/// două minute, apoi vine alta; ordinea se rotește după fiecare tură, iar culorile,
/// animalele și fructele se schimbă la fiecare minut, așa că imaginea nu se repetă
/// timp de o oră. Totul e lent, fără sclipiri. (Aceeași logică ca pe TV.)
class KidsFrame {
  const KidsFrame(this.scene, this.t, this.variant, this.segment);
  final RadioBackground scene;
  final double t;
  final int variant;
  final int segment;
}

class KidColor {
  const KidColor(this.masc, this.fem, this.argb);
  final String masc;
  final String fem;
  final int argb;
}

class Animal {
  const Animal(this.name, this.emoji, this.sound);
  final String name;
  final String emoji;
  final String sound;
}

class Fruit {
  const Fruit(this.emoji, this.one, this.many);
  final String emoji;
  final String one;
  final String many;
}

enum KidShape {
  circle('Cercul', false),
  square('Pătratul', false),
  triangle('Triunghiul', false),
  star('Steaua', true),
  heart('Inima', true);

  const KidShape(this.label, this.feminine);
  final String label;
  final bool feminine;
}

class KidsTimeline {
  static const cycleMs = 60000;
  static const cyclesPerScene = 2;
  static const rotation = [
    RadioBackground.sky,
    RadioBackground.ocean,
    RadioBackground.farm,
    RadioBackground.balloons,
    RadioBackground.train,
    RadioBackground.shapes,
    RadioBackground.football,
    RadioBackground.sorcova,
    RadioBackground.santa,
    RadioBackground.dinos,
    RadioBackground.firefighters,
    RadioBackground.doctor,
    RadioBackground.zoo,
    RadioBackground.trees,
  ];

  static KidsFrame frame(int elapsedMs, RadioBackground mode) {
    final cycle = elapsedMs ~/ cycleMs;
    final t = (elapsedMs % cycleMs) / cycleMs;
    if (mode != RadioBackground.all) return KidsFrame(mode, t, cycle, 0);
    final segment = cycle ~/ cyclesPerScene;
    final round = segment ~/ rotation.length;
    return KidsFrame(rotation[(segment + round) % rotation.length], t, cycle, segment);
  }

  static const colors = [
    KidColor('roșu', 'roșie', 0xFFE53935),
    KidColor('galben', 'galbenă', 0xFFFDD835),
    KidColor('albastru', 'albastră', 0xFF1E88E5),
    KidColor('verde', 'verde', 0xFF43A047),
    KidColor('portocaliu', 'portocalie', 0xFFFB8C00),
    KidColor('mov', 'mov', 0xFF8E24AA),
    KidColor('roz', 'roz', 0xFFF06292),
    KidColor('alb', 'albă', 0xFFFFFFFF),
  ];

  static const animals = [
    Animal('Vaca', '🐄', 'Muu!'),
    Animal('Oaia', '🐑', 'Beee!'),
    Animal('Rața', '🦆', 'Mac-mac!'),
    Animal('Cățelul', '🐶', 'Ham-ham!'),
    Animal('Pisica', '🐱', 'Miau!'),
    Animal('Purcelul', '🐷', 'Oinc-oinc!'),
    Animal('Calul', '🐴', 'Ihaha!'),
    Animal('Găina', '🐔', 'Cot-cot!'),
    Animal('Capra', '🐐', 'Meee!'),
    Animal('Cocoșul', '🐓', 'Cucurigu!'),
  ];

  static const fruits = [
    Fruit('🍎', 'un măr', 'mere'),
    Fruit('🍐', 'o pară', 'pere'),
    Fruit('🍊', 'o portocală', 'portocale'),
    Fruit('🍌', 'o banană', 'banane'),
    Fruit('🍓', 'o căpșună', 'căpșuni'),
  ];

  static const _femNumbers = ['', 'o', 'două', 'trei', 'patru', 'cinci'];

  // Ocean
  static const fishStart = 0.10, fishStep = 0.14;
  static int fishVisible(double t) => t < fishStart ? 0 : min(5, ((t - fishStart) / fishStep).floor() + 1);
  static KidColor fishColor(int variant, int i) => colors[(variant * 3 + i) % 7];
  static const _fishWords = ['un pește', 'doi pești', 'trei pești', 'patru pești', 'cinci pești'];

  // Fermă
  static int farmSlot(double t) => min(4, (t * 5).floor());
  static Animal animal(int variant, int slot) => animals[(variant * 3 + slot) % animals.length];

  // Baloane
  static const balloonStart = 0.03, balloonStep = 0.15, balloonRise = 0.36;
  static KidColor balloonColor(int variant, int i) => colors[(variant * 5 + i) % colors.length];
  static int balloonsLaunched(double t) =>
      t < balloonStart ? 0 : min(5, ((t - balloonStart) / balloonStep).floor() + 1);

  // Tren
  static const screenCars = 6.25, trainCars = 6.0;
  static double trainProgress(double t) => ((t - 0.05) / 0.9).clamp(0.0, 1.0);
  static double trainFront(double t) => trainProgress(t) * (screenCars + trainCars);
  static int carAtCenter(double t) => (trainFront(t) - screenCars / 2).floor().clamp(-1, 6);
  static Fruit fruit(int variant) => fruits[variant % fruits.length];

  // Forme
  static int shapeSlot(double t) => min(4, (t * 5).floor());
  static KidShape shape(int variant, int slot) => KidShape.values[(variant + slot) % KidShape.values.length];
  static KidColor shapeColor(int variant, int slot) => colors[(variant * 2 + slot) % colors.length];

  // Fotbal: cinci șuturi pe minut, fiecare e gol
  static const kickAt = 0.15, goalAt = 0.6;
  static int kickSlot(double t) => min(4, (t * 5).floor());
  static double kickLocal(double t) => t * 5 - kickSlot(t);
  static int goals(double t) => kickSlot(t) + (kickLocal(t) >= goalAt ? 1 : 0);
  static const _goalWords = ['un gol', 'două goluri', 'trei goluri', 'patru goluri', 'cinci goluri'];

  // Sorcova: un vers la fiecare 12 secunde
  static const sorcovaVerses = [
    'Sorcova, vesela,',
    'Să trăiți, să-mbătrâniți,',
    'Ca un măr, ca un păr,',
    'Ca un fir de trandafir!',
    'La anul și la mulți ani!',
  ];
  static int verse(double t) => min(4, (t * 5).floor());

  // Moș Crăciun: sania trece pe cer și lasă cinci cadouri sub brad
  static const giftFirst = 0.15, giftStep = 0.13, giftFall = 0.06;
  static double sleighProgress(double t) => ((t - 0.05) / 0.8).clamp(0.0, 1.0);
  static int giftsLanded(double t) =>
      [for (var i = 0; i < 5; i++) i].where((i) => t >= giftFirst + i * giftStep + giftFall).length;
  static const _giftWords = ['un cadou', 'două cadouri', 'trei cadouri', 'patru cadouri', 'cinci cadouri'];

  // Dinozauri: apar unul câte unul și se plimbă
  static int dinosVisible(double t) => fishVisible(t);
  static const _dinoWords = ['un dinozaur', 'doi dinozauri', 'trei dinozauri', 'patru dinozauri', 'cinci dinozauri'];

  // Pompierii: 0 = iese fum, 1 = vine mașina, 2 = sting focul, 3 = gata
  static int firePhase(double t) => t < 0.2 ? 0 : (t < 0.45 ? 1 : (t < 0.8 ? 2 : 3));
  static double fireSize(double t) => t < 0.5 ? 1 : (t < 0.78 ? 1 - (t - 0.5) / 0.28 : 0);
  static double truckArrive(double t) => ((t - 0.2) / 0.22).clamp(0.0, 1.0);

  // La doctor
  static const patients = [('Ursulețul', '🧸'), ('Cățelul', '🐶'), ('Iepurașul', '🐰'), ('Puiul', '🐥')];
  static (String, String) patient(int variant) => patients[variant % patients.length];
  static int doctorStep(double t) => min(3, (t * 4).floor());

  // Zoo
  static const zoo = [
    ('🦁', 'Leul face Rrrr!'),
    ('🐘', 'Elefantul face Tuuu!'),
    ('🦒', 'Girafa are gâtul lung'),
    ('🐒', 'Maimuța face U-u-a-a!'),
    ('🦓', 'Zebra are dungi'),
    ('🐻', 'Ursul face Mmm!'),
    ('🐧', 'Pinguinul merge legănat'),
    ('🐯', 'Tigrul face Rrrr!'),
    ('🐊', 'Crocodilul face Clap-clap!'),
    ('🦛', 'Hipopotamul cască gura'),
  ];
  static int zooSlot(double t) => min(4, (t * 5).floor());
  static (String, String) zooAnimal(int variant, int slot) => zoo[(variant * 3 + slot) % zoo.length];

  // Plantăm copaci
  static int treeSlot(double t) => min(4, (t * 5).floor());
  static double treeLocal(double t) => t * 5 - treeSlot(t);
  static double treeGrowth(double t) => ((treeLocal(t) - 0.45) / 0.35).clamp(0.0, 1.0);
  static const _treeWords = ['un copac', 'doi copaci', 'trei copaci', 'patru copaci', 'cinci copaci'];

  static String caption(KidsFrame f) {
    switch (f.scene) {
      case RadioBackground.ocean:
        final n = fishVisible(f.t);
        if (f.t >= 0.86) return 'Pa-pa, peștișori!';
        return n == 0 ? 'Hai în mare!' : '$n · ${_fishWords[n - 1]}';
      case RadioBackground.farm:
        final a = animal(f.variant, farmSlot(f.t));
        return '${a.name} face ${a.sound}';
      case RadioBackground.balloons:
        final n = balloonsLaunched(f.t);
        return n == 0 ? 'Baloane colorate!' : 'Balonul ${balloonColor(f.variant, n - 1).masc}';
      case RadioBackground.train:
        final k = carAtCenter(f.t);
        if (k == -1) return 'Ciu-ciu! Vine trenul!';
        if (k == 0) return 'Locomotiva face: tu-tuuu!';
        if (k == 6) return 'Pa-pa, trenule!';
        final fr = fruit(f.variant);
        return '$k · ${k == 1 ? fr.one : '${_femNumbers[k]} ${fr.many}'}';
      case RadioBackground.shapes:
        final slot = shapeSlot(f.t);
        final s = shape(f.variant, slot);
        final c = shapeColor(f.variant, slot);
        return '${s.label} ${s.feminine ? c.fem : c.masc}';
      case RadioBackground.football:
        final g = goals(f.t);
        return kickLocal(f.t) >= goalAt ? 'Gooool! $g · ${_goalWords[g - 1]}' : 'Hai, șutează!';
      case RadioBackground.sorcova:
        return sorcovaVerses[verse(f.t)];
      case RadioBackground.santa:
        final n = giftsLanded(f.t);
        if (f.t >= 0.9) return 'Crăciun fericit!';
        return n == 0 ? 'Ho-ho-ho! Vine Moș Crăciun!' : '$n · ${_giftWords[n - 1]}';
      case RadioBackground.dinos:
        final n = dinosVisible(f.t);
        if (f.t >= 0.86) return 'Pa-pa, dinozauri!';
        return n == 0 ? 'Hai la dinozauri!' : '$n · ${_dinoWords[n - 1]}';
      case RadioBackground.firefighters:
        return const [
          'Iese fum! Sunăm la pompieri',
          'Nino-nino! Vin pompierii!',
          'Pompierii sting focul cu apă',
          'Bravo, pompierilor!',
        ][firePhase(f.t)];
      case RadioBackground.doctor:
        final p = patient(f.variant).$1;
        return [
          '$p s-a lovit la lăbuță',
          'Doctorița îl ascultă: bum-bum',
          'Îi pune un plasture',
          '$p e sănătos! Mulțumim!',
        ][doctorStep(f.t)];
      case RadioBackground.zoo:
        return zooAnimal(f.variant, zooSlot(f.t)).$2;
      case RadioBackground.trees:
        final local = treeLocal(f.t);
        final n = treeSlot(f.t) + 1;
        if (local < 0.25) return 'Săpăm o groapă';
        if (local < 0.45) return 'Punem sămânța și udăm';
        if (local < 0.8) return 'Copacul crește…';
        return '$n · ${_treeWords[n - 1]}';
      default:
        return SkyTimeline.caption(f.t);
    }
  }
}

/// Curăță titlul trimis de post în stream (ICY „StreamTitle”): melodia, emisiunea sau un slogan.
class NowPlaying {
  static String? clean(String? raw, String stationName) {
    if (raw == null) return null;
    var t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(RegExp(r'^[-| ]+|[-| ]+$'), '');
    if (t.length < 2) return null;
    if (t.toLowerCase() == stationName.trim().toLowerCase()) return null;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(t)) return null;
    return t;
  }
}

/// Temporizatorul de somn: oprit -> 30 -> 60 -> 90 -> oprit (minute).
class SleepTimer {
  static const options = [30, 60, 90];
  static int next(int leftMin) => options.firstWhere((o) => o > leftMin, orElse: () => 0);
}
