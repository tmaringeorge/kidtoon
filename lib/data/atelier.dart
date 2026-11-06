import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';

/// Paleta Atelierului: culori vii, ușor de deosebit, plus alb și negru.
const kidPalette = <Color>[
  Color(0xFFFF3B30), // roșu
  Color(0xFFFF9500), // portocaliu
  Color(0xFFFFCC00), // galben
  Color(0xFF34C759), // verde
  Color(0xFF00C7BE), // turcoaz
  Color(0xFF32ADE6), // albastru deschis
  Color(0xFF007AFF), // albastru
  Color(0xFFAF52DE), // mov
  Color(0xFFFF2D92), // roz
  Color(0xFFA2845E), // maro
  Color(0xFFFFD1B3), // piele
  Color(0xFF8E8E93), // gri
  Color(0xFF000000), // negru
  Color(0xFFFFFFFF), // alb
];

/// Numele culorilor, pentru vocea care le spune.
const kidPaletteNames = [
  'roșu',
  'portocaliu',
  'galben',
  'verde',
  'turcoaz',
  'albastru deschis',
  'albastru',
  'mov',
  'roz',
  'maro',
  'culoarea pielii',
  'gri',
  'negru',
  'alb',
];

// ---------------- Construiește ----------------

enum PieceShape { square, rect, circle, triangle, star, heart, half, hexagon, emoji }

/// O piesă din „Construiește”: o formă colorată sau un abțibild (emoji),
/// cu poziția (0..1 din suprafață), mărimea (din latura mică) și rotirea (radiani).
class Piece {
  Piece({
    required this.shape,
    this.color = const Color(0xFFFF3B30),
    this.emoji = '',
    this.x = 0.5,
    this.y = 0.5,
    this.size = 0.18,
    this.angle = 0,
  });

  PieceShape shape;
  Color color;
  String emoji;
  double x, y, size, angle;

  static const minSize = 0.05;
  static const maxSize = 0.9;

  Piece copy() => Piece(shape: shape, color: color, emoji: emoji, x: x, y: y, size: size, angle: angle);

  void moveBy(double dx, double dy) {
    x = (x + dx).clamp(0.0, 1.0);
    y = (y + dy).clamp(0.0, 1.0);
  }

  void scaleBy(double f) => size = (size * f).clamp(minSize, maxSize);

  /// Lățimea și înălțimea relativă (dreptunghiul și semicercul sunt mai late).
  (double, double) get aspect => switch (shape) {
    PieceShape.rect => (1.6, 0.8),
    PieceShape.half => (1.0, 0.5),
    _ => (1.0, 1.0),
  };

  /// E punctul (0..1) pe piesă? [ratio] = înălțime / lățime a suprafeței.
  bool contains(double px, double py, double ratio) {
    // Lucrăm în unități de „latură mică”, ca piesele să nu fie strivite pe ecrane late.
    final w = ratio < 1 ? 1 / ratio : 1.0;
    final h = ratio < 1 ? 1.0 : ratio;
    final lx = (px - x) * w;
    final ly = (py - y) * h;
    // Rotim punctul înapoi, în sistemul piesei.
    final c = cos(-angle), s = sin(-angle);
    final rx = lx * c - ly * s;
    final ry = lx * s + ly * c;
    final (ax, ay) = aspect;
    return rx.abs() <= size * ax / 2 + 0.01 && ry.abs() <= size * ay / 2 + 0.01;
  }
}

/// Abțibildurile din „Construiește” și ștampilele din „Desenează”.
const kidStickers = [
  '⭐',
  '❤️',
  '🌸',
  '🌳',
  '☀️',
  '☁️',
  '🌈',
  '🐶',
  '🐱',
  '🐰',
  '🦋',
  '🐞',
  '🐟',
  '🦖',
  '🚗',
  '🚂',
  '✈️',
  '🎈',
  '🍎',
  '🏰',
  '👑',
  '🎁',
  '🚀',
  '🌙',
];

/// Idei de început în „Construiește”: o căsuță, un robot, un tren, o rachetă.
class BuildTemplate {
  const BuildTemplate(this.title, this.emoji, this.background, this.make);
  final String title;
  final String emoji;
  final int background;
  final List<Piece> Function() make;
}

