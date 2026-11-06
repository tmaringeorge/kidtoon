import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/radio.dart';
import 'kids_timeline.dart';
import 'sky_animation.dart';

/// Animațiile pentru copii din playerul radio (o scenă anume sau toate pe rând).
class KidsAnimation extends StatefulWidget {
  const KidsAnimation({super.key, required this.mode});
  final RadioBackground mode;

  @override
  State<KidsAnimation> createState() => _KidsAnimationState();
}

class _KidsAnimationState extends State<KidsAnimation> with SingleTickerProviderStateMixin {
  final _elapsed = ValueNotifier<int>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _elapsed.value = d.inMilliseconds)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _elapsed,
      builder: (context, ms, _) {
        final f = KidsTimeline.frame(ms, widget.mode);
        final caption = KidsTimeline.caption(f);
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1500),
              child: CustomPaint(
                key: ValueKey('${f.segment}-${f.scene.name}'),
                painter: _painterFor(f),
                size: Size.infinite,
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 56, left: 16, right: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      caption,
                      key: ValueKey(caption),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Color(0x88000000), offset: Offset(2, 3), blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  CustomPainter _painterFor(KidsFrame f) {
    switch (f.scene) {
      case RadioBackground.ocean:
        return _OceanPainter(f.t, f.variant);
      case RadioBackground.farm:
        return _FarmPainter(f.t, f.variant);
      case RadioBackground.balloons:
        return _BalloonPainter(f.t, f.variant);
      case RadioBackground.train:
        return _TrainPainter(f.t, f.variant);
      case RadioBackground.shapes:
        return _ShapesPainter(f.t, f.variant);
      case RadioBackground.football:
        return _FootballPainter(f.t, f.variant);
      case RadioBackground.sorcova:
        return _SorcovaPainter(f.t, f.variant);
      case RadioBackground.santa:
        return _SantaPainter(f.t, f.variant);
      case RadioBackground.dinos:
        return _DinosPainter(f.t, f.variant);
      case RadioBackground.firefighters:
        return _FirePainter(f.t, f.variant);
      case RadioBackground.doctor:
        return _DoctorPainter(f.t, f.variant);
      case RadioBackground.zoo:
        return _ZooPainter(f.t, f.variant);
      case RadioBackground.trees:
        return _TreesPainter(f.t, f.variant);
      default:
        return SkyPainter(f.t);
    }
  }
}

const _tau = 2 * pi;

double _fade(double x, [double edge = 0.12]) => (x / edge).clamp(0.0, 1.0) * ((1 - x) / edge).clamp(0.0, 1.0);

Paint _fill(Color c) => Paint()..color = c;

void _gradient(Canvas canvas, Size size, List<Color> colors) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );
}

void _text(Canvas canvas, String text, Offset center, double fontSize, {Color color = Colors.white, bool bold = true}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
        shadows: bold ? const [Shadow(color: Color(0x66000000), offset: Offset(1, 2), blurRadius: 4)] : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

void _emoji(Canvas canvas, String emoji, Offset center, double fontSize, [double alpha = 1]) {
  if (alpha <= 0) return;
  canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alpha));
  _text(canvas, emoji, center, fontSize, bold: false, color: Colors.black);
  canvas.restore();
}

void _cloud(Canvas canvas, Offset c, double r, Color color) {
  final p = _fill(color);
  canvas.drawCircle(c, r, p);
  canvas.drawCircle(c + Offset(-r * 1.1, r * 0.25), r * 0.8, p);
  canvas.drawCircle(c + Offset(r * 1.1, r * 0.2), r * 0.9, p);
  canvas.drawCircle(c + Offset(r * 0.2, r * 0.45), r * 0.7, p);
}

void _sun(Canvas canvas, Offset c, double r, double turn) {
  final ray = Paint()
    ..color = const Color(0xFFFFB300)
    ..strokeWidth = r * 0.12
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 12; i++) {
    final a = i * pi / 6 + turn * _tau;
    canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 1.25, c + Offset(cos(a), sin(a)) * r * 1.6, ray);
  }
  canvas.drawCircle(c, r, _fill(const Color(0xFFFFD54F)));
}

void _hill(Canvas canvas, Size size, double top, double cx, double h, Color color) {
  final path = Path()
    ..moveTo(0, size.height)
    ..lineTo(0, top + h)
    ..quadraticBezierTo(cx, top - h, size.width, top + h * 0.6)
    ..lineTo(size.width, size.height)
    ..close();
  canvas.drawPath(path, _fill(color));
}

Path _starPath(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final p = c + Offset(cos(a), sin(a)) * rad;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

abstract class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t, this.variant);
  final double t;
  final int variant;

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t || old.variant != variant;
}

// ---------------- Ocean ----------------

