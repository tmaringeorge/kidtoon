import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/categories.dart';
import 'data/ghi_character.dart';
import 'data/ghi_episodes.dart';
import 'data/ghi_studio.dart';
import 'data/models.dart';
import 'data/parental.dart';
import 'data/presets.dart';
import 'data/radio.dart';
import 'data/radio_frequencies.dart';
import 'data/repository.dart';
import 'data/xmltv.dart';
import 'widgets/ghi_animation.dart' show setStudioPeople, setGhiCharacter;

/// Starea aplicației: posturi, categorii, favorite, recente, ghid TV, surse.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _favorites = (_prefs.getStringList('fav') ?? []).toSet();
    _recents = _prefs.getStringList('recent') ?? [];
    builtInEnabled = _prefs.getBool('builtin') ?? true;
    epgUrls = _prefs.getStringList('epg') ?? [];
    radioFavorites = (_prefs.getStringList('radioFav') ?? []).toSet();
    radioSort = RadioSort.values.where((s) => s.name == _prefs.getString('radioSort')).firstOrNull ?? RadioSort.popular;
    radioBackground = _bgByName(_prefs.getString('radioBg2')) ?? RadioBackground.all;
    // Cine alesese înainte „ecran negru” pornește în modul Adult.
    final storedMode = RadioMode.values.where((m) => m.name == _prefs.getString('radioMode')).firstOrNull;
    final wasBlack =
        _prefs.getString('radioBg2') == 'black' ||
        (_prefs.getString('radioBg2') == null && _prefs.getString('radioBg') == 'black');
    radioMode = storedMode ?? (wasBlack ? RadioMode.adult : RadioMode.kid);
    final raw = _prefs.getString('playlists');
    if (raw != null) {
      playlists = (jsonDecode(raw) as List).map((e) => PlaylistSource.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      // Prima pornire: lista publică de desene animate (iptv-org, categoria Copii).
      playlists = [Presets.kids];
    }
    kidsOnly = _prefs.getBool('kidsOnly') ?? true;
    hiddenChannels = (_prefs.getStringList('hidden') ?? []).toSet();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    reload();
  }

  final SharedPreferences _prefs;
  final repository = Repository();
  Timer? _clock;

  bool loading = true;
  bool epgLoading = false;

  /// Posturile pe care le vede copilul (după filtrul părinților).
  List<Channel> channels = [];

  /// Toate posturile încărcate, pentru Setări (părinții aleg ce se vede).
  List<Channel> allChannels = [];
  List<String> categories = [Categories.all];
  String selectedCategory = Categories.all;
  Epg epg = Epg.empty;
  List<String> errors = [];
  int filteredOut = 0;
  List<PlaylistSource> playlists = [];
  bool builtInEnabled = true;
  List<String> epgUrls = [];
  String query = '';

  // ---- Radio ----
  final radioRepository = RadioRepository();
  List<RadioStation> radioStations = [];
  bool radioLoading = false;
  String? radioError;
  Set<String> radioFavorites = {};
  RadioBackground radioBackground = RadioBackground.all;
  RadioSort radioSort = RadioSort.popular;
  RadioMode radioMode = RadioMode.kid;

  void setRadioMode(RadioMode mode) {
    radioMode = mode;
    _prefs.setString('radioMode', mode.name);
    notifyListeners();
  }

  void nextRadioBackground() => setRadioBackground(radioBackground.next);
  void previousRadioBackground() => setRadioBackground(radioBackground.previous);

  /// Am întrebat deja de economisirea bateriei (o singură dată).
  bool get batteryAsked => _prefs.getBool('batteryAsked') ?? false;
  set batteryAsked(bool v) => _prefs.setBool('batteryAsked', v);

  /// Episoadele cu GHI (fișier comun cu TV-ul), pornite în locul animațiilor.
  GhiBook? ghiBook;

  /// Ce vede copilul (vechiul „ghiOn” devine episoadele cu GHI).
  KidContent get kidContent =>
      KidContent.values.where((c) => c.name == _prefs.getString('kidContent')).firstOrNull ??
      ((_prefs.getBool('ghiOn') ?? false) ? KidContent.ghi : KidContent.animations);

  void setKidContent(KidContent c) {
    _prefs.setString('kidContent', c.name);
    notifyListeners();
  }

  void cycleKidContent() => setKidContent(kidContent.next);

  /// Minutele unei sesiuni înainte de pauza lungă (0 = fără limită).
  int get sessionLimit => _prefs.getInt('sessionLimit') ?? ScreenCare.defaultLimit;

  void setSessionLimit(int min) {
    _prefs.setInt('sessionLimit', min);
    notifyListeners();
  }

  int get touchScene => _prefs.getInt('touchScene') ?? 0;

  void setTouchScene(int index) {
    final n = ghiBook?.touch.length ?? 0;
    if (n == 0) return;
    _prefs.setInt('touchScene', ((index % n) + n) % n);
    notifyListeners();
  }

  void nextTouchScene() => setTouchScene(touchScene + 1);
  void previousTouchScene() => setTouchScene(touchScene - 1);

  int get ghiEpisode => _prefs.getInt('ghiEpisode') ?? 0;

  String? _ghiRaw;

  /// Personajele și episoadele create în Studio (salvate pe telefon).
  StudioLibrary studio = StudioLibrary();
  StudioStore? _studioStore;

  Future<GhiBook?> loadGhi() async {
    if (ghiBook != null) return ghiBook;
    try {
      _ghiRaw = await rootBundle.loadString('assets/ghi/episodes.json');
      try {
        final dir = await getApplicationSupportDirectory();
        _studioStore = StudioStore(File('${dir.path}/ghi_studio.json'));
        studio = await _studioStore!.load();
      } catch (_) {}
      _applyStudio();
      notifyListeners();
    } catch (_) {}
    return ghiBook;
  }

  void _applyStudio() {
    final raw = _ghiRaw;
    if (raw == null) return;
    setStudioPeople(studio.people);
    setGhiCharacter(character);
    ghiBook = studio.mergeInto(GhiBook.parse(character.personalize(raw)), character.personalize);
  }

  /// Numele lui GHI, băiat sau fată și costumașul (dinozaur, balaur, leu, ursuleț).
  GhiCharacter get character => GhiCharacter.decode(_prefs.getString('ghiCharacter'));
  set character(GhiCharacter c) {
    _prefs.setString('ghiCharacter', c.encode());
    _applyStudio();
    notifyListeners();
  }

  /// Un episod din Studio, cu numele și cuvintele potrivite, pentru previzualizare.
  GhiEpisode personalEpisode(Map<String, dynamic> ep) =>
      GhiEpisode((jsonDecode(character.personalize(jsonEncode(ep))) as Map).cast<String, dynamic>());

  /// Salvează ce s-a schimbat în Studio și pune episoadele noi în listă.
  Future<void> saveStudio() async {
    _applyStudio();
    notifyListeners();
    await _studioStore?.save(studio);
  }

  /// Poziția în listă a unui episod din Studio (după cele din aplicație).
  int? studioEpisodeIndex(String draftId) {
    final i = ghiBook?.episodes.indexWhere((e) => e.id == 'studio_$draftId') ?? -1;
    return i < 0 ? null : i;
  }

  /// Ultima adresă a TV-ului folosită la trimitere.
  String get tvAddress => _prefs.getString('ghiTvAddress') ?? '';
  set tvAddress(String v) => _prefs.setString('ghiTvAddress', v);

  void setGhiEpisode(int index) {
    final n = ghiBook?.episodes.length ?? 0;
    if (n == 0) return;
    _prefs.setInt('ghiEpisode', ((index % n) + n) % n);
    notifyListeners();
  }

  void nextGhiEpisode() => setGhiEpisode(ghiEpisode + 1);
  void previousGhiEpisode() => setGhiEpisode(ghiEpisode - 1);

  void setRadioSort(RadioSort sort) {
    radioSort = sort;
    _prefs.setString('radioSort', sort.name);
    notifyListeners();
  }

  static RadioBackground? _bgByName(String? name) => RadioBackground.values.where((b) => b.name == name).firstOrNull;

  Future<void> loadRadio({bool force = false}) async {
    if (radioLoading || (!force && radioStations.isNotEmpty)) return;
    radioLoading = true;
    radioError = null;
    notifyListeners();
    try {
      radioStations = await radioRepository.load(force: force);
    } catch (e) {
      radioError = e.toString().replaceFirst('Exception: ', '');
    }
    radioLoading = false;
    notifyListeners();
  }

  void toggleRadioFavorite(RadioStation s) {
    if (!radioFavorites.remove(s.id)) radioFavorites.add(s.id);
    _prefs.setStringList('radioFav', radioFavorites.toList());
    notifyListeners();
  }

  void setRadioBackground(RadioBackground bg) {
    radioBackground = bg;
    _prefs.setString('radioBg2', bg.name);
    notifyListeners();
  }

  Set<String> _favorites = {};
  List<String> _recents = [];
  int _loadToken = 0;

  Set<String> get favorites => _favorites;
  DateTime get now => DateTime.now();

  List<Channel> channelsIn(String category) {
    switch (category) {
      case Categories.all:
        return channels;
      case Categories.favorites:
        return channels.where((c) => _favorites.contains(c.key)).toList();
      case Categories.recent:
        return _recents.map((k) => channels.where((c) => c.key == k).firstOrNull).whereType<Channel>().toList();
      case Categories.other:
        return channels.where((c) => c.categories.isEmpty).toList();
      default:
        return channels.where((c) => c.categories.contains(category)).toList();
    }
  }

  List<Channel> get visibleChannels {
    final list = channelsIn(selectedCategory);
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  int numberOf(Channel c) => channels.indexOf(c) + 1;

  Channel? get lastChannel {
    final k = _prefs.getString('last');
    return k == null ? null : channels.where((c) => c.key == k).firstOrNull;
  }

  Future<void> reload() async {
    final token = ++_loadToken;
    loading = true;
    notifyListeners();
    final res = await repository.loadChannels(builtIn: builtInEnabled, playlists: playlists);
    if (token != _loadToken) return;
    allChannels = res.channels;
    channels = KidFilter.apply(allChannels, kidsOnly: kidsOnly, hidden: hiddenChannels);
    categories = _buildCategories(channels);
    if (!categories.contains(selectedCategory)) selectedCategory = Categories.all;
    errors = res.errors;
    filteredOut = res.filteredOut;
    loading = false;
    epgLoading = true;
    notifyListeners();
    final e = await repository.loadEpg({...epgUrls, ...res.epgUrls}.toList());
    if (token != _loadToken) return;
    epg = e;
    epgLoading = false;
    notifyListeners();
  }

  Future<void> refreshSources() async {
    await repository.clearCache();
    if (radioStations.isNotEmpty) loadRadio(force: true);
    await reload();
  }

  List<String> _buildCategories(List<Channel> list) {
    final counts = <String, int>{};
    for (final c in list) {
      for (final g in c.categories) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sorted = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      Categories.all,
      Categories.favorites,
      Categories.recent,
      ...sorted,
      if (list.any((c) => c.categories.isEmpty)) Categories.other,
    ];
  }

  void selectCategory(String c) {
    selectedCategory = c;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void toggleFavorite(Channel c) {
    if (!_favorites.remove(c.key)) _favorites.add(c.key);
    _prefs.setStringList('fav', _favorites.toList());
    notifyListeners();
  }

  void markWatched(Channel c) {
    _recents = [c.key, ..._recents.where((k) => k != c.key)].take(20).toList();
    _prefs.setStringList('recent', _recents);
    _prefs.setString('last', c.key);
    notifyListeners();
  }

  // ---- Părinți ----
  /// Doar posturi pentru copii (Copii, Educație, Familie). Pornit implicit.
  bool kidsOnly = true;

  /// Posturile ascunse de părinte, chiar dacă sunt pentru copii.
  Set<String> hiddenChannels = {};

  void _applyFilter() {
    channels = KidFilter.apply(allChannels, kidsOnly: kidsOnly, hidden: hiddenChannels);
    categories = _buildCategories(channels);
    if (!categories.contains(selectedCategory)) selectedCategory = Categories.all;
    notifyListeners();
  }

  void setKidsOnly(bool v) {
    kidsOnly = v;
    _prefs.setBool('kidsOnly', v);
    _applyFilter();
  }

  void toggleHidden(Channel c) {
    if (!hiddenChannels.remove(c.key)) hiddenChannels.add(c.key);
    _prefs.setStringList('hidden', hiddenChannels.toList());
    _applyFilter();
  }

  /// PIN-ul părinților (4 cifre) sau gol, când se folosește doar întrebarea de înmulțire.
  String get parentPin => _prefs.getString('parentPin') ?? '';
  void setParentPin(String pin) {
    if (pin.isEmpty) {
      _prefs.remove('parentPin');
    } else if (ParentPin.isValid(pin)) {
      _prefs.setString('parentPin', pin);
    }
    notifyListeners();
  }

  /// Copilul și-a ales deja prietenul (numele, costumașul) la prima pornire.
  bool get characterChosen => _prefs.getBool('characterChosen') ?? false;
  void chooseCharacter(GhiCharacter c) {
    _prefs.setBool('characterChosen', true);
    character = c;
  }

  /// Secțiunea deschisă ultima dată în meniul lateral.
  int get lastSection => _prefs.getInt('section') ?? 0;
  set lastSection(int i) => _prefs.setInt('section', i);

  // ---- Setări ----
  void _savePlaylists() => _prefs.setString('playlists', jsonEncode(playlists.map((e) => e.toJson()).toList()));

  void addPlaylist(String name, String url) {
    playlists = [...playlists.where((p) => p.url != url), PlaylistSource(name: name.isEmpty ? url : name, url: url)];
    _savePlaylists();
    reload();
  }

  void removePlaylist(PlaylistSource p) {
    playlists = playlists.where((e) => e.url != p.url).toList();
    _savePlaylists();
    reload();
  }

  void togglePlaylist(PlaylistSource p) {
    playlists = [for (final e in playlists) e.url == p.url ? e.copyWith(enabled: !e.enabled) : e];
    _savePlaylists();
    reload();
  }

  void setBuiltIn(bool v) {
    builtInEnabled = v;
    _prefs.setBool('builtin', v);
    reload();
  }

  void addEpg(String url) {
    epgUrls = {...epgUrls, url}.toList();
    _prefs.setStringList('epg', epgUrls);
    reload();
  }

  void removeEpg(String url) {
    epgUrls = epgUrls.where((e) => e != url).toList();
    _prefs.setStringList('epg', epgUrls);
    reload();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }
}
