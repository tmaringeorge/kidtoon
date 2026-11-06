import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../app_state.dart';
import '../data/ghi_episodes.dart';
import '../data/ghi_studio.dart';
import '../theme.dart';
import '../widgets/ghi_animation.dart';

/// Studio: părintele face personaje noi și episoade noi cu GHI, le salvează pe telefon
/// și le poate trimite pe TV.
class GhiStudioScreen extends StatefulWidget {
  const GhiStudioScreen({super.key, required this.state});
  final AppState state;

  @override
  State<GhiStudioScreen> createState() => _GhiStudioScreenState();
}

class _GhiStudioScreenState extends State<GhiStudioScreen> {
  AppState get state => widget.state;
  StudioLibrary get lib => state.studio;

  Future<void> _editDraft([StudioDraft? draft]) async {
    final saved = await Navigator.push<StudioDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => DraftEditorScreen(state: state, draft: draft),
      ),
    );
    if (saved == null) return;
    final i = lib.drafts.indexWhere((d) => d.id == saved.id);
    if (i >= 0) {
      lib.drafts[i] = saved;
    } else {
      lib.drafts.add(saved);
    }
    await state.saveStudio();
    if (mounted) setState(() {});
  }

  Future<void> _editPerson([StudioPerson? person]) async {
    final saved = await Navigator.push<StudioPerson>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonEditorScreen(state: state, person: person),
      ),
    );
    if (saved == null) {
      // Previzualizarea a putut schimba personajele desenate; revenim la cele salvate.
      setStudioPeople(lib.people);
      return;
    }
    final i = lib.people.indexWhere((p) => p.id == saved.id);
    if (i >= 0) {
      lib.people[i] = saved;
    } else {
      lib.people.add(saved);
    }
    await state.saveStudio();
    if (mounted) setState(() {});
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nu')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Da, șterge')),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteDraft(StudioDraft d) async {
    if (!await _confirm('Ștergi episodul „${d.title.isEmpty ? 'fără nume' : d.title}”?')) return;
    lib.drafts.removeWhere((x) => x.id == d.id);
    await state.saveStudio();
    if (mounted) setState(() {});
  }

  Future<void> _deletePerson(StudioPerson p) async {
    final used = lib.drafts.where((d) => d.steps.any((s) => s.who == p.id)).length;
    final extra = used > 0
        ? ' Apare în $used episod${used == 1 ? '' : 'e'}; acolo va fi desenată mami în locul lui.'
        : '';
    if (!await _confirm('Ștergi personajul „${p.name}”?$extra')) return;
    lib.people.removeWhere((x) => x.id == p.id);
    await state.saveStudio();
    if (mounted) setState(() {});
  }

  void _play(StudioDraft d) {
    final base = state.ghiBook;
    if (base == null || d.steps.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GhiPreviewScreen(book: base, episode: state.personalEpisode(d.toEpisode())),
      ),
    );
  }

  Future<void> _sendToTv() async {
    if (lib.drafts.every((d) => d.steps.isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fă întâi un episod cu cel puțin un pas.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _SendDialog(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🎨 Studio de povești'),
          actions: [IconButton(tooltip: 'Trimite pe TV', icon: const Icon(Icons.tv), onPressed: _sendToTv)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Episoadele mele'),
              Tab(text: 'Personajele mele'),
            ],
          ),
        ),
        body: TabBarView(children: [_episodes(), _people()]),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => DefaultTabController.of(context).index == 0 ? _editDraft() : _editPerson(),
            icon: const Icon(Icons.add),
            label: const Text('Nou'),
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: KidColors.textDim, fontSize: 16),
      ),
    ),
  );

  Widget _episodes() {
    if (lib.drafts.isEmpty) {
      return _empty(
        'Încă nu ai episoade.\nApasă „Nou”, alege un decor și adaugă pași: ce face ${state.character.name}, cine mai vine și ce obiecte apar.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final d in lib.drafts)
          ListTile(
            leading: const CircleAvatar(child: Text('🎬')),
            title: Text(d.title.isEmpty ? 'Episod fără nume' : d.title),
            subtitle: Text('${Studio.sets[d.set] ?? d.set} · ${d.steps.length} pași'),
            onTap: () => _editDraft(d),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Joacă',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: d.steps.isEmpty ? null : () => _play(d),
                ),
                IconButton(tooltip: 'Șterge', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteDraft(d)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _people() {
    if (lib.people.isEmpty) {
      return _empty(
        'Fă un personaj nou: bunicul, o mătușă, un prieten sau oricine vrei.\nApoi îl pui în episoadele tale.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final p in lib.people)
          ListTile(
            leading: SizedBox(width: 48, height: 48, child: PersonAvatar(personId: p.id)),
            title: Text(p.name),
            subtitle: Text([Studio.styles[p.style] ?? '', if (p.hat != null) Studio.hats[p.hat] ?? ''].join(' · ')),
            onTap: () => _editPerson(p),
            trailing: IconButton(
              tooltip: 'Șterge',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deletePerson(p),
            ),
          ),
      ],
    );
  }
}

/// Capul și umerii unui personaj, pentru liste și previzualizare.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.personId, this.full = false});
  final String personId;
  final bool full;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PersonPainter(personId, full));
}

class _PersonPainter extends CustomPainter {
  _PersonPainter(this.id, this.full);
  final String id;
  final bool full;

  @override
  bool shouldRepaint(_PersonPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final p = GhiPerson({'who': id, 'x': 0.5, 'pose': full ? 'wave' : 'stand', 'face': 'happy', 'flip': false});
    if (full) {
      paintPerson(canvas, p, 0.3, 1, size.width / 2, size.height * 0.97, size.height * 0.82);
    } else {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width / 2)));
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE3F2FD));
      paintPerson(canvas, p, 0.3, 1, size.width / 2, size.height * 2.6, size.height * 2.3);
      canvas.restore();
    }
  }
}