class _OceanPainter extends _ScenePainter {
  _OceanPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _gradient(canvas, size, const [Color(0xFF4FC3F7), Color(0xFF0277BD), Color(0xFF01579B)]);
    for (var i = 0; i < 4; i++) {
      final x = w * (0.1 + i * 0.27) + sin(t * _tau + i) * w * 0.02;
      final ray = Path()
        ..moveTo(x - w * 0.03, 0)
        ..lineTo(x + w * 0.03, 0)
        ..lineTo(x + w * 0.09, h * 0.8)
        ..lineTo(x - w * 0.01, h * 0.8)
        ..close();
      canvas.drawPath(ray, _fill(Colors.white.withValues(alpha: 0.06)));
    }
    final sandTop = h * 0.88;
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, sandTop)
        ..quadraticBezierTo(w * 0.25, sandTop - h * 0.03, w * 0.5, sandTop)
        ..quadraticBezierTo(w * 0.75, sandTop + h * 0.03, w, sandTop - h * 0.01)
        ..lineTo(w, h)
        ..close(),
      _fill(const Color(0xFFFFE0A3)),
    );
    final weed = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.025
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final baseX = w * (0.08 + i * 0.21);
      final sway = sin(t * _tau * 3 + i * 1.3) * w * 0.04;
      final tall = h * (0.16 + (i % 3) * 0.05);
      canvas.drawPath(
        Path()
          ..moveTo(baseX, sandTop + h * 0.02)
          ..quadraticBezierTo(baseX - sway, sandTop - tall * 0.5, baseX + sway, sandTop - tall),
        weed,
      );
    }
    for (var i = 0; i < 9; i++) {
      final p = (t * 3 + i * 0.137) % 1;
      final x = w * (0.05 + (i * 0.113) % 0.9) + sin(p * _tau * 2 + i) * w * 0.015;
      canvas.drawCircle(
        Offset(x, sandTop - p * sandTop),
        size.shortestSide * (0.012 + (i % 3) * 0.006),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final r = size.shortestSide * 0.09;
    for (var i = 0; i < KidsTimeline.fishVisible(t); i++) {
      final start = KidsTimeline.fishStart + i * KidsTimeline.fishStep;
      final alpha = ((t - start) / 0.03).clamp(0.0, 1.0) * ((1 - t) / 0.06).clamp(0.0, 1.0);
      final x = (((t - start) * 0.55 + i * 0.19 + 0.05) % 1.25 - 0.12) * w;
      final y = h * (0.30 + i * 0.11) + sin(t * _tau * 4 + i) * h * 0.01;
      _fish(canvas, Offset(x, y), r, Color(KidsTimeline.fishColor(variant, i).argb).withValues(alpha: alpha));
      _text(canvas, '${i + 1}', Offset(x, y - r * 1.2), r * 0.7, color: Colors.white.withValues(alpha: alpha));
    }
  }

  void _fish(Canvas canvas, Offset c, double r, Color color) {
    final p = _fill(color);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.8, c.dy)
        ..lineTo(c.dx - r * 1.5, c.dy - r * 0.6)
        ..lineTo(c.dx - r * 1.5, c.dy + r * 0.6)
        ..close(),
      p,
    );
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 1.24), p);
    final a = color.a;
    canvas.drawCircle(c + Offset(r * 0.5, -r * 0.15), r * 0.2, _fill(Colors.white.withValues(alpha: a)));
    canvas.drawCircle(c + Offset(r * 0.55, -r * 0.15), r * 0.1, _fill(const Color(0xFF263238).withValues(alpha: a)));
  }
}

// ---------------- Fermă ----------------

class _FarmPainter extends _ScenePainter {
  _FarmPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF81D4FA), Color(0xFFE1F5FE)]);
    _sun(canvas, Offset(w * 0.85, h * 0.14), m * 0.08, t * 0.3);
    _cloud(canvas, Offset(w * (0.25 + 0.1 * sin(t * _tau)), h * 0.2), m * 0.06, Colors.white);
    final ground = h * 0.62;
    _hill(canvas, size, ground, w * 0.6, h * 0.05, const Color(0xFF8BC34A));
    // Hambarul.
    final bx = w * 0.05, bw = w * 0.3, bTop = ground - h * 0.12;
    canvas.drawRect(Rect.fromLTWH(bx, bTop, bw, h * 0.18), _fill(const Color(0xFFC62828)));
    canvas.drawPath(
      Path()
        ..moveTo(bx - bw * 0.08, bTop)
        ..lineTo(bx + bw / 2, bTop - h * 0.08)
        ..lineTo(bx + bw * 1.08, bTop)
        ..close(),
      _fill(const Color(0xFF8D2A1F)),
    );
    final door = Rect.fromLTWH(bx + bw * 0.3, bTop + h * 0.06, bw * 0.4, h * 0.12);
    final line = Paint()
      ..color = const Color(0xFFFFF8E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;
    canvas.drawRect(door, line);
    canvas.drawLine(door.topLeft, door.bottomRight, line);
    canvas.drawLine(door.topRight, door.bottomLeft, line);
    // Gardul.
    final fenceY = ground + h * 0.05;
    final brown = Paint()
      ..color = const Color(0xFFA1887F)
      ..strokeWidth = h * 0.008;
    canvas.drawLine(Offset(w * 0.4, fenceY), Offset(w, fenceY), brown);
    canvas.drawLine(Offset(w * 0.4, fenceY + h * 0.035), Offset(w, fenceY + h * 0.035), brown);
    for (var x = w * 0.42; x < w; x += w * 0.08) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, fenceY - h * 0.03, w * 0.02, h * 0.08), Radius.circular(w * 0.01)),
        _fill(const Color(0xFFA1887F)),
      );
    }
    // Animalul de acum, cu o mică țopăială și balonul cu sunetul lui.
    final slot = KidsTimeline.farmSlot(t);
    final local = t * 5 - slot;
    final a = KidsTimeline.animal(variant, slot);
    final alpha = _fade(local);
    final hop = (sin(local * pi * 4)).abs() * h * 0.02;
    _emoji(canvas, a.emoji, Offset(w * 0.5, h * 0.74 - hop), m * 0.32, alpha);
    if (local > 0.3) {
      final ba = alpha * ((local - 0.3) / 0.08).clamp(0.0, 1.0);
      final bubble = Offset(w * 0.68, h * 0.48);
      final bubbleRect = Rect.fromCenter(center: bubble, width: m * 0.5, height: m * 0.18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, Radius.circular(m * 0.09)),
        _fill(Colors.white.withValues(alpha: ba)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(bubble.dx - m * 0.12, bubbleRect.bottom - 2)
          ..lineTo(bubble.dx - m * 0.18, bubbleRect.bottom + m * 0.08)
          ..lineTo(bubble.dx - m * 0.03, bubbleRect.bottom - 2)
          ..close(),
        _fill(Colors.white.withValues(alpha: ba)),
      );
      _text(canvas, a.sound, bubble, m * 0.07, color: const Color(0xFF5D4037).withValues(alpha: ba));
    }
  }
}

