import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/ghi_episodes.dart';
import '../data/ghi_character.dart';
import '../data/ghi_studio.dart';
import 'kid_tile.dart' show Remote;

const _tau = 2 * pi;

/// Un episod cu GHI: generic, povestea pe pași, apoi „Ce am învățat”.
/// La final trece singur la următorul (prin [onFinished]).
class GhiAnimation extends StatefulWidget {
  const GhiAnimation({
    super.key,
    required this.book,
    required this.index,
    required this.onFinished,
    this.onSay,
    this.onNext,
    this.onPrevious,
    this.autofocus = false,
    this.focusNode,
  });
  final GhiBook book;
  final int index;
  final VoidCallback onFinished;

  /// Vocea care povestește: primește fiecare text nou de pe ecran.
  final void Function(String text)? onSay;

  /// Telecomanda: ◀ ▶ trec la alt episod când nu e o întrebare pe ecran.
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<GhiAnimation> createState() => _GhiAnimationState();
}

class _GhiAnimationState extends State<GhiAnimation> with SingleTickerProviderStateMixin {
  final _elapsed = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _start = Duration.zero;
  Duration _last = Duration.zero;
  bool _finished = false;
  // Întrebările: cu cât am sărit înainte, la ce pas s-a răspuns corect și când a fost o alegere greșită.
  int _shift = 0;
  int _answeredBeat = -1;
  int _wrongAt = -1 << 30;
  String _lastSaid = '';
  // Telecomanda: obiectul ales la întrebare (◀ ▶ și OK).
  int _focus = 1;
  int _focusBeat = -1;

  GhiEpisode get _ep => widget.book.episodes[widget.index.clamp(0, widget.book.episodes.length - 1)];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      _last = d;
      final ms = (d - _start).inMilliseconds + _shift;
      _elapsed.value = ms;
      if (!_finished && ms >= GhiTimeline.durationMs(_ep)) {
        _finished = true;
        widget.onFinished();
      }
    })..start();
  }

  @override
  void didUpdateWidget(GhiAnimation old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _start = _last;
      _finished = false;
      _shift = 0;
      _answeredBeat = -1;
      _wrongAt = -1 << 30;
      _focusBeat = -1;
      _elapsed.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  /// Copilul atinge un obiect la o întrebare: bravo dacă e cel bun, altfel „mai caută”.
  void _tap(Offset pos, Size size) {
    final phase = GhiTimeline.phase(_ep, _elapsed.value);
    if (phase.kind != GhiPhaseKind.step) return;
    final beat = _ep.beats[phase.index];
    if (beat.ask == null || _answeredBeat == phase.index) return;
    final i = GhiTimeline.askHit(
      beat,
      phase.local,
      pos.dx / size.width,
      pos.dy / size.height,
      size.height / size.width,
    );
    if (i >= 0) _pick(i);
  }

  /// Întrebarea de pe ecran care așteaptă răspuns (indexul pasului), sau -1.
  int get _openAsk {
    final phase = GhiTimeline.phase(_ep, _elapsed.value);
    if (phase.kind != GhiPhaseKind.step) return -1;
    final beat = _ep.beats[phase.index];
    if (beat.ask == null || _answeredBeat == phase.index || beat.props.isEmpty) return -1;
    return phase.index;
  }

  /// Telecomanda: la o întrebare ◀ ▶ aleg obiectul și OK răspunde; altfel ◀ ▶ schimbă episodul.
  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e)) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final ask = _openAsk;
    if (ask >= 0) {
      final n = _ep.beats[ask].props.length;
      if (_focusBeat != ask) {
        _focusBeat = ask;
        _focus = min(1, n - 1);
      }
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
        setState(() => _focus = (_focus + (k == LogicalKeyboardKey.arrowRight ? 1 : -1) + n) % n);
        return KeyEventResult.handled;
      }
      if (Remote.isOk(k)) {
        _pick(_focus);
        return KeyEventResult.handled;
      }
    }
    if (k == LogicalKeyboardKey.arrowRight && widget.onNext != null) {
      widget.onNext!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft && widget.onPrevious != null) {
      widget.onPrevious!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _pick(int i) {
    final ms = _elapsed.value;
    final ep = _ep;
    final phase = GhiTimeline.phase(ep, ms);
    if (phase.kind != GhiPhaseKind.step) return;
    final ask = ep.beats[phase.index].ask;
    if (ask == null || _answeredBeat == phase.index) return;
    if (i == ask.answer) {
      _answeredBeat = phase.index;
      _shift += GhiTimeline.skipAfterAnswer(ep, ms);
    } else {
      _wrongAt = ms;
    }
  }

  String _caption(GhiEpisode ep, GhiPhase phase, int ms) {
    switch (phase.kind) {
      case GhiPhaseKind.title:
        return ep.title;
      case GhiPhaseKind.end:
        return 'Ce am învățat: ${ep.learn}';
      case GhiPhaseKind.step:
        return GhiTimeline.askCaption(
          ep.beats[phase.index],
          phase.local,
          answered: _answeredBeat == phase.index,
          wrong: ms - _wrongAt < GhiTimeline.wrongMs,
        );
    }
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
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) => _tap(d.localPosition, box.biggest),
            child: _frames(),
          ),
        );
      },
    );
  }

  Widget _frames() {
    return ValueListenableBuilder<int>(
      valueListenable: _elapsed,
      builder: (context, ms, _) {
        final ep = _ep;
        final phase = GhiTimeline.phase(ep, ms);
        final caption = _caption(ep, phase, ms);
        if (caption != _lastSaid) {
          _lastSaid = caption;
          final say = widget.onSay;
          if (say != null) WidgetsBinding.instance.addPostFrameCallback((_) => say(caption));
        }
        final answered = phase.kind == GhiPhaseKind.step && _answeredBeat == phase.index;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            CustomPaint(
              painter: GhiPainter(
                widget.book,
                ep,
                ms,
                answered: answered,
                focus: phase.kind == GhiPhaseKind.step && _focusBeat == phase.index ? _focus : -1,
              ),
              size: Size.infinite,
            ),
            // Benzi negre sus și jos, ca la cinema.
            const Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(heightFactor: 0.05, widthFactor: 1, child: ColoredBox(color: Colors.black)),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(heightFactor: 0.05, widthFactor: 1, child: ColoredBox(color: Colors.black)),
            ),
            if (phase.kind == GhiPhaseKind.title) _titleCard(ep, phase.local),
            if (phase.kind == GhiPhaseKind.end) _endCard(ep, phase.local),
            if (phase.kind == GhiPhaseKind.step)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64, left: 72, right: 72),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
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
    );
  }

  Widget _titleCard(GhiEpisode ep, double local) {
    final a = (local / 0.15).clamp(0.0, 1.0) * ((1 - local) / 0.2).clamp(0.0, 1.0);
    return Center(
      child: Opacity(
        opacity: a,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎬  Episodul ${widget.index + 1}',
                style: const TextStyle(color: Color(0xFFFFE082), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                ep.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  shadows: _shadow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endCard(GhiEpisode ep, double local) {
    final a = (local / 0.12).clamp(0.0, 1.0) * ((1 - local) / 0.1).clamp(0.0, 1.0);
    return Center(
      child: Opacity(
        opacity: a,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⭐ Ce am învățat',
                style: TextStyle(color: Color(0xFFF57C00), fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                ep.learn,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF263238), fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _shadow = [Shadow(color: Color(0x99000000), offset: Offset(2, 3), blurRadius: 8)];

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

void ghiText(Canvas canvas, String s, Offset c, double px, Color color, {bool bold = true, double alpha = 1}) {
  if (px < 2 || alpha <= 0.01) return;
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: color.withValues(alpha: color.a * alpha.clamp(0.0, 1.0)),
        fontSize: px,
        fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
        shadows: bold ? const [Shadow(color: Color(0x88000000), offset: Offset(1, 2), blurRadius: 4)] : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

void ghiEmoji(Canvas canvas, String e, Offset c, double px, [double alpha = 1]) {
  if (px < 2 || alpha <= 0.01) return;
  canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)));
  ghiText(canvas, e, c, px, Colors.black, bold: false);
  canvas.restore();
}

void _rotated(Canvas canvas, double deg, Offset pivot, void Function() draw) {
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(deg * pi / 180);
  canvas.translate(-pivot.dx, -pivot.dy);
  draw();
  canvas.restore();
}

void _tri(Canvas canvas, Offset a, Offset b, Offset c, Color color) => canvas.drawPath(
  Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close(),
  _fill(color),
);

void _cloud(Canvas canvas, Offset c, double r, Color color) {
  final p = _fill(color);
  canvas.drawCircle(c, r, p);
  canvas.drawCircle(c + Offset(-r * 0.9, r * 0.25), r * 0.8, p);
  canvas.drawCircle(c + Offset(r * 0.95, r * 0.2), r * 0.85, p);
  canvas.drawCircle(c + Offset(r * 0.3, -r * 0.55), r * 0.65, p);
}

Rect _r(double l, double t, double w, double h) => Rect.fromLTWH(l, t, w, h);

void _arc(Canvas canvas, Color c, double startDeg, double sweepDeg, bool center, Rect rect, [double? stroke]) {
  canvas.drawArc(
    rect,
    startDeg * pi / 180,
    sweepDeg * pi / 180,
    center,
    stroke == null ? _fill(c) : _stroke(c, stroke),
  );
}

/// Desenează un cadru: decorul, obiectele, numărătoarea și pe GHI, cu o cameră care se apropie încet.
class GhiPainter extends CustomPainter {
  GhiPainter(this.book, this.ep, this.ms, {this.answered = false, this.focus = -1});
  final GhiBook book;
  final GhiEpisode ep;
  final int ms;

  /// La o întrebare: copilul a ales deja obiectul bun.
  final bool answered;

  /// Obiectul ales cu telecomanda (-1 = niciunul).
  final int focus;

  @override
  bool shouldRepaint(GhiPainter old) => old.ms != ms || old.ep != ep || old.answered != answered || old.focus != focus;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = GhiTimeline.phase(ep, ms);
    // Mișcare lină, la fiecare cadru al ecranului.
    final ts = ms / 1000;
    int bi;
    double local, zoom;
    switch (phase.kind) {
      case GhiPhaseKind.title:
        bi = 0;
        local = 0;
        zoom = 1.25 - 0.25 * GhiTimeline.ease(phase.local);
      case GhiPhaseKind.step:
        bi = phase.index;
        local = phase.local;
        zoom = GhiTimeline.camera(ep.beats[bi], bi).at(phase.local);
      case GhiPhaseKind.end:
        bi = ep.beats.length - 1;
        local = 1;
        zoom = 1;
    }
    final beat = ep.beats[bi];
    final set = book.set(ep.set);
    final w = size.width, h = size.height;
    final ask = phase.kind == GhiPhaseKind.step ? beat.ask : null;
    // Când răspunsul e bun, GHI sare de bucurie.
    final g = ask != null && answered ? cheer(beat.ghi) : beat.ghi;
    final gx = g.x.at(local) * w;
    final gy = (g.y?.at(local) ?? (set.horizon + (1 - set.horizon) * 0.55)) * h;
    // Pe telefon (portret) GHI e un pic mai mic, ca să încapă și decorul.
    final ghiH = min(h * 0.42, w * 0.55);

    final pivot = Offset(gx, gy - ghiH * 0.5);
    // Decorul se mișcă mai încet decât personajele (paralaxă), ca în filme.
    final backZoom = 1 + (zoom - 1) * 0.5;
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(backZoom);
    canvas.translate(-pivot.dx + (w / 2 - gx) * 0.03, -pivot.dy);
    paintSetBack(canvas, size, set, ts);
    canvas.restore();
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(zoom);
    canvas.translate(-pivot.dx, -pivot.dy);
    if (ask != null) paintAskRings(canvas, size, beat, local, ts, answered: answered, focus: answered ? -1 : focus);
    for (final p in beat.props.where((p) => !p.front)) {
      _prop(canvas, size, p, local, ts);
    }
    if (beat.count != null) _count(canvas, size, beat.count!, local);
    // Privirea: GHI se uită la răspuns, la mami sau tati; părinții se uită la GHI.
    double? target;
    if (ask != null && ask.answer < beat.props.length) {
      target = beat.props[ask.answer].x.at(local) * w;
    } else if (beat.people.isNotEmpty) {
      target = beat.people.first.x.at(local) * w;
    }
    for (final pp in beat.people) {
      final px = pp.x.at(local) * w;
      paintPerson(
        canvas,
        pp,
        local,
        ts,
        px,
        (pp.y?.at(local) ?? (set.horizon + (1 - set.horizon) * 0.45)) * h,
        min(h * 0.66, w * 0.86),
        gazeAt: ((gx - px) / (w * 0.15)).clamp(-1.0, 1.0),
      );
    }
    paintGhi(
      canvas,
      g,
      local,
      ts,
      gx,
      gy,
      ghiH,
      look: target == null ? 0 : ((target - gx) / (w * 0.15)).clamp(-1.0, 1.0),
    );
    for (final p in beat.props.where((p) => p.front)) {
      _prop(canvas, size, p, local, ts);
    }
    paintSetFront(canvas, size, set, ts);
    canvas.restore();

    // La o tăietură de cadru, o clipă de întuneric moale.
    if (phase.kind == GhiPhaseKind.step && GhiTimeline.isCut(ep, phase.index) && phase.ms < 500) {
      canvas.drawRect(Offset.zero & size, _fill(Colors.black.withValues(alpha: 0.6 * (1 - phase.ms / 500))));
    }
    // Vignetă: marginile puțin mai întunecate, ca într-un film.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: const [Colors.transparent, Color(0x55000000)],
          radius: 0.9,
        ).createShader(rect),
    );
  }
}

/// GHI se bucură: aceeași poziție, dar sare, zâmbește și suflă steluțe.
GhiPose cheer(GhiPose g) => GhiPose({
  'pose': 'happy',
  'x': [g.x.from, g.x.to],
  'y': g.y == null ? null : [g.y!.from, g.y!.to],
  'face': 'happy',
  'puff': 'stars',
  'flip': g.flip,
});

/// Cercurile de la întrebări: unul auriu pe răspuns (după ce e găsit sau când GHI îl arată),
/// iar pe TV unul alb pe obiectul ales cu săgețile.
void paintAskRings(
  Canvas canvas,
  Size size,
  GhiBeat beat,
  double local,
  double ts, {
  bool answered = false,
  int focus = -1,
}) {
  final ask = beat.ask;
  if (ask == null) return;
  for (var i = 0; i < beat.props.length; i++) {
    final p = beat.props[i];
    final c = Offset(p.x.at(local) * size.width, p.y.at(local) * size.height);
    final r = p.size * size.shortestSide * 0.85;
    if (i == ask.answer && (answered || local >= GhiTimeline.reveal)) {
      final pulse = 1 + 0.08 * sin(ts * _tau * 1.2);
      canvas.drawCircle(c, r * 1.25 * pulse, _fill(const Color(0x55FFE082)));
      canvas.drawCircle(c, r * pulse, _stroke(const Color(0xFFFFC107), r * 0.12));
      if (answered) {
        for (var k = 0; k < 6; k++) {
          final a = k * pi / 3 + ts * 1.5;
          ghiText(canvas, '✦', c + Offset(cos(a), sin(a)) * r * 1.5, r * 0.35, const Color(0xFFFFD54F));
        }
      }
    } else {
      canvas.drawCircle(c, r, _fill(const Color(0x33FFFFFF)));
    }
    if (i == focus) canvas.drawCircle(c, r * 1.12, _stroke(Colors.white, r * 0.1));
  }
}

// ---------------- Decorurile ----------------

const _groundDecos = {
  'flowers',
  'lake',
  'reeds',
  'stripes',
  'goal',
  'rug',
  'path',
  'fence',
  'grass_edge',
  'counter',
  'bed',
  'lamp',
  'sink',
  'rails',
  'desk',
};
const _frontDecos = {'tub_front', 'snowfall', 'rain'};

void paintSetBack(Canvas canvas, Size size, GhiSet set, double ts) {
  final w = size.width, h = size.height, hz = set.horizon * h;
  final sky = Rect.fromLTWH(0, 0, w, hz);
  canvas.drawRect(
    sky,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: set.sky.map(Color.new).toList(),
      ).createShader(sky),
  );
  for (final d in set.deco.where((d) => !_groundDecos.contains(d) && !_frontDecos.contains(d))) {
    _deco(canvas, size, d, set, ts);
  }
  // Pământul: mai deschis spre orizont, mai închis în față, ca în lumina adevărată.
  final groundRect = Rect.fromLTWH(0, hz, w, h - hz);
  final ground = Color(set.ground);
  canvas.drawRect(
    groundRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(ground, Colors.white, 0.18)!, ground, Color.lerp(ground, Colors.black, 0.18)!],
        stops: const [0, 0.35, 1],
      ).createShader(groundRect),
  );
  // Ceață ușoară la orizont: ce e departe pare mai palid.
  final haze = Rect.fromLTWH(0, hz - h * 0.06, w, h * 0.08);
  canvas.drawRect(
    haze,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0x33FFFFFF), Colors.transparent],
      ).createShader(haze),
  );
  final shade = Rect.fromLTWH(0, hz, w, h * 0.05);
  canvas.drawRect(
    shade,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x22000000), Colors.transparent],
      ).createShader(shade),
  );
  for (final d in set.deco.where(_groundDecos.contains)) {
    _deco(canvas, size, d, set, ts);
  }
}

