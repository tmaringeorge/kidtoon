import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart';
import '../widgets/ghi_touch.dart';
import '../widgets/kid_tile.dart';
import '../widgets/screen_care.dart';
import 'welcome_screen.dart';

const _tileColors = [
  KidColors.pink,
  KidColors.purple,
  KidColors.orange,
  KidColors.green,
  KidColors.blue,
  KidColors.teal,
  KidColors.red,
];

/// Titlul mare al unei secțiuni.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 16,
      20 + MediaQuery.paddingOf(context).right,
      8,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        ),
        ?trailing,
      ],
    ),
  );
}

int _cols(double w) => w > 1100 ? 4 : (w > 620 ? 3 : 2);

/// Lista poveștilor (episoadele din aplicație și cele făcute de părinți în Studio).
class StoriesSection extends StatelessWidget {
  const StoriesSection({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final book = state.ghiBook;
        if (book == null) return const Center(child: CircularProgressIndicator());
        final name = state.character.name;
        return LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SectionTitle(
                  '🎬 Povești cu $name',
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WelcomeScreen(state: state, editing: true)),
                    ),
                    icon: const Icon(Icons.face_rounded),
                    label: const Text('Prietenul meu'),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16 + MediaQuery.paddingOf(context).right,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cols(box.maxWidth),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: book.episodes.length,
                  itemBuilder: (context, i) {
                    final ep = book.episodes[i];
                    return KidTile(
                      color: _tileColors[i % _tileColors.length],
                      title: ep.title,
                      subtitle: ep.learn,
                      autofocus: i == state.ghiEpisode.clamp(0, book.episodes.length - 1),
                      selected: i == state.ghiEpisode,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryPlayerScreen(state: state, index: i),
                        ),
                      ),
                      child: _EpisodeCard(
                        number: i + 1,
                        title: ep.title,
                        learn: ep.learn,
                        studio: ep.id.startsWith('studio_'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.number, required this.title, required this.learn, required this.studio});
  final int number;
  final String title;
  final String learn;
  final bool studio;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0x44FFFFFF),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
            const Spacer(),
            Text(studio ? '🎨' : '🎬', style: const TextStyle(fontSize: 26)),
          ],
        ),
        const Spacer(),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          '⭐ $learn',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
        ),
      ],
    ),
  );
}

/// Scenele din „Atinge și învață”.
class TouchSection extends StatelessWidget {
  const TouchSection({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final book = state.ghiBook;
        if (book == null) return const Center(child: CircularProgressIndicator());
        return LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SectionTitle('👆 Atinge și învață')),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16 + MediaQuery.paddingOf(context).right,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cols(box.maxWidth),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: book.touch.length,
                  itemBuilder: (context, i) {
                    final scene = book.touch[i];
                    return KidTile(
                      color: _tileColors[(i + 2) % _tileColors.length],
                      emoji: scene.items.take(3).map((e) => e.emoji).join(),
                      title: scene.title,
                      autofocus: i == 0,
                      onTap: () {
                        state.setTouchScene(i);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TouchPlayScreen(state: state)));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Vocea în română care povestește și spune ce a atins copilul.
class KidVoice {
  KidVoice() {
    _tts
      ..setLanguage('ro-RO')
      ..setSpeechRate(0.45);
  }
  final _tts = FlutterTts();
  void say(String text) => _tts.speak(text);
  void stop() => _tts.stop();
}

/// Mod pe tot ecranul, fără bare de sistem, cu ecranul mereu aprins.
mixin _FullScreen<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}

/// O poveste pe tot ecranul. ◀ ▶ (sau glisare, sau săgețile mari) schimbă povestea;
/// la întrebări copilul atinge răspunsul (pe TV: ◀ ▶ și OK). Fără radio: doar vocea povestește.
class StoryPlayerScreen extends StatefulWidget {
  const StoryPlayerScreen({super.key, required this.state, required this.index});
  final AppState state;
  final int index;

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen> with _FullScreen {
  late final _care = CareController(widget.state);
  final _voice = KidVoice();

  @override
  void initState() {
    super.initState();
    widget.state.setGhiEpisode(widget.index);
  }

  @override
  void dispose() {
    _voice.stop();
    _care.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final book = state.ghiBook;
          if (book == null || book.episodes.isEmpty) return const Center(child: CircularProgressIndicator());
          final i = state.ghiEpisode.clamp(0, book.episodes.length - 1);
          return Stack(
            fit: StackFit.expand,
            children: [
              CareView(
                controller: _care,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -200) state.nextGhiEpisode();
                    if (v > 200) state.previousGhiEpisode();
                  },
                  child: GhiAnimation(
                    book: book,
                    index: i,
                    autofocus: true,
                    onFinished: () {
                      _care.episodeDone();
                      state.nextGhiEpisode();
                    },
                    onNext: state.nextGhiEpisode,
                    onPrevious: state.previousGhiEpisode,
                    onSay: _voice.say,
                  ),
                ),
              ),
              _Controls(onPrevious: state.previousGhiEpisode, onNext: state.nextGhiEpisode),
            ],
          );
        },
      ),
    );
  }
}

/// „Atinge și învață” pe tot ecranul: copilul atinge (pe TV alege cu săgețile și OK)
/// și vocea spune ce este. ◀ după primul lucru / ▶ după ultimul schimbă scena.
class TouchPlayScreen extends StatefulWidget {
  const TouchPlayScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TouchPlayScreen> createState() => _TouchPlayScreenState();
}

class _TouchPlayScreenState extends State<TouchPlayScreen> with _FullScreen {
  late final _care = CareController(widget.state);
  final _voice = KidVoice();

  @override
  void dispose() {
    _voice.stop();
    _care.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final book = state.ghiBook;
          if (book == null || book.touch.isEmpty) return const Center(child: CircularProgressIndicator());
          final scene = book.touch[state.touchScene.clamp(0, book.touch.length - 1)];
          return Stack(
            fit: StackFit.expand,
            children: [
              CareView(
                controller: _care,
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -200) state.nextTouchScene();
                    if (v > 200) state.previousTouchScene();
                  },
                  child: GhiTouch(
                    book: book,
                    scene: scene,
                    autofocus: true,
                    onTap: (i) => _voice.say(scene.items[i].say),
                    onNextScene: state.nextTouchScene,
                    onPreviousScene: state.previousTouchScene,
                  ),
                ),
              ),
              _Controls(onPrevious: state.previousTouchScene, onNext: state.nextTouchScene),
            ],
          );
        },
      ),
    );
  }
}

/// Butonul Înapoi și săgețile mari de pe margini (doar pentru atingere; pe TV se folosesc ◀ ▶).
class _Controls extends StatelessWidget {
  const _Controls({required this.onPrevious, required this.onNext});
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, VoidCallback onTap) => ExcludeFocus(
      child: Padding(
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
      ),
    );
    return Stack(
      children: [
        Align(alignment: Alignment.centerLeft, child: arrow(Icons.chevron_left, onPrevious)),
        Align(alignment: Alignment.centerRight, child: arrow(Icons.chevron_right, onNext)),
        SafeArea(
          child: ExcludeFocus(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                iconSize: 32,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
