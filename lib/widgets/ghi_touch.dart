import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/ghi_episodes.dart';
import 'ghi_animation.dart';
import 'kid_tile.dart' show Remote;

const _shadow = [Shadow(color: Color(0x99000000), offset: Offset(2, 3), blurRadius: 8)];

GhiPose _pose(String pose, double x, String face, {String? puff, double? y}) =>
    GhiPose({'pose': pose, 'x': x, 'y': y, 'face': face, 'puff': puff});

/// Un ceas de cadre, ca desenele să se miște.
mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  final elapsed = ValueNotifier<int>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => elapsed.value = d.inMilliseconds)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    elapsed.dispose();
    super.dispose();
  }
}

/// „Atinge și învață”: copilul atinge un lucru, lucrul sare, apare numele,
/// iar [onTap] spune cu voce ce este.
class GhiTouch extends StatefulWidget {
  const GhiTouch({
    super.key,
    required this.book,
    required this.scene,
    required this.onTap,
    this.onNextScene,
    this.onPreviousScene,
    this.autofocus = false,
    this.focusNode,
  });
  final GhiBook book;
  final GhiTouchScene scene;
  final void Function(int index) onTap;

  /// Telecomanda: după ultimul lucru ▶ trece la scena următoare, înainte de primul ◀ la cea dinainte.
  final VoidCallback? onNextScene;
  final VoidCallback? onPreviousScene;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<GhiTouch> createState() => _GhiTouchState();
}

class _GhiTouchState extends State<GhiTouch> with SingleTickerProviderStateMixin, _Clock {
  int _tapped = -1;
  int _tappedAt = 0;
  // Lucrul ales cu telecomanda (-1 până se apasă o săgeată).
  int _focus = -1;

  @override
  void didUpdateWidget(GhiTouch old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id) {
      _tapped = -1;
      if (_focus >= 0) _focus = 0;
    }
  }

  void _hit(int i) {
    setState(() {
      _tapped = i;
      _tappedAt = elapsed.value;
    });
    widget.onTap(i);
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e)) return KeyEventResult.ignored;
    final n = widget.scene.items.length;
    if (n == 0) return KeyEventResult.ignored;
    const cols = GhiTouchLayout.cols;
    final k = e.logicalKey;
    if (Remote.isOk(k)) {
      if (_focus < 0) {
        setState(() => _focus = 0);
      } else {
        _hit(_focus);
      }
      return KeyEventResult.handled;
    }
    var f = _focus < 0 ? 0 : _focus;
    if (k == LogicalKeyboardKey.arrowRight) {
      if (_focus >= 0 && f == n - 1) {
        widget.onNextScene?.call();
        return KeyEventResult.handled;
      }
      f = _focus < 0 ? 0 : f + 1;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (_focus >= 0 && f == 0) {
        widget.onPreviousScene?.call();
        return KeyEventResult.handled;
      }
      f = _focus < 0 ? 0 : f - 1;
    } else if (k == LogicalKeyboardKey.arrowDown && f + cols < n) {
      f += cols;
    } else if (k == LogicalKeyboardKey.arrowUp && f - cols >= 0) {
      f -= cols;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() => _focus = f.clamp(0, n - 1));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Focus(
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          onKeyEvent: _key,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final i = GhiTouchLayout.hit(
                widget.scene.items.length,
                d.localPosition.dx / box.maxWidth,
                d.localPosition.dy / box.maxHeight,
                box.maxHeight / box.maxWidth,
                0.1,
              );
              if (i >= 0) _hit(i);
            },
            child: ValueListenableBuilder<int>(
              valueListenable: elapsed,
              builder: (context, ms, _) {
                final since = _tapped >= 0 ? ms - _tappedAt : 1 << 30;
                final caption = _tapped >= 0 && since < 6000
                    ? widget.scene.items[_tapped].say
                    : '${widget.scene.title}: atinge ceva!';
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _TouchPainter(widget.book, widget.scene, ms, _tapped, since, _focus)),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 64, left: 64, right: 64),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              caption,
                              key: ValueKey(caption),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                shadows: _shadow,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.book, this.scene, this.ms, this.tapped, this.since, this.focus);
  final GhiBook book;
  final GhiTouchScene scene;
  final int ms, tapped, since, focus;

  @override
  bool shouldRepaint(_TouchPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final ts = GhiTimeline.quantize(ms) / 1000;
    final set = book.set(scene.set);
    paintSetBack(canvas, size, set, ts);
    final px = min(size.shortestSide * 0.15, size.width * 0.13);
    for (var i = 0; i < scene.items.length; i++) {
      final item = scene.items[i];
      final c = Offset(GhiTouchLayout.x(i) * size.width, GhiTouchLayout.y(i) * size.height);
      final bounce = i == tapped && since < 1200 ? sin(since / 1200 * pi * 3).abs() * (1 - since / 1200) : 0.0;
      final breathe = 1 + 0.03 * sin(ts * 1.5 + i);
      // Un cerc deschis în spate, ca lucrurile să se vadă bine pe orice decor.
      canvas.drawCircle(c, px * 0.75, Paint()..color = const Color(0x55FFFFFF));
      // Pe TV: rama albă arată ce e ales cu telecomanda.
      if (i == focus) {
        canvas.drawCircle(
          c,
          px * 0.86,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = px * 0.08,
        );
      }
      final center = c - Offset(0, bounce * px * 0.4);
      final sz = px * (breathe + bounce * 0.3);
      if (RegExp(r'^[0-9A-Za-z]{1,2}$').hasMatch(item.emoji)) {
        ghiText(canvas, item.emoji, center, sz, const Color(0xFF1E88E5));
      } else {
        ghiEmoji(canvas, item.emoji, center, sz);
      }
      if (i == tapped) ghiText(canvas, item.name, c + Offset(0, px * 0.95), px * 0.3, Colors.white);
    }
    paintSetFront(canvas, size, set, ts);
    // GHI în colțul din stânga, se bucură când atingi ceva.
    final happy = since < 2500;
    paintGhi(
      canvas,
      _pose(happy ? 'happy' : 'stand', 0.13, happy ? 'wow' : 'happy', puff: happy ? 'stars' : null),
      0,
      ts,
      size.width * 0.13,
      size.height * 0.94,
      min(size.height * 0.34, size.width * 0.3),
    );
  }
}

