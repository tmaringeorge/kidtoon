import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidtoon/data/m3u_parser.dart';
import 'package:kidtoon/data/models.dart';
import 'package:kidtoon/data/parental.dart';
import 'package:kidtoon/data/radio.dart';
import 'package:kidtoon/data/source_filter.dart';
import 'package:kidtoon/data/xmltv.dart';
import 'package:kidtoon/widgets/sky_animation.dart';

void main() {
  test('lista KidToon inclusă se parsează (poate fi goală)', () {
    final p = M3uParser.parse(File('assets/copii.m3u').readAsStringSync(), 'x');
    expect(p.channels.every((c) => SourceFilter.isAllowed(c.url)), isTrue);
  });

  test('filtrul pentru copii păstrează doar desene, educație și familie', () {
    const m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="a" group-title="Kids",Desene 1
https://cdn.example.org/desene1.m3u8
#EXTINF:-1 tvg-id="b" group-title="News",Stiri
https://cdn.example.org/stiri.m3u8
#EXTINF:-1 tvg-id="c" group-title="Animation;Kids",Desene 2
https://cdn.example.org/desene2.m3u8
#EXTINF:-1 tvg-id="d" group-title="Education",Scoala
https://cdn.example.org/scoala.m3u8
#EXTINF:-1 tvg-id="e",Fara categorie
https://cdn.example.org/fara.m3u8
''';
    final all = M3uParser.parse(m3u, 'x').channels;
    expect(all.length, 5);
    final kids = KidFilter.apply(all, kidsOnly: true);
    expect(kids.map((c) => c.name), ['Desene 1', 'Desene 2', 'Scoala']);
    final hidden = KidFilter.apply(all, kidsOnly: true, hidden: {kids.first.key});
    expect(hidden.map((c) => c.name), ['Desene 2', 'Scoala']);
    expect(KidFilter.apply(all, kidsOnly: false).length, 5);
  });

  test('filtrul blocheaza restream-uri neautorizate', () {
    expect(SourceFilter.isAllowed('https://thor1.syndula1.cfd/ernews/use.m3u8'), isFalse);
    expect(SourceFilter.isAllowed('https://vip-acasatv.online:25463/lrZuGxAuP3/6782859900/714.m3u8'), isFalse);
    expect(SourceFilter.isAllowed('http://panel.example.com/live/user123/pass456/1234.ts'), isFalse);
    expect(SourceFilter.isAllowed('https://tvr-1.lg.mncdn.com/tvr1/smil:tvr1.smil/playlist.m3u8'), isTrue);
  });

  test('XMLTV: acum si urmeaza, potrivire dupa id si dupa nume', () {
    final now = DateTime.now();
    String f(DateTime t) {
      final u = t.toUtc();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
    }

    final xml = '''<?xml version="1.0"?><tv>
      <channel id="TVR1.ro"><display-name>TVR 1</display-name></channel>
      <channel id="digi"><display-name>Digi 24 HD</display-name></channel>
      <programme start="${f(now.subtract(const Duration(minutes: 10)))}" stop="${f(now.add(const Duration(minutes: 10)))}" channel="TVR1.ro"><title>Telejurnal</title></programme>
      <programme start="${f(now.add(const Duration(minutes: 10)))}" stop="${f(now.add(const Duration(minutes: 40)))}" channel="TVR1.ro"><title>Film</title></programme>
      <programme start="${f(now.subtract(const Duration(minutes: 1)))}" stop="${f(now.add(const Duration(minutes: 1)))}" channel="digi"><title>Jurnal</title></programme>
    </tv>''';
    final epg = XmlTvParser.parse(xml, now: now);
    final tvr = Channel(key: 'a', name: 'TVR 1', url: 'u', categories: [], sourceName: 's', tvgId: 'TVR1.ro@SD');
    final (live, next) = epg.nowAndNext(tvr, now);
    expect(live?.title, 'Telejurnal');
    expect(next?.title, 'Film');
    final digi = Channel(key: 'b', name: 'Digi 24', url: 'u', categories: [], sourceName: 's');
    expect(epg.nowAndNext(digi, now).$1?.title, 'Jurnal');
  });

  test('antet url-tvg, virgule in nume, EXTVLCOPT', () {
    final p = M3uParser.parse('''#EXTM3U url-tvg="https://ex.ro/epg.xml.gz"
#EXTINF:-1 tvg-id="A.ro" tvg-logo="https://ex.ro/a.png" group-title="News;Sports",Post, cu virgula (1080p) [Not 24/7]
#EXTVLCOPT:http-referrer=https://ex.ro/
https://ex.ro/a.m3u8
''', 't');
    expect(p.epgUrls, ['https://ex.ro/epg.xml.gz']);
    final ch = p.channels.single;
    expect(ch.name, 'Post, cu virgula');
    expect(ch.categories, ['Știri', 'Sport']);
    expect(ch.referrer, 'https://ex.ro/');
  });

  test('radio-browser: parsare, fara duplicate, fara stream gol', () {
    final list = RadioParser.parse('''[
      {"stationuuid":"a","name":" Europa FM ","url":"http://x/a","url_resolved":"https://x/a.mp3","favicon":"https://x/a.png","tags":"news,talk"},
      {"stationuuid":"b","name":"EUROPA FM","url":"http://x/b","url_resolved":"","favicon":null,"tags":null},
      {"stationuuid":"c","name":"Fara stream","url":"","url_resolved":""},
      {"stationuuid":"d","name":"Radio ZU","url":"http://zu/live","url_resolved":null,"favicon":""}
    ]''');
    expect(list.map((s) => s.name), ['Europa FM', 'Radio ZU']);
    expect(list[0].streamUrl, 'https://x/a.mp3');
    expect(list[0].tags, ['news', 'talk']);
    expect(list[1].logo, isNull);
  });

  test('animatia cerului numara stelele de la 1 la 5', () {
    expect(SkyTimeline.dayness(0.1), 1);
    expect(SkyTimeline.dayness(0.7), 0);
    expect(SkyTimeline.starsVisible(0.55), 0);
    expect(SkyTimeline.starsVisible(SkyTimeline.firstStar + 0.001), 1);
    expect(SkyTimeline.starsVisible(0.92), 5);
    expect(SkyTimeline.caption(SkyTimeline.firstStar + 2 * SkyTimeline.starStep + 0.01), '3 · trei stele');
  });
}