final buildTemplates = <BuildTemplate>[
  BuildTemplate('Foaie goală', '📄', 0, () => []),
  BuildTemplate(
    'Căsuța',
    '🏠',
    0,
    () => [
      Piece(shape: PieceShape.square, color: kidPalette[2], x: 0.5, y: 0.62, size: 0.34),
      Piece(shape: PieceShape.triangle, color: kidPalette[0], x: 0.5, y: 0.31, size: 0.36),
      Piece(shape: PieceShape.rect, color: kidPalette[9], x: 0.5, y: 0.7, size: 0.1, angle: 1.5708),
      Piece(shape: PieceShape.square, color: kidPalette[5], x: 0.44, y: 0.6, size: 0.08),
      Piece(shape: PieceShape.square, color: kidPalette[5], x: 0.56, y: 0.6, size: 0.08),
      Piece(shape: PieceShape.emoji, emoji: '🌳', x: 0.82, y: 0.62, size: 0.26),
      Piece(shape: PieceShape.emoji, emoji: '☀️', x: 0.14, y: 0.16, size: 0.16),
    ],
  ),
  BuildTemplate(
    'Robotul',
    '🤖',
    2,
    () => [
      Piece(shape: PieceShape.square, color: kidPalette[11], x: 0.5, y: 0.3, size: 0.2),
      Piece(shape: PieceShape.circle, color: kidPalette[2], x: 0.45, y: 0.28, size: 0.05),
      Piece(shape: PieceShape.circle, color: kidPalette[2], x: 0.55, y: 0.28, size: 0.05),
      Piece(shape: PieceShape.rect, color: kidPalette[6], x: 0.5, y: 0.56, size: 0.24, angle: 1.5708),
      Piece(shape: PieceShape.rect, color: kidPalette[11], x: 0.4, y: 0.5, size: 0.14),
      Piece(shape: PieceShape.rect, color: kidPalette[11], x: 0.6, y: 0.5, size: 0.14),
      Piece(shape: PieceShape.rect, color: kidPalette[12], x: 0.44, y: 0.84, size: 0.12, angle: 1.5708),
      Piece(shape: PieceShape.rect, color: kidPalette[12], x: 0.56, y: 0.84, size: 0.12, angle: 1.5708),
      Piece(shape: PieceShape.star, color: kidPalette[0], x: 0.5, y: 0.16, size: 0.08),
    ],
  ),
  BuildTemplate(
    'Trenulețul',
    '🚂',
    0,
    () => [
      Piece(shape: PieceShape.rect, color: kidPalette[0], x: 0.25, y: 0.62, size: 0.2),
      Piece(shape: PieceShape.square, color: kidPalette[6], x: 0.2, y: 0.47, size: 0.12),
      Piece(shape: PieceShape.rect, color: kidPalette[3], x: 0.52, y: 0.62, size: 0.18),
      Piece(shape: PieceShape.rect, color: kidPalette[2], x: 0.77, y: 0.62, size: 0.18),
      for (final x in [0.18, 0.32, 0.46, 0.58, 0.71, 0.83])
        Piece(shape: PieceShape.circle, color: kidPalette[12], x: x, y: 0.75, size: 0.08),
      Piece(shape: PieceShape.emoji, emoji: '☁️', x: 0.3, y: 0.3, size: 0.12),
    ],
  ),
  BuildTemplate(
    'Racheta',
    '🚀',
    2,
    () => [
      Piece(shape: PieceShape.rect, color: kidPalette[13], x: 0.5, y: 0.55, size: 0.36, angle: 1.5708),
      Piece(shape: PieceShape.triangle, color: kidPalette[0], x: 0.5, y: 0.2, size: 0.29),
      Piece(shape: PieceShape.circle, color: kidPalette[5], x: 0.5, y: 0.45, size: 0.09),
      Piece(shape: PieceShape.triangle, color: kidPalette[0], x: 0.4, y: 0.74, size: 0.12, angle: -0.5),
      Piece(shape: PieceShape.triangle, color: kidPalette[0], x: 0.6, y: 0.74, size: 0.12, angle: 0.5),
      Piece(shape: PieceShape.emoji, emoji: '🔥', x: 0.5, y: 0.86, size: 0.12, angle: 3.1416),
      Piece(shape: PieceShape.emoji, emoji: '🌙', x: 0.82, y: 0.18, size: 0.14),
      Piece(shape: PieceShape.star, color: kidPalette[2], x: 0.18, y: 0.24, size: 0.07),
    ],
  ),
];

/// Fundalurile din „Construiește”.
const buildBackgrounds = [
  ('Afară', [Color(0xFF8FD3FF), Color(0xFFD7F5FF), Color(0xFF7BD66A)]),
  ('Marea', [Color(0xFF4FC3F7), Color(0xFF0288D1), Color(0xFFFFE0A3)]),
  ('Spațiul', [Color(0xFF0B1033), Color(0xFF2A1B5C), Color(0xFF3A2A7A)]),
  ('Foaie albă', [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFF2F2F2)]),
];

// ---------------- Galeria ----------------

/// Lucrările copilului, salvate ca imagini PNG pe telefon / TV.
class ArtStore {
  ArtStore([this._dirOverride]);
  final Directory? _dirOverride;

  Future<Directory> _dir() async {
    final base = _dirOverride ?? Directory('${(await getApplicationSupportDirectory()).path}/atelier');
    return base.create(recursive: true);
  }

  static String fileName(String kind, DateTime t) =>
      '${kind}_${t.year}${_two(t.month)}${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}.png';

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<File> save(String kind, Uint8List png, [DateTime? at]) async {
    final f = File('${(await _dir()).path}/${fileName(kind, at ?? DateTime.now())}');
    return f.writeAsBytes(png, flush: true);
  }

  /// Cele mai noi primele.
  Future<List<File>> list() async {
    final d = await _dir();
    final files = await d.list().where((e) => e is File && e.path.endsWith('.png')).cast<File>().toList();
    files.sort((a, b) => _stamp(b).compareTo(_stamp(a)));
    return files;
  }

  /// Data din numele fișierului („desen_20260102_030405.png” → „20260102_030405”).
  static String _stamp(File f) {
    final n = f.path.split('/').last;
    final i = n.indexOf('_');
    return i < 0 ? n : n.substring(i + 1);
  }

  static String kindOf(File f) {
    final n = f.path.split('/').last;
    return switch (n.split('_').first) {
      'colorat' => '🖍️ Colorat',
      'desen' => '✏️ Desen',
      'construit' => '🧱 Construit',
      _ => '🎨',
    };
  }
}
