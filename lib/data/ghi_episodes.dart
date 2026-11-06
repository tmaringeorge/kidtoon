import 'dart:convert';
import 'dart:math';

/// Episoadele cu GHI, bebelușul-dragon. Povestea stă în `assets/ghi/episodes.json`
/// (comun cu aplicația de TV), iar aici sunt modelul și cronometrul:
/// generic de început, pașii poveștii, apoi „Ce am învățat”.

double _num(Object? v, double d) => v is num ? v.toDouble() : d;

/// Un interval de la..la, parcurs pe durata unui pas (sau o valoare fixă).
class Span {
  const Span(this.from, this.to);
  final double from;
  final double to;

  double at(double x) => from + (to - from) * GhiTimeline.ease(x);

  static Span of(Object? v, double d) {
    if (v is List && v.length >= 2) return Span(_num(v[0], d), _num(v[1], d));
    final x = _num(v, d);
    return Span(x, x);
  }
}

int _color(String hex) => 0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16);

class GhiSet {
  GhiSet(this.sky, this.ground, this.horizon, this.deco);
  final List<int> sky;
  final int ground;
  final double horizon;
  final List<String> deco;
}

class GhiPose {
  GhiPose(Map<String, dynamic> g)
    : pose = g['pose'] as String? ?? 'stand',
      x = Span.of(g['x'], 0.35),
      y = g['y'] == null ? null : Span.of(g['y'], 0),
      face = g['face'] as String? ?? 'happy',
      puff = g['puff'] as String?,
      hold = g['hold'] as String?,
      hat = g['hat'] as String?,
      think = g['think'] as String?,
      flip = g['flip'] == true,
      motion = g['m'] as String?;
  final String pose;
  final Span x;
  final Span? y;
  final String face;
  final String? puff, hold, hat, think, motion;
  final bool flip;
}

class GhiProp {
  GhiProp(Map<String, dynamic> p)
    : emoji = p['e'] as String,
      x = Span.of(p['x'], 0.5),
      y = Span.of(p['y'], 0.5),
      size = _num(p['s'], 0.12),
      motion = p['m'] as String? ?? 'none',
      appear = _num(p['in'], 0),
      vanish = _num(p['out'], 1),
      front = p['front'] == true;
  final String emoji;
  final Span x, y;
  final double size, appear, vanish;
  final String motion;
  final bool front;
}

/// Mami sau tati, desenați lângă GHI.
class GhiPerson {
  GhiPerson(Map<String, dynamic> p)
    : who = p['who'] as String? ?? 'mami',
      x = Span.of(p['x'], 0.6),
      y = p['y'] == null ? null : Span.of(p['y'], 0),
      pose = p['pose'] as String? ?? 'stand',
      face = p['face'] as String? ?? 'happy',
      hold = p['hold'] as String?,
      flip = p['flip'] != false;
  final String who, pose, face;
  final Span x;
  final Span? y;
  final String? hold;
  final bool flip;
}

/// O întrebare în episod: „Care e mingea? Arată cu degetul!”. [answer] e obiectul corect din props.
class GhiAsk {
  GhiAsk(Map<String, dynamic> a)
    : answer = _num(a['answer'], 0).toInt(),
      yes = a['yes'] as String? ?? 'Bravo!',
      no = a['no'] as String? ?? 'Mai caută puțin!',
      hint = a['hint'] as String? ?? 'Uite aici!';
  final int answer;
  final String yes, no, hint;
}

class GhiCount {
  GhiCount(Map<String, dynamic> c)
    : items = (c['items'] as List).cast<String>(),
      labels = (c['labels'] as List?)?.cast<String>() ?? const [],
      y = _num(c['y'], 0.3),
      size = _num(c['s'], 0.1),
      x = Span.of(c['x'], 0.5);
  final List<String> items, labels;
  final double y, size;
  final Span x;
}

class GhiBeat {
  GhiBeat(Map<String, dynamic> b)
    : say = b['say'] as String? ?? '',
      sec = _num(b['sec'], 10).toInt(),
      ghi = GhiPose((b['ghi'] as Map).cast<String, dynamic>()),
      props = ((b['props'] as List?) ?? const []).map((p) => GhiProp((p as Map).cast<String, dynamic>())).toList(),
      count = b['count'] == null ? null : GhiCount((b['count'] as Map).cast<String, dynamic>()),
      cam = b['cam'] == null ? null : Span.of(b['cam'], 1),
      people = ((b['people'] as List?) ?? const []).map((p) => GhiPerson((p as Map).cast<String, dynamic>())).toList(),
      ask = b['ask'] == null ? null : GhiAsk((b['ask'] as Map).cast<String, dynamic>());
  final String say;
  final int sec;
  final GhiPose ghi;
  final List<GhiProp> props;
  final GhiCount? count;
  final Span? cam;
  final List<GhiPerson> people;
  final GhiAsk? ask;
}