void paintSetFront(Canvas canvas, Size size, GhiSet set, double ts) {
  for (final d in set.deco.where(_frontDecos.contains)) {
    _deco(canvas, size, d, set, ts);
  }
}

void _deco(Canvas canvas, Size size, String name, GhiSet set, double ts) {
  final w = size.width, h = size.height, mm = size.shortestSide, hz = set.horizon * h;
  switch (name) {
    case 'sun':
      final c = Offset(w * 0.86, h * 0.17);
      _rotated(canvas, ts * 6, c, () {
        for (var i = 0; i < 10; i++) {
          final a = i * _tau / 10;
          final d = Offset(cos(a), sin(a));
          canvas.drawLine(c + d * (mm * 0.085), c + d * (mm * 0.12), _stroke(const Color(0xFFFFD54F), mm * 0.012));
        }
      });
      canvas.drawCircle(c, mm * 0.1, _fill(const Color(0x55FFF59D)));
      canvas.drawCircle(c, mm * 0.07, _fill(const Color(0xFFFFCA28)));
    case 'clouds' || 'clouds_grey' || 'clouds_low':
      final color = name == 'clouds_grey' ? const Color(0xFF90A4AE) : Colors.white;
      final n = name == 'clouds_grey' ? 5 : 3;
      for (var i = 0; i < n; i++) {
        final speed = name == 'clouds_low' ? 0.04 : 0.01;
        final x = (((i * 0.37 + ts * speed) % 1.2) - 0.1) * w;
        final y = name == 'clouds_low' ? h * (0.6 + i * 0.09) : h * (0.1 + (i % 3) * 0.07);
        _cloud(canvas, Offset(x, y), mm * (0.045 + (i % 2) * 0.02), color.withValues(alpha: 0.92));
      }
    case 'hills' || 'hills_dark' || 'hills_snow':
      final (a, b) = switch (name) {
        'hills_dark' => (const Color(0xFF1B5E20), const Color(0xFF2E7D32)),
        'hills_snow' => (const Color(0xFFE0E0E0), const Color(0xFFF5F5F5)),
        _ => (const Color(0xFF7CB342), const Color(0xFF9CCC65)),
      };
      canvas.drawOval(_r(-w * 0.2, hz - h * 0.12, w * 0.8, h * 0.3), _fill(a));
      canvas.drawOval(_r(w * 0.4, hz - h * 0.09, w * 0.9, h * 0.26), _fill(b));
    case 'stars':
      for (var i = 0; i < 40; i++) {
        final x = ((i * 0.618) % 1) * w;
        final y = ((i * 0.377 + 0.05) % 1) * hz * 0.85;
        final tw = 0.5 + 0.5 * sin(ts * 2 + i);
        canvas.drawCircle(
          Offset(x, y),
          mm * (0.003 + (i % 3) * 0.002),
          _fill(Colors.white.withValues(alpha: 0.3 + 0.7 * tw)),
        );
      }
    case 'moon':
      final c = Offset(w * 0.8, h * 0.2);
      canvas.drawCircle(c, mm * 0.12, _fill(const Color(0x33FFF59D)));
      canvas.drawCircle(c, mm * 0.075, _fill(const Color(0xFFFFF59D)));
      canvas.drawCircle(c + Offset(-mm * 0.02, mm * 0.01), mm * 0.015, _fill(const Color(0x22000000)));
      canvas.drawCircle(c + Offset(mm * 0.025, -mm * 0.02), mm * 0.01, _fill(const Color(0x22000000)));
    case 'window' || 'window_night':
      final l = w * 0.1, t = h * 0.16, sw = w * 0.2, sh = h * 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(l - 8, t - 8, sw + 16, sh + 16), const Radius.circular(10)),
        _fill(Colors.white),
      );
      final night = name == 'window_night';
      canvas.drawRect(_r(l, t, sw, sh), _fill(night ? const Color(0xFF1A237E) : const Color(0xFF81D4FA)));
      if (night) {
        canvas.drawCircle(Offset(l + sw * 0.7, t + sh * 0.3), sw * 0.12, _fill(const Color(0xFFFFF59D)));
        for (var i = 0; i < 6; i++) {
          canvas.drawCircle(Offset(l + sw * ((i * 0.37) % 1), t + sh * ((i * 0.53) % 1)), 2.5, _fill(Colors.white));
        }
      } else {
        _cloud(canvas, Offset(l + sw * 0.4, t + sh * 0.35), sw * 0.1, Colors.white);
      }
      canvas.drawLine(Offset(l + sw / 2, t), Offset(l + sw / 2, t + sh), _stroke(Colors.white, 8));
      canvas.drawLine(Offset(l, t + sh / 2), Offset(l + sw, t + sh / 2), _stroke(Colors.white, 8));
      canvas.drawRect(_r(l - w * 0.03, t - 12, w * 0.04, sh + 30), _fill(const Color(0xFFEF9A9A)));
      canvas.drawRect(_r(l + sw - w * 0.01, t - 12, w * 0.04, sh + 30), _fill(const Color(0xFFEF9A9A)));
    case 'frame':
      canvas.drawRect(_r(w * 0.62, h * 0.18, w * 0.16, h * 0.2), _fill(const Color(0xFF8D6E63)));
      canvas.drawRect(_r(w * 0.635, h * 0.2, w * 0.13, h * 0.16), _fill(const Color(0xFFB3E5FC)));
      _tri(
        canvas,
        Offset(w * 0.64, h * 0.36),
        Offset(w * 0.69, h * 0.25),
        Offset(w * 0.74, h * 0.36),
        const Color(0xFF66BB6A),
      );
      canvas.drawCircle(Offset(w * 0.735, h * 0.24), h * 0.02, _fill(const Color(0xFFFFCA28)));
    case 'board':
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.42, h * 0.13, w * 0.4, h * 0.3), const Radius.circular(12)),
        _fill(const Color(0xFF6D4C41)),
      );
      canvas.drawRect(_r(w * 0.435, h * 0.15, w * 0.37, h * 0.26), _fill(const Color(0xFF2E7D32)));
      const dots = [Color(0xFFFFEB3B), Color(0xFFFF8A80), Color(0xFF80D8FF)];
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(w * (0.5 + i * 0.12), h * 0.36), h * 0.025, _fill(dots[i]));
      }
    case 'garland':
      const colors = [Color(0xFFE53935), Color(0xFFFFB300), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA)];
      for (var i = 0; i < 14; i++) {
        final x = w * (i + 0.5) / 14;
        final y = h * 0.1 + sin(i / 13 * pi) * h * 0.06;
        _tri(
          canvas,
          Offset(x - w * 0.025, y),
          Offset(x + w * 0.025, y),
          Offset(x, y + h * 0.07),
          colors[i % colors.length],
        );
      }
    case 'balloons':
      const colors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFB300)];
      for (var i = 0; i < 3; i++) {
        final c = Offset(w * (0.05 + i * 0.05), h * (0.32 + (i % 2) * 0.06) + sin(ts * 1.5 + i) * h * 0.01);
        canvas.drawLine(c + Offset(0, h * 0.05), c + Offset(0, h * 0.2), _stroke(const Color(0xFF9E9E9E), 2));
        canvas.drawOval(_r(c.dx - w * 0.022, c.dy - h * 0.05, w * 0.044, h * 0.1), _fill(colors[i]));
      }
    case 'curtain':
      for (var side = 0; side < 2; side++) {
        final l = side == 0 ? 0.0 : w * 0.84;
        canvas.drawRect(_r(l, 0, w * 0.16, hz), _fill(const Color(0xFFB71C1C)));
        for (var k = 0; k < 4; k++) {
          canvas.drawRect(_r(l + w * (0.02 + k * 0.04), 0, w * 0.012, hz), _fill(const Color(0x33000000)));
        }
      }
      canvas.drawRect(_r(0, 0, w, h * 0.08), _fill(const Color(0xFF8E0000)));
    case 'spotlight':
      final a = 0.18 + 0.05 * sin(ts * 1.3);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.46, 0)
          ..lineTo(w * 0.52, 0)
          ..lineTo(w * 0.7, hz + h * 0.12)
          ..lineTo(w * 0.15, hz + h * 0.12)
          ..close(),
        _fill(const Color(0xFFFFF59D).withValues(alpha: a)),
      );
    case 'tiles':
      final step = h * 0.08;
      final p = _stroke(const Color(0x55FFFFFF), 2);
      for (var y = 0.0; y < hz; y += step) {
        canvas.drawLine(Offset(0, y), Offset(w, y), p);
      }
      for (var x = 0.0; x < w; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, hz), p);
      }
    case 'shelves':
      const goods = [
        Color(0xFFE57373),
        Color(0xFFFFD54F),
        Color(0xFF81C784),
        Color(0xFF64B5F6),
        Color(0xFFFFB74D),
        Color(0xFFBA68C8),
      ];
      for (var r = 0; r < 3; r++) {
        final y = h * (0.22 + r * 0.18);
        for (var k = 0; k < 8; k++) {
          final bh = h * (0.06 + (k * 7 + r * 3) % 4 * 0.012);
          canvas.drawRRect(
            RRect.fromRectAndRadius(_r(w * (0.47 + k * 0.065), y - bh, w * 0.05, bh), const Radius.circular(6)),
            _fill(goods[(k + r) % goods.length]),
          );
        }
        canvas.drawRect(_r(w * 0.45, y, w * 0.55, h * 0.02), _fill(const Color(0xFF8D6E63)));
      }
    case 'barn':
      final l = w * 0.7, top = hz - h * 0.28;
      canvas.drawRect(_r(l, top + h * 0.08, w * 0.22, h * 0.2), _fill(const Color(0xFFC62828)));
      _tri(
        canvas,
        Offset(l - w * 0.02, top + h * 0.08),
        Offset(l + w * 0.11, top - h * 0.02),
        Offset(l + w * 0.24, top + h * 0.08),
        const Color(0xFF8E0000),
      );
      final white = _stroke(Colors.white, 5);
      canvas.drawRect(_r(l + w * 0.08, hz - h * 0.12, w * 0.06, h * 0.12), white);
      canvas.drawLine(Offset(l + w * 0.08, hz - h * 0.12), Offset(l + w * 0.14, hz), white);
      canvas.drawLine(Offset(l + w * 0.14, hz - h * 0.12), Offset(l + w * 0.08, hz), white);
    case 'trees':
      for (var i = 0; i < 5; i++) {
        final x = w * (0.08 + i * 0.22);
        canvas.drawRect(_r(x - w * 0.008, hz - h * 0.1, w * 0.016, h * 0.1), _fill(const Color(0xFF6D4C41)));
        canvas.drawCircle(Offset(x, hz - h * 0.14), mm * 0.07, _fill(const Color(0xFF558B2F)));
        canvas.drawCircle(Offset(x + mm * 0.04, hz - h * 0.11), mm * 0.05, _fill(const Color(0xFF689F38)));
      }
    case 'sea':
      final top = hz - h * 0.14;
      canvas.drawRect(_r(0, top, w, hz - top), _fill(const Color(0xFF29B6F6)));
      for (var k = 0; k < 3; k++) {
        final y = top + (hz - top) * (0.25 + k * 0.25);
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x <= w; x += w / 40) {
          path.lineTo(x, y + sin(x / w * 12 + ts * 1.5 + k) * h * 0.006);
        }
        canvas.drawPath(path, _stroke(const Color(0x88FFFFFF), 3));
      }
    case 'flowers':
      const colors = [Color(0xFFFFEB3B), Color(0xFFF06292), Colors.white, Color(0xFFBA68C8)];
      for (var i = 0; i < 12; i++) {
        final x = ((i * 0.613 + 0.03) % 1) * w;
        final y = hz + ((i * 0.41) % 1) * (h - hz) * 0.8 + h * 0.02;
        for (var k = 0; k < 5; k++) {
          canvas.drawCircle(
            Offset(x + cos(k * _tau / 5) * mm * 0.01, y + sin(k * _tau / 5) * mm * 0.01),
            mm * 0.008,
            _fill(colors[i % 4]),
          );
        }
        canvas.drawCircle(Offset(x, y), mm * 0.006, _fill(const Color(0xFFFF9800)));
      }
    case 'lake':
      canvas.drawOval(_r(w * 0.5, hz + h * 0.04, w * 0.6, h * 0.27), _fill(const Color(0xFF4FC3F7)));
      canvas.drawOval(_r(w * 0.56, hz + h * 0.08, w * 0.46, h * 0.18), _fill(const Color(0xFF29B6F6)));
      for (var k = 0; k < 3; k++) {
        final r = (ts * 0.3 + k / 3) % 1;
        canvas.drawOval(
          _r(w * 0.75 - r * w * 0.06, hz + h * 0.16 - r * h * 0.02, r * w * 0.12, r * h * 0.04),
          _stroke(Colors.white.withValues(alpha: 0.5 * (1 - r)), 2),
        );
      }
    case 'reeds':
      for (var i = 0; i < 7; i++) {
        final x = w * (0.5 + i * 0.015);
        final sway = sin(ts * 1.2 + i) * w * 0.004;
        canvas.drawLine(Offset(x, hz + h * 0.12), Offset(x + sway, hz - h * 0.02), _stroke(const Color(0xFF558B2F), 4));
        canvas.drawOval(_r(x + sway - 4, hz - h * 0.04, 8, h * 0.03), _fill(const Color(0xFF6D4C41)));
      }
    case 'stripes':
      for (var i = 0; i < 8; i += 2) {
        canvas.drawRect(_r(w * i / 8, hz, w / 8, h - hz), _fill(const Color(0x1AFFFFFF)));
      }
    case 'goal':
      final l = w * 0.78, t = hz - h * 0.12, gw = w * 0.17, gh = h * 0.22;
      final net = _stroke(const Color(0x88FFFFFF), 2);
      for (var k = 1; k < 6; k++) {
        canvas.drawLine(Offset(l + gw * k / 6, t), Offset(l + gw * k / 6, t + gh), net);
      }
      for (var k = 1; k < 5; k++) {
        canvas.drawLine(Offset(l, t + gh * k / 5), Offset(l + gw, t + gh * k / 5), net);
      }
      final post = _stroke(Colors.white, 8);
      canvas.drawLine(Offset(l, t + gh), Offset(l, t), post);
      canvas.drawLine(Offset(l, t), Offset(l + gw, t), post);
      canvas.drawLine(Offset(l + gw, t), Offset(l + gw, t + gh), post);
    case 'rug':
      canvas.drawOval(_r(w * 0.2, hz + h * 0.06, w * 0.6, h * 0.16), _fill(const Color(0xFFE57373)));
    case 'path':
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.45, hz)
          ..lineTo(w * 0.55, hz)
          ..lineTo(w * 0.75, h)
          ..lineTo(w * 0.25, h)
          ..close(),
        _fill(const Color(0xFFD7CCC8)),
      );
    case 'fence':
      canvas.drawRect(_r(0, hz - h * 0.05, w, h * 0.012), _fill(const Color(0xFFBCAAA4)));
      for (var x = 0.0; x < w; x += w * 0.04) {
        canvas.drawRect(_r(x, hz - h * 0.08, w * 0.012, h * 0.09), _fill(const Color(0xFFD7CCC8)));
      }
    case 'grass_edge':
      canvas.drawRect(_r(0, hz - h * 0.01, w, h * 0.025), _fill(const Color(0xFF7CB342)));
    case 'counter':
      canvas.drawRect(_r(w * 0.55, hz - h * 0.14, w * 0.45, h * 0.14), _fill(const Color(0xFF8D6E63)));
      canvas.drawRect(_r(w * 0.54, hz - h * 0.16, w * 0.46, h * 0.025), _fill(const Color(0xFFECEFF1)));
    case 'bed':
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.24, h * 0.55, w * 0.04, h * 0.31), const Radius.circular(8)),
        _fill(const Color(0xFF8D6E63)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.26, h * 0.7, w * 0.44, h * 0.06), const Radius.circular(12)),
        _fill(Colors.white),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.4, h * 0.71, w * 0.3, h * 0.12), const Radius.circular(16)),
        _fill(const Color(0xFF5C6BC0)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.26, h * 0.8, w * 0.44, h * 0.06), const Radius.circular(6)),
        _fill(const Color(0xFF6D4C41)),
      );
    case 'lamp':
      final c = Offset(w * 0.82, hz - h * 0.12);
      canvas.drawCircle(c, mm * 0.16, _fill(const Color(0x33FFE082)));
      canvas.drawRect(_r(w * 0.77, hz - h * 0.05, w * 0.1, h * 0.05), _fill(const Color(0xFF6D4C41)));
      canvas.drawLine(Offset(c.dx, hz - h * 0.05), c, _stroke(const Color(0xFF6D4C41), 5));
      _tri(
        canvas,
        Offset(c.dx - mm * 0.05, c.dy + mm * 0.02),
        Offset(c.dx + mm * 0.05, c.dy + mm * 0.02),
        Offset(c.dx, c.dy - mm * 0.05),
        const Color(0xFFFFE082),
      );
    case 'sink':
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.68, h * 0.15, w * 0.18, h * 0.25), const Radius.circular(14)),
        _fill(const Color(0xFFB0BEC5)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.69, h * 0.165, w * 0.16, h * 0.22), const Radius.circular(12)),
        _fill(const Color(0xFFE1F5FE)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.66, hz - h * 0.2, w * 0.22, h * 0.08), const Radius.circular(20)),
        _fill(Colors.white),
      );
      canvas.drawRect(_r(w * 0.755, hz - h * 0.12, w * 0.03, h * 0.12), _fill(const Color(0xFFECEFF1)));
    case 'rails':
      final y1 = hz + h * 0.05, y2 = hz + h * 0.1;
      for (var x = 0.0; x < w; x += w * 0.04) {
        canvas.drawRect(_r(x, y1 - h * 0.005, w * 0.015, y2 - y1 + h * 0.01), _fill(const Color(0xFF8D6E63)));
      }
      final rail = Paint()
        ..color = const Color(0xFF607D8B)
        ..strokeWidth = h * 0.008;
      canvas.drawLine(Offset(0, y1), Offset(w, y1), rail);
      canvas.drawLine(Offset(0, y2), Offset(w, y2), rail);
    case 'desk':
      // Masa de lucru cu monitorul și tastatura.
      canvas.drawRect(_r(w * 0.68, hz - h * 0.02, w * 0.28, h * 0.025), _fill(const Color(0xFF8D6E63)));
      canvas.drawRect(_r(w * 0.7, hz, w * 0.02, h * 0.14), _fill(const Color(0xFF6D4C41)));
      canvas.drawRect(_r(w * 0.92, hz, w * 0.02, h * 0.14), _fill(const Color(0xFF6D4C41)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.72, hz - h * 0.2, w * 0.18, h * 0.15), const Radius.circular(8)),
        _fill(const Color(0xFF263238)),
      );
      final screen = _r(w * 0.73, hz - h * 0.19, w * 0.16, h * 0.13);
      canvas.drawRect(
        screen,
        Paint()..shader = const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF7E57C2)]).createShader(screen),
      );
      canvas.drawRect(_r(w * 0.8, hz - h * 0.05, w * 0.02, h * 0.03), _fill(const Color(0xFF455A64)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(w * 0.73, hz - h * 0.03, w * 0.12, h * 0.012), const Radius.circular(3)),
        _fill(const Color(0xFFCFD8DC)),
      );
    case 'tub_front':
      final l = w * 0.32, t = h * 0.74;
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(l, t, w * 0.36, h * 0.17), const Radius.circular(40)),
        _fill(Colors.white),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r(l, t + h * 0.12, w * 0.36, h * 0.05), const Radius.circular(30)),
        _fill(const Color(0xFFCFD8DC)),
      );
      for (var k = 0; k < 9; k++) {
        canvas.drawCircle(
          Offset(l + w * 0.36 * (k + 0.5) / 9, t + sin(ts * 2 + k) * 3),
          mm * (0.025 + (k % 3) * 0.008),
          _fill(Colors.white),
        );
      }
      canvas.drawCircle(Offset(l + w * 0.05, t + h * 0.19), mm * 0.015, _fill(const Color(0xFF90A4AE)));
      canvas.drawCircle(Offset(l + w * 0.31, t + h * 0.19), mm * 0.015, _fill(const Color(0xFF90A4AE)));
    case 'snowfall':
      for (var i = 0; i < 50; i++) {
        final x = ((i * 0.618) % 1) * w + sin(ts + i) * w * 0.01;
        final y = (((i * 0.29) + ts * 0.05 * (1 + i % 3)) % 1) * h;
        canvas.drawCircle(Offset(x, y), mm * (0.004 + (i % 3) * 0.003), _fill(Colors.white.withValues(alpha: 0.9)));
      }
    case 'rain':
      for (var i = 0; i < 60; i++) {
        final x = ((i * 0.618) % 1) * w;
        final y = (((i * 0.31) + ts * 0.6) % 1) * h;
        canvas.drawLine(Offset(x, y), Offset(x - w * 0.004, y + h * 0.03), _stroke(const Color(0xAA81D4FA), 3));
      }
  }
}

