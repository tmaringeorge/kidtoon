import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/parental.dart';
import '../theme.dart';

/// Poarta părinților: înainte de Setări, surse noi, modul Adult sau Studio.
/// Fără PIN: o înmulțire cu 4 variante. Cu PIN: tastatură cu cifre mari (merge și cu telecomanda).
class ParentGate {
  static Future<bool> open(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _GateDialog(pin: state.parentPin, onForgot: () => state.setParentPin('')),
    );
    return ok ?? false;
  }

  /// Deschide [page] doar dacă trece de poartă.
  static Future<void> push(BuildContext context, AppState state, WidgetBuilder page) async {
    if (!await open(context, state) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: page));
  }
}

class _GateDialog extends StatefulWidget {
  const _GateDialog({required this.pin, required this.onForgot});
  final String pin;
  final VoidCallback onForgot;

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  late bool _usePin = widget.pin.isNotEmpty;
  var _q = ParentQuestion.random();
  late var _choices = _q.choices();
  String _typed = '';
  String? _error;

  void _answer(int v) {
    if (_q.check(v)) {
      // Cine a uitat PIN-ul și a răspuns corect: PIN-ul se șterge (se poate pune altul din Setări).
      if (widget.pin.isNotEmpty) widget.onForgot();
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _error = 'Nu e corect. Încearcă din nou.';
      _q = ParentQuestion.random();
      _choices = _q.choices();
    });
  }

  void _digit(String d) {
    if (_typed.length >= 4) return;
    setState(() {
      _typed += d;
      _error = null;
    });
    if (_typed.length == 4) {
      if (_typed == widget.pin) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _typed = '';
          _error = 'PIN greșit.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KidColors.panel,
      title: const Row(
        children: [
          Icon(Icons.lock_rounded, color: KidColors.accent),
          SizedBox(width: 10),
          Text('Doar pentru părinți'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: _usePin ? _pinPad() : _question()),
      ),
      actions: [
        if (_usePin)
          TextButton(
            onPressed: () => setState(() {
              _usePin = false;
              _error = null;
            }),
            child: const Text('Am uitat PIN-ul'),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Renunță')),
      ],
    );
  }

  List<Widget> _question() => [
    if (widget.pin.isNotEmpty)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'Răspunde corect și PIN-ul se șterge; poți pune altul din Setări.',
          style: TextStyle(color: KidColors.textDim),
        ),
      ),
    Text(_q.text, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
    const SizedBox(height: 16),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _choices.length; i++)
          SizedBox(
            width: 150,
            height: 60,
            child: FilledButton.tonal(
              autofocus: i == 0,
              onPressed: () => _answer(_choices[i]),
              child: Text('${_choices[i]}', style: const TextStyle(fontSize: 24)),
            ),
          ),
      ],
    ),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, style: const TextStyle(color: KidColors.live)),
      ),
  ];

  List<Widget> _pinPad() => [
    const Text('Introdu PIN-ul', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.all(6),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _typed.length ? KidColors.accent : Colors.transparent,
              border: Border.all(color: KidColors.accent, width: 2),
            ),
          ),
      ],
    ),
    const SizedBox(height: 8),
    for (final row in const [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', ''],
    ])
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final d in row)
            Padding(
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                width: 72,
                height: 56,
                child: d.isEmpty
                    ? null
                    : FilledButton.tonal(
                        autofocus: d == '1',
                        onPressed: () => d == '⌫'
                            ? setState(() => _typed = _typed.isEmpty ? '' : _typed.substring(0, _typed.length - 1))
                            : _digit(d),
                        child: Text(d, style: const TextStyle(fontSize: 24)),
                      ),
              ),
            ),
        ],
      ),
    if (_error != null) Text(_error!, style: const TextStyle(color: KidColors.live)),
  ];
}
