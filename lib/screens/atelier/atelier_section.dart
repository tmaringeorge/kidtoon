import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets/kid_tile.dart';
import '../stories_screen.dart' show SectionTitle;
import 'builder_screen.dart';
import 'coloring_screen.dart';
import 'drawing_screen.dart';
import 'gallery_screen.dart';

/// Atelierul copilului: colorează, desenează, construiește și galeria cu lucrări.
class AtelierSection extends StatelessWidget {
  const AtelierSection({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    final tiles = [
      KidTile(
        color: KidColors.green,
        emoji: '🖍️',
        title: 'Colorează',
        subtitle: 'Planșe cu căsuțe, pești, flori…',
        autofocus: true,
        onTap: () => push(ColoringScreen(state: state)),
      ),
      KidTile(
        color: KidColors.yellow,
        emoji: '✏️',
        title: 'Desenează',
        subtitle: 'Creion, curcubeu, ștampile',
        onTap: () => push(DrawingScreen(state: state)),
      ),
      KidTile(
        color: KidColors.red,
        emoji: '🧱',
        title: 'Construiește',
        subtitle: 'Forme și abțibilduri',
        onTap: () => push(BuilderScreen(state: state)),
      ),
      KidTile(
        color: KidColors.purple,
        emoji: '🖼️',
        title: 'Galeria mea',
        subtitle: 'Tot ce ai făcut',
        onTap: () => push(const GalleryScreen()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth > 900 ? 4 : 2;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SectionTitle('🎨 Atelierul lui ${state.character.name}')),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16 + MediaQuery.paddingOf(context).right, 24),
              sliver: SliverGrid.count(
                crossAxisCount: cols,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: cols == 4 ? 0.95 : 1.1,
                children: tiles,
              ),
            ),
          ],
        );
      },
    );
  }
}