// ---------------- Baloane ----------------

class _BalloonPainter extends _ScenePainter {
  _BalloonPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF90CAF9), Color(0xFFFFF3E0)]);
    for (var i = 0; i < 3; i++) {
      final cx = (((t * 0.8) + i * 0.37) % 1.3 - 0.15) * w;
      _cloud(canvas, Offset(cx, h * (0.2 + i * 0.14)), m * 0.06, Colors.white.withValues(alpha: 0.85));
    }
    _hill(canvas, size, h * 0.88, w * 0.4, h * 0.04, const Color(0xFF9CCC65));
    final r = m * 0.1;
    for (var i = 0; i < 5; i++) {
      final p = (t - (KidsTimeline.balloonStart + i * KidsTimeline.balloonStep)) / KidsTimeline.balloonRise;
      if (p < 0 || p > 1) continue;
      final x = w * (0.14 + i * 0.18) + sin(p * _tau * 1.5 + i) * w * 0.02;
      final y = h * 1.1 - p * h * 1.4;
      final color = Color(KidsTimeline.balloonColor(variant, i).argb);
      canvas.drawPath(
        Path()
          ..moveTo(x, y + r * 1.2)
          ..quadraticBezierTo(x - r * 0.3, y + r * 1.8, x + r * 0.1, y + r * 2.6),
        Paint()
          ..color = const Color(0xFF616161)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, y + r * 1.1)
          ..lineTo(x - r * 0.15, y + r * 1.32)
          ..lineTo(x + r * 0.15, y + r * 1.32)
          ..close(),
        _fill(color),
      );
      final body = Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2.4);
      canvas.drawOval(body, _fill(color));
      if (color.toARGB32() == 0xFFFFFFFF) {
        canvas.drawOval(
          body,
          Paint()
            ..color = const Color(0x33000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.drawOval(
        Rect.fromLTWH(x - r * 0.55, y - r * 0.85, r * 0.35, r * 0.6),
        _fill(Colors.white.withValues(alpha: 0.45)),
      );
    }
  }
}

// ---------------- Tren ----------------

class _TrainPainter extends _ScenePainter {
  _TrainPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _gradient(canvas, size, const [Color(0xFF64B5F6), Color(0xFFE3F2FD)]);
    _sun(canvas, Offset(w * 0.15, h * 0.16), size.shortestSide * 0.07, t * 0.3);
    _hill(canvas, size, h * 0.6, w * 0.7, h * 0.06, const Color(0xFFAED581));
    // Copaci în depărtare care trec încet (parcă mergem cu trenul).
    for (var i = 0; i < 7; i++) {
      final x = (((i / 7) - t * 0.6) % 1) * w * 1.2 - w * 0.1;
      final baseY = h * 0.64;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY - h * 0.03),
        Paint()
          ..color = const Color(0xFF6D4C41)
          ..strokeWidth = 3,
      );
      canvas.drawCircle(Offset(x, baseY - h * 0.045), size.shortestSide * 0.05, _fill(const Color(0xFF558B2F)));
    }
    final rail = h * 0.72;
    canvas.drawRect(Rect.fromLTWH(0, rail - h * 0.01, w, h), _fill(const Color(0xFF7CB342)));
    for (var sx = 0.0; sx < w; sx += w * 0.06) {
      canvas.drawRect(Rect.fromLTWH(sx, rail + h * 0.004, w * 0.025, h * 0.015), _fill(const Color(0xFF795548)));
    }
    canvas.drawLine(
      Offset(0, rail + h * 0.006),
      Offset(w, rail + h * 0.006),
      Paint()
        ..color = const Color(0xFF616161)
        ..strokeWidth = 3,
    );

    final car = w / KidsTimeline.screenCars;
    final front = KidsTimeline.trainFront(t) * car;
    final carH = car * 0.55;
    final top = rail - carH - car * 0.12;
    final fruit = KidsTimeline.fruit(variant);
    for (var k = 0; k <= 5; k++) {
      final right = front - k * car;
      final left = right - car * 0.94;
      if (right < 0 || left > w) continue;
      final wheelR = car * 0.11;
      final body = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, car * 0.94, carH), Radius.circular(car * 0.06));
      if (k == 0) {
        canvas.drawRRect(body, _fill(const Color(0xFFD32F2F)));
        canvas.drawRect(Rect.fromLTWH(left, top - carH * 0.6, car * 0.42, carH * 0.6), _fill(const Color(0xFFB71C1C)));
        canvas.drawRect(
          Rect.fromLTWH(left + car * 0.08, top - carH * 0.45, car * 0.26, carH * 0.3),
          _fill(const Color(0xFFBBDEFB)),
        );
        canvas.drawRect(
          Rect.fromLTWH(right - car * 0.3, top - carH * 0.5, car * 0.14, carH * 0.5),
          _fill(const Color(0xFF424242)),
        );
        for (var j = 0; j < 3; j++) {
          final p = (t * 6 + j / 3) % 1;
          canvas.drawCircle(
            Offset(right - car * 0.23 - p * car * 0.5, top - carH * 0.6 - p * car * 0.6),
            car * (0.06 + p * 0.1),
            _fill(Colors.white.withValues(alpha: 0.7 * (1 - p))),
          );
        }
      } else {
        canvas.drawRRect(body, _fill(Color(KidsTimeline.colors[(k + variant) % 7].argb)));
        final fs = car * 0.17;
        for (var j = 0; j < k; j++) {
          final fx = left + car * 0.47 + (j - (k - 1) / 2) * fs * 0.95;
          _emoji(canvas, fruit.emoji, Offset(fx, top - fs * 0.45), fs * 0.8);
        }
        final c = Offset(left + car * 0.47, top + carH * 0.5);
        canvas.drawCircle(c, carH * 0.3, _fill(Colors.white));
        _text(canvas, '$k', c, carH * 0.36, color: const Color(0xFF37474F));
      }
      canvas.drawLine(
        Offset(left - car * 0.06, top + carH * 0.75),
        Offset(left, top + carH * 0.75),
        Paint()
          ..color = const Color(0xFF424242)
          ..strokeWidth = car * 0.03,
      );
      for (final wx in [left + car * 0.22, left + car * 0.72]) {
        final c = Offset(wx, rail - wheelR * 0.2);
        canvas.drawCircle(c, wheelR, _fill(const Color(0xFF37474F)));
        final a = front / wheelR;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * wheelR * 0.8,
          c - Offset(cos(a), sin(a)) * wheelR * 0.8,
          Paint()
            ..color = const Color(0xFFB0BEC5)
            ..strokeWidth = wheelR * 0.2,
        );
      }
    }
  }
}

