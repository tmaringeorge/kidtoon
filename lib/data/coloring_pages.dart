import 'dart:math';
import 'dart:ui';

/// O zonă dintr-o planșă de colorat: un contur închis pe care copilul îl umple cu o culoare.
/// Coordonatele sunt pe o pagină de 100 × 100.
class ColorRegion {
  ColorRegion(this.path, {this.name = ''});
  final Path path;
  final String name;

  late final Rect bounds = path.getBounds();
  Offset get center => bounds.center;
}

/// O planșă: zonele, de la cea din spate (fundalul) la cea din față.
class ColoringPage {
  ColoringPage(this.id, this.title, this.emoji, this.regions);
  final String id;
  final String title;
  final String emoji;
  final List<ColorRegion> regions;

  static const size = 100.0;

  /// Zona de sub deget (coordonate pe pagină), cea mai din față; -1 dacă nu e nimic acolo.
  int hit(Offset p) {
    for (var i = regions.length - 1; i >= 0; i--) {
      if (regions[i].path.contains(p)) return i;
    }
    return -1;
  }

  /// Telecomanda: următoarea zonă în direcția săgeții (dx, dy sunt -1, 0 sau 1), sau -1 la margine.
  int neighbor(int from, int dx, int dy) {
    if (from < 0 || from >= regions.length) return regions.isEmpty ? -1 : regions.length - 1;
    final c = regions[from].center;
    var best = -1;
    var bestScore = double.infinity;
    for (var i = 0; i < regions.length; i++) {
      if (i == from) continue;
      final d = regions[i].center - c;
      final along = d.dx * dx + d.dy * dy;
      if (along <= 0.5) continue;
      final across = (d.dx * dy).abs() + (d.dy * dx).abs();
      final score = along + across * 2;
      if (score < bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }
}

// ---------------- Forme ajutătoare (pe pagina de 100 × 100) ----------------

Path _rect(double l, double t, double w, double h) => Path()..addRect(Rect.fromLTWH(l, t, w, h));

Path _round(double l, double t, double w, double h, double r) =>
    Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r)));

Path _circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

Path _oval(double x, double y, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Path _union(List<Path> parts) => parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));

Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

Path _cloud(double x, double y, double r) => _union([
  _circle(x, y, r),
  _circle(x - r * 0.9, y + r * 0.3, r * 0.75),
  _circle(x + r * 0.95, y + r * 0.25, r * 0.8),
]);

Path starPath(double x, double y, double r, [int points = 5, double inner = 0.45]) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -pi / 2 + i * pi / points;
    final rr = i.isEven ? r : r * inner;
    final o = Offset(x + rr * cos(a), y + rr * sin(a));
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

Path heartPath(double x, double y, double r) {
  return Path()
    ..moveTo(x, y + r * 0.9)
    ..cubicTo(x - r * 1.4, y + r * 0.1, x - r * 0.9, y - r * 1.0, x, y - r * 0.35)
    ..cubicTo(x + r * 0.9, y - r * 1.0, x + r * 1.4, y + r * 0.1, x, y + r * 0.9)
    ..close();
}

/// O bandă de curcubeu (jumătate de inel).
Path _band(double cx, double cy, double outer, double inner) {
  return Path()
    ..moveTo(cx - outer, cy)
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: outer), pi, pi, false)
    ..lineTo(cx + inner, cy)
    ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: inner), 0, -pi, false)
    ..close();
}

ColorRegion _r(Path p, [String name = '']) => ColorRegion(p, name: name);

