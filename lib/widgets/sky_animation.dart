import 'dart:math';

import 'package:flutter/material.dart';

/// Animație calmă pentru copii mici, afișată cât se ascultă radio: răsare
/// soarele, se lasă seara, apare luna și stelele se numără încet de la 1 la 5.
/// Un ciclu durează un minut; fără sclipiri sau mișcări bruște.
class SkyTimeline {
  static const cycle = Duration(seconds: 60);
  static const sunEnd = 0.48;
  static const moonStart = 0.48;
  static const firstStar = 0.60;
  static const starStep = 0.065;

  /// 1 = zi, 0 = noapte.
  static double dayness(double t) {
    if (t < 0.40) return 1;
    if (t < 0.50) return 1 - (t - 0.40) / 0.10;
    if (t < 0.92) return 0;
    return (t - 0.92) / 0.08;
  }

  static int starsVisible(double t) =>
      (t < firstStar || t >= 0.94) ? 0 : min(5, ((t - firstStar) / starStep).floor() + 1);

  static const _counts = ['o stea', 'două stele', 'trei stele', 'patru stele', 'cinci stele'];

  static String caption(double t) {
    final stars = starsVisible(t);
    if (t < 0.40) return 'Bună dimineața, Soare!';
    if (t < 0.50) return 'Se face seară';
    if (stars == 0 && t < 0.92) return 'A apărut Luna';
    if (stars > 0) return '$stars · ${_counts[stars - 1]}';
    return 'Bună dimineața!';
  }
}

/// Scena „cer cu soare, lună și stele”; t = poziția în ciclul de un minut.
class SkyPainter extends CustomPainter {
  SkyPainter(this.t);
  final double t;

  static const dayTop = Color(0xFF6EC6FF), dayBottom = Color(0xFFD8F1FF);
  static const nightTop = Color(0xFF0B1240), nightBottom = Color(0xFF2B3A7A);
  static const sun = Color(0xFFFFD54F), sunRay = Color(0xFFFFB300), moon = Color(0xFFFFF4C2), star = Color(0xFFFFE57F);
  static const hillDay = Color(0xFF7CC576), hillNight = Color(0xFF1E4D3A);
  static const hillDay2 = Color(0xFF5DAE5A), hillNight2 = Color(0xFF173D2E);
  static const stars = [
    Offset(0.18, 0.22),
    Offset(0.34, 0.14),
    Offset(0.50, 0.26),
    Offset(0.66, 0.16),
    Offset(0.80, 0.28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final d = SkyTimeline.dayness(t);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(nightTop, dayTop, d)!, Color.lerp(nightBottom, dayBottom, d)!],
        ).createShader(rect),
    );
    final horizon = size.height * 0.78;
    final m = size.shortestSide;

    if (t < SkyTimeline.sunEnd) {
      final p = t / SkyTimeline.sunEnd;
      _sun(canvas, Offset(size.width * (0.12 + 0.76 * p), horizon - sin(p * pi) * size.height * 0.5), m * 0.1);
    }
    if (d > 0) {
      for (var i = 0; i < 3; i++) {
        final x = (((t * 1.6) + i * 0.4) % 1.3 - 0.15) * size.width;
        _cloud(canvas, Offset(x, size.height * (0.2 + i * 0.08)), m * 0.06, Colors.white.withValues(alpha: 0.9 * d));
      }
    }
    if (t >= SkyTimeline.moonStart) {
      final p = min(1.0, (t - SkyTimeline.moonStart) / 0.12);
      _moon(canvas, Offset(size.width * 0.84, horizon - sin(p * pi / 2) * size.height * 0.58), m * 0.08, 1 - d);
    }
    final visible = SkyTimeline.starsVisible(t);
    for (var i = 0; i < visible; i++) {
      final appear = SkyTimeline.firstStar + i * SkyTimeline.starStep;
      final fade = ((t - appear) / 0.02).clamp(0.0, 1.0);
      final twinkle = 1 + 0.06 * sin((t * 60 + i) * 2);
      final pos = Offset(stars[i].dx * size.width, stars[i].dy * size.height);
      final r = m * 0.05 * twinkle * (0.6 + 0.4 * fade);
      canvas.drawPath(_star(pos, r), Paint()..color = star.withValues(alpha: fade * (1 - d)));
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: fade * (1 - d)),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + r * 1.1));
    }
    _hill(
      canvas,
      size,
      horizon - size.height * 0.02,
      size.width * 0.3,
      size.height * 0.16,
      Color.lerp(hillNight2, hillDay2, d)!,
    );
    _hill(
      canvas,
      size,
      horizon + size.height * 0.02,
      size.width * 0.75,
      size.height * 0.14,
      Color.lerp(hillNight, hillDay, d)!,
    );
  }

  void _sun(Canvas canvas, Offset c, double r) {
    final ray = Paint()
      ..color = sunRay
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + t * 2 * pi;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * r * 1.25, c + Offset(cos(a), sin(a)) * r * 1.6, ray);
    }
    canvas.drawCircle(c, r, Paint()..color = sun);
    final eye = Paint()..color = const Color(0xFF6D4C41);
    canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.2), r * 0.09, eye);
    canvas.drawCircle(c + Offset(r * 0.35, -r * 0.2), r * 0.09, eye);
    canvas.drawArc(
      Rect.fromLTWH(c.dx - r * 0.45, c.dy - r * 0.3, r * 0.9, r * 0.8),
      20 * pi / 180,
      140 * pi / 180,
      false,
      eye
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );
  }

  void _cloud(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c + Offset(-r * 1.1, r * 0.25), r * 0.8, p);
    canvas.drawCircle(c + Offset(r * 1.1, r * 0.2), r * 0.9, p);
    canvas.drawCircle(c + Offset(r * 0.2, r * 0.45), r * 0.7, p);
  }

  void _moon(Canvas canvas, Offset c, double r, double alpha) {
    final full = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cut = Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.45, -r * 0.2), radius: r * 0.9));
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), Paint()..color = moon.withValues(alpha: alpha));
  }

  Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a), sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  void _hill(Canvas canvas, Size size, double top, double cx, double h, Color color) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + h)
      ..quadraticBezierTo(cx, top - h, size.width, top + h * 0.6)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.t != t;
}