// ---------------- Obiecte și numărătoare ----------------

void _prop(Canvas canvas, Size size, GhiProp p, double local, double ts) {
  if (local < p.appear || local > p.vanish) return;
  final a =
      ((local - p.appear) / 0.05).clamp(0.0, 1.0) * (p.vanish < 1 ? ((p.vanish - local) / 0.05).clamp(0.0, 1.0) : 1.0);
  final w = size.width, h = size.height;
  var x = p.x.at(local) * w;
  var y = p.y.at(local) * h;
  var px = p.size * size.shortestSide;
  var rot = 0.0;
  switch (p.motion) {
    case 'bob':
      y += sin(ts * _tau * 0.6) * h * 0.01;
    case 'swim':
      y += sin(ts * _tau) * h * 0.008;
    case 'hop':
      y -= sin(ts * pi * 1.5).abs() * h * 0.03;
    case 'float':
      x += sin(ts * 1.5) * w * 0.01;
      y += sin(ts * 1.1) * h * 0.01;
    case 'pulse':
      px *= 1 + 0.08 * sin(ts * _tau);
    case 'beat':
      px *= 1 + 0.2 * sin(ts * pi * 2.2).abs();
    case 'grow':
      px *= GhiTimeline.ease(local / 0.5);
    case 'spin':
      rot = ts * 180;
    case 'wiggle':
      rot = sin(ts * _tau * 1.5) * 10;
  }
  _rotated(canvas, rot, Offset(x, y), () => ghiEmoji(canvas, p.emoji, Offset(x, y), px, a));
}

