import 'dart:convert';
import 'dart:io';

import 'ghi_episodes.dart';

/// Studio: personaje și episoade create de părinte în aplicație.
///
/// Pe telefon se păstrează „ciornele” (pașii simpli din editor), ca să poată fi modificate oricând.
/// Din ele se fac episoade în același format ca `assets/ghi/episodes.json`, iar pe TV se trimite
/// doar rezultatul: `{"people": [...], "episodes": [...]}`.

/// Un personaj nou, făcut de părinte: nume, piele, păr, haine și ce poartă pe cap.
class StudioPerson {
  StudioPerson({
    required this.id,
    required this.name,
    this.skin = '#F2C6A0',
    this.hair = '#5D4037',
    this.top = '#42A5F5',
    this.bottom = '#455A64',
    this.shoes = '#4E342E',
    this.style = 'short',
    this.dress = false,
    this.hat,
    this.beard = false,
    this.glasses = false,
  });

  factory StudioPerson.fromJson(Map<String, dynamic> j) => StudioPerson(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Prieten',
    skin: j['skin'] as String? ?? '#F2C6A0',
    hair: j['hair'] as String? ?? '#5D4037',
    top: j['top'] as String? ?? '#42A5F5',
    bottom: j['bottom'] as String? ?? '#455A64',
    shoes: j['shoes'] as String? ?? '#4E342E',
    style: j['style'] as String? ?? 'short',
    dress: j['dress'] == true,
    hat: j['hat'] as String?,
    beard: j['beard'] == true,
    glasses: j['glasses'] == true,
  );

  String id, name, skin, hair, top, bottom, shoes, style;
  bool dress, beard, glasses;
  String? hat;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'skin': skin,
    'hair': hair,
    'top': top,
    'bottom': bottom,
    'shoes': shoes,
    'style': style,
    'dress': dress,
    if (hat != null) 'hat': hat,
    'beard': beard,
    'glasses': glasses,
  };
}

/// O acțiune din editor: eticheta pe care o vede părintele și cum se joacă.
class StudioAction {
  const StudioAction(this.id, this.label, this.pose, {this.face = 'happy', this.puff});
  final String id, label, pose, face;
  final String? puff;
}

class Studio {
  static const ghiActions = [
    StudioAction('stand', 'stă', 'stand'),
    StudioAction('walk', 'merge', 'walk'),
    StudioAction('happy', 'se bucură', 'happy', puff: 'stars'),
    StudioAction('wave', 'face cu mâna', 'wave'),
    StudioAction('jump', 'sare', 'jump'),
    StudioAction('dance', 'dansează', 'dance', puff: 'notes'),
    StudioAction('sit', 'stă jos', 'sit', face: 'calm'),
    StudioAction('wow', 'se miră', 'stand', face: 'wow'),
    StudioAction('sad', 'e trist', 'stand', face: 'sad'),
    StudioAction('love', 'iubește', 'stand', puff: 'hearts'),
    StudioAction('fly', 'zboară', 'fly'),
    StudioAction('kick', 'șutează', 'kick', face: 'wow'),
    StudioAction('sleep', 'doarme', 'sleep', face: 'sleepy', puff: 'zzz'),
  ];

  static const personActions = [
    StudioAction('stand', 'stă', 'stand'),
    StudioAction('walk', 'vine', 'walk'),
    StudioAction('wave', 'face cu mâna', 'wave'),
    StudioAction('point', 'arată', 'point'),
    StudioAction('clap', 'bate din palme', 'clap'),
    StudioAction('reach', 'întinde mâna', 'reach'),
    StudioAction('hold', 'ține obiectul', 'hold'),
    StudioAction('carry', 'ridică brațele', 'carry'),
    StudioAction('sit', 'stă jos', 'sit', face: 'calm'),
    StudioAction('kick', 'șutează', 'kick'),
  ];

  /// Personajele gata făcute, cu numele lor în română.
  static const builtInPeople = {
    'mami': 'Mami',
    'tati': 'Tati',
    'bunica': 'Bunica',
    'educatoare': 'Educatoarea',
    'pompier': 'Pompierul',
    'doctor': 'Doctorița',
    'politist': 'Polițistul',
    'bucatar': 'Bucătarul',
    'constructor': 'Constructorul',
    'fermier': 'Fermierul',
    'postas': 'Poștărița',
    'pilot': 'Pilotul',
    'veterinar': 'Veterinara',
    'brutar': 'Brutăreasa',
  };

