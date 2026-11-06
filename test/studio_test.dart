import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/data/ghi_character.dart';
import 'package:kidtoon/data/ghi_episodes.dart';
import 'package:kidtoon/data/ghi_studio.dart';

void main() {
  final book = GhiBook.parse(File('assets/ghi/episodes.json').readAsStringSync());

  StudioLibrary sample() => StudioLibrary(
        people: [StudioPerson(id: 'p1', name: 'Bunicul Ion', beard: true, glasses: true, hat: 'straw')],
        drafts: [
          StudioDraft(id: 'e1', title: 'GHI la bunicul', set: 'farm', learn: 'Spunem mulțumesc.', steps: [
            StudioStep(say: 'GHI merge la bunicul', action: 'walk'),
            StudioStep(say: 'Bunicul îi dă un măr', who: 'p1', whoAction: 'hold', thing: '🍎'),
            StudioStep(thing: '🍎', ask: true),
            StudioStep(say: 'GHI dansează cu mami', action: 'dance', who: 'mami', whoAction: 'clap', thing: '🎈'),
          ]),
          StudioDraft(id: 'e2'),
        ],
      );

  test('decorurile și acțiunile din Studio există în aplicație', () {
    for (final s in Studio.sets.keys) {
      expect(book.sets.containsKey(s), isTrue, reason: s);
    }
    for (final t in Studio.things.keys) {
      expect(t.trim(), isNotEmpty);
    }
  });

  test('episodul din Studio se joacă la fel ca celelalte', () {
    final lib = sample();
    final ep = GhiEpisode(lib.drafts.first.toEpisode());
    expect(ep.id, 'studio_e1');
    expect(ep.title, 'GHI la bunicul');
    expect(ep.beats.length, 4);
    expect(ep.beats[1].people.single.who, 'p1');
    final ask = ep.beats[2];
    expect(ask.ask, isNotNull);
    expect(ask.props.length, 3);
    expect(ask.props[ask.ask!.answer].emoji, '🍎');
    expect(ask.props.map((p) => p.emoji).toSet().length, 3);
    expect(ask.say, contains('mărul'));
    expect(GhiTimeline.durationMs(ep), greaterThan(30000));
  });

  test('ciornele goale nu ajung în carte și nici pe TV', () {
    final lib = sample();
    expect(lib.episodes().length, 1);
    final merged = lib.mergeInto(book);
    expect(merged.episodes.length, book.episodes.length + 1);
    final tv = jsonDecode(lib.exportForTv()) as Map<String, dynamic>;
    expect((tv['episodes'] as List).length, 1);
    expect((tv['people'] as List).single['name'], 'Bunicul Ion');
  });

  test('biblioteca se salvează și se încarcă înapoi', () async {
    final dir = await Directory.systemTemp.createTemp('studio');
    final store = StudioStore(File('${dir.path}/ghi_studio.json'));
    await store.save(sample());
    final back = await store.load();
    expect(back.people.single.beard, isTrue);
    expect(back.drafts.first.steps[2].ask, isTrue);
    expect(jsonEncode(back.toJson()), jsonEncode(sample().toJson()));
    await dir.delete(recursive: true);
  });

  test('adresa TV-ului', () {
    expect(StudioSender.uri('192.168.1.23').toString(), 'http://192.168.1.23:8765/ghi');
    expect(StudioSender.uri(' 10.0.0.5:9000 ').toString(), 'http://10.0.0.5:9000/ghi');
  });

  test('GHI poate avea alt nume, poate fi fată și alt animal', () {
    final raw = File('assets/ghi/episodes.json').readAsStringSync();
    const ana = GhiCharacter(name: 'Ana', girl: true, avatar: 'leu');
    final b = GhiBook.parse(ana.personalize(raw));
    final all = b.episodes.expand((e) => [e.title, e.learn, ...e.beats.map((x) => x.say)]).join('\n');
    expect(all, isNot(contains('GHI')));
    expect(all, isNot(contains('{')));
    expect(all, contains('Ana e fericită'));
    expect(all, contains('Mami o îmbrățișează'));
    expect(all, contains('ca o leoaică cuminte'));
    expect(b.episodes.length, book.episodes.length);
    // Băiatul GHI, dinozaurul verde: aceleași povești ca înainte.
    final ghi = GhiBook.parse(const GhiCharacter().personalize(raw));
    final text = ghi.episodes.expand((e) => e.beats.map((x) => x.say)).join('\n');
    expect(text, contains('GHI e fericit'));
    expect(text, contains('Mami îl îmbrățișează'));
    expect(text, contains('ca un dragon cuminte'));
    expect(GhiCharacter.clean('  "Ion{}"  '), 'Ion');
    expect(GhiCharacter.clean(''), 'GHI');
    expect(GhiCharacter.decode(ana.encode()).avatar, 'leu');
    expect(GhiCharacter.decode('stricat').name, 'GHI');
  });

  test('Studio trimite și personajul pe TV', () {
    final tv = jsonDecode(sample().exportForTv(const GhiCharacter(name: 'Ana', girl: true).toJson())) as Map<String, dynamic>;
    expect(tv['character']['name'], 'Ana');
    final eps = sample().episodes(const GhiCharacter(name: 'Ana').personalize);
    expect(eps.first.title, 'GHI la bunicul'.replaceAll('GHI', 'Ana'));
  });
}