void _count(Canvas canvas, Size size, GhiCount c, double local) {
  final n = c.items.length;
  final shown = GhiTimeline.counted(n, local);
  final px = c.size * size.shortestSide;
  const letterColors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFFB300)];
  for (var i = 0; i < shown; i++) {
    final start = 0.1 + i * 0.75 / n;
    final pop = GhiTimeline.ease((local - start) / 0.04);
    final fx = n == 1 ? (c.x.from + c.x.to) / 2 : c.x.from + (c.x.to - c.x.from) * i / (n - 1);
    final center = Offset(fx * size.width, c.y * size.height);
    final item = c.items[i];
    if (item.length == 1 && RegExp(r'[A-Za-z]').hasMatch(item)) {
      ghiText(canvas, item, center, px * 1.2 * pop, letterColors[i % 4]);
    } else {
      ghiEmoji(canvas, item, center, px * pop);
    }
    ghiText(canvas, '${i + 1}', center - Offset(0, px * 0.95), px * 0.45, const Color(0xFFFFF59D), alpha: pop);
    if (i < c.labels.length) {
      ghiText(canvas, c.labels[i], center + Offset(0, px * 0.95), px * 0.32, Colors.white, alpha: pop);
    }
  }
}

// ---------------- GHI ----------------

/// Culorile costumașului: blana (sau solzii), burtica, țepii sau coama.
class _Fur {
  const _Fur(this.main, this.dark, this.light, this.belly, this.spike, this.horn, this.feet);
  final Color main, dark, light, belly, spike, horn, feet;
}

const _furs = {
  'dragon': _Fur(
    Color(0xFF7CB342),
    Color(0xFF558B2F),
    Color(0xFFA5D66B),
    Color(0xFFDCEDC8),
    Color(0xFFFFB74D),
    Color(0xFFFFF3E0),
    Color(0xFF33691E),
  ),
  'balaur': _Fur(
    Color(0xFFE0553A),
    Color(0xFFB23A22),
    Color(0xFFFF8A65),
    Color(0xFFFFE0B2),
    Color(0xFFFFD54F),
    Color(0xFFFFF3E0),
    Color(0xFF7F2412),
  ),
  'leu': _Fur(
    Color(0xFFF2B33D),
    Color(0xFFC98A1E),
    Color(0xFFFFD27A),
    Color(0xFFFFF1D0),
    Color(0xFFB5651D),
    Color(0xFFFFF3E0),
    Color(0xFF8D5A14),
  ),
  'urs': _Fur(
    Color(0xFF8D6E63),
    Color(0xFF6D4C41),
    Color(0xFFAC8F84),
    Color(0xFFE6D5CB),
    Color(0xFF5D4037),
    Color(0xFFFFF3E0),
    Color(0xFF4E342E),
  ),
};

/// Cum e GHI acum: costumașul și dacă e fată (are fundiță).
String _avatar = 'dragon';
bool _girl = false;
_Fur get _f => _furs[_avatar] ?? _furs['dragon']!;
Color get _green => _f.main;
Color get _greenDark => _f.dark;
Color get _greenLight => _f.light;
Color get _belly => _f.belly;
Color get _spike => _f.spike;
Color get _horn => _f.horn;
const _skin = Color(0xFFFFDDBF);

/// Se cheamă când părintele schimbă personajul (și la pornire).
void setGhiCharacter(GhiCharacter c) {
  _avatar = c.avatar;
  _girl = c.girl;
}

void paintGhi(
  Canvas canvas,
  GhiPose g,
  double local,
  double ts,
  double gx,
  double gy,
  double height, {
  double look = 0,
}) {
  final u = height / 100;
  final sitting = g.pose == 'sit' || g.pose == 'sleep';
  var lift = switch (g.pose) {
    'jump' => sin(ts * pi * 1.2).abs() * 22,
    'happy' => sin(ts * pi * 2).abs() * 7,
    'walk' => sin(ts * pi * 3).abs() * 3,
    _ => 0.0,
  };
  if (sitting) lift = -10;
  final breathe = sin(ts * pi) * 0.8;
  final swingX = g.motion == 'swing' ? sin(ts * 1.6) * 14 : 0.0;
  // Dansul, sau o mică legănare când stă, ca să nu pară încremenit.
  final sway = g.pose == 'dance' ? sin(ts * pi * 2) * 10 : (g.pose == 'stand' ? sin(ts * 0.9) * 1.6 : 0.0);

  if (g.motion == 'swing') {
    final rope = _stroke(const Color(0xFF6D4C41), 3 * u);
    canvas.drawLine(
      Offset(gx + swingX * u * 0.3 - 22 * u, gy - height * 1.4),
      Offset(gx + swingX * u - 22 * u, gy - 2 * u),
      rope,
    );
    canvas.drawLine(
      Offset(gx + swingX * u * 0.3 + 22 * u, gy - height * 1.4),
      Offset(gx + swingX * u + 22 * u, gy - 2 * u),
      rope,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(gx + swingX * u - 26 * u, gy - 3 * u, 52 * u, 6 * u), Radius.circular(2 * u)),
      _fill(const Color(0xFF8D6E63)),
    );
  }

  // Umbra pe pământ.
  canvas.drawOval(_r(gx - 26 * u, gy - 3 * u, 52 * u, 7 * u), _fill(const Color(0x33000000)));

  canvas.save();
  canvas.translate(gx + swingX * u, gy - lift * u);
  if (g.flip) canvas.scale(-1, 1);
  canvas.rotate(sway * pi / 180);

  Offset p(double x, double y) => Offset(x * u, y * u);

  // Coada cu țepi, dă din ea.
  final wag = sin(ts * _tau * 0.8) * 6;
  final tail = Path()
    ..moveTo(-14 * u, -22 * u)
    ..quadraticBezierTo(-40 * u, -14 * u + wag * u * 0.5, -50 * u, -30 * u + wag * u);
  switch (_avatar) {
    case 'urs':
      // Ursulețul: o codiță mică și rotundă.
      canvas.drawCircle(p(-27, -20 + wag * 0.2), 7 * u, _fill(_greenDark));
      canvas.drawCircle(p(-27, -20 + wag * 0.2), 5.5 * u, _fill(_green));
    case 'leu':
      // Leul: coadă subțire cu un smoc la capăt.
      canvas.drawPath(tail, _stroke(_greenDark, 6 * u));
      canvas.drawPath(tail, _stroke(_green, 4 * u));
      canvas.drawCircle(p(-50, -31 + wag), 6 * u, _fill(_spike));
      canvas.drawCircle(p(-52, -33 + wag), 3 * u, _fill(_darker(_spike)));
    default:
      canvas.drawPath(tail, _stroke(_greenDark, 12 * u));
      canvas.drawPath(tail, _stroke(_green, 8 * u));
      _tri(canvas, p(-54, -30 + wag), p(-46, -34 + wag), p(-52, -42 + wag), _spike);
  }

  // Aripioarele.
  final flap = g.pose == 'fly' ? sin(ts * _tau * 2) * 25 : sin(ts * _tau * 0.5) * 6;
  // Leul și ursulețul au aripioare doar când zboară (ca în povești).
  final wings = _avatar == 'dragon' || _avatar == 'balaur' || g.pose == 'fly';
  if (wings) {
    _rotated(canvas, -20 - flap, p(-12, -46), () {
      canvas.drawPath(
        Path()
          ..moveTo(-12 * u, -46 * u)
          ..quadraticBezierTo(-36 * u, -66 * u, -40 * u, -48 * u)
          ..quadraticBezierTo(-30 * u, -50 * u, -26 * u, -40 * u)
          ..close(),
        _fill(_greenLight),
      );
    });
  }

  // Brațul din spate.
  final backArm = switch (g.pose) {
    'happy' || 'fly' => -2.6,
    'dance' => -2.2 + sin(ts * 6) * 0.3,
    _ => -0.35,
  };
  _arm(canvas, Offset(-15 * u, (-44 + breathe) * u), backArm, u);

  // Picioarele.
  if (sitting) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(-4 * u, -14 * u, 26 * u, 12 * u), Radius.circular(6 * u)),
      _fill(_greenDark),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(_r(0, -12 * u, 24 * u, 12 * u), Radius.circular(6 * u)), _fill(_green));
  } else {
    final step = g.pose == 'walk' ? sin(ts * _tau * 1.5) * 6 : 0.0;
    final kick = g.pose == 'kick' && local >= 0.25 && local <= 0.5 ? 35.0 : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r((-16 - step) * u, -18 * u, 13 * u, 18 * u), Radius.circular(6 * u)),
      _fill(_greenDark),
    );
    _rotated(canvas, -kick, p(8, -18), () {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_r((2 + step) * u, -18 * u, 13 * u, 18 * u), Radius.circular(6 * u)),
        _fill(_green),
      );
    });
    canvas.drawOval(_r((-18 - step) * u, -4 * u, 16 * u, 6 * u), _fill(_f.feet));
    canvas.drawOval(_r((1 + step) * u, -4 * u, 16 * u, 6 * u), _fill(_f.feet));
  }

  // Corpul și burtica.
  canvas.drawOval(_r(-23 * u, (-58 + breathe) * u, 46 * u, 46 * u), _fill(_greenDark));
  final bodyRect = _r(-21 * u, (-56 + breathe) * u, 42 * u, 42 * u);
  canvas.drawOval(
    bodyRect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.3),
        radius: 0.9,
        colors: [_greenLight, _green, _greenDark],
      ).createShader(bodyRect),
  );
  canvas.drawOval(_r(-11 * u, (-50 + breathe) * u, 26 * u, 32 * u), _fill(_belly));
  for (var k = 0; k < 3; k++) {
    canvas.drawLine(
      p(-8, -42 + k * 8 + breathe),
      p(12, -42 + k * 8 + breathe),
      _stroke(const Color(0x33558B2F), 1.5 * u),
    );
  }

  // Capul: glugă de dragon cu coarne și țepi, fața de bebeluș.
  final hc = p(0, -76 + breathe);
  final tilt = g.pose == 'sleep' ? 14.0 : 0.0;
  _rotated(canvas, tilt, hc, () {
    _hood(canvas, hc, ts, u, p);
    canvas.drawCircle(hc, 29 * u, _fill(_greenDark));
    final hoodRect = Rect.fromCircle(center: hc, radius: 27 * u);
    canvas.drawCircle(
      hc,
      27 * u,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [_greenLight, _green, _greenDark],
        ).createShader(hoodRect),
    );
    final fc = p(4, -72 + breathe);
    final faceRect = Rect.fromCircle(center: fc, radius: 19 * u);
    canvas.drawCircle(
      fc,
      19 * u,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          radius: 0.95,
          colors: [Color(0xFFFFE8D6), _skin, Color(0xFFF2C29E)],
        ).createShader(faceRect),
    );
    // Umbra glugii pe frunte.
    _arc(
      canvas,
      const Color(0x22000000),
      200,
      140,
      false,
      Rect.fromLTWH(fc.dx - 17 * u, fc.dy - 19 * u, 34 * u, 20 * u),
      3 * u,
    );
    // Bucla de păr.
    _arc(
      canvas,
      const Color(0xFF6D4C41),
      200,
      200,
      false,
      Rect.fromLTWH(fc.dx - 6 * u, fc.dy - 24 * u, 12 * u, 10 * u),
      3 * u,
    );
    _face(canvas, g.face, fc, ts, u, g.flip ? -look : look);
    if (_avatar == 'leu' || _avatar == 'urs') _ears(canvas, hc, u);
    if (_girl && g.hat == null) _bow(canvas, p(17, -99 + breathe), u);
    _hat(canvas, g.hat, hc, u);
  });

  // Brațul din față, cu ce ține GHI în mână.
  final frontArm = switch (g.pose) {
    'happy' || 'fly' => 2.6,
    'wave' => 2.4 + sin(ts * _tau * 1.5) * 0.4,
    'reach' => 1.6,
    'dance' => 2.2 + sin(ts * 6 + 1) * 0.3,
    _ => g.hold != null ? 0.9 : 0.35,
  };
  final hand = _arm(canvas, Offset(15 * u, (-44 + breathe) * u), frontArm, u);
  if (g.hold != null) ghiEmoji(canvas, g.hold!, hand + Offset(4 * u, -6 * u), 18 * u);

  // Bulă de gând.
  if (g.think != null) {
    canvas.drawCircle(p(24, -100), 4 * u, _fill(Colors.white));
    canvas.drawCircle(p(32, -110), 6 * u, _fill(Colors.white));
    canvas.drawCircle(p(46, -128), 16 * u, _fill(Colors.white));
    ghiEmoji(canvas, g.think!, p(46, -128), 18 * u);
  }

  if (g.puff != null) _puff(canvas, g.puff!, p(14, -64 + breathe), ts, u);
  canvas.restore();
}

