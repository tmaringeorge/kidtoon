import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/ghi_character.dart';
import '../data/ghi_episodes.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart';

/// Personajul: numele, băiat sau fată și costumașul. Se vede pe loc și se aplică tuturor poveștilor.
class GhiCharacterScreen extends StatefulWidget {
  const GhiCharacterScreen({super.key, required this.state});
  final AppState state;

  @override
  State<GhiCharacterScreen> createState() => _GhiCharacterScreenState();
}

class _GhiCharacterScreenState extends State<GhiCharacterScreen> with SingleTickerProviderStateMixin {
  late GhiCharacter c = widget.state.character;
  late final _name = TextEditingController(text: c.name);
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

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final example = c.personalize('GHI e {fericit|fericită}! Mami {îl|o} îmbrățișează pe GHI, {dragonul} cel mic.');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personajul poveștilor'),
        actions: [
          TextButton(
            onPressed: () {
              widget.state.character = c.copyWith(name: _name.text);
              Navigator.pop(context);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(16)),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(painter: CharacterPreview(_anim.value * 60, c)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            example,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KidColors.textDim),
          ),
          _title('Numele'),
          TextField(
            controller: _name,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'GHI'),
            onChanged: (v) => setState(() => c = c.copyWith(name: v)),
          ),
          _title('Băiat sau fată'),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Băiat'),
                selected: !c.girl,
                onSelected: (_) => _change(c.copyWith(girl: false)),
              ),
              ChoiceChip(
                label: const Text('Fată (cu fundiță)'),
                selected: c.girl,
                onSelected: (_) => _change(c.copyWith(girl: true)),
              ),
            ],
          ),
          _title('Costumașul'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in GhiCharacter.avatars.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: c.avatar == e.key,
                  onSelected: (_) => _change(c.copyWith(avatar: e.key)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Poveștile spun numele ales și vorbesc despre un băiat sau o fată. '
            'Pe TV se schimbă din Setări sau când trimiți episoade din Studio.',
            style: TextStyle(color: KidColors.textDim),
          ),
          if (!c.isDefault)
            TextButton(
              onPressed: () {
                _name.text = 'GHI';
                _change(const GhiCharacter());
              },
              child: const Text('Înapoi la dinozaurul verde'),
            ),
        ],
      ),
    );
  }
}

/// Personajul ales, desenat pe loc (face cu mâna și se bucură).
class CharacterPreview extends CustomPainter {
  CharacterPreview(this.ts, this.c);
  final double ts;
  final GhiCharacter c;

  @override
  bool shouldRepaint(CharacterPreview old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = (ts % 6) < 3;
    final g = GhiPose({'pose': wave ? 'wave' : 'happy', 'x': 0.5, 'face': 'happy', 'flip': false});
    final h = min(size.height * 0.55, size.width * 0.4);
    paintGhi(canvas, g, 0.3, ts, size.width / 2, size.height * 0.93, h);
  }
}