// ---------------- Forme ----------------

class _ShapesPainter extends _ScenePainter {
  _ShapesPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF283593), Color(0xFF5C6BC0)]);
    final slot = KidsTimeline.shapeSlot(t);
    final local = t * 5 - slot;
    for (var j = 0; j < slot; j++) {
      _shape(
        canvas,
        KidsTimeline.shape(variant, j),
        Offset(w * (0.2 + j * 0.15), h * 0.84),
        m * 0.06,
        Color(KidsTimeline.shapeColor(variant, j).argb),
      );
    }
    final alpha = _fade(local, 0.1);
    final grow = 0.7 + 0.3 * (local / 0.15).clamp(0.0, 1.0);
    final c = Offset(w / 2, h * 0.5);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sin(local * _tau) * 8 * pi / 180);
    canvas.scale(grow);
    _shape(
      canvas,
      KidsTimeline.shape(variant, slot),
      Offset.zero,
      m * 0.24,
      Color(KidsTimeline.shapeColor(variant, slot).argb).withValues(alpha: alpha),
    );
    canvas.restore();
  }

  void _shape(Canvas canvas, KidShape shape, Offset c, double r, Color color) {
    final p = _fill(color);
    switch (shape) {
      case KidShape.circle:
        canvas.drawCircle(c, r, p);
      case KidShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 1.8, height: r * 1.8),
            Radius.circular(r * 0.1),
          ),
          p,
        );
      case KidShape.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r * 1.05, c.dy + r * 0.8)
            ..lineTo(c.dx - r * 1.05, c.dy + r * 0.8)
            ..close(),
          p,
        );
      case KidShape.star:
        canvas.drawPath(_starPath(c, r * 1.1), p);
      case KidShape.heart:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy + r * 0.9)
            ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.1, c.dx - r * 0.8, c.dy - r * 1.3, c.dx, c.dy - r * 0.45)
            ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.3, c.dx + r * 1.6, c.dy - r * 0.1, c.dx, c.dy + r * 0.9)
            ..close(),
          p,
        );
    }
  }
}

// ---------------- Fotbal ----------------

void _ball(Canvas canvas, Offset c, double r, double spin) {
  canvas.drawCircle(c, r, _fill(Colors.white));
  final dark = const Color(0xFF263238);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08,
  );
  final pent = Path();
  final spoke = Paint()
    ..color = dark
    ..strokeWidth = r * 0.07;
  for (var i = 0; i < 5; i++) {
    final a = -pi / 2 + i * _tau / 5 + spin;
    final p = c + Offset(cos(a), sin(a)) * r * 0.38;
    i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
    canvas.drawLine(p, c + Offset(cos(a), sin(a)) * r, spoke);
  }
  canvas.drawPath(pent..close(), _fill(dark));
}

class _FootballPainter extends _ScenePainter {
  _FootballPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _gradient(canvas, Size(w, h * 0.45), const [Color(0xFF64B5F6), Color(0xFFBBDEFB)]);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.3, w, h * 0.15), _fill(const Color(0xFF546E7A)));
    for (var i = 0; i < 24; i++) {
      final x = w * (i + 0.5) / 24;
      final y = h * (0.34 + (i % 3) * 0.035) - (sin(t * _tau * 6 + i)).abs() * h * 0.008;
      canvas.drawCircle(
        Offset(x, y),
        size.shortestSide * 0.018,
        _fill(Color(KidsTimeline.colors[(i + variant) % 8].argb)),
      );
    }
    for (var i = 0; i < 8; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.45 + i * h * 0.07, w, h * 0.07 + 1),
        _fill(i.isEven ? const Color(0xFF43A047) : const Color(0xFF388E3C)),
      );
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.5, h * 0.45), Offset(w * 0.5, h), line);
    canvas.drawCircle(Offset(w * 0.5, h * 0.72), size.shortestSide * 0.18, line);
    final goalL = w * 0.7, goalR = w * 0.95, goalTop = h * 0.55, goalBottom = h * 0.78;
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = goalL + (goalR - goalL) * i / 8;
      canvas.drawLine(Offset(x, goalTop), Offset(x, goalBottom), net);
    }
    for (var i = 1; i < 6; i++) {
      final y = goalTop + (goalBottom - goalTop) * i / 6;
      canvas.drawLine(Offset(goalL, y), Offset(goalR, y), net);
    }
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(goalL, goalBottom), Offset(goalL, goalTop), post);
    canvas.drawLine(Offset(goalL, goalTop), Offset(goalR, goalTop), post);
    canvas.drawLine(Offset(goalR, goalTop), Offset(goalR, goalBottom), post);
    final r = size.shortestSide * 0.06;
    final local = KidsTimeline.kickLocal(t);
    final scored = KidsTimeline.goals(t) - (local >= KidsTimeline.goalAt ? 1 : 0);
    for (var i = 0; i < scored; i++) {
      _ball(canvas, Offset(goalL + r * 0.9 + i * r * 1.0, goalBottom - r * 0.5), r * 0.45, 0);
    }
    final start = Offset(w * 0.2, h * 0.86), end = Offset(w * 0.83, h * 0.68);
    final p = ((local - KidsTimeline.kickAt) / (KidsTimeline.goalAt - KidsTimeline.kickAt)).clamp(0.0, 1.0);
    final arc = h * (0.15 + (variant % 3) * 0.05);
    final ball = Offset(start.dx + (end.dx - start.dx) * p, start.dy + (end.dy - start.dy) * p - sin(p * pi) * arc);
    final alpha = ((1 - local) / 0.08).clamp(0.0, 1.0);
    if (alpha > 0) {
      canvas.drawCircle(
        Offset(ball.dx, start.dy + r + (end.dy - start.dy) * p),
        r * 0.9,
        _fill(Colors.black.withValues(alpha: 0.18 * alpha)),
      );
      _ball(canvas, ball, r, p * 4 * pi);
    }
  }
}

