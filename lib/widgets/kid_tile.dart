import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// O placă mare, colorată, pentru copii: se apasă cu degetul sau se alege cu telecomanda
/// (când e aleasă se mărește puțin și primește o ramă albă).
class KidTile extends StatefulWidget {
  const KidTile({
    super.key,
    required this.color,
    required this.onTap,
    this.emoji,
    this.title,
    this.subtitle,
    this.child,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.selected = false,
    this.radius = 26,
  });

  final Color color;
  final String? emoji;
  final String? title;
  final String? subtitle;
  final Widget? child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool selected;
  final double radius;

  @override
  State<KidTile> createState() => _KidTileState();
}

class _KidTileState extends State<KidTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    final content =
        widget.child ??
        LayoutBuilder(
          builder: (context, box) {
            final h = box.maxHeight.isFinite ? box.maxHeight : 160.0;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.emoji != null)
                    Flexible(
                      child: FittedBox(
                        child: Text(widget.emoji!, style: TextStyle(fontSize: (h * 0.42).clamp(28, 96))),
                      ),
                    ),
                  if (widget.title != null)
                    Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (h * 0.13).clamp(15, 26),
                        fontWeight: FontWeight.w900,
                        shadows: const [Shadow(color: Color(0x55000000), offset: Offset(1, 2), blurRadius: 4)],
                      ),
                    ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: const Color(0xE6FFFFFF), fontSize: (h * 0.085).clamp(11, 16)),
                    ),
                ],
              ),
            );
          },
        );
    final on = _focused || widget.selected;
    return AnimatedScale(
      scale: _focused ? 1.06 : 1,
      duration: const Duration(milliseconds: 140),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: on ? KidColors.focus : Colors.transparent, width: 4),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _focused ? 0.7 : 0.35),
              blurRadius: _focused ? 22 : 10,
              offset: const Offset(0, 6),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(widget.color, Colors.white, 0.18)!, widget.color],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            onFocusChange: (f) => setState(() => _focused = f),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            focusColor: Colors.transparent,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Buton rotund mare, cu pictogramă (pentru bara de unelte din Atelier și din player).
class KidRoundButton extends StatelessWidget {
  const KidRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = KidColors.card,
    this.iconColor = Colors.white,
    this.size = 56,
    this.tooltip,
    this.selected = false,
    this.child,
    this.autofocus = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;
  final String? tooltip;
  final bool selected;
  final Widget? child;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final b = _FocusRing(
      selected: selected,
      shape: const CircleBorder(),
      builder: (focused) => Material(
        color: color,
        shape: CircleBorder(
          side: BorderSide(color: focused || selected ? KidColors.focus : Colors.transparent, width: 3.5),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          autofocus: autofocus,
          onTap: onTap,
          focusColor: Colors.transparent,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: child ?? Icon(icon, color: iconColor, size: size * 0.5),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Ține minte dacă butonul dinăuntru e ales cu telecomanda și îl mărește puțin.
class _FocusRing extends StatefulWidget {
  const _FocusRing({required this.builder, required this.shape, this.selected = false});
  final Widget Function(bool focused) builder;
  final ShapeBorder shape;
  final bool selected;

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (f) => setState(() => _focused = f),
    child: AnimatedScale(
      scale: _focused ? 1.12 : 1,
      duration: const Duration(milliseconds: 120),
      child: widget.builder(_focused),
    ),
  );
}

/// Tastele telecomenzii, ca să nu le scriem peste tot.
class Remote {
  static bool isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.gameButtonA;

  static bool isDown(KeyEvent e) => e is KeyDownEvent || e is KeyRepeatEvent;
}