/// Editorul unui episod: nume, decor, ce învățăm și pașii.
class DraftEditorScreen extends StatefulWidget {
  const DraftEditorScreen({super.key, required this.state, this.draft});
  final AppState state;
  final StudioDraft? draft;

  @override
  State<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends State<DraftEditorScreen> {
  late final StudioDraft d = widget.draft == null
      ? StudioDraft(id: widget.state.studio.newId('e'))
      : StudioDraft.fromJson(widget.draft!.toJson());
  late final _title = TextEditingController(text: d.title);
  late final _learn = TextEditingController(text: d.learn);

  @override
  void dispose() {
    _title.dispose();
    _learn.dispose();
    super.dispose();
  }

  String _describe(StudioStep s) {
    final act = Studio.ghiActions.firstWhere((a) => a.id == s.action, orElse: () => Studio.ghiActions.first);
    final parts = ['${widget.state.character.name} ${act.label}'];
    if (s.ask && s.thing != null) {
      parts.add('întrebare: care e ${Studio.things[s.thing] ?? s.thing}?');
    } else {
      if (s.who != null) {
        final pa = Studio.personActions.firstWhere(
          (a) => a.id == s.whoAction,
          orElse: () => Studio.personActions.first,
        );
        parts.add('${widget.state.studio.personName(s.who!)} ${pa.label}');
      }
      if (s.thing != null) parts.add(s.thing!);
    }
    return parts.join(' · ');
  }

  Future<void> _editStep([int? index]) async {
    final step = index == null ? StudioStep() : StudioStep.fromJson(d.steps[index].toJson());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StepSheet(state: widget.state, step: step),
    );
    if (ok != true) return;
    setState(() {
      if (index == null) {
        d.steps.add(step);
      } else {
        d.steps[index] = step;
      }
    });
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= d.steps.length) return;
    setState(() {
      final s = d.steps.removeAt(i);
      d.steps.insert(j, s);
    });
  }

  void _sync() {
    d.title = _title.text;
    d.learn = _learn.text;
  }

  void _preview() {
    _sync();
    final base = widget.state.ghiBook;
    if (base == null || d.steps.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GhiPreviewScreen(book: base, episode: widget.state.personalEpisode(d.toEpisode())),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = d.steps.isEmpty ? 0 : (GhiTimeline.durationMs(GhiEpisode(d.toEpisode())) / 1000).round();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.draft == null ? 'Episod nou' : 'Modifică episodul'),
        actions: [
          IconButton(
            tooltip: 'Previzualizează',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: d.steps.isEmpty ? null : _preview,
          ),
          TextButton(
            onPressed: () {
              _sync();
              Navigator.pop(context, d);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Numele episodului',
              hintText: 'GHI la bunicul',
              helperText: 'Scrie GHI unde vrei numele prietenului; se înlocuiește singur.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _learn,
            decoration: const InputDecoration(
              labelText: 'Ce am învățat (la final)',
              hintText: 'Spunem „mulțumesc” când primim ceva.',
            ),
          ),
          const SizedBox(height: 16),
          const Text('Decorul', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in Studio.sets.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: d.set == e.key,
                  onSelected: (_) => setState(() => d.set = e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Pașii poveștii', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (total > 0)
                Text('cam ${total ~/ 60} min ${total % 60} s', style: const TextStyle(color: KidColors.textDim)),
            ],
          ),
          if (d.steps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Adaugă primul pas: ce spune povestea, ce face ${widget.state.character.name}, cine mai e acolo și ce obiect apare.',
                style: const TextStyle(color: KidColors.textDim),
              ),
            ),
          for (var i = 0; i < d.steps.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(d.steps[i].say.isEmpty ? '(fără text)' : d.steps[i].say),
                subtitle: Text(_describe(d.steps[i])),
                onTap: () => _editStep(i),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_upward), onPressed: i == 0 ? null : () => _move(i, -1)),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == d.steps.length - 1 ? null : () => _move(i, 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => d.steps.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editStep(),
            icon: const Icon(Icons.add),
            label: const Text('Adaugă un pas'),
          ),
        ],
      ),
    );
  }
}