// ---------------- Sorcova ----------------

void _snow(Canvas canvas, Size size, double t) {
  for (var i = 0; i < 40; i++) {
    final speed = 0.6 + (i % 4) * 0.2;
    final p = (t * speed * 2 + i * 0.0731) % 1;
    final x = size.width * ((i * 0.137) % 1) + sin(p * _tau * 2 + i) * size.width * 0.015;
    canvas.drawCircle(
      Offset(x, p * size.height),
      size.shortestSide * (0.006 + (i % 3) * 0.003),
      _fill(Colors.white.withValues(alpha: 0.85)),
    );
  }
}

class _SorcovaPainter extends _ScenePainter {
  _SorcovaPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF7986CB)]);
    _snow(canvas, size, t);
    _hill(canvas, size, h * 0.88, w * 0.5, h * 0.04, const Color(0xFFE8EAF6));
    final base = Offset(w * 0.5, h * 0.95);
    final stickLen = h * 0.5;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(sin(t * _tau * 5) * 14 * pi / 180);
    final top = Offset(0, -stickLen);
    canvas.drawLine(
      Offset.zero,
      top,
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = m * 0.03
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 5; i++) {
      final sway = sin(t * _tau * 5 + i) * m * 0.04;
      final x0 = top.dx + (i - 2) * m * 0.035;
      canvas.drawPath(
        Path()
          ..moveTo(x0, top.dy + h * 0.02)
          ..quadraticBezierTo(x0 + sway, top.dy + h * 0.12, x0 - sway, top.dy + h * 0.22),
        Paint()
          ..color = Color(KidsTimeline.colors[(i + variant) % 7].argb)
          ..style = PaintingStyle.stroke
          ..strokeWidth = m * 0.016
          ..strokeCap = StrokeCap.round,
      );
    }
    final fr = m * 0.075;
    const spots = [
      Offset(0, -2.2),
      Offset(-1.3, -1.5),
      Offset(1.3, -1.5),
      Offset(-1.9, -0.2),
      Offset(1.9, -0.2),
      Offset(-0.7, -0.4),
      Offset(0.7, -0.4),
      Offset(0, -1.2),
    ];
    for (var i = 0; i < spots.length; i++) {
      final c = top + spots[i] * fr;
      final color = Color(KidsTimeline.colors[(i * 3 + variant) % 8].argb);
      for (var k = 0; k < 6; k++) {
        final a = k * _tau / 6 + t * 2;
        canvas.drawCircle(c + Offset(cos(a), sin(a)) * fr * 0.45, fr * 0.42, _fill(color));
      }
      canvas.drawCircle(c, fr * 0.3, _fill(const Color(0xFFFFF59D)));
    }
    canvas.restore();
  }
}

// ---------------- Moș Crăciun ----------------

void _gift(Canvas canvas, Offset c, double s, Color color) {
  final ribbon = _fill(const Color(0xFFFFEB3B).withValues(alpha: color.a));
  canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s), _fill(color));
  canvas.drawRect(Rect.fromCenter(center: c, width: s * 0.16, height: s), ribbon);
  canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s * 0.16), ribbon);
  canvas.drawCircle(c + Offset(-s * 0.12, -s * 0.56), s * 0.14, ribbon);
  canvas.drawCircle(c + Offset(s * 0.12, -s * 0.56), s * 0.14, ribbon);
}