/// Ce e în spatele glugii: țepi și coarne (dragon), încă 6 căpșoare (balaur) sau coama (leu).
void _hood(Canvas canvas, Offset hc, double ts, double u, Offset Function(double, double) p) {
  switch (_avatar) {
    case 'balaur':
      // Balaurul cu 7 capete: glugă cu coarne și încă 6 căpșoare pe gâturi, fiecare cu ochii lui.
      const angles = [-168.0, -140.0, -112.0, -68.0, -40.0, -12.0];
      for (var k = 0; k < angles.length; k++) {
        final a = angles[k] * pi / 180;
        final bob = sin(ts * 2.2 + k * 1.3) * 2.2;
        final head = hc + Offset(cos(a), sin(a)) * (44 * u) + Offset(0, bob * u);
        final neck = hc + Offset(cos(a), sin(a)) * (12 * u);
        canvas.drawLine(neck, head, _stroke(_greenDark, 8 * u));
        canvas.drawLine(neck, head, _stroke(_green, 5.5 * u));
        _tri(
          canvas,
          head + Offset(-6 * u, -6 * u),
          head + Offset(-8 * u, -15 * u),
          head + Offset(-1 * u, -8 * u),
          _horn,
        );
        _tri(canvas, head + Offset(1 * u, -8 * u), head + Offset(8 * u, -15 * u), head + Offset(6 * u, -6 * u), _horn);
        canvas.drawCircle(head, 9.5 * u, _fill(_greenDark));
        final r = Rect.fromCircle(center: head, radius: 8.5 * u);
        canvas.drawCircle(
          head,
          8.5 * u,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.4, -0.4),
              colors: [_greenLight, _green, _greenDark],
            ).createShader(r),
        );
        canvas.drawOval(Rect.fromCenter(center: head + Offset(0, 3.5 * u), width: 9 * u, height: 5 * u), _fill(_belly));
        // Clipesc pe rând, nu toate odată.
        final blink = ((ts * 0.7 + k * 0.37) % 4.0) < 0.12;
        for (final ex in [-3.2, 3.2]) {
          final e = head + Offset(ex * u, -1.5 * u);
          if (blink) {
            canvas.drawLine(e - Offset(1.8 * u, 0), e + Offset(1.8 * u, 0), _stroke(const Color(0xFF3E2723), 1 * u));
          } else {
            canvas.drawCircle(e, 2.2 * u, _fill(Colors.white));
            canvas.drawCircle(e + Offset(0.3 * u, 0.3 * u), 1.3 * u, _fill(const Color(0xFF3E2723)));
            canvas.drawCircle(e + Offset(-0.4 * u, -0.5 * u), 0.5 * u, _fill(Colors.white));
          }
        }
        canvas.drawArc(
          Rect.fromCenter(center: head + Offset(0, 3 * u), width: 5 * u, height: 3.4 * u),
          0.2,
          pi - 0.4,
          false,
          _stroke(const Color(0xFF6D2B1A), 0.9 * u),
        );
      }
      _tri(canvas, p(-10, -98), p(-14, -114), p(-2, -100), _horn);
      _tri(canvas, p(8, -100), p(16, -114), p(18, -96), _horn);
    case 'leu':
      // Coama: un cerc de smocuri, mai închise spre margine.
      for (var k = 0; k < 14; k++) {
        final a = k / 14 * _tau + sin(ts * 0.8) * 0.03;
        canvas.drawCircle(hc + Offset(cos(a), sin(a)) * (30 * u), 10 * u, _fill(_darker(_spike, 0.85)));
      }
      for (var k = 0; k < 14; k++) {
        final a = (k + 0.5) / 14 * _tau;
        canvas.drawCircle(hc + Offset(cos(a), sin(a)) * (27 * u), 8 * u, _fill(_spike));
      }
    case 'urs':
      break;
    default:
      _tri(canvas, p(-22, -92), p(-14, -102), p(-8, -96), _spike);
      _tri(canvas, p(-27, -80), p(-36, -84), p(-26, -70), _spike);
      _tri(canvas, p(-10, -98), p(-14, -114), p(-2, -100), _horn);
      _tri(canvas, p(8, -100), p(16, -114), p(18, -96), _horn);
  }
}

/// Urechiușe rotunde pe glugă (leu și ursuleț).
void _ears(Canvas canvas, Offset hc, double u) {
  final big = _avatar == 'urs' ? 9.0 : 7.0;
  for (final x in [-19.0, 19.0]) {
    final c = hc + Offset(x * u, -21 * u);
    canvas.drawCircle(c, (big + 1.5) * u, _fill(_greenDark));
    canvas.drawCircle(c, big * u, _fill(_green));
    canvas.drawCircle(c + Offset(0, 1 * u), big * 0.55 * u, _fill(_belly));
  }
}