/// Un pas: textul, ce face GHI, cine mai e acolo și ce face, obiectul și întrebarea.
class _StepSheet extends StatefulWidget {
  const _StepSheet({required this.state, required this.step});
  final AppState state;
  final StudioStep step;

  @override
  State<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<_StepSheet> {
  StudioStep get s => widget.step;
  late final _say = TextEditingController(text: s.say);

  @override
  void dispose() {
    _say.dispose();
    super.dispose();
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final people = {...Studio.builtInPeople, for (final p in widget.state.studio.people) p.id: p.name};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              TextField(
                controller: _say,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ce spune povestea',
                  hintText: 'GHI merge cu bunicul la pescuit',
                ),
              ),
              _title('Ce face ${widget.state.character.name}'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in Studio.ghiActions)
                    ChoiceChip(
                      label: Text(a.label),
                      selected: s.action == a.id,
                      onSelected: (_) => setState(() => s.action = a.id),
                    ),
                ],
              ),
              _title('Cine mai e în scenă'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text('Doar ${widget.state.character.name}'),
                    selected: s.who == null,
                    onSelected: (_) => setState(() => s.who = null),
                  ),
                  for (final e in people.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: s.who == e.key,
                      onSelected: (_) => setState(() => s.who = e.key),
                    ),
                ],
              ),
              if (s.who != null) ...[
                _title('Ce face ${people[s.who] ?? ''}'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in Studio.personActions)
                      ChoiceChip(
                        label: Text(a.label),
                        selected: s.whoAction == a.id,
                        onSelected: (_) => setState(() => s.whoAction = a.id),
                      ),
                  ],
                ),
              ],
              _title('Un obiect'),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Niciunul'),
                    selected: s.thing == null,
                    onSelected: (_) => setState(() {
                      s.thing = null;
                      s.ask = false;
                    }),
                  ),
                  for (final e in Studio.things.entries)
                    ChoiceChip(
                      label: Text(e.key, style: const TextStyle(fontSize: 22)),
                      tooltip: e.value,
                      selected: s.thing == e.key,
                      onSelected: (_) => setState(() => s.thing = e.key),
                    ),
                ],
              ),
              if (s.thing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.ask,
                  onChanged: (v) => setState(() => s.ask = v),
                  title: Text('Întrebare: „Care e ${Studio.things[s.thing] ?? 'acesta'}? Arată cu degetul!”'),
                  subtitle: const Text('Pe ecran apar 3 obiecte, iar copilul îl atinge pe cel bun.'),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  s.say = _say.text.trim();
                  Navigator.pop(context, true);
                },
                child: const Text('Gata'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creatorul de personaje: nume, păr, piele, haine, pălărie, ochelari, barbă.
class PersonEditorScreen extends StatefulWidget {
  const PersonEditorScreen({super.key, required this.state, this.person});
  final AppState state;
  final StudioPerson? person;

  @override
  State<PersonEditorScreen> createState() => _PersonEditorScreenState();
}

class _PersonEditorScreenState extends State<PersonEditorScreen> {
  late final StudioPerson p = widget.person == null
      ? StudioPerson(id: widget.state.studio.newId('p'), name: '')
      : StudioPerson.fromJson(widget.person!.toJson());
  late final _name = TextEditingController(text: p.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Desenul se schimbă pe loc, cât alegi.
  void _refresh(VoidCallback change) {
    setState(change);
    setStudioPeople([...widget.state.studio.people.where((x) => x.id != p.id), p]);
  }

  @override
  void initState() {
    super.initState();
    setStudioPeople([...widget.state.studio.people.where((x) => x.id != p.id), p]);
  }

  Widget _swatches(List<String> colors, String current, void Function(String) pick) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final c in colors)
        GestureDetector(
          onTap: () => _refresh(() => pick(c)),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFF000000 | int.parse(c.substring(1), radix: 16)),
              shape: BoxShape.circle,
              border: Border.all(
                color: c == current ? KidColors.accent : const Color(0x33000000),
                width: c == current ? 4 : 1,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person == null ? 'Personaj nou' : 'Modifică personajul'),
        actions: [
          TextButton(
            onPressed: () {
              p.name = _name.text.trim().isEmpty ? 'Un prieten nou' : _name.text.trim();
              Navigator.pop(context, p);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(16)),
            child: PersonAvatar(personId: p.id, full: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Numele', hintText: 'Bunicul Ion'),
          ),
          _title('Părul'),
          Wrap(
            spacing: 6,
            children: [
              for (final e in Studio.styles.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: p.style == e.key,
                  onSelected: (_) => _refresh(() => p.style = e.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _swatches(Studio.hairs, p.hair, (c) => p.hair = c),
          _title('Pielea'),
          _swatches(Studio.skins, p.skin, (c) => p.skin = c),
          _title('Bluza'),
          _swatches(Studio.clothes, p.top, (c) => p.top = c),
          _title(p.dress ? 'Ciorapii' : 'Pantalonii'),
          _swatches(Studio.clothes, p.bottom, (c) => p.bottom = c),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rochie'),
            value: p.dress,
            onChanged: (v) => _refresh(() => p.dress = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ochelari'),
            value: p.glasses,
            onChanged: (v) => _refresh(() => p.glasses = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Barbă'),
            value: p.beard,
            onChanged: (v) => _refresh(() => p.beard = v),
          ),
          _title('Pe cap'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in Studio.hats.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: p.hat == e.key,
                  onSelected: (_) => _refresh(() => p.hat = e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Episodul pe tot ecranul, cu vocea care povestește, ca să vezi cum iese.
class GhiPreviewScreen extends StatefulWidget {
  const GhiPreviewScreen({super.key, required this.book, required this.episode});
  final GhiBook book;
  final GhiEpisode episode;

  @override
  State<GhiPreviewScreen> createState() => _GhiPreviewScreenState();
}

class _GhiPreviewScreenState extends State<GhiPreviewScreen> {
  final _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('ro-RO');
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = GhiBook(widget.book.sets, [widget.episode], widget.book.touch);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GhiAnimation(book: book, index: 0, onFinished: () => Navigator.maybePop(context), onSay: _tts.speak),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trimiterea pe TV: adresa și codul pe care le arată TV-ul.
class _SendDialog extends StatefulWidget {
  const _SendDialog({required this.state});
  final AppState state;

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  late final _address = TextEditingController(text: widget.state.tvAddress);
  final _code = TextEditingController();
  bool _busy = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final n = await StudioSender.send(
        _address.text,
        _code.text,
        widget.state.studio.exportForTv(widget.state.character.toJson()),
      );
      widget.state.tvAddress = _address.text.trim();
      setState(() {
        _ok = true;
        _result = 'Gata! TV-ul are acum $n episoade de-ale tale. Le găsești la 🎬, după celelalte.';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _result = e is StudioSendError ? e.message : 'Nu am putut trimite: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trimite pe TV'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pe TV: Setări → „Primește episoade de pe telefon”. Scrie aici adresa și codul de pe ecran.'),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Adresa TV-ului', hintText: '192.168.1.23'),
            ),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Codul de pe TV'),
            ),
            if (_result != null)
              Text(
                _result!,
                style: TextStyle(color: _ok ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_ok ? 'Închide' : 'Renunță')),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Trimite'),
        ),
      ],
    );
  }
}
