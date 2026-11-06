import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/ghi_character.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart' show setGhiCharacter;
import '../widgets/kid_tile.dart';
import 'ghi_character_screen.dart' show CharacterPreview;

/// Prima pornire (și „Prietenul meu” din meniu): copilul își alege prietenul din povești.
/// Numele ales apare peste tot în aplicație și în toate poveștile.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.state, this.editing = false});
  final AppState state;

  /// Deschis din aplicație (nu la prima pornire): are buton Înapoi.
  final bool editing;

  static const suggestions = ['Bubu', 'Dino', 'Tita', 'Mimi', 'Zuzu', 'Leo', 'Pufi', 'Ghi'];
  static const costumes = {
    'dragon': ('🦖', KidColors.green, 'Dinozaur'),
    'balaur': ('🐉', KidColors.teal, 'Balaur'),
    'leu': ('🦁', KidColors.orange, 'Leu'),
    'urs': ('🧸', KidColors.pink, 'Ursuleț'),
  };

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late GhiCharacter c = widget.editing ? widget.state.character : const GhiCharacter(name: '');
  late final _name = TextEditingController(text: widget.editing ? c.name : '');
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 60))
    ..repeat();

  @override
  void initState() {
    super.initState();
    setGhiCharacter(c);
  }

  @override
  void dispose() {
    _anim.dispose();
    _name.dispose();
    setGhiCharacter(widget.state.character);
    super.dispose();
  }

  void _change(GhiCharacter next) {
    setState(() => c = next);
    setGhiCharacter(c);
  }

  bool get _ready => _name.text.trim().isNotEmpty;

  void _done() {
    if (!_ready) return;
    widget.state.chooseCharacter(c.copyWith(name: _name.text.trim()));
    if (widget.editing) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    final name = _name.text.trim();
    final preview = Container(
      height: wide ? double.infinity : 230,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FD3FF), Color(0xFFD7F5FF), Color(0xFF9BE07A)],
          stops: [0, 0.7, 0.71],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(painter: CharacterPreview(_anim.value * 60, c)),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                name.isEmpty ? 'Salut! Cum mă cheamă?' : 'Salut! Eu sunt $name!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF3A2A7A), fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
    final form = ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
      children: [
        _title('1. Alege un nume'),
        TextField(
          controller: _name,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: 'Scrie numele',
            filled: true,
            fillColor: KidColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => c = c.copyWith(name: v)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in WelcomeScreen.suggestions)
              ChoiceChip(
                label: Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                selected: name == s,
                onSelected: (_) {
                  _name.text = s;
                  _change(c.copyWith(name: s));
                },
              ),
          ],
        ),
        _title('2. Ce costumaș poartă?'),
        SizedBox(
          height: 118,
          child: Row(
            children: [
              for (final e in WelcomeScreen.costumes.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: KidTile(
                      color: e.value.$2,
                      emoji: e.value.$1,
                      title: e.value.$3,
                      selected: c.avatar == e.key,
                      radius: 20,
                      onTap: () => _change(c.copyWith(avatar: e.key)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _title('3. Băiat sau fată?'),
        SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: KidTile(
                    color: KidColors.blue,
                    emoji: '👦',
                    title: 'Băiat',
                    radius: 20,
                    selected: !c.girl,
                    onTap: () => _change(c.copyWith(girl: false)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: KidTile(
                    color: KidColors.pink,
                    emoji: '👧',
                    title: 'Fată',
                    radius: 20,
                    selected: c.girl,
                    onTap: () => _change(c.copyWith(girl: true)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 70,
          child: FilledButton.icon(
            onPressed: _ready ? _done : null,
            icon: const Icon(Icons.rocket_launch_rounded, size: 30),
            label: Text(
              _ready ? (widget.editing ? 'Gata!' : 'Hai să ne jucăm cu $name!') : 'Alege întâi un nume',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.editing ? AppBar(title: const Text('Prietenul meu')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: preview),
                    const SizedBox(width: 20),
                    Expanded(child: form),
                  ],
                )
              : Column(
                  children: [
                    preview,
                    const SizedBox(height: 8),
                    Expanded(child: form),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: KidColors.accent),
    ),
  );
}