/// Fundița fetiței, prinsă pe glugă.
void _bow(Canvas canvas, Offset c, double u) {
  const pink = Color(0xFFEC407A);
  const pinkDark = Color(0xFFC2185B);
  for (final s in [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(c.dx + s * 6 * u, c.dy - 9 * u, c.dx + s * 11 * u, c.dy - 4 * u)
      ..quadraticBezierTo(c.dx + s * 12 * u, c.dy + 3 * u, c.dx + s * 10 * u, c.dy + 7 * u)
      ..quadraticBezierTo(c.dx + s * 5 * u, c.dy + 6 * u, c.dx, c.dy)
      ..close();
    canvas.drawPath(path, _fill(pink));
    canvas.drawPath(path, _stroke(pinkDark, 0.8 * u));
  }
  canvas.drawCircle(c, 3 * u, _fill(pinkDark));
  canvas.drawCircle(c + Offset(-0.8 * u, -0.8 * u), 1 * u, _fill(const Color(0x88FFFFFF)));
}

/// Un braț: umărul, unghiul (0 = în jos, pozitiv = în față). Întoarce poziția mâinii.
Offset _arm(Canvas canvas, Offset shoulder, double angle, double u) {
  final hand = shoulder + Offset(sin(angle), cos(angle)) * (18 * u);
  canvas.drawLine(shoulder, hand, _stroke(_greenDark, 11 * u));
  canvas.drawLine(shoulder, hand, _stroke(_green, 8 * u));
  canvas.drawCircle(hand, 4.5 * u, _fill(_skin));
  return hand;
}

/// [look] -1..1: încotro se uită ochii (stânga / dreapta).
void _face(Canvas canvas, String face, Offset c, double ts, double u, [double look = 0]) {
  const dark = Color(0xFF3E2723);
  const mouth = Color(0xFF8D3B3B);
  final eyeL = c + Offset(-6 * u, -2 * u);
  final eyeR = c + Offset(8 * u, -2 * u);
  // Clipește la intervale puțin diferite, ca un copil adevărat.
  final blink = ((ts + sin(ts * 0.37) * 1.3) % 3.7) < 0.14;
  if (face == 'sleepy' || blink) {
    for (final e in [eyeL, eyeR]) {
      _arc(canvas, dark, 0, 180, false, Rect.fromLTWH(e.dx - 3.5 * u, e.dy - 2 * u, 7 * u, 4 * u), 1.6 * u);
    }
  } else {
    final r = face == 'wow' ? 3.8 * u : 3.2 * u;
    for (final e in [eyeL, eyeR]) {
      // Ochi cu alb, iris căprui, pupilă și două luciri.
      canvas.drawCircle(e, r * 1.15, _fill(Colors.white));
      final iris = e + Offset(r * (0.1 + 0.3 * look), 0);
      canvas.drawCircle(iris, r * 0.85, _fill(const Color(0xFF6D4C41)));
      canvas.drawCircle(iris, r * 0.5, _fill(dark));
      canvas.drawCircle(iris + Offset(r * 0.3, -r * 0.35), r * 0.3, _fill(Colors.white));
      canvas.drawCircle(iris + Offset(-r * 0.35, r * 0.35), r * 0.14, _fill(Colors.white.withValues(alpha: 0.7)));
      _arc(canvas, dark, 200, 140, false, Rect.fromCircle(center: e, radius: r * 1.15), 0.9 * u);
    }
  }
  canvas.drawCircle(c + Offset(-11 * u, 5 * u), 3.5 * u, _fill(const Color(0x66FF8A80)));
  canvas.drawCircle(c + Offset(13 * u, 5 * u), 3.5 * u, _fill(const Color(0x66FF8A80)));
  final mc = c + Offset(1 * u, 8 * u);
  switch (face) {
    case 'wow':
      canvas.drawOval(Rect.fromLTWH(mc.dx - 3 * u, mc.dy - 3.5 * u, 6 * u, 7 * u), _fill(mouth));
    case 'sleepy':
      canvas.drawOval(Rect.fromLTWH(mc.dx - 2 * u, mc.dy - 2 * u, 4 * u, 4 * u), _fill(mouth));
    case 'sad':
      _arc(canvas, dark, 200, 140, false, Rect.fromLTWH(mc.dx - 5 * u, mc.dy, 10 * u, 7 * u), 1.6 * u);
      canvas.drawOval(Rect.fromLTWH(eyeR.dx - 1.5 * u, eyeR.dy + 4 * u, 3 * u, 5 * u), _fill(const Color(0xFF4FC3F7)));
    case 'calm':
      _arc(canvas, dark, 20, 140, false, Rect.fromLTWH(mc.dx - 4 * u, mc.dy - 3 * u, 8 * u, 5 * u), 1.6 * u);
    default:
      _arc(canvas, mouth, 0, 180, true, Rect.fromLTWH(mc.dx - 5.5 * u, mc.dy - 4 * u, 11 * u, 8 * u));
      _arc(canvas, const Color(0xFFFF8A80), 30, 120, true, Rect.fromLTWH(mc.dx - 3.5 * u, mc.dy - 1 * u, 7 * u, 5 * u));
  }
}

void _hat(Canvas canvas, String? hat, Offset hc, double u) {
  switch (hat) {
    case 'party':
      final base = hc + Offset(4 * u, -24 * u);
      _tri(
        canvas,
        base + Offset(-12 * u, 0),
        base + Offset(12 * u, 0),
        base + Offset(2 * u, -30 * u),
        const Color(0xFFE91E63),
      );
      canvas.drawLine(
        base + Offset(-7 * u, -8 * u),
        base + Offset(8 * u, -10 * u),
        _stroke(const Color(0xFFFFEB3B), 2.5 * u),
      );
      canvas.drawLine(
        base + Offset(-3 * u, -18 * u),
        base + Offset(5 * u, -19 * u),
        _stroke(const Color(0xFFFFEB3B), 2.5 * u),
      );
      canvas.drawCircle(base + Offset(2 * u, -31 * u), 4 * u, _fill(const Color(0xFFFFEB3B)));
    case 'helmet':
      _arc(
        canvas,
        const Color(0xFF1E88E5),
        180,
        180,
        true,
        Rect.fromLTWH(hc.dx - 30 * u, hc.dy - 32 * u, 60 * u, 44 * u),
      );
      canvas.drawLine(hc + Offset(-2 * u, -30 * u), hc + Offset(-2 * u, -12 * u), _stroke(Colors.white, 3 * u));
    case 'beanie':
      _arc(
        canvas,
        const Color(0xFFE53935),
        180,
        180,
        true,
        Rect.fromLTWH(hc.dx - 29 * u, hc.dy - 30 * u, 58 * u, 40 * u),
      );
      canvas.drawRect(Rect.fromLTWH(hc.dx - 29 * u, hc.dy - 12 * u, 58 * u, 6 * u), _fill(Colors.white));
      canvas.drawCircle(hc + Offset(0, -32 * u), 6 * u, _fill(Colors.white));
  }
}

void _puff(Canvas canvas, String kind, Offset origin, double ts, double u) {
  for (var i = 0; i < 6; i++) {
    final q = (ts * 0.45 + i / 6) % 1;
    final pos = origin + Offset((q * 26 + sin(q * 6 + i) * 4) * u, -q * 46 * u);
    final a = 1 - q;
    switch (kind) {
      case 'steam':
        canvas.drawCircle(pos, (3 + q * 6) * u, _fill(Colors.white.withValues(alpha: 0.7 * a)));
      case 'bubbles':
        canvas.drawCircle(pos, (2.5 + q * 4) * u, _stroke(const Color(0xFFB3E5FC).withValues(alpha: a), 1.2 * u));
        canvas.drawCircle(pos + Offset(-1.2 * u, -1.2 * u), 0.8 * u, _fill(Colors.white.withValues(alpha: a)));
      case 'stars':
        final r = (3 + q * 3) * u;
        final path = Path();
        for (var k = 0; k < 8; k++) {
          final ang = k * pi / 4 - pi / 2;
          final rr = k.isEven ? r : r * 0.4;
          final pt = pos + Offset(cos(ang) * rr, sin(ang) * rr);
          if (k == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, _fill(const Color(0xFFFFD54F).withValues(alpha: a)));
      case 'hearts':
        ghiEmoji(canvas, '💗', pos, (6 + q * 4) * u, a);
      case 'notes':
        ghiEmoji(canvas, i.isEven ? '🎵' : '🎶', pos, (7 + q * 3) * u, a);
      case 'zzz':
        ghiText(canvas, 'z', pos, (6 + q * 8) * u, Colors.white, alpha: a);
    }
  }
}

// ---------------- Oamenii: mami, tati, bunica și meseriile ----------------

/// Cum arată un om: piele, păr, haine, ce poartă pe cap și ce mai are pe el.
class _Look {
  const _Look({
    required this.skin,
    required this.hair,
    required this.top,
    required this.bottom,
    required this.shoes,
    this.style = 'short',
    this.dress = false,
    this.hat,
    this.extras = const {},
    this.beard = false,
    this.lashes = false,
    this.glasses = false,
    this.longSleeves = false,
    this.eyes = const Color(0xFF5D4037),
  });
  final Color skin, hair, top, bottom, shoes, eyes;
  final String style;
  final bool dress, beard, lashes, glasses, longSleeves;
  final String? hat;
  final Set<String> extras;
}

const _looks = <String, _Look>{
  'mami': _Look(
    skin: Color(0xFFF2C6A0),
    hair: Color(0xFF5D4037),
    top: Color(0xFFE57399),
    bottom: Color(0xFF3F51B5),
    shoes: Color(0xFF6D4C41),
    style: 'long',
    dress: true,
    lashes: true,
  ),
  'tati': _Look(
    skin: Color(0xFFE8B98F),
    hair: Color(0xFF3E2723),
    top: Color(0xFF42A5F5),
    bottom: Color(0xFF455A64),
    shoes: Color(0xFF263238),
    beard: true,
    extras: {'buttons'},
  ),
  'bunica': _Look(
    skin: Color(0xFFF0C8A8),
    hair: Color(0xFFCFD8DC),
    top: Color(0xFF9575CD),
    bottom: Color(0xFF5E35B1),
    shoes: Color(0xFF4E342E),
    style: 'bun',
    dress: true,
    glasses: true,
    lashes: true,
    longSleeves: true,
  ),
  'educatoare': _Look(
    skin: Color(0xFFF5CBA7),
    hair: Color(0xFF8D6E63),
    top: Color(0xFF26A69A),
    bottom: Color(0xFF37474F),
    shoes: Color(0xFF5D4037),
    style: 'bun',
    lashes: true,
    longSleeves: true,
  ),
  'pompier': _Look(
    skin: Color(0xFFE0AC85),
    hair: Color(0xFF3E2723),
    top: Color(0xFF3E2723),
    bottom: Color(0xFF3E2723),
    shoes: Color(0xFF212121),
    hat: 'fire',
    extras: {'reflect'},
    longSleeves: true,
    beard: true,
  ),
  'doctor': _Look(
    skin: Color(0xFFF1C27D),
    hair: Color(0xFF212121),
    top: Color(0xFF81D4FA),
    bottom: Color(0xFF4FC3F7),
    shoes: Color(0xFFECEFF1),
    style: 'bun',
    extras: {'coat', 'stetho'},
    lashes: true,
    glasses: true,
  ),
  'politist': _Look(
    skin: Color(0xFFA1785C),
    hair: Color(0xFF212121),
    top: Color(0xFF90CAF9),
    bottom: Color(0xFF1A237E),
    shoes: Color(0xFF212121),
    hat: 'police',
    extras: {'badge', 'tie', 'belt'},
    eyes: Color(0xFF3E2723),
  ),
  'bucatar': _Look(
    skin: Color(0xFFE8B98F),
    hair: Color(0xFF4E342E),
    top: Color(0xFFFAFAFA),
    bottom: Color(0xFF616161),
    shoes: Color(0xFF212121),
    hat: 'chef',
    extras: {'apron', 'chefButtons'},
    beard: true,
  ),
  'constructor': _Look(
    skin: Color(0xFFD7A07A),
    hair: Color(0xFF3E2723),
    top: Color(0xFF1E88E5),
    bottom: Color(0xFF3949AB),
    shoes: Color(0xFF795548),
    hat: 'hard',
    extras: {'vest'},
    beard: true,
  ),
  'fermier': _Look(
    skin: Color(0xFFE6B48A),
    hair: Color(0xFF6D4C41),
    top: Color(0xFFD32F2F),
    bottom: Color(0xFF1565C0),
    shoes: Color(0xFF4E342E),
    hat: 'straw',
    extras: {'overall', 'plaid'},
    beard: true,
  ),
  'postas': _Look(
    skin: Color(0xFFF2C6A0),
    hair: Color(0xFFFFB74D),
    top: Color(0xFF1976D2),
    bottom: Color(0xFF0D47A1),
    shoes: Color(0xFF212121),
    style: 'long',
    hat: 'post',
    extras: {'bag'},
    lashes: true,
    eyes: Color(0xFF1E88E5),
  ),
  'pilot': _Look(
    skin: Color(0xFF8D5524),
    hair: Color(0xFF1B1B1B),
    top: Color(0xFFFAFAFA),
    bottom: Color(0xFF1A237E),
    shoes: Color(0xFF111111),
    style: 'bun',
    hat: 'pilot',
    extras: {'tie', 'wings'},
    lashes: true,
    eyes: Color(0xFF3E2723),
  ),
  'veterinar': _Look(
    skin: Color(0xFFF5D0B5),
    hair: Color(0xFFBF360C),
    top: Color(0xFF66BB6A),
    bottom: Color(0xFF388E3C),
    shoes: Color(0xFFECEFF1),
    style: 'long',
    extras: {'stetho'},
    lashes: true,
    eyes: Color(0xFF43A047),
  ),
  'brutar': _Look(
    skin: Color(0xFFEDC09A),
    hair: Color(0xFF6D4C41),
    top: Color(0xFFFFF8E1),
    bottom: Color(0xFF8D6E63),
    shoes: Color(0xFF5D4037),
    style: 'bun',
    hat: 'baker',
    extras: {'apron'},
    lashes: true,
    longSleeves: true,
  ),
};

final _customLooks = <String, _Look>{};

Color _hex(String hex, Color fallback) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Personajele făcute de părinte în Studio devin oameni desenați ca toți ceilalți.
void setStudioPeople(List<StudioPerson> people) {
  _customLooks
    ..clear()
    ..addAll({
      for (final p in people)
        p.id: _Look(
          skin: _hex(p.skin, const Color(0xFFF2C6A0)),
          hair: _hex(p.hair, const Color(0xFF5D4037)),
          top: _hex(p.top, const Color(0xFF42A5F5)),
          bottom: _hex(p.bottom, const Color(0xFF455A64)),
          shoes: _hex(p.shoes, const Color(0xFF4E342E)),
          style: p.style,
          dress: p.dress,
          hat: p.hat,
          beard: p.beard,
          glasses: p.glasses,
          lashes: p.style != 'short' || p.dress,
        ),
    });
}

Color _darker(Color c, [double f = 0.8]) => Color.from(alpha: c.a, red: c.r * f, green: c.g * f, blue: c.b * f);
Color _lighter(Color c, [double f = 0.25]) =>
    Color.from(alpha: c.a, red: c.r + (1 - c.r) * f, green: c.g + (1 - c.g) * f, blue: c.b + (1 - c.b) * f);

/// Un braț cu cot: mâneca, antebrațul și mâna cu degetul mare. Întoarce poziția mâinii.
Offset _personArm(Canvas canvas, Offset shoulder, double angle, double u, Color sleeve, Color skin, bool longSleeve) {
  final elbow = shoulder + Offset(sin(angle), cos(angle)) * (15 * u);
  final a2 = angle * 0.92;
  final hand = elbow + Offset(sin(a2), cos(a2)) * (14 * u);
  canvas.drawLine(shoulder, elbow, _stroke(sleeve, 8 * u));
  final cuff = longSleeve ? elbow + (hand - elbow) * 0.8 : elbow + (hand - elbow) * 0.12;
  canvas.drawLine(elbow, cuff, _stroke(sleeve, 7 * u));
  canvas.drawLine(cuff, hand, _stroke(skin, 5.6 * u));
  // Palma și degetul mare.
  canvas.save();
  canvas.translate(hand.dx, hand.dy);
  canvas.rotate(-a2);
  canvas.drawOval(Rect.fromCenter(center: Offset(0, 1.2 * u), width: 6.4 * u, height: 7.4 * u), _fill(skin));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(3 * u, -0.6 * u), width: 2.4 * u, height: 4.2 * u),
    _fill(_darker(skin, 0.95)),
  );
  canvas.drawLine(Offset(-1.6 * u, 3.6 * u), Offset(1.6 * u, 3.6 * u), _stroke(_darker(skin, 0.85), 0.5 * u));
  canvas.restore();
  return hand;
}