  /// Decorurile, cu nume pe înțelesul părintelui.
  static const sets = {
    'meadow': 'Pajiște',
    'park': 'Parc',
    'room': 'Cameră',
    'kitchen': 'Bucătărie',
    'bedroom': 'Dormitor',
    'bath': 'Baie',
    'kinder': 'Grădiniță',
    'party': 'Petrecere',
    'farm': 'Fermă',
    'field': 'Teren de fotbal',
    'lake': 'Lac',
    'beach': 'Plajă',
    'snow': 'Zăpadă',
    'rain': 'Ploaie',
    'night': 'Noapte cu stele',
    'garden': 'Grădină',
    'shop': 'Magazin',
    'street': 'Stradă',
    'station': 'Gară',
    'airport': 'Aeroport',
    'clinic': 'Cabinet',
    'site': 'Șantier',
    'office': 'Birou',
    'stage': 'Scenă',
    'sky': 'Cer',
  };

  static const hats = {
    null: 'Fără',
    'straw': 'Pălărie de paie',
    'chef': 'Bonetă de bucătar',
    'baker': 'Bonețică',
    'hard': 'Cască de constructor',
    'fire': 'Cască de pompier',
    'police': 'Șapcă de polițist',
    'post': 'Șapcă',
    'pilot': 'Chipiu de pilot',
  };

  static const skins = ['#F5D0B5', '#F2C6A0', '#E8B98F', '#D7A07A', '#A1785C', '#8D5524', '#5C3A21'];
  static const hairs = ['#212121', '#3E2723', '#5D4037', '#8D6E63', '#FFB74D', '#BF360C', '#CFD8DC', '#F5F5F5'];
  static const clothes = [
    '#E53935',
    '#E57399',
    '#9575CD',
    '#3F51B5',
    '#42A5F5',
    '#26A69A',
    '#66BB6A',
    '#FDD835',
    '#FB8C00',
    '#8D6E63',
    '#455A64',
    '#FAFAFA',
  ];
  static const styles = {'short': 'Păr scurt', 'long': 'Păr lung', 'bun': 'Coc'};

  /// Obiecte de pus în scenă, cu numele folosit la întrebări.
  static const things = {
    '⚽': 'mingea',
    '🎈': 'balonul',
    '🧸': 'ursulețul',
    '🍎': 'mărul',
    '🍌': 'banana',
    '🐕': 'cățelul',
    '🐈': 'pisicuța',
    '🐰': 'iepurașul',
    '🦆': 'rățușca',
    '🐄': 'văcuța',
    '🚗': 'mașina',
    '🚂': 'trenul',
    '✈️': 'avionul',
    '🚲': 'bicicleta',
    '🌞': 'soarele',
    '🌙': 'luna',
    '⭐': 'steluța',
    '🌈': 'curcubeul',
    '🌻': 'floarea',
    '🌳': 'copacul',
    '🏠': 'căsuța',
    '📖': 'cartea',
    '🎂': 'tortul',
    '🍪': 'biscuitul',
    '🥛': 'laptele',
    '🍞': 'pâinea',
    '🧁': 'brioșa',
    '🥕': 'morcovul',
    '🦋': 'fluturele',
    '🐟': 'peștișorul',
    '🎁': 'cadoul',
    '🪥': 'periuța',
    '🧼': 'săpunul',
    '🎹': 'pianul',
    '🥁': 'toba',
    '❤️': 'inimioara',
  };

  static const _distractors = ['🍎', '⭐', '🐈', '🌻', '🚗', '🐕', '🎈', '🍌', '🐰', '🌙'];

  /// Cât ține un pas: destul cât să fie citit rar textul, dar nu prea mult.
  static int stepSeconds(String say) => (6 + say.length ~/ 8).clamp(8, 16);
}

/// Un pas din editor: ce se spune, ce face GHI, cine mai e în scenă și ce obiect apare.
class StudioStep {
  StudioStep({this.say = '', this.action = 'stand', this.who, this.whoAction = 'stand', this.thing, this.ask = false});

  factory StudioStep.fromJson(Map<String, dynamic> j) => StudioStep(
    say: j['say'] as String? ?? '',
    action: j['action'] as String? ?? 'stand',
    who: j['who'] as String?,
    whoAction: j['whoAction'] as String? ?? 'stand',
    thing: j['thing'] as String?,
    ask: j['ask'] == true,
  );

  String say, action, whoAction;
  String? who, thing;

  /// „Care e mingea? Arată cu degetul!” cu obiectul acestui pas.
  bool ask;