class _SantaPainter extends _ScenePainter {
  _SantaPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF0D1B4C), Color(0xFF283E8C)]);
    for (var i = 0; i < 14; i++) {
      final pos = Offset(w * ((i * 0.193 + 0.05) % 1), h * (0.05 + (i * 0.071) % 0.35));
      canvas.drawPath(_starPath(pos, m * 0.012 * (1 + 0.15 * sin(t * _tau * 3 + i))), _fill(const Color(0xFFFFF59D)));
    }
    canvas.drawCircle(Offset(w * 0.82, h * 0.12), m * 0.07, _fill(const Color(0xFFFFF4C2)));
    _snow(canvas, size, t);
    final ground = h * 0.8;
    _hill(canvas, size, ground, w * 0.4, h * 0.03, const Color(0xFFF5F5F5));
    for (var i = 0; i < 2; i++) {
      final hx = w * (0.06 + i * 0.27), hw = w * 0.2, hTop = ground - h * 0.08;
      canvas.drawRect(Rect.fromLTWH(hx, hTop, hw, h * 0.1), _fill(const Color(0xFF8D6E63)));
      canvas.drawPath(
        Path()
          ..moveTo(hx - hw * 0.1, hTop)
          ..lineTo(hx + hw / 2, hTop - h * 0.05)
          ..lineTo(hx + hw * 1.1, hTop)
          ..close(),
        _fill(Colors.white),
      );
      canvas.drawRect(
        Rect.fromLTWH(hx + hw * 0.35, hTop + h * 0.025, hw * 0.3, h * 0.03),
        _fill(const Color(0xFFFFD54F)),
      );
    }
    final treeX = w * 0.78, treeBase = ground + h * 0.02;
    for (var k = 0; k < 3; k++) {
      final tw = w * (0.3 - k * 0.07), ty = treeBase - h * (0.05 + k * 0.06);
      canvas.drawPath(
        Path()
          ..moveTo(treeX - tw / 2, ty)
          ..lineTo(treeX, ty - h * 0.1)
          ..lineTo(treeX + tw / 2, ty)
          ..close(),
        _fill(const Color(0xFF2E7D32)),
      );
    }
    canvas.drawPath(_starPath(Offset(treeX, treeBase - h * 0.27), m * 0.04), _fill(const Color(0xFFFFD54F)));
    // Beculețe care se aprind încet pe rând.
    for (var k = 0; k < 9; k++) {
      final lx = treeX + ((k % 3) - 1) * w * 0.07 * (1.2 - (k ~/ 3) * 0.3);
      final ly = treeBase - h * (0.07 + (k ~/ 3) * 0.06);
      final on = 0.5 + 0.5 * sin(t * _tau * 3 + k * 1.7);
      canvas.drawCircle(
        Offset(lx, ly),
        m * 0.012,
        _fill(Color(KidsTimeline.colors[k % 7].argb).withValues(alpha: 0.4 + 0.6 * on)),
      );
    }
    final giftS = m * 0.08;
    Offset pile(int i) => Offset(treeX + (i - 2) * giftS * 1.1, treeBase + giftS * 0.1);
    // Sania merge de la dreapta la stânga, cu renii în față.
    double sleighX(double p) => w * 1.3 - p * w * 1.6;
    final sp = KidsTimeline.sleighProgress(t);
    for (var i = 0; i < 5; i++) {
      final drop = KidsTimeline.giftFirst + i * KidsTimeline.giftStep;
      if (t < drop) continue;
      final q = ((t - drop) / KidsTimeline.giftFall).clamp(0.0, 1.0);
      final from = Offset(sleighX(KidsTimeline.sleighProgress(drop)), h * 0.34);
      final to = pile(i);
      final fade = ((1 - t) / 0.05).clamp(0.0, 1.0);
      _gift(
        canvas,
        Offset(from.dx + (to.dx - from.dx) * q, from.dy + (to.dy - from.dy) * q * q),
        giftS,
        Color(KidsTimeline.colors[(i * 2 + variant) % 7].argb).withValues(alpha: fade),
      );
    }
    if (sp > 0.001 && sp < 0.999) {
      _emoji(canvas, '🦌🦌🛷🎅', Offset(sleighX(sp), h * 0.3 + sin(sp * _tau) * h * 0.03), m * 0.1);
    }
  }
}

// ---------------- Dinozauri ----------------

void _palm(Canvas canvas, Offset base, double h, double t) {
  final top = Offset(base.dx + h * 0.08, base.dy - h);
  canvas.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx + h * 0.15, base.dy - h * 0.5, top.dx, top.dy),
    Paint()
      ..color = const Color(0xFF795548)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.07
      ..strokeCap = StrokeCap.round,
  );
  final leaf = Paint()
    ..color = const Color(0xFF2E7D32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.05
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 6; i++) {
    final a = -pi + i * pi / 5 + sin(t * _tau * 2 + i) * 0.06;
    final end = Offset(top.dx + cos(a) * h * 0.45, top.dy + sin(a) * h * 0.25 + h * 0.12);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo((top.dx + end.dx) / 2, top.dy - h * 0.12, end.dx, end.dy),
      leaf,
    );
  }
}

class _DinosPainter extends _ScenePainter {
  _DinosPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFFFFB74D), Color(0xFFFFE0B2), Color(0xFFFFF3E0)]);
    final vBase = h * 0.66;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.4, vBase)
        ..lineTo(w * 0.62, h * 0.4)
        ..lineTo(w * 0.74, h * 0.4)
        ..lineTo(w * 0.98, vBase)
        ..close(),
      _fill(const Color(0xFF6D4C41)),
    );
    for (var i = 0; i < 4; i++) {
      final p = (t * 2 + i / 4) % 1;
      canvas.drawCircle(
        Offset(w * 0.68 + p * w * 0.05, h * 0.38 - p * h * 0.18),
        m * (0.04 + p * 0.07),
        _fill(const Color(0xFF9E9E9E).withValues(alpha: 0.6 * (1 - p))),
      );
    }
    _hill(canvas, size, h * 0.64, w * 0.3, h * 0.04, const Color(0xFF9CCC65));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), _fill(const Color(0xFF8BC34A)));
    _palm(canvas, Offset(w * 0.1, h * 0.76), h * 0.22, t);
    _palm(canvas, Offset(w * 0.92, h * 0.8), h * 0.18, t + 0.3);
    const emojis = ['🦕', '🦖', '🦕', '🦖', '🦕'];
    for (var i = 0; i < KidsTimeline.dinosVisible(t); i++) {
      final start = KidsTimeline.fishStart + i * KidsTimeline.fishStep;
      final alpha = ((t - start) / 0.03).clamp(0.0, 1.0) * ((1 - t) / 0.06).clamp(0.0, 1.0);
      final x = w * 1.15 - (((t - start) * 0.5 + i * 0.17) % 1.3) * w;
      final y = h * (0.76 + (i % 2) * 0.08) - (sin((t - start) * _tau * 6)).abs() * h * 0.008;
      final sz = m * (0.2 + (i % 2) * 0.06);
      _emoji(canvas, emojis[i], Offset(x, y), sz, alpha);
      _text(canvas, '${i + 1}', Offset(x, y - sz * 0.75), sz * 0.3, color: Colors.white.withValues(alpha: alpha));
    }
  }
}

// ---------------- Pompierii ----------------

