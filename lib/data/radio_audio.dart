import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../widgets/kids_timeline.dart';
import 'radio.dart';
import 'repository.dart';

/// Playerul radio comun, care merge și în fundal (ecran stins, altă aplicație),
/// cu notificare de control, ca la YouTube. just_audio_background permite un
/// singur player, așa că îl păstrăm pe tot parcursul aplicației.
class RadioAudio {
  RadioAudio._() {
    // Melodia sau emisiunea, dacă postul o trimite în stream (ICY StreamTitle).
    player.icyMetadataStream.listen((m) => nowPlaying.value = NowPlaying.clean(m?.info?.title, _stationName));
  }
  static final instance = RadioAudio._();

  final player = AudioPlayer(userAgent: Repository.userAgent);

  /// Ce cântă acum (null dacă postul nu trimite).
  final nowPlaying = ValueNotifier<String?>(null);
  String _stationName = '';

  /// Minutele rămase până la oprirea automată (0 = fără temporizator).
  final sleepLeft = ValueNotifier<int>(0);
  Timer? _sleepTick;
  DateTime? _sleepEnd;

  Future<void> play(RadioStation s) async {
    _stationName = s.name;
    nowPlaying.value = null;
    await player.stop();
    final source = AudioSource.uri(
      Uri.parse(s.streamUrl),
      headers: const {'User-Agent': Repository.userAgent},
      tag: MediaItem(
        id: s.id,
        title: s.name,
        artist: 'KidToon Radio',
        artUri: s.logo == null ? null : Uri.tryParse(s.logo!),
      ),
    );
    await player.setAudioSource(source);
    unawaited(player.play());
  }

  Future<void> stop() async {
    setSleep(0);
    await player.stop();
  }

  /// Pornește (sau anulează, cu 0) temporizatorul de somn.
  void setSleep(int minutes) {
    _sleepTick?.cancel();
    if (minutes <= 0) {
      _sleepEnd = null;
      sleepLeft.value = 0;
      return;
    }
    _sleepEnd = DateTime.now().add(Duration(minutes: minutes));
    sleepLeft.value = minutes;
    _sleepTick = Timer.periodic(const Duration(seconds: 15), (_) => _checkSleep());
  }

  void _checkSleep() {
    final end = _sleepEnd;
    if (end == null) return;
    final left = end.difference(DateTime.now());
    if (left <= Duration.zero) {
      setSleep(0);
      player.pause();
    } else {
      sleepLeft.value = (left.inSeconds / 60).ceil();
    }
  }
}
