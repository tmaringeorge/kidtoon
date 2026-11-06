import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart' show setGhiCharacter;
import '../widgets/kid_tile.dart';
import 'atelier/builder_screen.dart';
import 'atelier/coloring_screen.dart';
import 'atelier/drawing_screen.dart';
import 'ghi_character_screen.dart' show CharacterPreview;
import 'main_screen.dart';
import 'stories_screen.dart';
import 'welcome_screen.dart';

/// Acasă: prietenul copilului îl salută și îi arată ce poate face, în plăci mari.
class HomeSection extends StatefulWidget {
  const HomeSection({super.key, required this.state, required this.onGo});
  final AppState state;
  final void Function(Section) onGo;

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 60))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = state.character;
        setGhiCharacter(c);
        final book = state.ghiBook;
        final epIndex = book == null || book.episodes.isEmpty ? 0 : state.ghiEpisode.clamp(0, book.episodes.length - 1);
        final tiles = <Widget>[
          if (book != null && book.episodes.isNotEmpty)
            KidTile(
              color: KidColors.pink,
              emoji: '▶️',
              title: 'Continuă povestea',
              subtitle: book.episodes[epIndex].title,
              autofocus: true,
              onTap: () => _push(StoryPlayerScreen(state: state, index: epIndex)),
            ),
          KidTile(
            color: KidColors.purple,
            emoji: '🎬',
            title: 'Povești cu ${c.name}',
            onTap: () => widget.onGo(Section.stories),
          ),
          KidTile(
            color: KidColors.orange,
            emoji: '👆',
            title: 'Atinge și învață',
            onTap: () => widget.onGo(Section.touch),
          ),
          KidTile(
            color: KidColors.green,
            emoji: '🖍️',
            title: 'Colorează',
            onTap: () => _push(ColoringScreen(state: state)),
          ),
          KidTile(
            color: KidColors.yellow,
            emoji: '✏️',
            title: 'Desenează',
            onTap: () => _push(DrawingScreen(state: state)),
          ),
          KidTile(
            color: KidColors.red,
            emoji: '🧱',
            title: 'Construiește',
            onTap: () => _push(BuilderScreen(state: state)),
          ),
          KidTile(color: KidColors.blue, emoji: '📺', title: 'Desene TV', onTap: () => widget.onGo(Section.tv)),
          KidTile(
            color: KidColors.teal,
            emoji: '🎵',
            title: 'Radio cu animații',
            onTap: () => widget.onGo(Section.radio),
          ),
        ];
        final safe = MediaQuery.paddingOf(context);
        return LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth > 1100 ? 4 : (box.maxWidth > 620 ? 3 : 2);
            final greeting = Container(
              height: box.maxWidth > 620 ? 200 : 170,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8FD3FF), Color(0xFFD7F5FF), Color(0xFF9BE07A)],
                  stops: [0, 0.74, 0.75],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: box.maxWidth > 620 ? 220 : 130,
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => CustomPaint(size: Size.infinite, painter: CharacterPreview(_anim.value * 60, c)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Bună! Eu sunt ${c.name}!',
                            style: TextStyle(
                              color: const Color(0xFF3A2A7A),
                              fontSize: box.maxWidth > 620 ? 32 : 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Ce facem azi?',
                            style: TextStyle(color: Color(0xFF3A2A7A), fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _push(WelcomeScreen(state: state, editing: true)),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Prietenul meu'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, safe.top + 16, 16 + safe.right, 12),
                  sliver: SliverToBoxAdapter(child: greeting),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16 + safe.right, 24 + safe.bottom),
                  sliver: SliverGrid.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.25,
                    children: tiles,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
