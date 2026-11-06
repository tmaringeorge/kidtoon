import 'dart:convert';

/// Cum e GHI pentru copilul vostru: numele, băiat sau fată și ce costumaș poartă.
/// Poveștile au „GHI”, {băiat|fată} și {dragonul}; aici se aleg cuvintele potrivite.
class GhiCharacter {
  const GhiCharacter({this.name = 'GHI', this.girl = false, this.avatar = 'dragon'});

  factory GhiCharacter.fromJson(Map<String, dynamic> j) => GhiCharacter(
    name: clean(j['name'] as String? ?? 'GHI'),
    girl: j['girl'] == true,
    avatar: avatars.containsKey(j['avatar']) ? j['avatar'] as String : 'dragon',
  );

  static GhiCharacter decode(String? s) {
    if (s == null || s.isEmpty) return const GhiCharacter();
    try {
      return GhiCharacter.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const GhiCharacter();
    }
  }

  final String name;
  final bool girl;

  /// dragon, balaur, leu sau urs.
  final String avatar;

  static const avatars = {
    'dragon': 'Dinozaurul verde (ca acum)',
    'balaur': 'Balaurul cu 7 capete',
    'leu': 'Leul',
    'urs': 'Ursulețul',
  };

  /// Cum se spune animalul în povești: „un …”, „…-ul” și la plural, pentru băiat și pentru fată.
  static const _nouns = {
    'dragon': (['un dragon', 'dragonul', 'Dragonii'], ['o dragoniță', 'dragonița', 'Dragonițele']),
    'balaur': (['un balaur', 'balaurul', 'Balaurii'], ['o bălăuriță', 'bălăurița', 'Bălăurițele']),
    'leu': (['un leu', 'leul', 'Leii'], ['o leoaică', 'leoaica', 'Leoaicele']),
    'urs': (['un ursuleț', 'ursulețul', 'Urșii'], ['o ursuliță', 'ursulița', 'Ursulițele']),
  };

  Map<String, dynamic> toJson() => {'name': name, 'girl': girl, 'avatar': avatar};
  String encode() => jsonEncode(toJson());

  GhiCharacter copyWith({String? name, bool? girl, String? avatar}) =>
      GhiCharacter(name: clean(name ?? this.name), girl: girl ?? this.girl, avatar: avatar ?? this.avatar);

  bool get isDefault => name == 'GHI' && !girl && avatar == 'dragon';

  /// Un nume scurt, fără semne care ar strica fișierul poveștilor.
  static String clean(String s) {
    final t = s.replaceAll(RegExp(r'["\\{}|<>]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return 'GHI';
    return t.length > 16 ? t.substring(0, 16).trim() : t;
  }

  static final _pair = RegExp(r'\{([^{}|"\\]*)\|([^{}|"\\]*)\}');
  static final _noun = RegExp(r'\{(un_dragon|dragonul|Dragonii)\}');

  /// Textul poveștii (sau tot fișierul JSON) cu numele, băiat/fată și animalul alese.
  String personalize(String text) {
    final n = (_nouns[avatar] ?? _nouns['dragon']!);
    final words = girl ? n.$2 : n.$1;
    return text
        .replaceAllMapped(_pair, (m) => girl ? m[2]! : m[1]!)
        .replaceAllMapped(
          _noun,
          (m) => switch (m[1]) {
            'un_dragon' => words[0],
            'dragonul' => words[1],
            _ => words[2],
          },
        )
        .replaceAll('GHI', name);
  }
}