void _flame(Canvas canvas, Offset c, double r, double t, int k) {
  if (r <= 1) return;
  final wob = 1 + 0.08 * sin(t * _tau * 8 + k);
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - r * 0.6, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.7, c.dy - r * 1.1 * wob, c.dx, c.dy - r * 1.8 * wob)
      ..quadraticBezierTo(c.dx + r * 0.7, c.dy - r * 1.1 * wob, c.dx + r * 0.6, c.dy)
      ..close(),
    _fill(const Color(0xFFFF7043)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - r * 0.3, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.35, c.dy - r * 0.6, c.dx, c.dy - r * wob)
      ..quadraticBezierTo(c.dx + r * 0.35, c.dy - r * 0.6, c.dx + r * 0.3, c.dy)
      ..close(),
    _fill(const Color(0xFFFFD54F)),
  );
}

class _FirePainter extends _ScenePainter {
  _FirePainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF90CAF9), Color(0xFFE3F2FD)]);
    _cloud(canvas, Offset(w * 0.25, h * 0.2), m * 0.06, Colors.white);
    final ground = h * 0.74;
    canvas.drawRect(Rect.fromLTWH(0, ground, w, h - ground), _fill(const Color(0xFF9E9E9E)));
    for (var x = 0.0; x < w; x += w * 0.15) {
      canvas.drawRect(Rect.fromLTWH(x, ground + h * 0.08, w * 0.07, h * 0.01), _fill(Colors.white));
    }
    final hx = w * 0.45, hw = w * 0.48, hTop = ground - h * 0.2;
    canvas.drawRect(Rect.fromLTWH(hx, hTop, hw, h * 0.2), _fill(const Color(0xFFFFCC80)));
    canvas.drawPath(
      Path()
        ..moveTo(hx - hw * 0.08, hTop)
        ..lineTo(hx + hw / 2, hTop - h * 0.09)
        ..lineTo(hx + hw * 1.08, hTop)
        ..close(),
      _fill(const Color(0xFFD84315)),
    );
    canvas.drawRect(
      Rect.fromLTWH(hx + hw * 0.4, ground - h * 0.09, hw * 0.2, h * 0.09),
      _fill(const Color(0xFF8D6E63)),
    );
    canvas.drawRect(
      Rect.fromLTWH(hx + hw * 0.1, hTop + h * 0.035, hw * 0.22, h * 0.05),
      _fill(const Color(0xFFB3E5FC)),
    );
    canvas.drawRect(
      Rect.fromLTWH(hx + hw * 0.68, hTop + h * 0.035, hw * 0.22, h * 0.05),
      _fill(const Color(0xFFB3E5FC)),
    );
    final fs = KidsTimeline.fireSize(t);
    for (var i = 0; i < 3; i++) {
      final p = (t * 3 + i / 3) % 1;
      canvas.drawCircle(
        Offset(hx + hw * 0.7 + p * w * 0.04, hTop - h * 0.07 - p * h * 0.18),
        m * (0.04 + p * 0.06),
        _fill(const Color(0xFF757575).withValues(alpha: 0.5 * fs * (1 - p))),
      );
    }
    _flame(canvas, Offset(hx + hw * 0.62, hTop - h * 0.02), m * 0.07 * fs, t, 0);
    _flame(canvas, Offset(hx + hw * 0.8, hTop), m * 0.055 * fs, t, 1);
    final arrive = KidsTimeline.truckArrive(t);
    final eased = 1 - (1 - arrive) * (1 - arrive);
    final truckSize = m * 0.3;
    final truck = Offset(-w * 0.3 + eased * w * 0.5, ground - truckSize * 0.25);
    if (t >= 0.2) {
      _emoji(canvas, '🚒', truck, truckSize);
      _emoji(canvas, '🧑‍🚒', Offset(truck.dx + truckSize * 0.5, ground + truckSize * 0.25), truckSize * 0.45);
    }
    if (KidsTimeline.firePhase(t) == 2) {
      final from = Offset(truck.dx + truckSize * 0.4, ground - truckSize * 0.45);
      final to = Offset(hx + hw * 0.7, hTop);
      for (var i = 0; i < 14; i++) {
        final q = ((i / 14) + t * 6) % 1;
        canvas.drawCircle(
          Offset(from.dx + (to.dx - from.dx) * q, from.dy + (to.dy - from.dy) * q - sin(q * pi) * h * 0.12),
          m * 0.012,
          _fill(const Color(0xFF29B6F6).withValues(alpha: 0.85)),
        );
      }
    }
    if (KidsTimeline.firePhase(t) == 3) _emoji(canvas, '👍', Offset(hx + hw / 2, hTop - h * 0.16), m * 0.12);
  }
}

// ---------------- La doctor ----------------

class _DoctorPainter extends _ScenePainter {
  _DoctorPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)]);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.3, w * 0.22, h * 0.24), const Radius.circular(10)),
      _fill(Colors.white),
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.155, h * 0.35, w * 0.03, h * 0.08), _fill(const Color(0xFFE53935)));
    canvas.drawRect(Rect.fromLTWH(w * 0.125, h * 0.375, w * 0.09, h * 0.03), _fill(const Color(0xFFE53935)));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.8, w, h * 0.2), _fill(const Color(0xFF80DEEA)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.64, w * 0.6, h * 0.05), const Radius.circular(8)),
      _fill(Colors.white),
    );
    final step = KidsTimeline.doctorStep(t);
    final patient = KidsTimeline.patient(variant).$2;
    final ps = m * 0.3;
    final pc = Offset(w * 0.4, h * 0.56);
    final bounce = step == 3 ? (sin(t * _tau * 6)).abs() * h * 0.02 : 0.0;
    _emoji(canvas, patient, pc - Offset(0, bounce), ps);
    _emoji(canvas, '👩‍⚕️', Offset(w * 0.8, h * 0.56), m * 0.3);
    switch (step) {
      case 0:
        _emoji(canvas, '😢', pc + Offset(ps * 0.55, -ps * 0.5), ps * 0.3);
      case 1:
        final beat = 1 + 0.18 * (sin(t * _tau * 10)).abs();
        _emoji(canvas, '🩺', Offset(w * 0.62, h * 0.52), ps * 0.4);
        _emoji(canvas, '❤️', pc - Offset(0, ps * 0.75), ps * 0.28 * beat);
      case 2:
        _emoji(canvas, '🩹', pc + Offset(-ps * 0.3, ps * 0.15), ps * 0.35);
      default:
        _emoji(canvas, '🩹', pc + Offset(-ps * 0.3, ps * 0.15 - bounce), ps * 0.35);
        for (var i = 0; i < 4; i++) {
          final q = (t * 4 + i / 4) % 1;
          _emoji(canvas, '💖', pc + Offset((i - 1.5) * ps * 0.4, -ps * 0.6 - q * h * 0.2), ps * 0.2, 1 - q);
        }
    }
  }
}

