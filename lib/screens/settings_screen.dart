import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/battery.dart';
import '../data/ghi_episodes.dart';
import '../data/parental.dart';
import '../data/presets.dart';
import '../data/radio.dart';
import '../data/repository.dart';
import '../theme.dart';
import 'welcome_screen.dart';
import 'ghi_studio_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;

  static String nameFromUrl(String url) => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('🔒 Părinți: setări și surse')),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16 + MediaQuery.paddingOf(context).left,
            0,
            16 + MediaQuery.paddingOf(context).right,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const _Section('Pentru părinți'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Doar posturi pentru copii'),
              subtitle: Text('La Desene TV apar doar categoriile: ${KidFilter.label}.'),
              value: state.kidsOnly,
              onChanged: state.setKidsOnly,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ascunde posturi'),
              subtitle: Text(
                state.hiddenChannels.isEmpty
                    ? 'Alegi posturile pe care copilul nu le vede.'
                    : '${state.hiddenChannels.length} posturi ascunse',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _HiddenChannelsScreen(state: state))),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_outlined),
              title: Text(state.parentPin.isEmpty ? 'Pune un PIN pentru părinți' : 'Schimbă PIN-ul'),
              subtitle: Text(
                state.parentPin.isEmpty
                    ? 'Acum se intră aici cu o înmulțire. Cu PIN, doar cine știe cele 4 cifre.'
                    : 'Setările, sursele, modul Adult și Studio cer PIN-ul.',
              ),
              onTap: () => _setPin(context, state),
              trailing: state.parentPin.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Scoate PIN-ul',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => state.setParentPin(''),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.channels.length} posturi pentru copil (din ${state.allChannels.length} încărcate)'
              '${state.filteredOut > 0 ? ' · ${state.filteredOut} intrări ascunse (surse neautorizate)' : ''}'
              '${state.epg.isEmpty ? ' · fără ghid TV' : ' · ghid TV activ'}',
              style: const TextStyle(color: KidColors.textDim),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.loading ? null : state.refreshSources,
              icon: const Icon(Icons.refresh),
              label: Text(state.loading ? 'Se actualizează…' : 'Actualizează acum toate sursele'),
            ),
            const _Section('Liste de posturi (M3U)'),
            SwitchListTile(
              title: const Text(Repository.builtInName),
              subtitle: const Text('Lista inclusă în aplicație (assets/copii.m3u), ușor de completat.'),
              value: state.builtInEnabled,
              onChanged: state.setBuiltIn,
            ),
            for (final p in state.playlists)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                leading: Switch(value: p.enabled, onChanged: (_) => state.togglePlaylist(p)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => state.removePlaylist(p)),
              ),
            _AddField(
              hint: 'https://exemplu.ro/lista.m3u',
              label: 'Adaugă listă M3U',
              onAdd: (url) => state.addPlaylist(nameFromUrl(url), url),
            ),
            const SizedBox(height: 8),
            const Text('Sugestii (liste publice iptv-org):', style: TextStyle(color: KidColors.textDim)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in Presets.playlists)
                  ActionChip(
                    avatar: Icon(state.playlists.any((e) => e.url == p.url) ? Icons.check : Icons.add, size: 18),
                    label: Text(p.name),
                    onPressed: state.playlists.any((e) => e.url == p.url)
                        ? null
                        : () => state.addPlaylist(p.name, p.url),
                  ),
              ],
            ),
            const _Section('Radio'),
            const Text(
              'Mod radio: Copil (animații) sau Adult (ecran simplu, cu postul și melodia):',
              style: TextStyle(color: KidColors.textDim),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RadioMode>(
              segments: [
                for (final m in RadioMode.values)
                  ButtonSegment(
                    value: m,
                    label: Text(m.label),
                    icon: Icon(m == RadioMode.kid ? Icons.child_care : Icons.person),
                  ),
              ],
              selected: {state.radioMode},
              onSelectionChanged: (s) => state.setRadioMode(s.first),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ecran sănătos: pauză de clipit la 5 minute, oprire după 3 episoade la rând și odihnă după:',
              style: TextStyle(color: KidColors.textDim),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final m in ScreenCare.limits) ButtonSegment(value: m, label: Text(ScreenCare.limitLabel(m))),
              ],
              selected: {state.sessionLimit},
              onSelectionChanged: (s) => state.setSessionLimit(s.first),
            ),
            const SizedBox(height: 12),
            const Text(
              'Animația din modul Copil (se păstrează pentru data viitoare):',
              style: TextStyle(color: KidColors.textDim),
            ),
            RadioGroup<RadioBackground>(
              groupValue: state.radioBackground,
              onChanged: (v) => state.setRadioBackground(v!),
              child: Column(
                children: [for (final bg in RadioBackground.values) RadioListTile(value: bg, title: Text(bg.label))],
              ),
            ),
            const Text(
              '„Toate pe rând” schimbă desenul la fiecare 2 minute și nu repetă aceeași imagine timp de o oră. '
              'Radioul merge și în fundal, cu ecranul stins; îl oprești din notificare.',
              style: TextStyle(color: KidColors.textDim, fontSize: 13),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Nu lăsa sistemul să oprească radioul'),
              subtitle: const Text('Scoate KidToon de la economisirea bateriei, ca radioul să cânte cu ecranul stins.'),
              onTap: Battery.requestUnrestricted,
            ),
            const _Section('Prietenul copilului și poveștile'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🐉', style: TextStyle(fontSize: 26)),
              title: Text('Prietenul: ${state.character.name}'),
              subtitle: const Text('Numele, băiat sau fată, dinozaur, balaur cu 7 capete, leu sau ursuleț'),
              onTap: () async {
                await state.loadGhi();
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => WelcomeScreen(state: state, editing: true)));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🎨', style: TextStyle(fontSize: 26)),
              title: const Text('Studio: fă episoade și personaje'),
              subtitle: const Text('Creezi, salvezi și trimiți pe TV'),
              onTap: () async {
                await state.loadGhi();
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => GhiStudioScreen(state: state)));
              },
            ),
            const _Section('Ghid TV (XMLTV)'),
            for (final url in state.epgUrls)
              ListTile(
                title: Text(nameFromUrl(url)),
                subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => state.removeEpg(url)),
              ),
            _AddField(hint: 'https://exemplu.ro/ghid.xml.gz', label: 'Adaugă ghid TV', onAdd: state.addEpg),
            Wrap(
              children: [
                for (final url in Presets.epg)
                  ActionChip(
                    avatar: Icon(state.epgUrls.contains(url) ? Icons.check : Icons.add, size: 18),
                    label: const Text('Ghid TV România (epgshare01)'),
                    onPressed: state.epgUrls.contains(url) ? null : () => state.addEpg(url),
                  ),
              ],
            ),
            if (state.errors.isNotEmpty) ...[
              const _Section('Erori la ultima actualizare'),
              for (final e in state.errors) Text(e, style: const TextStyle(color: KidColors.live)),
            ],
            const _Section('Despre'),
            const Text(
              'KidToon redă doar stream-uri publice, oferite gratuit de televiziuni. Poți adăuga liste proprii; '
              'intrările din surse cunoscute ca retransmisii neautorizate sunt ascunse automat, iar cu „Doar posturi '
              'pentru copii” pornit copilul vede doar desene și emisiuni educative.\n\n'
              'Pe TV: săgețile și OK merg peste tot; în player ▲▼ schimbă postul, OK arată lista, cifrele aleg numărul. '
              'Pe telefon: glisează sus/jos pentru alt post, ține apăsat un post pentru ❤️.',
              style: TextStyle(color: KidColors.textDim, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(color: KidColors.accent, fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class _AddField extends StatefulWidget {
  const _AddField({required this.hint, required this.label, required this.onAdd});
  final String hint;
  final String label;
  final void Function(String) onAdd;

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _ctrl = TextEditingController();

  void _submit() {
    final t = _ctrl.text.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) {
      widget.onAdd(t);
      _ctrl.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Linkul trebuie să înceapă cu http:// sau https://')));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _submit, child: const Text('Adaugă')),
      ],
    ),
  );
}

/// Setează PIN-ul părinților (4 cifre).
Future<void> _setPin(BuildContext context, AppState state) async {
  final ctrl = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('PIN pentru părinți'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: true,
        decoration: const InputDecoration(hintText: '4 cifre'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Renunță')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Salvează')),
      ],
    ),
  );
  if (pin == null || !context.mounted) return;
  if (!ParentPin.isValid(pin)) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN-ul trebuie să aibă exact 4 cifre.')));
    return;
  }
  state.setParentPin(pin);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN-ul a fost salvat.')));
}

/// Toate posturile încărcate: părintele bifează ce nu vrea să vadă copilul.
class _HiddenChannelsScreen extends StatelessWidget {
  const _HiddenChannelsScreen({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.kidsOnly ? state.allChannels.where(KidFilter.isForKids).toList() : state.allChannels;
        return Scaffold(
          appBar: AppBar(title: const Text('Ascunde posturi')),
          body: list.isEmpty
              ? const Center(
                  child: Text('Nu sunt posturi încărcate.', style: TextStyle(color: KidColors.textDim)),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final hidden = state.hiddenChannels.contains(c.key);
                    return SwitchListTile(
                      title: Text(c.name),
                      subtitle: Text(c.categories.isEmpty ? c.sourceName : c.categories.join(' · ')),
                      value: !hidden,
                      onChanged: (_) => state.toggleHidden(c),
                    );
                  },
                ),
        );
      },
    );
  }
}
