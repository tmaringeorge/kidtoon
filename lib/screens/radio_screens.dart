import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../data/battery.dart';
import '../data/ghi_episodes.dart';
import 'welcome_screen.dart';
import 'ghi_studio_screen.dart';
import 'parent_gate.dart';
import '../widgets/kid_tile.dart' show Remote;
import '../data/radio.dart';
import '../data/radio_audio.dart';
import '../data/radio_frequencies.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart';
import '../widgets/ghi_touch.dart';
import '../widgets/kids_animation.dart';
import '../widgets/kids_timeline.dart';

class RadioLogo extends StatelessWidget {
  const RadioLogo(this.station, {super.key, this.size = 48});
  final RadioStation station;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        station.name.characters.take(2).toString().toUpperCase(),
        style: TextStyle(color: KidColors.textDim, fontWeight: FontWeight.w900, fontSize: size * 0.32),
      ),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: KidColors.logoBox, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(5),
      child: station.logo == null
          ? fallback
          : Image.network(station.logo!, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key, required this.state, this.embedded = false});
  final AppState state;

  /// În meniul principal (secțiunea Radio), fără buton Înapoi.
  final bool embedded;

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  String _query = '';
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    widget.state.loadRadio();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        var list = state.radioStations;
        if (_favoritesOnly) list = list.where((s) => state.radioFavorites.contains(s.id)).toList();
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
        }
        list = state.radioSort.apply(list);
        final safe = MediaQuery.paddingOf(context);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !widget.embedded,
            title: const Text('🎵 Radio cu animații', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              if (state.radioLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              PopupMenuButton<RadioSort>(
                tooltip: 'Ordonează',
                icon: const Icon(Icons.sort),
                initialValue: state.radioSort,
                onSelected: state.setRadioSort,
                itemBuilder: (_) => [
                  for (final s in RadioSort.values)
                    CheckedPopupMenuItem(value: s, checked: s == state.radioSort, child: Text(s.label)),
                ],
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => state.loadRadio(force: true)),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(104),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Caută un radio',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: KidColors.card,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Toate'),
                          selected: !_favoritesOnly,
                          onSelected: (_) => setState(() => _favoritesOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Favorite'),
                          selected: _favoritesOnly,
                          onSelected: (_) => setState(() => _favoritesOnly = true),
                        ),
                        const Spacer(),
                        Text('${list.length} posturi', style: const TextStyle(color: KidColors.textDim)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: () {
            if (state.radioLoading && state.radioStations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.radioError != null && state.radioStations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.radioError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KidColors.textDim),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => state.loadRadio(force: true), child: const Text('Încearcă din nou')),
                  ],
                ),
              );
            }
            if (list.isEmpty) {
              return Center(
                child: Text(
                  _favoritesOnly
                      ? 'Nu ai radiouri favorite.\nȚine apăsat pe un post ca să-l adaugi.'
                      : 'Nu am găsit posturi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KidColors.textDim),
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(12 + safe.left, 4, 12 + safe.right, 24 + safe.bottom),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final s = list[i];
                final fav = state.radioFavorites.contains(s.id);
                return Material(
                  color: KidColors.card,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: RadioLogo(s),
                    title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: () {
                      final freq = RadioFrequencies.bucharest(s.name);
                      final parts = [if (freq != null) RadioFrequencies.label(freq), ...s.tags];
                      return parts.isEmpty
                          ? null
                          : Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis);
                    }(),
                    trailing: fav ? const Icon(Icons.star, color: KidColors.accent) : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RadioPlayerScreen(state: state, list: list, index: i),
                      ),
                    ),
                    onLongPress: () => state.toggleRadioFavorite(s),
                  ),
                );
              },
            );
          }(),
        );
      },
    );
  }
}

class RadioPlayerScreen extends StatefulWidget {
  const RadioPlayerScreen({super.key, required this.state, required this.list, required this.index});
  final AppState state;
  final List<RadioStation> list;
  final int index;

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  late int _index = widget.index;
  final _audio = RadioAudio.instance;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<PlaybackEvent>? _errSub;
  bool _loading = true;
  bool _playing = false;
  bool _panelOpen = true;
  // Pe TV: poveștile și „Atinge și învață” primesc tastele (întrebări, alegerea lucrurilor).
  final _contentFocus = FocusNode();
  String _focusedMode = '';
  String? _error;