// ---------------- Zoo ----------------

class _ZooPainter extends _ScenePainter {
  _ZooPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFFFFE082), Color(0xFFFFF8E1)]);
    _sun(canvas, Offset(w * 0.82, h * 0.15), m * 0.08, t * 0.3);
    _hill(canvas, size, h * 0.6, w * 0.5, h * 0.04, const Color(0xFFDCE775));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.7, w, h * 0.3), _fill(const Color(0xFFC0CA33)));
    canvas.drawLine(
      Offset(w * 0.18, h * 0.72),
      Offset(w * 0.2, h * 0.46),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = w * 0.025,
    );
    canvas.drawOval(Rect.fromLTWH(w * 0.02, h * 0.4, w * 0.36, h * 0.08), _fill(const Color(0xFF689F38)));
    final slot = KidsTimeline.zooSlot(t);
    final local = t * 5 - slot;
    final a = KidsTimeline.zooAnimal(variant, slot);
    final x = w * (0.6 - 0.1 * (1 - (local / 0.2).clamp(0.0, 1.0)));
    final hop = (sin(local * pi * 3)).abs() * h * 0.012;
    _emoji(canvas, a.$1, Offset(x, h * 0.66 - hop), m * 0.42, _fade(local));
    for (var j = 0; j < slot; j++) {
      _emoji(canvas, KidsTimeline.zooAnimal(variant, j).$1, Offset(w * (0.2 + j * 0.15), h * 0.88), m * 0.1);
    }
  }
}

// ---------------- Plantăm copaci ----------------

void _tree(Canvas canvas, Offset base, double h, double growth) {
  if (growth <= 0) return;
  final th = h * growth;
  canvas.drawLine(
    base,
    Offset(base.dx, base.dy - th * 0.55),
    Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = h * 0.08 * max(0.3, growth)
      ..strokeCap = StrokeCap.round,
  );
  final c = Offset(base.dx, base.dy - th * 0.7);
  final r = h * 0.28 * growth;
  canvas.drawCircle(c, r, _fill(const Color(0xFF388E3C)));
  canvas.drawCircle(c + Offset(-r * 0.6, r * 0.2), r * 0.8, _fill(const Color(0xFF43A047)));
  canvas.drawCircle(c + Offset(r * 0.6, r * 0.2), r * 0.8, _fill(const Color(0xFF43A047)));
  canvas.drawCircle(c + Offset(0, -r * 0.4), r * 0.6, _fill(const Color(0xFF66BB6A)));
}

class _TreesPainter extends _ScenePainter {
  _TreesPainter(super.t, super.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, m = size.shortestSide;
    _gradient(canvas, size, const [Color(0xFF81D4FA), Color(0xFFE1F5FE)]);
    _sun(canvas, Offset(w * 0.15, h * 0.15), m * 0.08, t * 0.3);
    _cloud(canvas, Offset(w * (0.6 + 0.1 * sin(t * _tau)), h * 0.18), m * 0.06, Colors.white);
    final ground = h * 0.78;
    canvas.drawRect(Rect.fromLTWH(0, ground, w, h - ground), _fill(const Color(0xFF8D6E63)));
    canvas.drawRect(Rect.fromLTWH(0, ground - h * 0.015, w, h * 0.02), _fill(const Color(0xFF7CB342)));
    final slot = KidsTimeline.treeSlot(t);
    final local = KidsTimeline.treeLocal(t);
    Offset spot(int i) => Offset(w * (0.12 + i * 0.19), ground);
    final treeH = h * 0.3;
    for (var j = 0; j < slot; j++) {
      _tree(canvas, spot(j), treeH, 1);
    }
    final here = spot(slot);
    if (local < 0.45) {
      canvas.drawOval(Rect.fromCenter(center: here, width: w * 0.12, height: h * 0.02), _fill(const Color(0xFF5D4037)));
    }
    if (local < 0.25) _emoji(canvas, '🧑‍🌾', here + Offset(w * 0.1, -h * 0.06), m * 0.2);
    if (local >= 0.25 && local < 0.45) {
      _emoji(canvas, '🌱', here - Offset(0, h * 0.025), m * 0.1);
      for (var i = 0; i < 6; i++) {
        final q = ((i / 6) + t * 10) % 1;
        canvas.drawCircle(
          Offset(here.dx - w * 0.03 + i * w * 0.012, ground - h * 0.16 + q * h * 0.12),
          m * 0.01,
          _fill(const Color(0xFF29B6F6)),
        );
      }
      _emoji(canvas, '🚿', here + Offset(w * 0.03, -h * 0.19), m * 0.13);
    }
    _tree(canvas, here, treeH, KidsTimeline.treeGrowth(t));
    if (local >= 0.8) {
      _emoji(canvas, '🐦', here + Offset(w * 0.04, -treeH * 0.95 + sin(t * _tau * 8) * h * 0.008), m * 0.09);
    }
  }
}
