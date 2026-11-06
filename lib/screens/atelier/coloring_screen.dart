import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../data/atelier.dart';
import '../../data/coloring_pages.dart';
import '../../theme.dart';
import '../../widgets/kid_tile.dart';
import '../stories_screen.dart' show KidVoice;
import 'common.dart';

/// Colorează: copilul alege o planșă.
class ColoringScreen extends StatelessWidget {
  const ColoringScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    const colors = [
      KidColors.pink,
      KidColors.orange,
      KidColors.green,
      KidColors.blue,
      KidColors.purple,
      KidColors.teal,
    ];
    return Scaffold(
      appBar: atelierBar(context, '🖍️ Colorează', const []),
      body: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth > 1100 ? 5 : (box.maxWidth > 620 ? 4 : 2);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: coloringPages.length,
            itemBuilder: (context, i) {
              final page = coloringPages[i];
              return KidTile(
                color: colors[i % colors.length],
                autofocus: i == 0,
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ColoringCanvasScreen(page: page))),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomPaint(
                              painter: ColoringPainter(page, List.filled(page.regions.length, Colors.white)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${page.emoji} ${page.title}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Planșa: atingi o zonă și se umple cu culoarea aleasă.
/// Pe TV: săgețile aleg zona (rama galbenă), OK o colorează; din marginea foii săgeata duce la culori.
class ColoringCanvasScreen extends StatefulWidget {
  const ColoringCanvasScreen({super.key, required this.page});
  final ColoringPage page;

  @override
  State<ColoringCanvasScreen> createState() => _ColoringCanvasScreenState();
}

class _ColoringCanvasScreenState extends State<ColoringCanvasScreen> {
  late final List<Color> _fills = List.filled(widget.page.regions.length, Colors.white);
  final _history = <(int, Color)>[];
  Color _color = kidPalette[0];
  int _focus = -1;
  bool _sheetFocused = false;
  final _key = GlobalKey();
  final _voice = KidVoice();

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  void _fill(int i) {
    if (i < 0 || _fills[i] == _color) return;
    setState(() {
      _history.add((i, _fills[i]));
      _fills[i] = _color;
    });
    final name = widget.page.regions[i].name;
    final ci = kidPalette.indexOf(_color);
    if (name.isNotEmpty && ci >= 0) _voice.say('${name[0].toUpperCase()}${name.substring(1)}, ${kidPaletteNames[ci]}!');
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final (i, c) = _history.removeLast();
      _fills[i] = c;
    });
  }

  Future<void> _clear() async {
    if (!await confirmClear(context)) return;
    setState(() {
      _history.clear();
      _fills.fillRange(0, _fills.length, Colors.white);
    });
  }

  void _surprise() {
    final r = Random();
    setState(() {
      for (var i = 0; i < _fills.length; i++) {
        _history.add((i, _fills[i]));
        _fills[i] = kidPalette[r.nextInt(kidPalette.length - 2)];
      }
    });
    _voice.say('Abracadabra!');
  }

  KeyEventResult _key2(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (Remote.isOk(k)) {
      _fill(_focus);
      return KeyEventResult.handled;
    }
    final (dx, dy) = switch (k) {
      LogicalKeyboardKey.arrowLeft => (-1, 0),
      LogicalKeyboardKey.arrowRight => (1, 0),
      LogicalKeyboardKey.arrowUp => (0, -1),
      LogicalKeyboardKey.arrowDown => (0, 1),
      _ => (0, 0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    final n = widget.page.neighbor(_focus, dx, dy);
    if (n < 0) return KeyEventResult.ignored; // la margine: telecomanda merge la culori / unelte
    setState(() => _focus = n);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final sheet = Focus(
      autofocus: true,
      onKeyEvent: _key2,
      onFocusChange: (f) => setState(() {
        _sheetFocused = f;
        if (f && _focus < 0) _focus = page.regions.length - 1;
      }),
      child: AspectRatio(
        aspectRatio: 1,
        child: Sheet(
          focused: _sheetFocused,
          child: LayoutBuilder(
            builder: (context, box) {
              final scale = box.maxWidth / ColoringPage.size;
              return GestureDetector(
                onTapUp: (d) => _fill(page.hit(d.localPosition / scale)),
                child: RepaintBoundary(
                  key: _key,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: ColoringPainter(page, _fills, focus: _sheetFocused ? _focus : -1),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final tools = [
      ToolButton(icon: Icons.undo_rounded, label: 'Înapoi', onTap: _history.isEmpty ? null : _undo),
      ToolButton(icon: Icons.auto_awesome_rounded, label: 'Surpriză', onTap: _surprise),
      ToolButton(icon: Icons.delete_sweep_rounded, label: 'Șterge', onTap: _clear),
      ToolButton(
        icon: Icons.star_rounded,
        label: 'Salvează',
        color: KidColors.green,
        onTap: () => saveArtwork(context, _key, 'colorat'),
      ),
    ];
    final palette = PaletteBar(selected: _color, onPick: (c) => setState(() => _color = c));
    return Scaffold(
      appBar: atelierBar(context, '${page.emoji} ${page.title}', const []),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight;
            if (wide) {
              return Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(6),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (final c in kidPalette)
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: KidRoundButton(
                                icon: Icons.check,
                                size: 48,
                                color: c,
                                selected: c == _color,
                                onTap: () => setState(() => _color = c),
                                child: c == _color
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: c.computeLuminance() > 0.6 ? Colors.black : Colors.white,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(padding: const EdgeInsets.all(12), child: sheet),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: SingleChildScrollView(child: Column(children: tools)),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(padding: const EdgeInsets.all(12), child: sheet),
                  ),
                ),
                SizedBox(height: 62, child: palette),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: tools),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Desenează planșa: zonele cu culorile lor și contururile negre groase.
class ColoringPainter extends CustomPainter {
  ColoringPainter(this.page, this.fills, {this.focus = -1});
  final ColoringPage page;
  final List<Color> fills;
  final int focus;

  @override
  bool shouldRepaint(ColoringPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height) / ColoringPage.size;
    canvas.save();
    canvas.scale(s);
    final line = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < page.regions.length; i++) {
      final p = page.regions[i].path;
      canvas.drawPath(p, Paint()..color = fills[i]);
      canvas.drawPath(p, line);
    }
    if (focus >= 0 && focus < page.regions.length) {
      final p = page.regions[focus].path;
      canvas.drawPath(
        p,
        Paint()
          ..color = KidColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawPath(p, Paint()..color = const Color(0x33FFC93C));
    }
    canvas.restore();
  }
}
