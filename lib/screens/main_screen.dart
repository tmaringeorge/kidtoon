import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'atelier/atelier_section.dart';
import 'home_section.dart';
import 'parent_gate.dart';
import 'radio_screens.dart';
import 'settings_screen.dart';
import 'stories_screen.dart';
import 'tv_section.dart';

/// Secțiunile din meniul lateral, ca în aplicația de TV: copilul e în față,
/// radioul și posturile TV sunt doar alte locuri de joacă.
enum Section {
  home('Acasă', '🏠', KidColors.purple),
  stories('Povești', '🎬', KidColors.pink),
  touch('Atinge', '👆', KidColors.orange),
  atelier('Atelier', '🎨', KidColors.green),
  tv('Desene', '📺', KidColors.blue),
  radio('Radio', '🎵', KidColors.teal);

  const Section(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

/// Ecranul principal: meniu lateral (se lărgește când e ales cu telecomanda) și secțiunea aleasă.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Section _section = Section.values[widget.state.lastSection.clamp(0, Section.values.length - 1)];
  bool _railFocused = false;

  @override
  void initState() {
    super.initState();
    widget.state.loadGhi();
  }

  void go(Section s) {
    setState(() => _section = s);
    widget.state.lastSection = s.index;
  }

  Widget _content() {
    final state = widget.state;
    return switch (_section) {
      Section.home => HomeSection(state: state, onGo: go),
      Section.stories => StoriesSection(state: state),
      Section.touch => TouchSection(state: state),
      Section.atelier => AtelierSection(state: state),
      Section.tv => TvSection(state: state),
      Section.radio => RadioScreen(state: state, embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final expanded = wide && _railFocused;
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Row(
        children: [
          // ---------------- Meniul lateral ----------------
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (f) => setState(() => _railFocused = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: (expanded ? 230 : 92) + safe.left,
              color: KidColors.panel,
              padding: EdgeInsets.only(left: safe.left, top: safe.top + 8, bottom: safe.bottom + 8),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/logo.png', width: 46, height: 46),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final s in Section.values)
                            _RailItem(
                              emoji: s.emoji,
                              label: s.label,
                              color: s.color,
                              selected: s == _section,
                              expanded: expanded,
                              onTap: () => go(s),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _RailItem(
                    emoji: '🔒',
                    label: 'Părinți',
                    color: KidColors.card,
                    selected: false,
                    expanded: expanded,
                    onTap: () => ParentGate.push(context, widget.state, (_) => SettingsScreen(state: widget.state)),
                  ),
                ],
              ),
            ),
          ),
          // ---------------- Secțiunea aleasă ----------------
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(_section), child: _content()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected ? widget.color : (_focused ? widget.color.withValues(alpha: 0.5) : Colors.transparent);
    final emoji = Text(widget.emoji, style: const TextStyle(fontSize: 30));
    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.expanded ? 20 : 13,
        fontWeight: FontWeight.w900,
        color: widget.selected || _focused ? Colors.white : KidColors.textDim,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _focused ? KidColors.focus : Colors.transparent, width: 3),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          focusColor: Colors.transparent,
          onFocusChange: (f) => setState(() => _focused = f),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: widget.expanded
                ? Row(
                    children: [
                      const SizedBox(width: 6),
                      emoji,
                      const SizedBox(width: 12),
                      Expanded(child: label),
                    ],
                  )
                : Column(children: [emoji, label]),
          ),
        ),
      ),
    );
  }
}
