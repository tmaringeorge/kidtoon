import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/ghi_episodes.dart';
import 'ghi_touch.dart';

/// Ecran sănătos: numără timpul cât copilul se uită, cere pauză de clipit la 5 minute
/// și odihnă după limita din Setări (sau după 3 povești la rând). Seara culorile devin mai calde.
class CareController extends ChangeNotifier {
  CareController(this.state) {
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (care.kind == CareKind.rest) return;
      activeMs += 100;
      // Notificăm doar când se schimbă ceva vizibil (nu la fiecare 100 ms).
      final k = care.kind;
      if (k != _lastKind || k == CareKind.blink) {
        _lastKind = k;
        notifyListeners();
      }
    });
  }

  final AppState state;
  Timer? _tick;
  int activeMs = 0;
  int episodesInRow = 0;
  CareKind _lastKind = CareKind.play;

  CareState get care => ScreenCare.state(activeMs, state.sessionLimit, episodesInRow);

  void episodeDone() {
    episodesInRow++;
    notifyListeners();
  }

  void unlock() {
    activeMs = 0;
    episodesInRow = 0;
    _lastKind = CareKind.play;
    notifyListeners();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

/// Pune peste [child] pauza de clipit, odihna și lumina caldă de seară.
class CareView extends StatelessWidget {
  const CareView({super.key, required this.controller, required this.child, this.audioNote = ''});
  final CareController controller;
  final Widget child;
  final String audioNote;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final care = controller.care;
        final now = DateTime.now();
        final evening = ScreenCare.eveningDim(now.hour, now.minute);
        if (care.kind == CareKind.rest) {
          return GhiRest(onUnlock: controller.unlock, name: controller.state.character.name, audioNote: audioNote);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (care.kind == CareKind.blink) GhiBlinkOverlay(ms: care.ms),
            if (evening > 0)
              IgnorePointer(
                child: ColoredBox(color: const Color(0xFF2A1400).withValues(alpha: evening)),
              ),
          ],
        );
      },
    );
  }
}
