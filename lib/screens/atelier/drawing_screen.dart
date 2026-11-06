import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../data/atelier.dart';
import '../../theme.dart';
import '../../widgets/kid_tile.dart';
import 'common.dart';

enum Brush { pen, rainbow, eraser, stamp }

/// O linie trasă cu degetul (sau cu telecomanda), în coordonate 0..1 ale foii.
class Stroke {
  Stroke(this.brush, this.color, this.width, [this.stamp = '']);
  final Brush brush;
  final Color color;

  /// Grosimea, din latura mică a foii.
  final double width;
  final String stamp;
  final points = <Offset>[];
}

/// Desen liber: creion, curcubeu, radieră și ștampile, cu 3 grosimi.
/// Pe TV: săgețile mișcă pensula, OK o pune pe foaie / o ridică (sau pune ștampila).
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final _strokes = <Stroke>[];
  Color _color = kidPalette[6];
  Brush _brush = Brush.pen;
  double _width = 0.02;
  String _stamp = kidStickers.first;
  final _key = GlobalKey();

  // Telecomanda: pensula și dacă e pe foaie.
  Offset _cursor = const Offset(0.5, 0.5);
  bool _penDown = false;
  bool _sheetFocused = false;

  static const _widths = [0.008, 0.02, 0.045];

  Stroke _newStroke() => Stroke(_brush, _color, _brush == Brush.stamp ? _width * 5 + 0.04 : _width, _stamp);

  void _start(Offset p) {
    setState(() => _strokes.add(_newStroke()..points.add(p)));
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    final s = _strokes.last;
    if (s.brush == Brush.stamp) return;
    setState(() => s.points.add(p));
  }

  Offset _norm(Offset local, Size size) =>
      Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  Future<void> _clear() async {
    if (_strokes.isEmpty || !await confirmClear(context)) return;
    setState(_strokes.clear);
  }

  KeyEventResult _key2(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (Remote.isOk(k)) {
      if (e is KeyRepeatEvent) return KeyEventResult.handled;
      if (_brush == Brush.stamp) {
        _start(_cursor);
      } else if (_penDown) {
        setState(() => _penDown = false);
      } else {
        setState(() => _penDown = true);
        _start(_cursor);
      }
      return KeyEventResult.handled;
    }
    const step = 0.025;
    final d = switch (k) {
      LogicalKeyboardKey.arrowLeft => const Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => const Offset(step, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -step),
      LogicalKeyboardKey.arrowDown => const Offset(0, step),
      _ => Offset.zero,
    };
    if (d == Offset.zero) return KeyEventResult.ignored;
    final next = _cursor + d;
    // La margine, cu pensula ridicată, săgeata duce la culori și unelte.
    if (!_penDown && (next.dx < 0 || next.dx > 1 || next.dy < 0 || next.dy > 1)) return KeyEventResult.ignored;
    setState(() => _cursor = Offset(next.dx.clamp(0.0, 1.0), next.dy.clamp(0.0, 1.0)));
    if (_penDown) _extend(_cursor);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sheet = Focus(
      autofocus: true,
      onKeyEvent: _key2,
      onFocusChange: (f) => setState(() {
        _sheetFocused = f;
        if (!f) _penDown = false;
      }),
      child: Sheet(
        focused: _sheetFocused,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return GestureDetector(
              onPanStart: (d) => _start(_norm(d.localPosition, size)),
              onPanUpdate: (d) => _extend(_norm(d.localPosition, size)),
              onTapUp: (d) {
                _start(_norm(d.localPosition, size));
                if (_brush != Brush.stamp) _extend(_norm(d.localPosition, size) + const Offset(0.0001, 0));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    key: _key,
                    child: CustomPaint(painter: DrawingPainter(_strokes)),
                  ),
                  if (_sheetFocused)
                    IgnorePointer(
                      child: CustomPaint(painter: _CursorPainter(_cursor, _penDown, _brush, _color, _width, _stamp)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final brushes = [
      ToolButton(
        icon: Icons.edit_rounded,
        label: 'Creion',
        selected: _brush == Brush.pen,
        onTap: () => setState(() => _brush = Brush.pen),
      ),
      ToolButton(
        icon: Icons.gradient_rounded,
        label: 'Curcubeu',
        selected: _brush == Brush.rainbow,
        onTap: () => setState(() => _brush = Brush.rainbow),
        child: const Text('🌈', style: TextStyle(fontSize: 24)),
      ),
      ToolButton(
        icon: Icons.auto_fix_normal_rounded,
        label: 'Radieră',
        selected: _brush == Brush.eraser,
        onTap: () => setState(() => _brush = Brush.eraser),
        child: const Text('🧽', style: TextStyle(fontSize: 24)),
      ),
      ToolButton(
        icon: Icons.emoji_emotions_rounded,
        label: 'Ștampilă',
        selected: _brush == Brush.stamp,
        onTap: _pickStamp,
        child: Text(_stamp, style: const TextStyle(fontSize: 24)),
      ),
      for (var i = 0; i < _widths.length; i++)
        ToolButton(
          icon: Icons.circle,
          label: ['Subțire', 'Mijlociu', 'Gros'][i],
          selected: _width == _widths[i],
          onTap: () => setState(() => _width = _widths[i]),
          child: Container(
            width: 8.0 + i * 9,
            height: 8.0 + i * 9,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
    ];
    final actions = [
      ToolButton(icon: Icons.undo_rounded, label: 'Înapoi', onTap: _strokes.isEmpty ? null : _undo),
      ToolButton(icon: Icons.delete_sweep_rounded, label: 'Șterge', onTap: _clear),
      ToolButton(
        icon: Icons.star_rounded,
        label: 'Salvează',
        color: KidColors.green,
        onTap: () => saveArtwork(context, _key, 'desen'),
      ),
    ];
    final palette = PaletteBar(
      selected: _color,
      onPick: (c) => setState(() {
        _color = c;
        if (_brush == Brush.eraser) _brush = Brush.pen;
      }),
    );

    return Scaffold(
      appBar: atelierBar(context, '✏️ Desenează', const []),
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
                          child: SingleChildScrollView(child: Column(children: brushes)),
                        ),
                        Expanded(
                          child: Padding(padding: const EdgeInsets.all(8), child: sheet),
                        ),
                        SizedBox(
                          width: 92,
                          child: SingleChildScrollView(child: Column(children: actions)),
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
                  child: ListView(scrollDirection: Axis.horizontal, children: [...brushes, ...actions]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickStamp() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KidColors.panel,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in kidStickers)
                KidRoundButton(
                  icon: Icons.circle,
                  size: 64,
                  autofocus: s == _stamp,
                  selected: s == _stamp,
                  onTap: () => Navigator.pop(context, s),
                  child: Text(s, style: const TextStyle(fontSize: 34)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _stamp = picked;
        _brush = Brush.stamp;
      });
    }
  }
}

/// Desenează liniile pe o foaie albă.
class DrawingPainter extends CustomPainter {
  DrawingPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  bool shouldRepaint(DrawingPainter old) => true;

  static const _rainbow = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF32ADE6),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final short = min(size.width, size.height);
    Offset px(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      if (s.brush == Brush.stamp) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.stamp,
            style: TextStyle(fontSize: s.width * short),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, px(s.points.first) - Offset(tp.width / 2, tp.height / 2));
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.width * short * (s.brush == Brush.eraser ? 2 : 1)
        ..color = s.brush == Brush.eraser ? Colors.white : s.color;
      if (s.brush == Brush.rainbow) {
        for (var i = 1; i < s.points.length; i++) {
          paint.color = _rainbow[(i ~/ 3) % _rainbow.length];
          canvas.drawLine(px(s.points[i - 1]), px(s.points[i]), paint);
        }
        if (s.points.length == 1) {
          canvas.drawCircle(px(s.points.first), paint.strokeWidth / 2, Paint()..color = _rainbow.first);
        }
        continue;
      }
      if (s.points.length == 1) {
        canvas.drawCircle(px(s.points.first), paint.strokeWidth / 2, Paint()..color = paint.color);
        continue;
      }
      final path = Path()..moveTo(px(s.points.first).dx, px(s.points.first).dy);
      for (final p in s.points.skip(1)) {
        final q = px(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, paint);
    }
  }
}

/// Pensula de pe TV: un cerc (gol când e ridicată, plin când desenează).
class _CursorPainter extends CustomPainter {
  _CursorPainter(this.p, this.down, this.brush, this.color, this.width, this.stamp);
  final Offset p;
  final bool down;
  final Brush brush;
  final Color color;
  final double width;
  final String stamp;

  @override
  bool shouldRepaint(_CursorPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(p.dx * size.width, p.dy * size.height);
    final r = max(10.0, width * min(size.width, size.height));
    if (brush == Brush.stamp) {
      final tp = TextPainter(
        text: TextSpan(text: stamp, style: const TextStyle(fontSize: 40)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.saveLayer(null, Paint()..color = const Color(0x99FFFFFF));
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      r + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black54,
    );
    if (down) canvas.drawCircle(c, r, Paint()..color = brush == Brush.eraser ? Colors.grey : color);
    canvas.drawCircle(
      c,
      r + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white,
    );
  }
}