class GhiEpisode {
  GhiEpisode(Map<String, dynamic> e)
    : id = e['id'] as String,
      title = e['title'] as String,
      set = e['set'] as String,
      learn = e['learn'] as String? ?? '',
      beats = (e['beats'] as List).map((b) => GhiBeat((b as Map).cast<String, dynamic>())).toList();
  final String id, title, set, learn;
  final List<GhiBeat> beats;
}

/// „Atinge și învață”: copilul atinge un lucru, iar GHI spune ce este.
class GhiTouchItem {
  GhiTouchItem(Map<String, dynamic> i)
    : emoji = i['e'] as String,
      name = i['name'] as String,
      say = i['say'] as String? ?? i['name'] as String;
  final String emoji, name, say;
}

class GhiTouchScene {
  GhiTouchScene(Map<String, dynamic> t)
    : id = t['id'] as String,
      title = t['title'] as String,
      set = t['set'] as String,
      items = (t['items'] as List).map((i) => GhiTouchItem(i as Map<String, dynamic>)).toList();
  final String id, title, set;
  final List<GhiTouchItem> items;
}

class GhiBook {
  GhiBook(this.sets, this.episodes, [this.touch = const []]);
  final Map<String, GhiSet> sets;
  final List<GhiEpisode> episodes;
  final List<GhiTouchScene> touch;

  GhiSet set(String name) => sets[name] ?? sets.values.first;

  static GhiBook parse(String text) {
    final root = jsonDecode(text) as Map<String, dynamic>;
    final sets = (root['sets'] as Map<String, dynamic>).map((k, v) {
      final o = v as Map<String, dynamic>;
      return MapEntry(
        k,
        GhiSet(
          (o['sky'] as List).map((c) => _color(c as String)).toList(),
          _color(o['ground'] as String? ?? '#8BC34A'),
          _num(o['horizon'], 0.72),
          ((o['deco'] as List?) ?? const []).cast<String>(),
        ),
      );
    });
    final episodes = (root['episodes'] as List).map((e) => GhiEpisode(e as Map<String, dynamic>)).toList();
    final touch = ((root['touch'] as List?) ?? const []).map((t) => GhiTouchScene(t as Map<String, dynamic>)).toList();
    return GhiBook(sets, episodes, touch);
  }
}

enum GhiPhaseKind { title, step, end }

/// Unde suntem într-un episod: genericul, un pas al poveștii sau finalul.
class GhiPhase {
  const GhiPhase(this.kind, this.local, [this.index = 0, this.ms = 0]);
  final GhiPhaseKind kind;
  final double local;
  final int index;
  final int ms;
}

class GhiTimeline {
  static const titleMs = 4000;
  static const endMs = 7000;

  /// Mișcare „pe cadre”, ca la desenele pentru cei mici: 10 cadre pe secundă.
  static const fps = 10;

  static int durationMs(GhiEpisode ep) => titleMs + ep.beats.fold<int>(0, (a, b) => a + b.sec * 1000) + endMs;

  static GhiPhase phase(GhiEpisode ep, int ms) {
    if (ms < titleMs) return GhiPhase(GhiPhaseKind.title, ms / titleMs);
    var left = ms - titleMs;
    for (var i = 0; i < ep.beats.length; i++) {
      final len = ep.beats[i].sec * 1000;
      if (left < len) return GhiPhase(GhiPhaseKind.step, left / len, i, left);
      left -= len;
    }
    return GhiPhase(GhiPhaseKind.end, (left / endMs).clamp(0.0, 1.0));
  }

  static String caption(GhiEpisode ep, int ms) {
    final p = phase(ep, ms);
    switch (p.kind) {
      case GhiPhaseKind.title:
        return ep.title;
      case GhiPhaseKind.step:
        return ep.beats[p.index].say;
      case GhiPhaseKind.end:
        return 'Ce am învățat: ${ep.learn}';
    }
  }

  /// Timpul rotunjit la cadru (10 pe secundă), ca mișcările să fie calme.
  static int quantize(int ms) => ms - ms % (1000 ~/ fps);