/// Pauza de clipit: GHI clipește încet de trei ori, apoi ne roagă să ne uităm departe.
class GhiBlinkOverlay extends StatelessWidget {
  const GhiBlinkOverlay({super.key, required this.ms});
  final int ms;

  @override
  Widget build(BuildContext context) {
    final lookAway = ms >= ScreenCare.lookAwayAtMs;
    final a = (ms / 1500).clamp(0.0, 1.0) * ((ScreenCare.blinkMs - ms) / 1500).clamp(0.0, 1.0);
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: (lookAway ? 0.85 : 0.6) * a),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!lookAway) CustomPaint(painter: _BlinkPainter(ms)),
            SafeArea(
              child: Align(
                alignment: lookAway ? Alignment.center : Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lookAway) const Text('🪟', style: TextStyle(fontSize: 72)),
                      Text(
                        ScreenCare.blinkCaption(ms),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: a),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          shadows: _shadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkPainter extends CustomPainter {
  _BlinkPainter(this.ms);
  final int ms;

  @override
  bool shouldRepaint(_BlinkPainter old) => old.ms != ms;

  @override
  void paint(Canvas canvas, Size size) {
    paintGhi(
      canvas,
      _pose('stand', 0.5, ScreenCare.eyesClosed(ms) ? 'sleepy' : 'calm', y: 0.86),
      0,
      0,
      size.width / 2,
      size.height * 0.86,
      min(size.height * 0.55, size.width * 0.7),
    );
  }
}

/// Odihna după sesiune: ecran liniștit, GHI doarme, radioul merge mai departe doar cu sunet.
/// Părintele ține apăsat 3 secunde ca să continue.
class GhiRest extends StatefulWidget {
  const GhiRest({super.key, required this.onUnlock, this.name = 'GHI', this.audioNote = 'Radioul cântă mai departe.'});
  final VoidCallback onUnlock;

  /// Numele ales pentru personaj.
  final String name;

  /// Ce se aude mai departe (radioul sau nimic).
  final String audioNote;

  @override
  State<GhiRest> createState() => _GhiRestState();
}

class _GhiRestState extends State<GhiRest> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      // Pe TV părintele ține apăsat OK 3 secunde.
      onKeyEvent: (node, e) {
        if (!Remote.isOk(e.logicalKey)) return KeyEventResult.ignored;
        if (e is KeyDownEvent) _keyStart = elapsed.value;
        if (e is KeyUpEvent && _keyStart >= 0 && elapsed.value - _keyStart >= ScreenCare.unlockHoldMs - 500) {
          _keyStart = -1;
          widget.onUnlock();
        }
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _holdStart = elapsed.value,
        onLongPressEnd: (_) {
          if (elapsed.value - _holdStart >= ScreenCare.unlockHoldMs - 500) widget.onUnlock();
        },
        child: ColoredBox(
          color: const Color(0xFF0B1026),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: elapsed,
                builder: (context, ms, _) => CustomPaint(painter: _RestPainter(ms)),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.name} a obosit și se odihnește 💤',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hai să ne jucăm altceva! ${widget.audioNote}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Părinte: ține degetul apăsat 3 secunde (pe TV: ține apăsat OK) ca să continuați.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0x88FFFFFF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _holdStart = 0;
  int _keyStart = -1;
}

class _RestPainter extends CustomPainter {
  _RestPainter(this.ms);
  final int ms;

  @override
  bool shouldRepaint(_RestPainter old) => old.ms != ms;

  @override
  void paint(Canvas canvas, Size size) {
    final ts = GhiTimeline.quantize(ms) / 1000;
    paintGhi(
      canvas,
      _pose('sleep', 0.5, 'sleepy', puff: 'zzz', y: 0.8),
      0,
      ts,
      size.width / 2,
      size.height * 0.8,
      min(size.height * 0.4, size.width * 0.55),
    );
  }
}
