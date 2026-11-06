import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';

class ChannelLogo extends StatelessWidget {
  const ChannelLogo(this.channel, {super.key, this.size = 56});
  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        channel.name.characters.take(2).toString().toUpperCase(),
        style: TextStyle(color: KidColors.textDim, fontWeight: FontWeight.w900, fontSize: size * 0.32),
      ),
    );
    return Container(
      width: size * 1.6,
      height: size,
      decoration: BoxDecoration(color: KidColors.logoBox, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(6),
      child: channel.logo == null
          ? fallback
          : Image.network(channel.logo!, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 3,
      backgroundColor: KidColors.logoBox,
      color: KidColors.accent,
    ),
  );
}
