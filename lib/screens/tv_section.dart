import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/kid_tile.dart';
import 'player_screen.dart';
import 'stories_screen.dart' show SectionTitle;

/// Desene TV: grila de posturi pentru copii (filtrate de părinți), ca grila din aplicația de TV:
/// categorii sus, plăci mari cu logo, emisiunea de acum și bară de progres.
class TvSection extends StatelessWidget {
  const TvSection({super.key, required this.state});
  final AppState state;

  void _play(BuildContext context, List<Channel> list, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(state: state, list: list, index: index),
      ),
    );
  }

  static String _emoji(String c) => switch (c) {
    Categories.all => '🌈',
    Categories.favorites => '❤️',
    Categories.recent => '🕒',
    'Copii' => '🧸',
    'Educație' => '📚',
    'Familie' => '👨‍👩‍👧',
    _ => '📺',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.visibleChannels;
        final last = state.lastChannel;
        final safe = MediaQuery.paddingOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              '📺 Desene TV',
              trailing: state.loading || state.epgLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : null,
            ),
            SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (last != null)
                    _Chip(
                      label: '▶️ Continuă: ${last.name}',
                      selected: false,
                      onTap: () => _play(context, state.channels, state.channels.indexOf(last)),
                    ),
                  for (final c in state.categories)
                    _Chip(
                      label: '${_emoji(c)} $c',
                      selected: c == state.selectedCategory,
                      onTap: () => state.selectCategory(c),
                    ),
                ],
              ),
            ),
            Expanded(child: _grid(context, list, safe)),
          ],
        );
      },
    );
  }

  Widget _grid(BuildContext context, List<Channel> list, EdgeInsets safe) {
    if (state.loading && state.channels.isEmpty) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      final msg = switch (state.selectedCategory) {
        Categories.favorites =>
          'Nu ai desene preferate încă.\nȚine apăsat pe un post (pe TV: ține apăsat OK) ca să-l pui la ❤️.',
        Categories.recent => 'Nu te-ai uitat încă la niciun post.',
        _ => 'Nu sunt desene încă.\nRoagă un părinte să adauge posturi din 🔒 Părinți.',
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧸', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: KidColors.textDim, fontSize: 20),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.refreshSources,
                icon: const Icon(Icons.refresh),
                label: const Text('Încearcă din nou'),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth > 1100 ? 4 : (box.maxWidth > 620 ? 3 : 2);
        return RefreshIndicator(
          onRefresh: state.refreshSources,
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16 + safe.right, 24 + safe.bottom),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) =>
                _ChannelCard(channel: list[i], state: state, autofocus: i == 0, onTap: () => _play(context, list, i)),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      selected: selected,
      onSelected: (_) => onTap(),
          showCheckmark: false,
      shape: const StadiumBorder(),
    ),
  );
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.state, required this.onTap, this.autofocus = false});
  final Channel channel;
  final AppState state;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final now = state.now;
    final (live, _) = state.epg.nowAndNext(channel, now);
    final fav = state.favorites.contains(channel.key);
    final color = [KidColors.blue, KidColors.purple, KidColors.teal, KidColors.pink][channel.name.length % 4];
    return KidTile(
      color: color,
      autofocus: autofocus,
      onTap: onTap,
      onLongPress: () {
        state.toggleFavorite(channel);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(fav ? '${channel.name} nu mai e la ❤️' : '${channel.name} e acum la ❤️'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    channel.logo == null
                        ? Center(
                            child: Text(
                              channel.name.characters.take(2).toString().toUpperCase(),
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                            ),
                          )
                        : Image.network(
                            channel.logo!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                channel.name.characters.take(2).toString().toUpperCase(),
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                    if (fav)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Text('❤️', style: TextStyle(fontSize: 22)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if (live != null) ...[
              Text(
                live.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: live.progress(now),
                  minHeight: 5,
                  backgroundColor: const Color(0x33FFFFFF),
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