Path _poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final o in pts.skip(1)) {
    p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Un om cu proporții de adult: față ovală, nas, buze, ochi cu gene, gât umbrit, mâini cu degete,
/// haine cu lumină și umbră și, la meserii, uniforma și ce poartă pe cap.
void paintPerson(
  Canvas canvas,
  GhiPerson p,
  double local,
  double ts,
  double px,
  double py,
  double height, {
  double gazeAt = 0,
}) {
  final look = _looks[p.who] ?? _customLooks[p.who] ?? _looks['mami']!;
  final u = height / 100;
  final sitting = p.pose == 'sit';
  final walk = p.pose == 'walk';
  final bob = walk ? sin(ts * pi * 2.4).abs() * 1.2 : sin(ts * pi * 0.8) * 0.4;
  final drop = sitting ? 22.0 : 0.0;

  // Umbra pe pământ, mai închisă chiar sub tălpi.
  canvas.drawOval(_r(px - 18 * u, py - 2.5 * u, 36 * u, 6 * u), _fill(const Color(0x22000000)));
  canvas.drawOval(_r(px - 11 * u, py - 1.5 * u, 22 * u, 3.5 * u), _fill(const Color(0x22000000)));

  canvas.save();
  canvas.translate(px, py);
  if (p.flip) canvas.scale(-1, 1);
  // Își mută ușor greutatea de pe un picior pe altul.
  if (!sitting && !walk) canvas.rotate(sin(ts * 0.7 + px) * 0.012);
  Offset o(double x, double y) => Offset(x * u, (y + drop - bob) * u);
  const hipY = -48.0;
  final legColor = look.extras.contains('overall')
      ? look.bottom
      : (look.dress ? _darker(look.skin, 0.95) : look.bottom);

  void shoe(Offset at) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(at.dx, at.dy, 14 * u, 6 * u), Radius.circular(3 * u)),
      _fill(look.shoes),
    );
    canvas.drawLine(
      at + Offset(2 * u, 1.4 * u),
      at + Offset(9 * u, 1.4 * u),
      _stroke(_lighter(look.shoes, 0.35), 0.8 * u),
    );
    canvas.drawLine(at + Offset(0, 5.6 * u), at + Offset(14 * u, 5.6 * u), _stroke(_darker(look.shoes, 0.6), 1 * u));
  }

  // Picioarele.
  if (sitting) {
    // Scaunul.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(o(-14, hipY + 5), o(16, hipY + 10)), Radius.circular(2 * u)),
      _fill(const Color(0xFF5D4037)),
    );
    canvas.drawLine(o(0, hipY + 9), o(0, -drop), _stroke(const Color(0xFF4E342E), 3 * u));
    canvas.drawLine(o(-10, -drop), o(10, -drop), _stroke(const Color(0xFF4E342E), 3 * u));
    for (final side in [-4.0, 4.0]) {
      canvas.drawLine(o(side - 2, hipY + 2), o(side + 20, hipY + 2), _stroke(_darker(legColor), 10 * u));
      canvas.drawLine(o(side + 20, hipY + 2), o(side + 20, hipY + 22), _stroke(legColor, 9 * u));
      shoe(o(side + 15, hipY + 20));
    }
  } else {
    final swing = walk ? sin(ts * pi * 2.4) * 16 : 0.0;
    final kick = p.pose == 'kick' && local >= 0.25 && local <= 0.5 ? 40.0 : 0.0;
    const sides = [-5.0, 5.0];
    for (var i = 0; i < 2; i++) {
      final side = sides[i];
      final ang = i == 0 ? swing : -swing - kick;
      _rotated(canvas, ang, o(side, hipY), () {
        final c = i == 0 ? _darker(legColor) : legColor;
        canvas.drawLine(o(side, hipY), o(side, -26), _stroke(c, 10 * u));
        canvas.drawLine(o(side, -26), o(side, -5), _stroke(c, 8.6 * u));
        if (look.extras.contains('reflect')) {
          canvas.drawLine(o(side - 4.3, -16), o(side + 4.3, -16), _stroke(const Color(0xFFFFEB3B), 2 * u));
        }
        shoe(o(side - 4, -6));
      });
    }
  }

  final shoulderL = o(-12, -79), shoulderR = o(12, -79);
  final backAngle = switch (p.pose) {
    'wave' || 'carry' => -2.7,
    'clap' => -1.3 + sin(ts * 9) * 0.25,
    'walk' => -sin(ts * pi * 2.4) * 0.4 - 0.15,
    _ => -0.2,
  };
  _personArm(
    canvas,
    shoulderL,
    backAngle,
    u,
    _darker(look.top),
    _darker(look.skin, 0.92),
    look.longSleeves || look.extras.contains('coat') || look.extras.contains('reflect'),
  );

  // Corpul, cu lumină din stânga și umbră în dreapta.
  final shade = [_lighter(look.top, 0.2), look.top, _darker(look.top, 0.78)];
  final torso = Path()
    ..moveTo(o(-13, -85).dx, o(-13, -85).dy)
    ..quadraticBezierTo(o(0, -88).dx, o(0, -88).dy, o(13, -85).dx, o(13, -85).dy)
    ..lineTo(o(15, -60).dx, o(15, -60).dy)
    ..lineTo(o(look.dress ? 22 : 14, look.dress ? -30 : -46).dx, o(0, look.dress ? -30 : -46).dy)
    ..quadraticBezierTo(
      o(0, look.dress ? -26 : -45).dx,
      o(0, look.dress ? -26 : -45).dy,
      o(look.dress ? -22 : -14, 0).dx,
      o(0, look.dress ? -30 : -46).dy,
    )
    ..lineTo(o(-15, -60).dx, o(-15, -60).dy)
    ..close();
  canvas.drawPath(torso, Paint()..shader = LinearGradient(colors: shade).createShader(torso.getBounds()));
  if (look.dress) {
    // Talia și faldurile rochiei.
    canvas.drawLine(o(-14, -60), o(14, -60), _stroke(_darker(look.top, 0.85), 1.6 * u));
    for (final fx in [-8.0, 0.0, 8.0]) {
      canvas.drawLine(o(fx * 0.6, -56), o(fx, -32), _stroke(const Color(0x1A000000), 1.2 * u));
    }
  } else {
    // Cureaua.
    canvas.drawRect(
      Rect.fromPoints(o(-14.5, -49), o(14.5, -45)),
      _fill(look.extras.contains('belt') ? const Color(0xFF212121) : _darker(look.bottom)),
    );
    canvas.drawRect(Rect.fromPoints(o(-2, -48.6), o(2, -45.4)), _fill(const Color(0xFFBDBDBD)));
  }
  final ex = look.extras;
  if (ex.contains('plaid')) {
    for (var k = 0; k < 4; k++) {
      canvas.drawLine(o(-13, -80 + k * 8.0), o(13, -80 + k * 8.0), _stroke(const Color(0x33000000), 1.4 * u));
      canvas.drawLine(o(-10 + k * 7.0, -84), o(-10 + k * 7.0, -48), _stroke(const Color(0x22000000), 1.4 * u));
    }
  }
  if (ex.contains('buttons') || ex.contains('badge')) {
    for (var k = 0; k < 3; k++) {
      canvas.drawCircle(o(0, -76 + k * 9.0), 0.9 * u, _fill(const Color(0x99FFFFFF)));
    }
    canvas.drawPath(_poly([o(-6, -85), o(0, -79), o(6, -85)]), _stroke(Colors.white, 1.4 * u));
  }
  if (ex.contains('chefButtons')) {
    for (var k = 0; k < 3; k++) {
      canvas.drawCircle(o(-4, -78 + k * 8.0), 1 * u, _fill(const Color(0xFF9E9E9E)));
      canvas.drawCircle(o(4, -78 + k * 8.0), 1 * u, _fill(const Color(0xFF9E9E9E)));
    }
  }
  if (ex.contains('tie')) {
    canvas.drawPath(
      _poly([o(-1.6, -84), o(1.6, -84), o(2.4, -64), o(0, -61), o(-2.4, -64)]),
      _fill(const Color(0xFF1A237E)),
    );
  }
  if (ex.contains('reflect')) {
    canvas.drawLine(o(-14, -62), o(14, -62), _stroke(const Color(0xFFFFEB3B), 3 * u));
    canvas.drawLine(o(-14, -66), o(14, -66), _stroke(const Color(0xFFBDBDBD), 1.2 * u));
  }
  if (ex.contains('vest')) {
    final vest = _poly([o(-14, -84), o(-5, -84), o(-3, -50), o(-14, -50)]);
    final vest2 = _poly([o(14, -84), o(5, -84), o(3, -50), o(14, -50)]);
    canvas.drawPath(vest, _fill(const Color(0xFFFF6D00)));
    canvas.drawPath(vest2, _fill(const Color(0xFFFF6D00)));
    for (final y in [-70.0, -60.0]) {
      canvas.drawLine(o(-14, y), o(-4, y), _stroke(const Color(0xFFE0E0E0), 2 * u));
      canvas.drawLine(o(4, y), o(14, y), _stroke(const Color(0xFFE0E0E0), 2 * u));
    }
  }
  if (ex.contains('overall')) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(o(-9, -70), o(9, -46)), Radius.circular(2 * u)),
      _fill(look.bottom),
    );
    canvas.drawLine(o(-8, -70), o(-11, -85), _stroke(look.bottom, 3 * u));
    canvas.drawLine(o(8, -70), o(11, -85), _stroke(look.bottom, 3 * u));
    canvas.drawCircle(o(-7, -68), 1.1 * u, _fill(const Color(0xFFFFD54F)));
    canvas.drawCircle(o(7, -68), 1.1 * u, _fill(const Color(0xFFFFD54F)));
    canvas.drawRect(Rect.fromPoints(o(-4, -64), o(4, -58)), _stroke(_darker(look.bottom), 0.8 * u));
  }
  if (ex.contains('apron')) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(o(-10, -74), o(10, -30)), Radius.circular(3 * u)),
      _fill(const Color(0xFFF5F5F5)),
    );
    canvas.drawLine(o(-10, -74), o(-7, -86), _stroke(const Color(0xFFF5F5F5), 1.5 * u));
    canvas.drawLine(o(10, -74), o(7, -86), _stroke(const Color(0xFFF5F5F5), 1.5 * u));
    canvas.drawRect(Rect.fromPoints(o(-6, -54), o(6, -46)), _stroke(const Color(0x22000000), 0.8 * u));
  }
  if (ex.contains('coat')) {
    // Halatul alb, deschis în față.
    canvas.drawPath(_poly([o(-15, -85), o(-4, -85), o(-2, -30), o(-17, -30)]), _fill(const Color(0xFFFAFAFA)));
    canvas.drawPath(_poly([o(15, -85), o(4, -85), o(2, -30), o(17, -30)]), _fill(const Color(0xFFEEEEEE)));
    canvas.drawPath(_poly([o(-4, -85), o(-1, -72), o(-7, -80)]), _fill(const Color(0xFFE0E0E0)));
    canvas.drawPath(_poly([o(4, -85), o(1, -72), o(7, -80)]), _fill(const Color(0xFFD6D6D6)));
    canvas.drawRect(Rect.fromPoints(o(7, -70), o(13, -64)), _stroke(const Color(0xFFBDBDBD), 0.8 * u));
    canvas.drawLine(o(9, -72), o(9, -66), _stroke(const Color(0xFF1E88E5), 1 * u));
  }
  if (ex.contains('stetho')) {
    final path = Path()
      ..moveTo(o(-6, -85).dx, o(-6, -85).dy)
      ..quadraticBezierTo(o(-9, -70).dx, o(-9, -70).dy, o(-2, -64).dx, o(-2, -64).dy)
      ..moveTo(o(6, -85).dx, o(6, -85).dy)
      ..quadraticBezierTo(o(9, -70).dx, o(9, -70).dy, o(2, -64).dx, o(2, -64).dy);
    canvas.drawPath(path, _stroke(const Color(0xFF455A64), 1.3 * u));
    canvas.drawLine(o(0, -64), o(0, -58), _stroke(const Color(0xFF455A64), 1.3 * u));
    canvas.drawCircle(o(0, -56.5), 2.2 * u, _fill(const Color(0xFFB0BEC5)));
    canvas.drawCircle(o(0, -56.5), 1.2 * u, _fill(const Color(0xFF78909C)));
  }
  if (ex.contains('badge')) {
    final c = o(-7, -74);
    final star = Path();
    for (var k = 0; k < 10; k++) {
      final r = (k.isEven ? 3.0 : 1.3) * u;
      final a = -pi / 2 + k * pi / 5;
      final pt = c + Offset(cos(a), sin(a)) * r;
      k == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(star..close(), _fill(const Color(0xFFFFC107)));
  }
  if (ex.contains('wings')) {
    canvas.drawLine(o(-11, -74), o(-3, -74), _stroke(const Color(0xFFFFC107), 1.6 * u));
    canvas.drawCircle(o(-7, -74), 1.2 * u, _fill(const Color(0xFFFFC107)));
    for (final s in [7.0, 9.0]) {
      canvas.drawLine(o(s, -84), o(s, -80), _stroke(const Color(0xFFFFC107), 1 * u));
    }
  }
  if (ex.contains('bag')) {
    canvas.drawLine(o(12, -84), o(-10, -52), _stroke(const Color(0xFF6D4C41), 2.2 * u));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(o(-18, -56), o(-4, -42)), Radius.circular(2 * u)),
      _fill(const Color(0xFF8D6E63)),
    );
    canvas.drawRect(Rect.fromPoints(o(-18, -56), o(-4, -51)), _fill(const Color(0xFF6D4C41)));
    ghiText(canvas, '✉', o(-11, -46), 4 * u, const Color(0xFFFFF8E1));
  }

  // Gâtul, cu umbra bărbiei.
  canvas.drawRect(Rect.fromPoints(o(-3.6, -91), o(3.6, -84)), _fill(_darker(look.skin, 0.92)));
  canvas.drawOval(Rect.fromPoints(o(-4, -89.5), o(4, -86.5)), _fill(const Color(0x22000000)));

  final head = o(0.5, -100);
  final faceRect = Rect.fromCenter(center: head, width: 20 * u, height: 24 * u);

  // Părul din spate (lung, coc, coadă).
  if (look.style == 'long') {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromPoints(o(-13, -109), o(-3, -82)), Radius.circular(5 * u)),
      _fill(_darker(look.hair, 0.85)),
    );
  }
  if (look.style == 'bun' && look.hat == null) {
    canvas.drawCircle(o(-6, -113), 5.5 * u, _fill(look.hair));
    canvas.drawCircle(o(-7, -114.5), 2 * u, _fill(_lighter(look.hair, 0.15)));
  }

  // Fața ovală, cu lumină din stânga sus.
  canvas.drawOval(
    faceRect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 0.9,
        colors: [_lighter(look.skin, 0.18), look.skin, _darker(look.skin, 0.88)],
        stops: const [0, 0.55, 1],
      ).createShader(faceRect),
  );
  // Urechea, cu interiorul mai închis.
  final ear = head + Offset(-9.2 * u, 0.5 * u);
  canvas.drawOval(Rect.fromCenter(center: ear, width: 4 * u, height: 6 * u), _fill(_darker(look.skin, 0.94)));
  canvas.drawOval(
    Rect.fromCenter(center: ear + Offset(0.3 * u, 0), width: 1.8 * u, height: 3.4 * u),
    _fill(_darker(look.skin, 0.8)),
  );

  // Părul de deasupra.
  final hairTop = Rect.fromCenter(center: head + Offset(-0.5 * u, -5 * u), width: 22.5 * u, height: 17 * u);
  switch (look.style) {
    case 'long':
      _arc(canvas, look.hair, 175, 195, true, hairTop);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - 3 * u, head.dy - 12 * u)
          ..quadraticBezierTo(head.dx + 6 * u, head.dy - 10 * u, head.dx + 10 * u, head.dy - 3 * u)
          ..lineTo(head.dx + 10.5 * u, head.dy - 9 * u)
          ..close(),
        _fill(look.hair),
      );
      // Coada care se leagănă.
      final sway = sin(ts * 2) * 2;
      canvas.drawOval(Rect.fromLTWH(o(-19 + sway * 0.3, -106).dx, o(0, -106).dy, 7 * u, 19 * u), _fill(look.hair));
    case 'bun':
      _arc(canvas, look.hair, 180, 180, true, hairTop);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - 6 * u, head.dy - 12 * u)
          ..quadraticBezierTo(head.dx + 5 * u, head.dy - 12 * u, head.dx + 10 * u, head.dy - 4 * u)
          ..lineTo(head.dx + 10 * u, head.dy - 9 * u)
          ..close(),
        _fill(look.hair),
      );
    default:
      _arc(canvas, look.hair, 168, 204, true, hairTop.deflate(0.3 * u));
      canvas.drawRect(
        Rect.fromPoints(head + Offset(-10.2 * u, -6 * u), head + Offset(-7.4 * u, 1 * u)),
        _fill(look.hair),
      );
  }
  // Șuvițe: câteva linii mai deschise dau senzația de păr adevărat.
  for (var k = 0; k < 3; k++) {
    _arc(canvas, _lighter(look.hair, 0.22), 205 + k * 22.0, 30, false, hairTop.deflate((1.5 + k) * u), 0.6 * u);
  }

  // Barba nerasă.
  if (look.beard) {
    _arc(
      canvas,
      look.hair.withValues(alpha: 0.18),
      15,
      150,
      true,
      Rect.fromCenter(center: head + Offset(0, 4 * u), width: 18 * u, height: 14 * u),
    );
  }

  // Ochii: alb, iris colorat, pupilă, luciri, pleoapă, gene și sprâncene.
  const dark = Color(0xFF2B1B17);
  final closed = ((ts + 1.7 + sin(ts * 0.29) * 1.1) % 4.3) < 0.12;
  final gaze = (p.flip ? -gazeAt : gazeAt) * 0.55;
  for (final exX in [-3.4, 4.6]) {
    final e = head + Offset(exX * u, -1.2 * u);
    if (closed) {
      _arc(canvas, dark, 20, 140, false, Rect.fromCenter(center: e, width: 3.8 * u, height: 2 * u), 0.7 * u);
    } else {
      canvas.drawOval(Rect.fromCenter(center: e, width: 4.2 * u, height: 2.9 * u), _fill(const Color(0xFFFDFDFD)));
      final iris = e + Offset((0.25 + gaze) * u, 0.1 * u);
      canvas.drawCircle(iris, 1.3 * u, _fill(look.eyes));
      canvas.drawCircle(iris, 0.7 * u, _fill(dark));
      canvas.drawCircle(iris + Offset(0.45 * u, -0.45 * u), 0.35 * u, _fill(Colors.white));
      // Pleoapa de sus.
      _arc(canvas, dark, 190, 160, false, Rect.fromCenter(center: e, width: 4.4 * u, height: 3.1 * u), 0.55 * u);
      if (look.lashes) {
        canvas.drawLine(e + Offset(1.6 * u, -1.1 * u), e + Offset(2.6 * u, -1.9 * u), _stroke(dark, 0.45 * u));
        canvas.drawLine(e + Offset(0.6 * u, -1.5 * u), e + Offset(1.2 * u, -2.4 * u), _stroke(dark, 0.45 * u));
      }
    }
    // Sprânceana, puțin arcuită.
    _arc(
      canvas,
      _darker(look.hair, look.hair.computeLuminance() > 0.5 ? 0.7 : 1),
      200,
      140,
      false,
      Rect.fromCenter(center: e + Offset(0, -2.6 * u), width: 4.6 * u, height: 2.2 * u),
      0.8 * u,
    );
  }
  if (look.glasses) {
    for (final exX in [-3.4, 4.6]) {
      canvas.drawCircle(head + Offset(exX * u, -1.2 * u), 2.8 * u, _stroke(const Color(0xFF5D4037), 0.55 * u));
    }
    canvas.drawLine(
      head + Offset(-0.6 * u, -1.4 * u),
      head + Offset(1.8 * u, -1.4 * u),
      _stroke(const Color(0xFF5D4037), 0.55 * u),
    );
  }
  // Nasul: o umbră pe o parte și nările.
  canvas.drawPath(
    Path()
      ..moveTo(head.dx + 1.4 * u, head.dy - 0.5 * u)
      ..quadraticBezierTo(head.dx + 3.4 * u, head.dy + 3.6 * u, head.dx + 1.6 * u, head.dy + 4.2 * u),
    _stroke(_darker(look.skin, 0.78), 0.65 * u),
  );
  canvas.drawCircle(head + Offset(0.4 * u, 4.1 * u), 0.45 * u, _fill(_darker(look.skin, 0.7)));
  canvas.drawCircle(head + Offset(2.4 * u, 4.1 * u), 0.45 * u, _fill(_darker(look.skin, 0.7)));
  // Obrajii.
  canvas.drawCircle(head + Offset(-5 * u, 3.4 * u), 2.4 * u, _fill(const Color(0x33FF8A80)));
  canvas.drawCircle(head + Offset(7 * u, 3.4 * u), 2.4 * u, _fill(const Color(0x33FF8A80)));
  // Gura: buza de sus mai închisă, buza de jos cu luciu.
  final m = head + Offset(1 * u, 7.2 * u);
  final lip = look.lashes ? const Color(0xFFC2185B) : _darker(look.skin, 0.62);
  switch (p.face) {
    case 'wow':
      canvas.drawOval(Rect.fromCenter(center: m, width: 3.4 * u, height: 3.8 * u), _fill(const Color(0xFF6D1F1F)));
      canvas.drawOval(Rect.fromCenter(center: m, width: 3.4 * u, height: 3.8 * u), _stroke(lip, 0.7 * u));
    case 'calm':
      _arc(
        canvas,
        lip,
        20,
        140,
        false,
        Rect.fromCenter(center: m - Offset(0, 1 * u), width: 5 * u, height: 2.6 * u),
        0.9 * u,
      );
    default:
      final smile = Path()
        ..moveTo(m.dx - 3.2 * u, m.dy - 1 * u)
        ..quadraticBezierTo(m.dx, m.dy + 0.2 * u, m.dx + 3.2 * u, m.dy - 1 * u)
        ..quadraticBezierTo(m.dx, m.dy + 3 * u, m.dx - 3.2 * u, m.dy - 1 * u)
        ..close();
      canvas.drawPath(smile, _fill(const Color(0xFF7B2B2B)));
      canvas.drawRect(
        Rect.fromCenter(center: m + Offset(0, -0.1 * u), width: 4 * u, height: 0.9 * u),
        _fill(const Color(0xFFF5F5F5)),
      );
      canvas.drawPath(smile, _stroke(lip, 0.6 * u));
  }

  // Ce poartă pe cap.
  _personHat(canvas, look.hat, head, u);

  final frontAngle = switch (p.pose) {
    'wave' => 2.5 + sin(ts * pi * 3) * 0.35,
    'reach' || 'hold' => 1.5,
    'carry' => 2.7,
    'clap' => 1.3 - sin(ts * 9) * 0.25,
    'point' => 2.0,
    'sit' => 1.3,
    'walk' => sin(ts * pi * 2.4) * 0.4 + 0.15,
    _ => p.hold != null ? 0.9 : 0.2,
  };
  final hand = _personArm(
    canvas,
    shoulderR,
    frontAngle,
    u,
    look.top,
    look.skin,
    look.longSleeves || ex.contains('coat') || ex.contains('reflect'),
  );
  if (ex.contains('coat')) {
    canvas.drawLine(
      shoulderR,
      shoulderR + Offset(sin(frontAngle), cos(frontAngle)) * (15 * u),
      _stroke(const Color(0xFFF5F5F5), 8 * u),
    );
  }
  if (p.hold != null) ghiEmoji(canvas, p.hold!, hand + Offset(3 * u, -4 * u), 14 * u);
  canvas.restore();
}