  static double ease(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Câte obiecte se văd deja când numărăm: apar pe rând, unul câte unul.
  static int counted(int n, double local) {
    var c = 0;
    for (var i = 0; i < n; i++) {
      if (local >= 0.1 + i * 0.75 / n) c++;
    }
    return c;
  }

  /// Zoom lent (aproape / departe) dacă pasul nu cere altceva.
  static Span camera(GhiBeat beat, int index) => beat.cam ?? (index.isEven ? const Span(1, 1.07) : const Span(1.07, 1));

  /// Tăietură de cadru: GHI apare în alt loc decât la finalul pasului de dinainte.
  static bool isCut(GhiEpisode ep, int index) =>
      index > 0 && (ep.beats[index].ghi.x.from - ep.beats[index - 1].ghi.x.to).abs() > 0.1;

  /// La o întrebare: după cât din pas arată GHI singur răspunsul, dacă nu a ales nimeni.
  static const reveal = 0.6;

  /// După un răspuns bun, ne mai bucurăm atât și trecem mai departe.
  static const answerHoldMs = 3500;

  /// Cât arată „Mai caută puțin!” după o alegere greșită.
  static const wrongMs = 1800;

  static int beatStartMs(GhiEpisode ep, int index) =>
      titleMs + ep.beats.take(index).fold<int>(0, (a, b) => a + b.sec * 1000);

  /// Textul unei întrebări, după ce s-a întâmplat: bravo, mai caută, uite aici, sau întrebarea.
  static String askCaption(GhiBeat beat, double local, {bool answered = false, bool wrong = false}) {
    final a = beat.ask;
    if (a == null) return beat.say;
    if (answered) return a.yes;
    if (wrong) return a.no;
    if (local >= reveal) return a.hint;
    return beat.say;
  }

  /// Ce obiect e sub deget la o întrebare (coordonate 0..1), sau -1. [radius] e relativ la lățime.
  static int askHit(GhiBeat beat, double local, double fx, double fy, double aspect, [double radius = 0.13]) {
    if (beat.ask == null) return -1;
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < beat.props.length; i++) {
      final p = beat.props[i];
      final dx = fx - p.x.at(local);
      final dy = (fy - p.y.at(local)) * aspect;
      final d = dx * dx + dy * dy;
      if (d < radius * radius && d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  /// Cu cât sărim înainte după un răspuns bun, ca pasul să se termine peste [answerHoldMs].
  static int skipAfterAnswer(GhiEpisode ep, int ms) {
    final p = phase(ep, ms);
    if (p.kind != GhiPhaseKind.step) return 0;
    final left = ep.beats[p.index].sec * 1000 - p.ms;
    return max(0, left - answerHoldMs);
  }

  static int next(int i, int n) => (i + 1) % n;
  static int previous(int i, int n) => (i - 1 + n) % n;
}

/// Așezarea lucrurilor în „Atinge și învață”: 4 pe rând, GHI stă în stânga jos.
class GhiTouchLayout {
  static const cols = 4;

  static double x(int i) => 0.33 + (i % cols) * 0.19;
  static double y(int i) => 0.36 + (i ~/ cols) * 0.3;

  /// Ce lucru e sub deget (coordonate 0..1), sau -1. [radius] e relativ la lățime.
  static int hit(int n, double fx, double fy, double aspect, [double radius = 0.09]) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < n; i++) {
      final dx = fx - x(i);
      final dy = (fy - y(i)) / aspect;
      final d = dx * dx + dy * dy;
      if (d < radius * radius && d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  static int move(int i, int n, int dx, int dy) {
    final j = i + dx + dy * cols;
    return j >= 0 && j < n ? j : i;
  }
}

enum CareKind { play, blink, rest }

class CareState {
  const CareState(this.kind, [this.ms = 0]);
  final CareKind kind;
  final int ms;
}

/// Ecran sănătos pentru cei mici: pauză de clipit la 5 minute, odihnă după limita
/// sesiunii (sau după 3 episoade la rând) și culori mai calde seara.
class ScreenCare {
  static const blinkEveryMs = 5 * 60000;
  static const blinkMs = 25000;
  static const lookAwayAtMs = 9000;
  static const maxEpisodes = 3;
  static const unlockHoldMs = 3000;
  static const limits = [15, 20, 30, 0];
  static const defaultLimit = 20;

  static CareState state(int activeMs, int limitMin, int episodesInRow) {
    if ((limitMin > 0 && activeMs >= limitMin * 60000) || episodesInRow >= maxEpisodes) {
      return const CareState(CareKind.rest);
    }
    if (activeMs >= blinkEveryMs && activeMs % blinkEveryMs < blinkMs) {
      return CareState(CareKind.blink, activeMs % blinkEveryMs);
    }
    return const CareState(CareKind.play);
  }

  static String blinkCaption(int ms) =>
      ms < lookAwayAtMs ? 'Hai să clipim împreună!' : 'Acum uită-te departe, pe fereastră…';

  /// Trei clipiri lente, cât GHI ne arată cum.
  static bool eyesClosed(int ms) => ms < lookAwayAtMs && ms % 3000 >= 1200 && ms % 3000 < 2200;

  /// Cât de cald/întunecat devine ecranul seara: 0 până la 19:00, apoi până la 0,3 la 21:00.
  static double eveningDim(int hour, int minute) {
    final h = hour + minute / 60;
    if (h < 6) return 0.3;
    if (h < 19) return 0;
    return ((h - 19) / 2).clamp(0.0, 1.0) * 0.3;
  }

  static String limitLabel(int min) => min == 0 ? 'Fără limită' : '$min min';
}
