import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/atelier.dart';
import '../../theme.dart';
import '../../widgets/kid_tile.dart';

/// Paleta de culori: cercuri mari; cea aleasă are o ramă albă și o bifă.
class PaletteBar extends StatelessWidget {
  const PaletteBar({
    super.key,
    required this.selected,
    required this.onPick,
    this.vertical = false,
    this.colors = kidPalette,
  });
  final Color selected;
  final ValueChanged<Color> onPick;
  final bool vertical;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final c in colors)
        Padding(
          padding: const EdgeInsets.all(4),
          child: KidRoundButton(
            icon: Icons.check_rounded,
            size: 46,
            color: c,
            selected: c == selected,
            onTap: () => onPick(c),
            child: c == selected
                ? Icon(Icons.check_rounded, color: c.computeLuminance() > 0.6 ? Colors.black : Colors.white, size: 26)
                : const SizedBox.shrink(),
          ),
        ),
    ];
    return FocusTraversalGroup(
      child: vertical
          ? SingleChildScrollView(
              child: Wrap(direction: Axis.vertical, children: items),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: items),
            ),
    );
  }
}

/// Bara cu unelte: butoane rotunde cu pictograme și o etichetă mică dedesubt.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
    this.child,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KidRoundButton(
          icon: icon,
          size: 50,
          tooltip: label,
          selected: selected,
          color: color ?? (selected ? KidColors.purple : KidColors.card),
          onTap: onTap,
          child: child,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: KidColors.textDim, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// Salvează ce e desenat sub [key] (un RepaintBoundary) în Galeria mea.
Future<bool> saveArtwork(BuildContext context, GlobalKey key, String kind) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return false;
    await ArtStore().save(kind, data.buffer.asUint8List());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⭐ Bravo! Am pus lucrarea în Galeria mea.', style: TextStyle(fontSize: 18)),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nu am putut salva lucrarea.')));
    }
    return false;
  }
}

/// „Sigur ștergem tot?” cu butoane mari.
Future<bool> confirmClear(BuildContext context, [String text = 'Ștergem tot și o luăm de la capăt?']) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🧽 De la capăt?'),
      content: Text(text, style: const TextStyle(fontSize: 18)),
      actions: [
        FilledButton.tonal(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Nu')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Da, șterge')),
      ],
    ),
  );
  return ok ?? false;
}

/// Ramă albă, rotunjită, pentru foaia de lucru; când e aleasă cu telecomanda devine galbenă.
class Sheet extends StatelessWidget {
  const Sheet({super.key, required this.child, this.focused = false});
  final Widget child;
  final bool focused;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: focused ? KidColors.accent : Colors.white24, width: focused ? 5 : 2),
      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
  );
}

/// Bara de sus a ecranelor din Atelier: Înapoi, titlul și acțiunile.
PreferredSizeWidget atelierBar(BuildContext context, String title, List<Widget> actions) => AppBar(
  toolbarHeight: 64,
  leading: Padding(
    padding: const EdgeInsets.all(6),
    child: IconButton.filledTonal(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
  ),
  title: Text(title),
  actions: [...actions, const SizedBox(width: 8)],
);