void _personHat(Canvas canvas, String? hat, Offset head, double u) {
  Offset h(double x, double y) => head + Offset(x * u, y * u);
  switch (hat) {
    case 'fire':
      // Casca de pompier: roșie, cu bor lat și scut în față.
      canvas.drawOval(Rect.fromCenter(center: h(-1, -9), width: 32 * u, height: 7 * u), _fill(const Color(0xFFB71C1C)));
      final dome = Rect.fromCenter(center: h(0, -10), width: 23 * u, height: 20 * u);
      canvas.drawArc(
        dome,
        pi,
        pi,
        true,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
          ).createShader(dome),
      );
      canvas.drawLine(h(0, -20), h(0, -10), _stroke(const Color(0xFF8E0000), 1.2 * u));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: h(7, -14), width: 6 * u, height: 7 * u),
          Radius.circular(1.5 * u),
        ),
        _fill(const Color(0xFFFFD54F)),
      );
    case 'police':
      canvas.drawRect(Rect.fromCenter(center: h(0, -12), width: 22 * u, height: 7 * u), _fill(const Color(0xFF1A237E)));
      canvas.drawOval(Rect.fromCenter(center: h(0, -16), width: 25 * u, height: 6 * u), _fill(const Color(0xFF283593)));
      canvas.drawRect(Rect.fromCenter(center: h(0, -10), width: 22 * u, height: 2 * u), _fill(const Color(0xFF212121)));
      canvas.drawPath(_poly([h(2, -9), h(14, -9), h(12, -6.5), h(2, -7.5)]), _fill(const Color(0xFF111111)));
      canvas.drawCircle(h(4, -13), 1.8 * u, _fill(const Color(0xFFFFC107)));
    case 'pilot':
      canvas.drawRect(Rect.fromCenter(center: h(0, -12), width: 22 * u, height: 7 * u), _fill(const Color(0xFF1A237E)));
      canvas.drawOval(Rect.fromCenter(center: h(0, -16), width: 25 * u, height: 6 * u), _fill(const Color(0xFF1A237E)));
      canvas.drawRect(
        Rect.fromCenter(center: h(0, -11), width: 22 * u, height: 1.6 * u),
        _fill(const Color(0xFFFFC107)),
      );
      canvas.drawPath(_poly([h(2, -9), h(14, -9), h(12, -6.5), h(2, -7.5)]), _fill(const Color(0xFF111111)));
      canvas.drawCircle(h(4, -13.5), 1.6 * u, _fill(const Color(0xFFFFC107)));
    case 'post':
      _arc(
        canvas,
        const Color(0xFF1565C0),
        180,
        180,
        true,
        Rect.fromCenter(center: h(0, -9), width: 22 * u, height: 16 * u),
      );
      canvas.drawPath(_poly([h(4, -9.5), h(15, -9), h(13, -6.5), h(4, -7.5)]), _fill(const Color(0xFF0D47A1)));
      canvas.drawCircle(h(1, -13), 1.6 * u, _fill(const Color(0xFFFFC107)));
    case 'hard':
      // Casca galbenă de constructor.
      final dome = Rect.fromCenter(center: h(0, -9), width: 24 * u, height: 20 * u);
      canvas.drawArc(
        dome,
        pi,
        pi,
        true,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0xFFFFF176), Color(0xFFFBC02D)],
          ).createShader(dome),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: h(1, -9), width: 30 * u, height: 3 * u),
          Radius.circular(1.5 * u),
        ),
        _fill(const Color(0xFFF9A825)),
      );
      canvas.drawLine(h(0, -19), h(0, -10), _stroke(const Color(0xFFF9A825), 1.4 * u));
    case 'straw':
      canvas.drawOval(Rect.fromCenter(center: h(0, -10), width: 36 * u, height: 7 * u), _fill(const Color(0xFFE6C36A)));
      _arc(
        canvas,
        const Color(0xFFEDD083),
        180,
        180,
        true,
        Rect.fromCenter(center: h(0, -11), width: 20 * u, height: 16 * u),
      );
      canvas.drawRect(
        Rect.fromCenter(center: h(0, -12), width: 20 * u, height: 2.4 * u),
        _fill(const Color(0xFFC62828)),
      );
      for (var k = -2; k <= 2; k++) {
        canvas.drawLine(h(k * 6.0 - 1, -9), h(k * 6.0 + 1, -11), _stroke(const Color(0x33000000), 0.5 * u));
      }
    case 'chef':
      canvas.drawRect(Rect.fromCenter(center: h(0, -11), width: 20 * u, height: 5 * u), _fill(const Color(0xFFF5F5F5)));
      for (final c in [h(-6, -20), h(0, -23), h(6, -20), h(0, -17)]) {
        canvas.drawCircle(c, 6.5 * u, _fill(const Color(0xFFFAFAFA)));
      }
      canvas.drawLine(h(-9, -13), h(9, -13), _stroke(const Color(0xFFE0E0E0), 0.8 * u));
    case 'baker':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: h(0, -12), width: 22 * u, height: 8 * u),
          Radius.circular(4 * u),
        ),
        _fill(const Color(0xFFFAFAFA)),
      );
      canvas.drawLine(h(-10, -9), h(10, -9), _stroke(const Color(0xFFE0E0E0), 0.8 * u));
  }
}
