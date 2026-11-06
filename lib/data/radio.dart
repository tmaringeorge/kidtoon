import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'repository.dart';

/// Ce se vede pe ecran cât se ascultă radio.
enum RadioBackground {
  all('Toate animațiile, pe rând'),
  sky('Cer cu soare, lună și stele'),
  ocean('Peștișori în mare'),
  farm('Animalele de la fermă'),
  balloons('Baloane colorate'),
  train('Trenulețul cu fructe'),
  shapes('Forme și culori'),
  football('Fotbal'),
  sorcova('Sorcova'),
  santa('Moș Crăciun'),
  dinos('Dinozauri'),
  firefighters('Pompierii'),
  doctor('La doctor'),
  zoo('Animale de la zoo'),
  trees('Plantăm copaci');

  const RadioBackground(this.label);
  final String label;

  /// Săgețile din player: următoarea / precedenta animație, în cerc.
  RadioBackground get next => values[(index + 1) % values.length];
  RadioBackground get previous => values[(index - 1 + values.length) % values.length];
}

/// Modul radioului: Copil (animații) sau Adult (ecran simplu, cu postul și melodia).
/// Ce vede copilul în modul Copil: animațiile, episoadele cu GHI sau „Atinge și învață”.
enum KidContent {
  animations('Animații'),
  ghi('Povești'),
  touch('Atinge și învață');

  const KidContent(this.label);
  final String label;

  KidContent get next => KidContent.values[(index + 1) % KidContent.values.length];
}

enum RadioMode {
  kid('Copil'),
  adult('Adult');

  const RadioMode(this.label);
  final String label;
  RadioMode get toggled => this == kid ? adult : kid;
}

/// Un post de radio din radio-browser.info.
class RadioStation {
  RadioStation({required this.id, required this.name, required this.streamUrl, this.logo, this.tags = const []});

  final String id;
  final String name;
  final String streamUrl;
  final String? logo;
  final List<String> tags;
}

class RadioParser {
  static List<RadioStation> parse(String body) {
    final seen = <String>{};
    final out = <RadioStation>[];
    for (final raw in jsonDecode(body) as List) {
      final m = raw as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').trim();
      final resolved = m['url_resolved'] as String? ?? '';
      final url = resolved.isNotEmpty ? resolved : (m['url'] as String? ?? '');
      if (name.isEmpty || !url.startsWith('http')) continue;
      // Același post apare uneori de mai multe ori; lista vine ordonată după popularitate.
      if (!seen.add(name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''))) continue;
      final fav = m['favicon'] as String? ?? '';
      out.add(
        RadioStation(
          id: m['stationuuid'] as String? ?? url,
          name: name,
          streamUrl: url,
          logo: fav.startsWith('http') ? fav : null,
          tags: (m['tags'] as String? ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .take(3)
              .toList(),
        ),
      );
    }
    return out;
  }
}

/// Posturile de radio din România, din baza publică radio-browser.info.
class RadioRepository {
  static const _servers = ['de1', 'fi1', 'at1', 'de2', 'nl1'];
  static const _path = '/json/stations/bycountrycodeexact/RO?hidebroken=true&order=clickcount&reverse=true&limit=1500';

  Future<List<RadioStation>> load({bool force = false}) async {
    final cache = File('${(await getTemporaryDirectory()).path}/radio-ro.json');
    final fresh =
        await cache.exists() && DateTime.now().difference(await cache.lastModified()) < const Duration(hours: 24);
    if (force || !fresh) {
      for (final s in _servers) {
        try {
          final resp = await http
              .get(Uri.parse('https://$s.api.radio-browser.info$_path'), headers: {'User-Agent': Repository.userAgent})
              .timeout(const Duration(seconds: 20));
          if (resp.statusCode != 200) continue;
          final body = utf8.decode(resp.bodyBytes);
          RadioParser.parse(body); // validează înainte de a scrie în cache
          await cache.writeAsString(body);
          break;
        } catch (_) {
          continue;
        }
      }
    }
    if (!await cache.exists()) throw Exception('Nu pot descărca lista de radiouri. Verifică internetul.');
    return RadioParser.parse(await cache.readAsString());
  }
}