  Map<String, dynamic> toJson() => {
    'say': say,
    'action': action,
    if (who != null) 'who': who,
    'whoAction': whoAction,
    if (thing != null) 'thing': thing,
    'ask': ask,
  };
}

/// Un episod din editor.
class StudioDraft {
  StudioDraft({required this.id, this.title = '', this.set = 'meadow', this.learn = '', List<StudioStep>? steps})
    : steps = steps ?? [];

  factory StudioDraft.fromJson(Map<String, dynamic> j) => StudioDraft(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    set: j['set'] as String? ?? 'meadow',
    learn: j['learn'] as String? ?? '',
    steps: ((j['steps'] as List?) ?? const [])
        .map((s) => StudioStep.fromJson((s as Map).cast<String, dynamic>()))
        .toList(),
  );

  String id, title, set, learn;
  final List<StudioStep> steps;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'set': set,
    'learn': learn,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  /// Episodul gata de jucat, în formatul din `episodes.json`.
  Map<String, dynamic> toEpisode() {
    final beats = <Map<String, dynamic>>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final act = Studio.ghiActions.firstWhere((a) => a.id == s.action, orElse: () => Studio.ghiActions.first);
      final pAct = Studio.personActions.firstWhere(
        (a) => a.id == s.whoAction,
        orElse: () => Studio.personActions.first,
      );
      final say = s.say.trim().isEmpty ? (act.id == 'sad' ? 'GHI e {trist|tristă}' : 'GHI ${act.label}') : s.say.trim();
      // GHI intră mergând în primul pas, apoi rămâne în același loc (fără tăieturi bruște).
      final ghi = <String, dynamic>{
        'pose': act.pose,
        'x': act.pose == 'walk' ? [0.1, 0.3] : 0.3,
        'face': act.face,
        if (act.puff != null) 'puff': act.puff,
        if (act.pose == 'fly') 'y': 0.62,
      };
      final props = <Map<String, dynamic>>[];
      final people = <Map<String, dynamic>>[];
      Map<String, dynamic>? ask;
      final thing = s.thing;
      if (s.ask && thing != null) {
        final name = Studio.things[thing] ?? 'acesta';
        final others = Studio._distractors.where((e) => e != thing).toList();
        final h = id.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) % 100003) + i * 7;
        final slot = h % 3;
        final items = [others[h % others.length], others[(h * 7 + 3) % others.length]];
        if (items[0] == items[1]) items[1] = others[(h + 1) % others.length];
        items.insert(slot, thing);
        const xs = [0.56, 0.72, 0.88];
        for (var k = 0; k < 3; k++) {
          props.add({'e': items[k], 'x': xs[k], 'y': 0.5, 's': 0.12, 'm': 'bob'});
        }
        final cap = name[0].toUpperCase() + name.substring(1);
        ask = {
          'answer': slot,
          'yes': 'Bravo! Ai găsit $name!',
          'no': 'Mai caută puțin!',
          'hint': 'Uite! $cap e aici, unde strălucește.',
        };
      } else {
        final who = s.who;
        final holds = who != null && pAct.pose == 'hold' && thing != null;
        if (who != null) {
          people.add({
            'who': who,
            'x': pAct.pose == 'walk' ? [0.95, 0.68] : 0.68,
            'pose': pAct.pose,
            'face': pAct.face,
            if (holds) 'hold': thing,
          });
        }
        if (thing != null && !holds) {
          props.add({'e': thing, 'x': who == null ? 0.62 : 0.5, 'y': 0.55, 's': 0.12, 'm': 'bob'});
        }
      }
      final sec = s.ask && ask != null ? 14 : Studio.stepSeconds(say);
      beats.add({
        'say': s.ask && ask != null && s.say.trim().isEmpty
            ? 'Care e ${Studio.things[thing] ?? 'acesta'}? Arată cu degetul!'
            : say,
        'sec': sec,
        'ghi': ghi,
        'props': props,
        if (people.isNotEmpty) 'people': people,
        'ask': ?ask,
        if (ask != null) 'cam': [1.0, 1.0],
      });
    }
    return {
      'id': 'studio_$id',
      'title': title.trim().isEmpty ? 'Episodul meu cu GHI' : title.trim(),
      'set': set,
      'learn': learn.trim().isEmpty ? 'Ne-am jucat împreună cu GHI.' : learn.trim(),
      'beats': beats,
    };
  }
}