/// Planșele de colorat incluse în aplicație.
final List<ColoringPage> coloringPages = [
  ColoringPage('casa', 'Căsuța', '🏠', [
    _r(_rect(0, 0, 100, 66), 'cerul'),
    _r(_rect(0, 66, 100, 34), 'iarba'),
    _r(_circle(86, 14, 9), 'soarele'),
    _r(_cloud(22, 14, 7), 'norul'),
    _r(_rect(58, 22, 7, 14), 'hornul'),
    _r(_rect(24, 42, 42, 36), 'peretele'),
    _r(_poly([18, 44, 45, 18, 72, 44]), 'acoperișul'),
    _r(_round(39, 56, 12, 22, 2), 'ușa'),
    _r(_rect(28, 50, 8, 8), 'fereastra'),
    _r(_rect(54, 50, 8, 8), 'fereastra'),
    _r(_rect(80, 52, 6, 24), 'trunchiul'),
    _r(_union([_circle(83, 44, 10), _circle(77, 50, 6), _circle(89, 50, 6)]), 'coroana'),
    _r(_poly([0, 86, 100, 86, 100, 100, 0, 100]), 'cărarea'),
  ]),
  ColoringPage('peste', 'Peștișorul', '🐠', [
    _r(_rect(0, 0, 100, 84), 'apa'),
    _r(_rect(0, 84, 100, 16), 'nisipul'),
    _r(_poly([70, 50, 92, 32, 92, 68]), 'coada'),
    _r(_oval(46, 50, 27, 18), 'corpul'),
    _r(_poly([36, 34, 50, 20, 58, 35]), 'aripioara'),
    _r(_poly([44, 64, 54, 76, 58, 62]), 'aripioara'),
    _r(_circle(30, 46, 4.5), 'ochiul'),
    _r(_minus(_oval(44, 50, 4, 12), _rect(0, 0, 41, 100)), 'dunga'),
    _r(_circle(16, 30, 3), 'bula'),
    _r(_circle(12, 20, 2.2), 'bula'),
    _r(_circle(18, 11, 1.6), 'bula'),
    _r(_union([_round(8, 62, 4, 24, 2), _round(13, 68, 4, 18, 2)]), 'alga'),
    _r(_poly([80, 92, 84, 84, 88, 92]), 'scoica'),
  ]),
  ColoringPage('floare', 'Floarea', '🌸', [
    _r(_rect(0, 0, 100, 100), 'fundalul'),
    _r(_circle(85, 15, 8), 'soarele'),
    _r(_rect(48, 46, 4, 32), 'tulpina'),
    _r(_oval(40, 62, 9, 4), 'frunza'),
    _r(_oval(60, 58, 9, 4), 'frunza'),
    for (var i = 0; i < 6; i++) _r(_circle(50 + 13 * cos(i * pi / 3), 32 + 13 * sin(i * pi / 3), 8.5), 'petala'),
    _r(_circle(50, 32, 8), 'mijlocul'),
    _r(_poly([34, 76, 66, 76, 61, 96, 39, 96]), 'ghiveciul'),
    _r(_rect(32, 74, 36, 5), 'marginea'),
  ]),
  ColoringPage('masina', 'Mașinuța', '🚗', [
    _r(_rect(0, 0, 100, 70), 'cerul'),
    _r(_rect(0, 70, 100, 30), 'drumul'),
    _r(_cloud(75, 18, 7), 'norul'),
    _r(_poly([28, 46, 36, 30, 66, 30, 76, 46]), 'cabina'),
    _r(_round(12, 44, 76, 20, 6), 'mașina'),
    _r(_poly([38, 44, 41, 34, 50, 34, 50, 44]), 'geamul'),
    _r(_poly([53, 44, 53, 34, 63, 34, 70, 44]), 'geamul'),
    _r(_circle(85, 50, 2.6), 'farul'),
    _r(_circle(30, 66, 9), 'roata'),
    _r(_circle(70, 66, 9), 'roata'),
    _r(_circle(30, 66, 3.5), 'janta'),
    _r(_circle(70, 66, 3.5), 'janta'),
    for (var i = 0; i < 4; i++) _r(_rect(4 + i * 26, 85, 14, 3), 'linia'),
  ]),
  ColoringPage('fluture', 'Fluturele', '🦋', [
    _r(_rect(0, 0, 100, 100), 'fundalul'),
    _r(_oval(30, 34, 20, 17), 'aripa'),
    _r(_oval(70, 34, 20, 17), 'aripa'),
    _r(_oval(34, 66, 15, 13), 'aripa'),
    _r(_oval(66, 66, 15, 13), 'aripa'),
    _r(_circle(28, 33, 6), 'bulina'),
    _r(_circle(72, 33, 6), 'bulina'),
    _r(_circle(34, 67, 4.5), 'bulina'),
    _r(_circle(66, 67, 4.5), 'bulina'),
    _r(_oval(50, 52, 5, 26), 'corpul'),
    _r(_circle(50, 24, 6), 'capul'),
    _r(_circle(40, 10, 3), 'antena'),
    _r(_circle(60, 10, 3), 'antena'),
  ]),
  ColoringPage('pisica', 'Pisicuța', '🐱', [
    _r(_rect(0, 0, 100, 100), 'fundalul'),
    _r(_round(72, 40, 8, 44, 4), 'coada'),
    _r(_oval(50, 70, 24, 22), 'corpul'),
    _r(_poly([28, 30, 30, 8, 44, 22]), 'urechea'),
    _r(_poly([72, 30, 70, 8, 56, 22]), 'urechea'),
    _r(_circle(50, 34, 22), 'capul'),
    _r(_oval(41, 31, 4, 5), 'ochiul'),
    _r(_oval(59, 31, 4, 5), 'ochiul'),
    _r(_poly([46, 40, 54, 40, 50, 45]), 'năsucul'),
    _r(_oval(50, 74, 12, 14), 'burtica'),
    _r(_oval(38, 90, 7, 4), 'lăbuța'),
    _r(_oval(62, 90, 7, 4), 'lăbuța'),
  ]),
  ColoringPage('racheta', 'Racheta', '🚀', [
    _r(_rect(0, 0, 100, 100), 'cerul'),
    _r(_circle(82, 80, 13), 'planeta'),
    _r(_minus(_oval(82, 80, 22, 5), _circle(82, 80, 13)), 'inelul'),
    _r(starPath(16, 16, 5), 'steaua'),
    _r(starPath(84, 20, 4), 'steaua'),
    _r(starPath(18, 74, 4), 'steaua'),
    _r(_poly([40, 78, 50, 98, 60, 78]), 'flacăra'),
    _r(_poly([36, 62, 26, 82, 40, 78]), 'aripa'),
    _r(_poly([64, 62, 74, 82, 60, 78]), 'aripa'),
    _r(_round(38, 30, 24, 50, 8), 'racheta'),
    _r(_poly([38, 32, 50, 6, 62, 32]), 'vârful'),
    _r(_circle(50, 46, 7), 'geamul'),
  ]),
  ColoringPage('dragon', 'Dinozaurul', '🦖', [
    _r(_rect(0, 0, 100, 76), 'cerul'),
    _r(_rect(0, 76, 100, 24), 'iarba'),
    _r(_poly([18, 62, 2, 50, 26, 54]), 'coada'),
    for (var i = 0; i < 4; i++)
      _r(_poly([30.0 + i * 9, 44 - i * 2, 34.5 + i * 9, 32 - i * 2, 39.0 + i * 9, 44 - i * 2]), 'țepii'),
    _r(_oval(44, 60, 24, 17), 'corpul'),
    _r(_oval(46, 64, 13, 10), 'burtica'),
    _r(_round(32, 70, 8, 14, 3), 'piciorul'),
    _r(_round(52, 70, 8, 14, 3), 'piciorul'),
    _r(_circle(72, 38, 13), 'capul'),
    _r(_circle(76, 34, 3), 'ochiul'),
    _r(_oval(84, 44, 4, 2.5), 'nasul'),
    _r(_cloud(20, 18, 6), 'norul'),
  ]),
  ColoringPage('curcubeu', 'Curcubeul', '🌈', [
    _r(_rect(0, 0, 100, 100), 'cerul'),
    for (var i = 0; i < 6; i++) _r(_band(50, 72, 44 - i * 5, 39 - i * 5), 'curcubeul'),
    _r(_cloud(12, 72, 9), 'norul'),
    _r(_cloud(88, 72, 9), 'norul'),
    _r(_circle(50, 14, 8), 'soarele'),
    _r(heartPath(50, 88, 6), 'inimioara'),
  ]),
  ColoringPage('forme', 'Forme', '⭐', [
    _r(_rect(0, 0, 100, 100), 'fundalul'),
    _r(_circle(25, 25, 16), 'cercul'),
    _r(_rect(60, 10, 30, 30), 'pătratul'),
    _r(_poly([25, 56, 8, 88, 42, 88]), 'triunghiul'),
    _r(starPath(75, 72, 18), 'steaua'),
    _r(heartPath(50, 50, 9), 'inima'),
    _r(_circle(25, 25, 7), 'cercul mic'),
    _r(_rect(69, 19, 12, 12), 'pătrățelul'),
  ]),
];