  // Ecran sănătos: timpul petrecut în modul Copil (pauză de clipit, odihnă după limită).
  final _active = ValueNotifier<int>(0);
  int _episodesInRow = 0;
  Timer? _careTick;
  final _tts = FlutterTts();
  Timer? _duck;

  RadioStation get _station => widget.list[_index];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _stateSub = _audio.player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() {
        _playing = st.playing;
        _loading = st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering;
        if (st.processingState == ProcessingState.ready) _error = null;
      });
    });
    _errSub = _audio.player.playbackEventStream.listen(
      (_) {},
      onError: (Object _) {
        if (mounted) setState(() => _fail());
      },
    );
    _open();
    _maybeAskBattery();
    widget.state.loadGhi();
    _careTick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final st = widget.state;
      if (st.radioMode != RadioMode.kid) return;
      if (ScreenCare.state(_active.value, st.sessionLimit, _episodesInRow).kind == CareKind.rest) return;
      _active.value += 100;
    });
    _tts
      ..setLanguage('ro-RO')
      ..setSpeechRate(0.45);
  }

  void _unlock() {
    _episodesInRow = 0;
    _active.value = 0;
    setState(() {});
  }

  /// GHI spune ce a atins copilul; radioul se aude mai încet cât vorbește.
  void _say(String text) {
    _tts.speak(text);
    _audio.player.setVolume(0.25);
    _duck?.cancel();
    // Cât durează să spună textul, cu o mică rezervă.
    _duck = Timer(Duration(milliseconds: 1200 + text.length * 75), () => _audio.player.setVolume(1));
  }

  Future<void> _pickTouchScene() async {
    final state = widget.state;
    final book = state.ghiBook;
    if (book == null) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('👆 Atinge și învață', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (var i = 0; i < book.touch.length; i++)
              ListTile(
                leading: Text(book.touch[i].items.first.emoji, style: const TextStyle(fontSize: 26)),
                title: Text(book.touch[i].title),
                trailing: i == state.touchScene ? const Icon(Icons.check, color: KidColors.accent) : null,
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) state.setTouchScene(picked);
  }

  /// O singură dată: cerem scutire de la economisirea bateriei, ca radioul să nu fie oprit cu ecranul stins.
  Future<void> _maybeAskBattery() async {
    final state = widget.state;
    if (state.batteryAsked || await Battery.isUnrestricted() || !mounted) return;
    state.batteryAsked = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radio cu ecranul stins'),
        content: const Text(
          'Ca telefonul să nu oprească radioul când e blocat, permite KidToon să ruleze fără restricții de baterie.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mai târziu')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Permite')),
        ],
      ),
    );
    if (ok == true) await Battery.requestUnrestricted();
  }

  void _fail() {
    _loading = false;
    _error = 'Postul nu răspunde acum. Încearcă altul.';
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _audio.play(_station);
    } catch (_) {
      if (mounted) setState(_fail);
    }
  }

  void _zap(int d) {
    setState(() => _index = (_index + d + widget.list.length) % widget.list.length);
    _open();
  }

  Future<void> _pickSleep() async {
    final current = _audio.sleepLeft.value;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Oprește radioul după…', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final m in SleepTimer.options)
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m de minute'),
                onTap: () => Navigator.pop(context, m),
              ),
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: Text(current > 0 ? 'Anulează temporizatorul' : 'Fără oprire'),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    );
    if (picked != null) _audio.setSleep(picked);
  }

  Future<void> _pickBackground() async {
    final state = widget.state;
    final picked = await showModalBottomSheet<RadioBackground>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Ce se vede pe ecran', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final bg in RadioBackground.values)
                ListTile(
                  leading: Icon(
                    bg == state.radioBackground ? Icons.check_circle : Icons.circle_outlined,
                    color: bg == state.radioBackground ? KidColors.accent : null,
                  ),
                  title: Text(bg.label),
                  onTap: () => Navigator.pop(context, bg),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) state.setRadioBackground(picked);
  }

  Future<void> _pickEpisode() async {
    final state = widget.state;
    final book = state.ghiBook;
    if (book == null) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  '🎬 Episoade cu ${state.character.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(child: Text('🐉')),
                title: Text('Personajul: ${state.character.name}'),
                subtitle: const Text('Numele, băiat sau fată, dinozaur, balaur, leu sau ursuleț'),
                onTap: () => Navigator.pop(context, -2),
              ),
              ListTile(
                leading: const CircleAvatar(child: Text('🎨')),
                title: const Text('Studio: fă episoade și personaje'),
                subtitle: const Text('Pentru părinți: creezi, salvezi și trimiți pe TV'),
                onTap: () => Navigator.pop(context, -1),
              ),
              for (var i = 0; i < book.episodes.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i == state.ghiEpisode ? KidColors.accent : null,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(book.episodes[i].title),
                  subtitle: Text(book.episodes[i].learn, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == -2) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => WelcomeScreen(state: state, editing: true)));
      return;
    }
    if (picked == -1) {
      if (!mounted) return;
      // Studio e pentru părinți.
      await ParentGate.push(context, state, (_) => GhiStudioScreen(state: state));
      return;
    }
    if (picked != null) state.setGhiEpisode(picked);
  }

  @override
  void dispose() {
    _careTick?.cancel();
    _contentFocus.dispose();
    _duck?.cancel();
    _tts.stop();
    _active.dispose();
    _audio.player.setVolume(1);
    _stateSub?.cancel();
    _errSub?.cancel();
    // Ieșirea din ecranul radio oprește radioul; ecranul stins sau altă aplicație nu.
    _audio.stop();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: Listenable.merge([state, _audio.sleepLeft, _audio.nowPlaying]),
      builder: (context, _) {
        final s = _station;
        final fav = state.radioFavorites.contains(s.id);
        final kid = state.radioMode == RadioMode.kid;
        final book = state.ghiBook;
        final content = kid && book != null ? state.kidContent : KidContent.animations;
        final ghi = content == KidContent.ghi && book!.episodes.isNotEmpty;
        final touch = content == KidContent.touch && book!.touch.isNotEmpty;
        final mode = ghi ? 'ghi' : (touch ? 'touch' : '');
        if (mode != _focusedMode) {
          _focusedMode = mode;
          if (mode.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _contentFocus.context != null) _contentFocus.requestFocus();
            });
          }
        }
        final touchIndex = book == null || book.touch.isEmpty ? 0 : state.touchScene.clamp(0, book.touch.length - 1);
        final ghiIndex = book == null ? 0 : state.ghiEpisode.clamp(0, book.episodes.length - 1);
        final sleep = _audio.sleepLeft.value;
        final nowPlaying = _audio.nowPlaying.value;
        final freq = RadioFrequencies.bucharest(s.name);
        final status =
            _error ??
            (_loading ? 'Se conectează…' : (s.tags.isEmpty ? 'În direct' : s.tags.join(' · '))) +
                (sleep > 0 ? '  ·  se oprește în $sleep min' : '');
        return Scaffold(
          backgroundColor: Colors.black,
          // Telecomanda: ◀ ▶ schimbă animația (poveștile și scenele au tastele lor), OK ascunde/arată panoul.
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, e) {
              if (!Remote.isDown(e)) return KeyEventResult.ignored;
              final k = e.logicalKey;
              if (k == LogicalKeyboardKey.channelUp) {
                _zap(-1);
              } else if (k == LogicalKeyboardKey.channelDown) {
                _zap(1);
              } else if (k == LogicalKeyboardKey.mediaPlayPause) {
                _playing ? _audio.player.pause() : _audio.player.play();
              } else if (!kid) {
                return KeyEventResult.ignored;
              } else if (k == LogicalKeyboardKey.arrowRight) {
                ghi ? state.nextGhiEpisode() : (touch ? state.nextTouchScene() : state.nextRadioBackground());
              } else if (k == LogicalKeyboardKey.arrowLeft) {
                ghi
                    ? state.previousGhiEpisode()
                    : (touch ? state.previousTouchScene() : state.previousRadioBackground());
              } else if (Remote.isOk(k) && node.hasPrimaryFocus) {
                setState(() => _panelOpen = !_panelOpen);
              } else {
                return KeyEventResult.ignored;
              }
              return KeyEventResult.handled;
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ce vede copilul, cu pauzele de clipit și odihna peste el.
                ValueListenableBuilder<int>(
                  valueListenable: _active,
                  builder: (context, activeMs, _) {
                    final care = kid
                        ? ScreenCare.state(activeMs, state.sessionLimit, _episodesInRow)
                        : const CareState(CareKind.play);
                    final now = DateTime.now();
                    final evening = ScreenCare.eveningDim(now.hour, now.minute);
                    final Widget body;
                    if (!kid) {
                      body = _AdultView(
                        station: s,
                        nowPlaying: nowPlaying,
                        status: status,
                        playing: _playing && !_loading,
                      );
                    } else if (care.kind == CareKind.rest) {
                      body = GhiRest(onUnlock: _unlock, name: state.character.name);
                    } else if (ghi) {
                      // Episoadele cu GHI: glisarea sau săgețile trec la alt episod.
                      body = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) state.nextGhiEpisode();
                          if (v > 200) state.previousGhiEpisode();
                        },
                        child: GhiAnimation(
                          focusNode: _contentFocus,
                          onNext: state.nextGhiEpisode,
                          onPrevious: state.previousGhiEpisode,
                          book: book,
                          index: ghiIndex,
                          onFinished: () {
                            _episodesInRow++;
                            state.nextGhiEpisode();
                          },
                          onSay: _say,
                        ),
                      );
                    } else if (touch) {
                      // Atinge și învață: glisarea schimbă scena.
                      body = GestureDetector(
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) state.nextTouchScene();
                          if (v > 200) state.previousTouchScene();
                        },
                        child: GhiTouch(
                          focusNode: _contentFocus,
                          onNextScene: state.nextTouchScene,
                          onPreviousScene: state.previousTouchScene,
                          book: book,
                          scene: book.touch[touchIndex],
                          onTap: (i) => _say(book.touch[touchIndex].items[i].say),
                        ),
                      );
                    } else {
                      // Copilul schimbă animația glisând sau cu săgețile mari de pe margini.
                      body = GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -200) state.nextRadioBackground();
                          if (v > 200) state.previousRadioBackground();
                        },
                        child: KidsAnimation(mode: state.radioBackground),
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        body,
                        if (care.kind == CareKind.blink) GhiBlinkOverlay(ms: care.ms),
                        // Seara, ecranul devine mai cald și mai întunecat.
                        if (evening > 0)
                          IgnorePointer(
                            child: ColoredBox(color: const Color(0xFF2A1400).withValues(alpha: evening)),
                          ),
                      ],
                    );
                  },
                ),
                if (kid) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BigArrow(
                      icon: Icons.chevron_left,
                      onTap: ghi
                          ? state.previousGhiEpisode
                          : touch
                          ? state.previousTouchScene
                          : state.previousRadioBackground,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _BigArrow(
                      icon: Icons.chevron_right,
                      onTap: ghi
                          ? state.nextGhiEpisode
                          : touch
                          ? state.nextTouchScene
                          : state.nextRadioBackground,
                    ),
                  ),
                ],
                SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          // Copil / Adult, direct din radio.
                          IconButton(
                            tooltip: kid ? 'Mod Adult' : 'Mod Copil',
                            // Modul Adult doar cu poarta părinților; înapoi la Copil oricând.
                            onPressed: () async {
                              if (kid && !await ParentGate.open(context, state)) return;
                              state.setRadioMode(state.radioMode.toggled);
                            },
                            icon: Icon(kid ? Icons.person_outline : Icons.child_care, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Oprire automată',
                            onPressed: _pickSleep,
                            icon: Icon(sleep > 0 ? Icons.bedtime : Icons.bedtime_outlined, color: Colors.white),
                          ),
                          if (kid && book != null)
                            // Butonul cu film: pornește / oprește episoadele cu GHI.
                            IconButton(
                              tooltip: ghi ? 'Înapoi la animații' : 'Povești cu ${state.character.name}',
                              onPressed: () => state.setKidContent(ghi ? KidContent.animations : KidContent.ghi),
                              style: ghi ? IconButton.styleFrom(backgroundColor: KidColors.accent) : null,
                              icon: Icon(Icons.movie, color: ghi ? Colors.black : Colors.white),
                            ),
                          if (kid && book != null)
                            // Atinge și învață: copilul atinge și GHI îi spune ce este.
                            IconButton(
                              tooltip: touch ? 'Înapoi la animații' : 'Atinge și învață',
                              onPressed: () => state.setKidContent(touch ? KidContent.animations : KidContent.touch),
                              style: touch ? IconButton.styleFrom(backgroundColor: KidColors.accent) : null,
                              icon: Icon(Icons.touch_app, color: touch ? Colors.black : Colors.white),
                            ),
                          if (kid)
                            IconButton(
                              tooltip: ghi
                                  ? 'Alege episodul'
                                  : touch
                                  ? 'Alege scena'
                                  : 'Alege animația',
                              onPressed: ghi
                                  ? _pickEpisode
                                  : touch
                                  ? _pickTouchScene
                                  : _pickBackground,
                              icon: Icon(
                                ghi || touch ? Icons.video_library_outlined : Icons.palette_outlined,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Panoul radioului se ascunde cu un buton și reapare din același loc.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _panelOpen
                            ? Container(
                                key: const ValueKey('open'),
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                                decoration: BoxDecoration(
                                  color: const Color(0x99000000),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ghi
                                                ? '🎬 Episodul ${ghiIndex + 1}: ${book.episodes[ghiIndex].title}'
                                                : touch
                                                ? '👆 ${book.touch[touchIndex].title}'
                                                : kid
                                                ? 'Animație: ${state.radioBackground.label}'
                                                : 'Mod Adult',
                                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Ascunde radioul',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => setState(() => _panelOpen = false),
                                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        RadioLogo(s, size: 56),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                [s.name, if (freq != null) RadioFrequencies.label(freq)].join('  ·  '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (nowPlaying != null)
                                                Text(
                                                  '♪ $nowPlaying',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: KidColors.accent,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              Text(status, style: const TextStyle(color: Color(0xDDFFFFFF))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                                          onPressed: () => _zap(-1),
                                        ),
                                        IconButton.filled(
                                          iconSize: 36,
                                          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                                          onPressed: () => _playing ? _audio.player.pause() : _audio.player.play(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                                          onPressed: () => _zap(1),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            fav ? Icons.star : Icons.star_border,
                                            color: fav ? KidColors.accent : Colors.white,
                                            size: 30,
                                          ),
                                          onPressed: () => state.toggleRadioFavorite(s),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                key: const ValueKey('closed'),
                                padding: const EdgeInsets.only(bottom: 16),
                                child: FilledButton.tonalIcon(
                                  onPressed: () => setState(() => _panelOpen = true),
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                  label: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Săgeată mare, ușor de apăsat de un copil mic.
class _BigArrow extends StatelessWidget {
  const _BigArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: const Color(0x44000000),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 56),
          ),
        ),
      ),
    );
  }
}

/// Modul Adult: ecran liniștit, cu postul, frecvența și ce cântă acum.
class _AdultView extends StatefulWidget {
  const _AdultView({required this.station, required this.nowPlaying, required this.status, required this.playing});
  final RadioStation station;
  final String? nowPlaying;
  final String status;
  final bool playing;

  @override
  State<_AdultView> createState() => _AdultViewState();
}

class _AdultViewState extends State<_AdultView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final freq = RadioFrequencies.bucharest(s.name);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141A2E), Color(0xFF0B0F1A)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 220),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RadioLogo(s, size: 160),
              const SizedBox(height: 24),
              Text(
                s.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              if (freq != null)
                Text(RadioFrequencies.label(freq), style: const TextStyle(color: KidColors.textDim, fontSize: 18)),
              const SizedBox(height: 16),
              Text(
                widget.nowPlaying != null ? '♪ ${widget.nowPlaying}' : widget.status,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.nowPlaying != null ? KidColors.accent : KidColors.textDim,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 12; i++)
                      Container(
                        width: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height:
                            36 *
                            (widget.playing
                                ? 0.25 + 0.75 * (sin(_c.value * 2 * pi * (1.3 + i * 0.37) + i)).abs()
                                : 0.15),
                        decoration: BoxDecoration(
                          color: KidColors.accent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