/// Tot ce a creat părintele: personaje și episoade.
class StudioLibrary {
  StudioLibrary({List<StudioPerson>? people, List<StudioDraft>? drafts}) : people = people ?? [], drafts = drafts ?? [];

  factory StudioLibrary.fromJson(Map<String, dynamic> j) => StudioLibrary(
    people: ((j['people'] as List?) ?? const [])
        .map((p) => StudioPerson.fromJson((p as Map).cast<String, dynamic>()))
        .toList(),
    drafts: ((j['drafts'] as List?) ?? const [])
        .map((d) => StudioDraft.fromJson((d as Map).cast<String, dynamic>()))
        .toList(),
  );

  final List<StudioPerson> people;
  final List<StudioDraft> drafts;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'people': people.map((p) => p.toJson()).toList(),
    'drafts': drafts.map((d) => d.toJson()).toList(),
  };

  /// Episoadele care se pot juca (doar cele cu cel puțin un pas).
  /// [text] potrivește numele și băiat/fată (vezi GhiCharacter.personalize).
  List<GhiEpisode> episodes([String Function(String)? text]) => drafts
      .where((d) => d.steps.isNotEmpty)
      .map(
        (d) => text == null
            ? GhiEpisode(d.toEpisode())
            : GhiEpisode((jsonDecode(text(jsonEncode(d.toEpisode()))) as Map).cast<String, dynamic>()),
      )
      .toList();

  /// Ce se trimite pe TV: personajele și episoadele gata făcute (fără ciorne).
  /// [character]: cum se numește GHI și cum arată, ca TV-ul să-l arate la fel.
  String exportForTv([Map<String, dynamic>? character]) => jsonEncode({
    'version': 1,
    'character': ?character,
    'people': people.map((p) => p.toJson()).toList(),
    'episodes': drafts.where((d) => d.steps.isNotEmpty).map((d) => d.toEpisode()).toList(),
  });

  /// Un id nou, scurt și unic în bibliotecă.
  String newId(String prefix) {
    var n = DateTime.now().millisecondsSinceEpoch % 1000000;
    final used = {...people.map((p) => p.id), ...drafts.map((d) => d.id)};
    while (used.contains('$prefix$n')) {
      n++;
    }
    return '$prefix$n';
  }

  String personName(String id) =>
      Studio.builtInPeople[id] ?? people.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;

  /// Cartea completă: episoadele din aplicație, apoi cele create de părinte.
  GhiBook mergeInto(GhiBook base, [String Function(String)? text]) =>
      GhiBook(base.sets, [...base.episodes, ...episodes(text)], base.touch);
}

/// Salvarea bibliotecii într-un fișier JSON pe telefon.
class StudioStore {
  StudioStore(this.file);
  final File file;

  Future<StudioLibrary> load() async {
    try {
      if (!await file.exists()) return StudioLibrary();
      return StudioLibrary.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return StudioLibrary();
    }
  }

  Future<void> save(StudioLibrary lib) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(lib.toJson()));
    await tmp.rename(file.path);
  }
}

/// Trimiterea pe TV, prin Wi-Fi-ul de acasă: TV-ul arată adresa și un cod de 4 cifre.
class StudioSender {
  static const port = 8765;

  static Uri uri(String address) {
    final a = address.trim();
    final host = a.contains(':') ? a.split(':').first : a;
    final p = a.contains(':') ? int.tryParse(a.split(':').last) ?? port : port;
    return Uri(scheme: 'http', host: host, port: p, path: '/ghi');
  }

  /// Trimite episoadele; întoarce câte a primit TV-ul sau aruncă o eroare cu mesaj pe înțeles.
  static Future<int> send(String address, String code, String body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.postUrl(uri(address));
      req.headers.set('X-Ghi-Code', code.trim());
      req.headers.contentType = ContentType.json;
      final bytes = utf8.encode(body);
      // Lungimea exactă: TV-ul nu primește trimiteri „pe bucăți”.
      req.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 10));
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == 403) throw const StudioSendError('Codul nu e bun. Uită-te din nou pe TV.');
      if (res.statusCode != 200) throw StudioSendError('TV-ul a răspuns cu eroarea ${res.statusCode}.');
      return int.tryParse(text.trim()) ?? 0;
    } on SocketException {
      throw const StudioSendError(
        'Nu găsesc TV-ul. Telefonul și TV-ul trebuie să fie pe același Wi-Fi, iar pe TV să fie deschis ecranul „Primește de pe telefon”.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class StudioSendError implements Exception {
  const StudioSendError(this.message);
  final String message;
  @override
  String toString() => message;
}
