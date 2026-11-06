import 'radio.dart';

/// Frecvențele FM din București pentru posturile mari (sursa: Wikipedia, „Media in Bucharest”).
/// radio-browser.info nu are frecvența, iar posturile naționale emit pe alte frecvențe în alte orașe.
class RadioFrequencies {
  static const _bucharest = {
    'trinitas': 88.5,
    'zu': 89.0,
    'dancefm': 89.5,
    'magicfm': 90.8,
    'nationalfm': 91.7,
    'vibefm': 92.1,
    'urbanfm': 92.7,
    'rfi': 93.5,
    'voceaevangheliei': 94.2,
    'guerrilla': 94.8,
    'kissfm': 96.1,
    'goldfm': 96.9,
    'digifm': 97.9,
    'virginradio': 100.2,
    'rockfm': 100.6,
    'romaniacultural': 101.3,
    'romanticfm': 101.9,
    'profm': 102.8,
    'seven': 103.4,
    'digi24fm': 103.8,
    'romaniamuzical': 104.8,
    'romaniaactualitati': 105.3,
    'sporttotalfm': 105.8,
    '3fm': 106.2,
    'europafm': 106.7,
  };

  static const _diacritics = {
    'ă': 'a',
    'â': 'a',
    'î': 'i',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
    'é': 'e',
    'ö': 'o',
    'ü': 'u',
  };

  static String fold(String s) => s.toLowerCase().split('').map((c) => _diacritics[c] ?? c).join();

  /// Cheia unui nume: fără diacritice, spații, „Radio” în față, „România/București” sau frecvența la coadă.
  static String key(String name) {
    var k = fold(name).replaceAll(RegExp('[^a-z0-9]'), '');
    for (var i = 0; i < 2; i++) {
      for (final suffix in ['bucuresti', 'romania', 'live']) {
        if (k.endsWith(suffix)) k = k.substring(0, k.length - suffix.length);
      }
      k = k.replaceAll(RegExp(r'\d{3,4}$'), '');
    }
    if (k.startsWith('radio')) k = k.substring(5);
    return k;
  }

  /// Frecvența în București (MHz) sau null dacă postul nu e în listă.
  static double? bucharest(String name) => _bucharest[key(name)];

  static String label(double mhz) => '${mhz.toStringAsFixed(1)} FM';
}

/// Ordinea listei de radiouri.
enum RadioSort {
  popular('Populare'),
  alpha('A–Z'),
  frequency('Frecvență');

  const RadioSort(this.label);
  final String label;

  // Alfabetul românesc: ă după a, â după ă, î după i, ș după s, ț după t.
  static String _collate(String s) => s
      .toLowerCase()
      .split('')
      .map(
        (c) => switch (c) {
          'ă' => 'a{',
          'â' => 'a|',
          'î' => 'i{',
          'ș' || 'ş' => 's{',
          'ț' || 'ţ' => 't{',
          _ => c,
        },
      )
      .join();

  List<RadioStation> apply(List<RadioStation> list) {
    switch (this) {
      case RadioSort.popular:
        return list; // vine deja ordonată după popularitate
      case RadioSort.alpha:
        return [...list]..sort((a, b) => _collate(a.name.trim()).compareTo(_collate(b.name.trim())));
      case RadioSort.frequency:
        return [...list]..sort((a, b) {
          final fa = RadioFrequencies.bucharest(a.name) ?? double.infinity;
          final fb = RadioFrequencies.bucharest(b.name) ?? double.infinity;
          final c = fa.compareTo(fb);
          return c != 0 ? c : _collate(a.name).compareTo(_collate(b.name));
        });
    }
  }
}
