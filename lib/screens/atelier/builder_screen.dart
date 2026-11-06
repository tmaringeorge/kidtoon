import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../data/atelier.dart';
import '../../data/coloring_pages.dart' show heartPath, starPath;
import '../../theme.dart';
import '../../widgets/kid_tile.dart';
import 'common.dart';

/// Construiește: copilul alege o idee (căsuța, robotul, trenul, racheta) sau o foaie goală.
class BuilderScreen extends StatelessWidget {
  const BuilderScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    const colors = [KidColors.purple, KidColors.orange, KidColors.blue, KidColors.green, KidColors.pink];
    return Scaffold(
      appBar: atelierBar(context, '🧱 Construiește', const []),
      body: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth > 1100 ? 5 : (box.maxWidth > 620 ? 3 : 2);
          return GridView.count(
            crossAxisCount: cols,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              for (var i = 0; i < buildTemplates.length; i++)
                KidTile(
                  color: colors[i % colors.length],
                  emoji: buildTemplates[i].emoji,
                  title: buildTemplates[i].title,
                  autofocus: i == 0,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BuildCanvasScreen(template: buildTemplates[i])),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Suprafața de construit: adaugi forme și abțibilduri, le muți cu degetul,
/// le mărești sau le rotești cu două degete (sau din butoane).
/// Pe TV: săgețile mută piesa aleasă, OK trece la piesa următoare; din margine săgeata duce la unelte.
class BuildCanvasScreen extends StatefulWidget {
  const BuildCanvasScreen({super.key, required this.template});
  final BuildTemplate template;

  @override
  State<BuildCanvasScreen> createState() => _BuildCanvasScreenState();
}

class _BuildCanvasScreenState extends State<BuildCanvasScreen> {
  late final List<Piece> _pieces = widget.template.make();
  late int _background = widget.template.background;
  int _selected = -1;
  Color _color = kidPalette[0];
  bool _sheetFocused = false;
  final _key = GlobalKey();

  // Gestul cu două degete: mărimea și unghiul de la început.
  double _startSize = 0, _startAngle = 0;

  Piece? get _sel => _selected >= 0 && _selected < _pieces.length ? _pieces[_selected] : null;

  void _add(Piece p) {
    final r = Random();
    p
      ..x = 0.5 + (r.nextDouble() - 0.5) * 0.2
      ..y = 0.5 + (r.nextDouble() - 0.5) * 0.2;
    setState(() {
      _pieces.add(p);
      _selected = _pieces.length - 1;
    });
  }

  void _addShape(PieceShape s) => _add(Piece(shape: s, color: _color));

  void _edit(void Function(Piece p) f) {
    final p = _sel;
    if (p == null) return;
    setState(() => f(p));
  }

  void _delete() {
    if (_sel == null) return;
    setState(() {
      _pieces.removeAt(_selected);
      _selected = _pieces.isEmpty ? -1 : _pieces.length - 1;
    });
  }

  void _duplicate() {
    final p = _sel;
    if (p == null) return;
    setState(() {
      _pieces.add(p.copy()..moveBy(0.04, 0.04));
      _selected = _pieces.length - 1;
    });
  }

  void _toFront() {
    final p = _sel;
    if (p == null) return;
    setState(() {
      _pieces
        ..removeAt(_selected)
        ..add(p);
      _selected = _pieces.length - 1;
    });
  }

  int _hit(Offset local, Size size) {
    final fx = local.dx / size.width, fy = local.dy / size.height;
    final ratio = size.height / size.width;
    for (var i = _pieces.length - 1; i >= 0; i--) {
      if (_pieces[i].contains(fx, fy, ratio)) return i;
    }
    return -1;
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (Remote.isOk(k)) {
      if (_pieces.isEmpty) return KeyEventResult.ignored;
      setState(() => _selected = (_selected + 1) % _pieces.length);
      return KeyEventResult.handled;
    }
    final p = _sel;
    if (p == null) return KeyEventResult.ignored;
    const step = 0.02;
    final (dx, dy) = switch (k) {
      LogicalKeyboardKey.arrowLeft => (-step, 0.0),
      LogicalKeyboardKey.arrowRight => (step, 0.0),
      LogicalKeyboardKey.arrowUp => (0.0, -step),
      LogicalKeyboardKey.arrowDown => (0.0, step),
      _ => (0.0, 0.0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    final nx = p.x + dx, ny = p.y + dy;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return KeyEventResult.ignored;
    setState(() => p.moveBy(dx, dy));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = Focus(
      autofocus: true,
      onKeyEvent: _keys,
      onFocusChange: (f) => setState(() {
        _sheetFocused = f;
        if (f && _selected < 0 && _pieces.isNotEmpty) _selected = _pieces.length - 1;
      }),
      child: Sheet(
        focused: _sheetFocused,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return GestureDetector(
              onTapUp: (d) => setState(() => _selected = _hit(d.localPosition, size)),
              onScaleStart: (d) {
                final i = _hit(d.localFocalPoint, size);
                if (i >= 0) setState(() => _selected = i);
                _startSize = _sel?.size ?? 0;
                _startAngle = _sel?.angle ?? 0;
              },
              onScaleUpdate: (d) {
                final p = _sel;
                if (p == null) return;
                setState(() {
                  p.moveBy(d.focalPointDelta.dx / size.width, d.focalPointDelta.dy / size.height);
                  if (d.pointerCount > 1) {
                    p.size = (_startSize * d.scale).clamp(Piece.minSize, Piece.maxSize);
                    p.angle = _startAngle + d.rotation;
                  }
                });
              },
              child: RepaintBoundary(
                key: _key,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: BuildPainter(_pieces, _background, selected: _selected),
                ),
              ),
            );
          },
        ),
      ),
    );

    final add = [
      for (final s in PieceShape.values.where((s) => s != PieceShape.emoji))
        ToolButton(
          icon: Icons.add,
          label: _shapeName(s),
          onTap: () => _addShape(s),
          child: SizedBox(width: 30, height: 30, child: CustomPaint(painter: _ShapeIcon(s, _color))),
        ),
      ToolButton(
        icon: Icons.emoji_emotions_rounded,
        label: 'Abțibild',
        onTap: _pickSticker,
        child: const Text('🐶', style: TextStyle(fontSize: 24)),
      ),
    ];
    final edit = [
      ToolButton(
        icon: Icons.zoom_in_rounded,
        label: 'Mai mare',
        onTap: _sel == null ? null : () => _edit((p) => p.scaleBy(1.15)),
      ),
      ToolButton(
        icon: Icons.zoom_out_rounded,
        label: 'Mai mic',
        onTap: _sel == null ? null : () => _edit((p) => p.scaleBy(1 / 1.15)),
      ),
      ToolButton(
        icon: Icons.rotate_right_rounded,
        label: 'Rotește',
        onTap: _sel == null ? null : () => _edit((p) => p.angle += pi / 8),
      ),
      ToolButton(icon: Icons.copy_rounded, label: 'Încă una', onTap: _sel == null ? null : _duplicate),
      ToolButton(icon: Icons.flip_to_front_rounded, label: 'În față', onTap: _sel == null ? null : _toFront),
      ToolButton(icon: Icons.delete_rounded, label: 'Scoate', onTap: _sel == null ? null : _delete),
      ToolButton(
        icon: Icons.landscape_rounded,
        label: buildBackgrounds[_background].$1,
        onTap: () => setState(() => _background = (_background + 1) % buildBackgrounds.length),
      ),
      ToolButton(
        icon: Icons.star_rounded,
        label: 'Salvează',
        color: KidColors.green,
        onTap: () async {
          final keep = _selected;
          setState(() => _selected = -1); // fără rama de selecție în poză
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) return;
          await saveArtwork(context, _key, 'construit');
          if (mounted) setState(() => _selected = keep);
        },
      ),
    ];
    final palette = PaletteBar(
      selected: _color,
      onPick: (c) {
        setState(() => _color = c);
        _edit((p) => p.color = c);
      },
    );

    return Scaffold(
      appBar: atelierBar(context, '${widget.template.emoji} ${widget.template.title}', const []),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight;
            if (wide) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: SingleChildScrollView(child: Column(children: add)),
                        ),
                        Expanded(
                          child: Padding(padding: const EdgeInsets.all(8), child: sheet),
                        ),
                        SizedBox(
                          width: 92,
                          child: SingleChildScrollView(child: Column(children: edit)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 62, child: Center(child: palette)),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: Padding(padding: const EdgeInsets.all(10), child: sheet),
                ),
                SizedBox(height: 62, child: palette),
                SizedBox(
                  height: 80,
                  child: ListView(scrollDirection: Axis.horizontal, children: add),
                ),
                SizedBox(
                  height: 80,
                  child: ListView(scrollDirection: Axis.horizontal, children: edit),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickSticker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KidColors.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < kidStickers.length; i++)
                  KidRoundButton(
                    icon: Icons.circle,
                    size: 64,
                    autofocus: i == 0,
                    onTap: () => Navigator.pop(context, kidStickers[i]),
                    child: Text(kidStickers[i], style: const TextStyle(fontSize: 34)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null) _add(Piece(shape: PieceShape.emoji, emoji: picked, size: 0.2));
  }

  static String _shapeName(PieceShape s) => switch (s) {
    PieceShape.square => 'Pătrat',
    PieceShape.rect => 'Dreptunghi',
    PieceShape.circle => 'Cerc',
    PieceShape.triangle => 'Triunghi',
    PieceShape.star => 'Stea',
    PieceShape.heart => 'Inimă',
    PieceShape.half => 'Semicerc',
    PieceShape.hexagon => 'Hexagon',
    PieceShape.emoji => 'Abțibild',
  };
}

/// Calea unei forme centrate în (0, 0), cu latura [s].
Path piecePath(PieceShape shape, double s) {
  final h = s / 2;
  switch (shape) {
    case PieceShape.square:
      return Path()..addRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s), Radius.circular(s * 0.06)),
      );
    case PieceShape.rect:
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 0.8),
          Radius.circular(s * 0.06),
        ),
      );
    case PieceShape.circle:
      return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: h));
    case PieceShape.triangle:
      return Path()
        ..moveTo(0, -h)
        ..lineTo(h, h)
        ..lineTo(-h, h)
        ..close();
    case PieceShape.star:
      return starPath(0, 0, h * 1.05);
    case PieceShape.heart:
      return heartPath(0, h * 0.05, h * 0.95);
    case PieceShape.half:
      return Path()
        ..moveTo(-h, h * 0.5)
        ..arcTo(Rect.fromCircle(center: Offset(0, h * 0.5), radius: h), pi, pi, false)
        ..close();
    case PieceShape.hexagon:
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        final o = Offset(h * cos(a), h * sin(a));
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p..close();
    case PieceShape.emoji:
      return Path()..addRect(Rect.fromCenter(center: Offset.zero, width: s, height: s));
  }
}

