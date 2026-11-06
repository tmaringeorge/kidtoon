import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/data/ghi_episodes.dart';

void main() {
  final book = GhiBook.parse(File('assets/ghi/episodes.json').readAsStringSync());

  test('toate episoadele sunt complete', () {
    expect(book.episodes.length, greaterThanOrEqualTo(25));
    final ids = book.episodes.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final ep in book.episodes) {
      expect(book.sets.containsKey(ep.set), isTrue, reason: ep.id);
      expect(ep.title.startsWith('GHI'), isTrue, reason: ep.id);
      expect(ep.learn, isNotEmpty);
      expect(ep.beats.length, inInclusiveRange(4, 12), reason: ep.id);
    }
    expect(ids, containsAll(['peste', 'fotbal', 'petrecere', 'joaca', 'gradinita', 'stetoscop', 'stele', 'baita', 'olita', 'animalute']));
  });

  test('mami și tati', () {
    final parents = ['mami_shopping', 'tati_tren', 'tati_fotbal', 'mami_prajituri', 'tati_calculator'];
    for (final id in parents) {
      final ep = book.episodes.firstWhere((e) => e.id == id);
      expect(ep.beats.any((b) => b.people.isNotEmpty), isTrue, reason: id);
    }
    for (final ep in book.episodes) {
      expect(GhiTimeline.isCut(ep, 0), isFalse);
    }
  });

  test('întrebări: arată cu degetul', () {
    for (final ep in book.episodes) {
      final i = ep.beats.indexWhere((b) => b.ask != null);
      expect(i, greaterThan(0), reason: ep.id);
      final beat = ep.beats[i];
      final ask = beat.ask!;
      final p = beat.props[ask.answer];
      expect(GhiTimeline.askHit(beat, 0.2, p.x.at(0.2), p.y.at(0.2), 0.56), ask.answer, reason: ep.id);
      expect(GhiTimeline.askHit(beat, 0.2, 0.05, 0.05, 0.56), -1);
      expect(GhiTimeline.askCaption(beat, 0.7), ask.hint);
      expect(GhiTimeline.askCaption(beat, 0.1, answered: true), ask.yes);
      expect(GhiTimeline.askCaption(beat, 0.1, wrong: true), ask.no);
      final start = GhiTimeline.beatStartMs(ep, i);
      expect(GhiTimeline.skipAfterAnswer(ep, start + 1000), beat.sec * 1000 - 1000 - GhiTimeline.answerHoldMs);
    }
    final parents = book.episodes.where((e) => e.id.startsWith('mami_') || e.id.startsWith('tati_') || e.id.startsWith('familie_')).toList();
    expect(parents.length, greaterThanOrEqualTo(11));
    expect(parents.every((e) => e.beats.length >= 8), isTrue);
  });

  test('meseriile au omul lor desenat', () {
    const jobs = ['pompier', 'doctor', 'politist', 'bucatar', 'constructor', 'fermier', 'postas', 'pilot', 'veterinar', 'brutar'];
    for (final job in jobs) {
      final ep = book.episodes.firstWhere((e) => e.id == job);
      expect(ep.beats.length, greaterThanOrEqualTo(8), reason: job);
      expect(ep.beats.any((b) => b.people.any((p) => p.who == job)), isTrue, reason: job);
    }
    const emojiPeople = {'👩', '👩‍🏫', '👵'};
    expect(book.episodes.every((e) => e.beats.every((b) => b.props.every((p) => !emojiPeople.contains(p.emoji)))), isTrue);
  });

  test('generic, poveste, ce am învățat', () {
    final ep = book.episodes.firstWhere((e) => e.id == 'peste');
    expect(GhiTimeline.caption(ep, 0), 'GHI la pescuit');
    expect(GhiTimeline.caption(ep, GhiTimeline.titleMs + 500), 'GHI merge la lac cu undița');
    expect(GhiTimeline.caption(ep, GhiTimeline.titleMs + 10500), 'Ssst! Stăm liniștiți și așteptăm');
    expect(GhiTimeline.caption(ep, GhiTimeline.durationMs(ep) - 100), startsWith('Ce am învățat'));
    expect(GhiTimeline.durationMs(ep), GhiTimeline.titleMs + 74000 + GhiTimeline.endMs);
  });

  test('numărătoare și cadre', () {
    expect(GhiTimeline.counted(3, 0.05), 0);
    expect(GhiTimeline.counted(3, 0.12), 1);
    expect(GhiTimeline.counted(3, 0.9), 3);
    expect(GhiTimeline.quantize(1299), 1200);
    expect(GhiTimeline.next(27, 28), 0);
    expect(GhiTimeline.previous(0, 28), 27);
    expect(const Span(0, 1).at(0.5), closeTo(0.5, 1e-9));
  });

  test('atinge și învață', () {
    expect(book.touch.length, greaterThanOrEqualTo(8));
    for (final t in book.touch) {
      expect(t.items.length, 8, reason: t.id);
      expect(book.sets.containsKey(t.set), isTrue, reason: t.id);
    }
    expect(GhiTouchLayout.hit(8, GhiTouchLayout.x(1) + 0.01, GhiTouchLayout.y(1), 9 / 16), 1);
    expect(GhiTouchLayout.hit(8, 0.05, 0.05, 9 / 16), -1);
    expect(GhiTouchLayout.move(1, 8, 0, 1), 5);
    expect(GhiTouchLayout.move(1, 8, 0, -1), 1);
  });

  test('ecran sănătos', () {
    const min = 60000;
    expect(ScreenCare.state(4 * min, 20, 0).kind, CareKind.play);
    expect(ScreenCare.state(5 * min + 1000, 20, 0).kind, CareKind.blink);
    expect(ScreenCare.state(5 * min + 1000, 20, 0).ms, 1000);
    expect(ScreenCare.state(5 * min + 30000, 20, 0).kind, CareKind.play);
    expect(ScreenCare.state(20 * min, 20, 0).kind, CareKind.rest);
    expect(ScreenCare.state(min, 20, 3).kind, CareKind.rest);
    expect(ScreenCare.state(90 * min + 1000, 0, 0).kind, CareKind.blink);
    expect(ScreenCare.blinkCaption(2000), 'Hai să clipim împreună!');
    expect(ScreenCare.eyesClosed(1500) && !ScreenCare.eyesClosed(500) && !ScreenCare.eyesClosed(10000), isTrue);
    expect(ScreenCare.eveningDim(12, 0), 0);
    expect(ScreenCare.eveningDim(20, 0), closeTo(0.15, 1e-9));
    expect(ScreenCare.eveningDim(22, 30), closeTo(0.3, 1e-9));
  });
}
