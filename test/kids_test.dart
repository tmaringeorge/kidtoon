import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/data/radio.dart';
import 'package:kidtoon/data/radio_frequencies.dart';
import 'package:kidtoon/widgets/kids_timeline.dart';

KidsFrame at(int minute, [RadioBackground mode = RadioBackground.all]) =>
    KidsTimeline.frame(minute * KidsTimeline.cycleMs + KidsTimeline.cycleMs ~/ 2, mode);

void main() {
  test('toate pe rând: scenele se schimbă la 2 minute și nu se repetă o oră', () {
    final scenes = [for (var m = 0; m < 60; m++) at(m).scene];
    expect(scenes.first, RadioBackground.sky);
    final segments = [for (var i = 0; i < 60; i += 2) scenes[i]];
    for (var i = 0; i < 60; i += 2) {
      expect(scenes[i + 1], scenes[i]);
    }
    for (var i = 1; i < segments.length; i++) {
      expect(segments[i], isNot(segments[i - 1]));
    }
    expect(segments.take(KidsTimeline.rotation.length).toSet(), KidsTimeline.rotation.toSet());
    final combos = {for (var m = 0; m < 60; m++) '${at(m).scene}-${at(m).variant}'};
    expect(combos.length, 60);
  });

  test('o singură scenă rămâne aleasă', () {
    expect({for (var m = 0; m < 30; m++) at(m, RadioBackground.train).scene}, {RadioBackground.train});
  });

  test('textele numără și spun culorile', () {
    expect(
      KidsTimeline.caption(const KidsFrame(RadioBackground.ocean, 0.10 + 2 * 0.14 + 0.01, 0, 0)),
      '3 · trei pești',
    );
    expect(KidsTimeline.caption(const KidsFrame(RadioBackground.farm, 0.05, 0, 0)), 'Vaca face Muu!');
    expect(KidsTimeline.caption(const KidsFrame(RadioBackground.balloons, 0.05, 0, 0)), 'Balonul roșu');
    expect(KidsTimeline.caption(const KidsFrame(RadioBackground.shapes, 0.05, 0, 0)), 'Cercul roșu');
    expect(KidsTimeline.caption(const KidsFrame(RadioBackground.shapes, 0.05, 4, 0)), 'Inima roșie');
    expect(KidsTimeline.caption(const KidsFrame(RadioBackground.train, 0.99, 0, 0)), 'Pa-pa, trenule!');
  });

  test('trenul: vagonul k duce k fructe', () {
    String captionFor(int k, int variant) {
      final t = [for (var i = 0; i <= 1000; i++) i / 1000].firstWhere((t) => KidsTimeline.carAtCenter(t) == k);
      return KidsTimeline.caption(KidsFrame(RadioBackground.train, t, variant, 0));
    }

    expect(captionFor(1, 0), '1 · un măr');
    expect(captionFor(2, 0), '2 · două mere');
    expect(captionFor(5, 1), '5 · cinci pere');
  });

  test('temporizatorul de somn', () {
    expect(SleepTimer.next(0), 30);
    expect(SleepTimer.next(42), 60);
    expect(SleepTimer.next(90), 0);
  });

  test('fotbal, sorcova, Moș Crăciun', () {
    String cap(RadioBackground b, double t) => KidsTimeline.caption(KidsFrame(b, t, 0, 0));
    expect(cap(RadioBackground.football, 0.05), 'Hai, șutează!');
    expect(cap(RadioBackground.football, 0.55), 'Gooool! 3 · trei goluri');
    expect(cap(RadioBackground.sorcova, 0.1), 'Sorcova, vesela,');
    expect(cap(RadioBackground.santa, 0.35), '2 · două cadouri');
    expect(cap(RadioBackground.santa, 0.95), 'Crăciun fericit!');
  });

  test('ce cântă acum', () {
    expect(NowPlaying.clean('  Smiley -  Vals ', 'Kiss FM'), 'Smiley - Vals');
    expect(NowPlaying.clean('Kiss FM', 'Kiss FM'), isNull);
    expect(NowPlaying.clean(' - ', 'Kiss FM'), isNull);
  });

  test('frecvențe București și sortare', () {
    expect(RadioFrequencies.bucharest('KISS FM 96.1'), 96.1);
    expect(RadioFrequencies.bucharest('Radio România Actualități'), 105.3);
    expect(RadioFrequencies.bucharest('Dance FM 89.5 Bucuresti'), 89.5);
    expect(RadioFrequencies.bucharest('Kiss FM Ballads'), isNull);
    RadioStation st(String n) => RadioStation(id: n, name: n, streamUrl: 'http://x');
    final list = [st('Radio ZU'), st('Europa FM'), st('Ăla Radio'), st('Kiss FM'), st('Alt Post')];
    expect(RadioSort.alpha.apply(list).map((s) => s.name), [
      'Alt Post',
      'Ăla Radio',
      'Europa FM',
      'Kiss FM',
      'Radio ZU',
    ]);
    expect(RadioSort.frequency.apply(list).map((s) => s.name), [
      'Radio ZU',
      'Kiss FM',
      'Europa FM',
      'Alt Post',
      'Ăla Radio',
    ]);
  });

  test('dinozauri, pompieri, doctor, zoo, copaci', () {
    String cap(RadioBackground b, double t, [int v = 0]) => KidsTimeline.caption(KidsFrame(b, t, v, 0));
    expect(cap(RadioBackground.dinos, 0.25), '2 · doi dinozauri');
    expect(cap(RadioBackground.firefighters, 0.3), 'Nino-nino! Vin pompierii!');
    expect(cap(RadioBackground.firefighters, 0.9), 'Bravo, pompierilor!');
    expect(cap(RadioBackground.doctor, 0.9, 1), 'Cățelul e sănătos! Mulțumim!');
    expect(cap(RadioBackground.zoo, 0.05), 'Leul face Rrrr!');
    expect(cap(RadioBackground.trees, 0.58), '3 · trei copaci');
    expect(RadioBackground.all.previous, RadioBackground.trees);
    expect(RadioBackground.trees.next, RadioBackground.all);
  });
}