/// Desenează fundalul și piesele (piesa aleasă are o ramă galbenă punctată).
class BuildPainter extends CustomPainter {
  BuildPainter(this.pieces, this.background, {this.selected = -1});
  final List<Piece> pieces;
  final int background;
  final int selected;

  @override
  bool shouldRepaint(BuildPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = buildBackgrounds[background].$2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: cols,
          stops: const [0, 0.72, 0.73],
        ).createShader(Offset.zero & size),
    );
    if (background == 2) {
      final r = Random(7);
      for (var i = 0; i < 40; i++) {
        canvas.drawCircle(
          Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.7),
          r.nextDouble() * 1.8 + 0.6,
          Paint()..color = Colors.white70,
        );
      }
    }
    final short = min(size.width, size.height);
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      final s = p.size * short;
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.angle);
      if (p.shape == PieceShape.emoji) {
        final tp = TextPainter(
          text: TextSpan(
            text: p.emoji,
            style: TextStyle(fontSize: s * 0.85),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      } else {
        final path = piecePath(p.shape, s);
        canvas.drawPath(path.shift(Offset(s * 0.03, s * 0.05)), Paint()..color = const Color(0x33000000));
        canvas.drawPath(path, Paint()..color = p.color);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, s * 0.025)
            ..color = Color.lerp(p.color, Colors.black, 0.35)!,
        );
      }
      if (i == selected) {
        final (ax, ay) = p.aspect;
        final rect = Rect.fromCenter(center: Offset.zero, width: s * ax + 12, height: s * ay + 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = KidColors.accent,
        );
      }
      canvas.restore();
    }
  }
}

class _ShapeIcon extends CustomPainter {
  _ShapeIcon(this.shape, this.color);
  final PieceShape shape;
  final Color color;

  @override
  bool shouldRepaint(_ShapeIcon old) => old.color != color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    final s = size.shortestSide * (shape == PieceShape.rect ? 0.6 : 0.9);
    canvas.drawPath(piecePath(shape, s), Paint()..color = color);
    canvas.drawPath(
      piecePath(shape, s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }
}
