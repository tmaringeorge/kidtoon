import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../data/ghi_episodes.dart' show CareKind;
import '../data/models.dart';
import '../data/repository.dart';
import '../theme.dart';
import '../widgets/channel_widgets.dart';
import '../widgets/kid_tile.dart' show Remote;
import '../widgets/screen_care.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.state, required this.list, required this.index});
  final AppState state;
  final List<Channel> list;
  final int index;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _index = widget.index;
  VideoPlayerController? _controller;
  String? _error;
  bool _overlay = true;
  Timer? _hideTimer;
  int _token = 0;
  // Ecran sănătos și numărul de post tastat din cifre (pe telecomandă).
  late final _care = CareController(widget.state)..addListener(_careChanged);
  bool _resting = false;
  String _digits = '';
  Timer? _digitTimer;

  Channel get _channel => widget.list[_index];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open();
  }

  Future<void> _open() async {
    final token = ++_token;
    final ch = _channel;
    final old = _controller;
    setState(() {
      _controller = null;
      _error = null;
    });
    await old?.dispose();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(ch.url),
      httpHeaders: {'User-Agent': Repository.userAgent, ...ch.httpHeaders},
      formatHint: ch.url.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null,
    );
    try {
      await c.initialize();
      if (token != _token) {
        await c.dispose();
        return;
      }
      await c.play();
      setState(() => _controller = c);
      widget.state.markWatched(ch);
    } catch (_) {
      await c.dispose();
      if (token != _token) return;
      setState(() => _error = 'Desenele nu merg acum pe acest post. Încearcă alt post! ▲▼');
    }
    _showOverlay();
  }

  /// La odihnă desenul se oprește; după deblocarea părintelui pornește din nou.
  void _careChanged() {
    final rest = _care.care.kind == CareKind.rest;
    if (rest == _resting) return;
    _resting = rest;
    rest ? _controller?.pause() : _controller?.play();
  }

  /// Telecomanda: ▲▼ / CH± schimbă postul, OK arată informațiile sau lista, cifrele aleg numărul.
  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (!Remote.isDown(e) || _resting) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp) {
      _zap(-1);
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) {
      _zap(1);
    } else if (Remote.isOk(k)) {
      _overlay ? _openList() : _showOverlay();
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      _showOverlay();
    } else {
      final d = int.tryParse(k.keyLabel);
      if (d == null || k.keyLabel.length != 1) return KeyEventResult.ignored;
      setState(() => _digits = ('$_digits$d').substring(0, min(3, _digits.length + 1)));
      _digitTimer?.cancel();
      _digitTimer = Timer(const Duration(milliseconds: 1500), () {
        final n = int.tryParse(_digits) ?? 0;
        setState(() => _digits = '');
        if (n >= 1 && n <= widget.list.length) {
          setState(() => _index = n - 1);
          _open();
        }
      });
    }
    return KeyEventResult.handled;
  }

  void _zap(int delta) {
    setState(() => _index = (_index + delta + widget.list.length) % widget.list.length);
    _open();
  }

  void _showOverlay() {
    setState(() => _overlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  void _toggleOrientation() {
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    SystemChrome.setPreferredOrientations(
      landscape ? [DeviceOrientation.portraitUp] : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
    );
  }

  void _openList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KidColors.panel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView.builder(
          controller: scroll,
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom + 8),
          itemCount: widget.list.length,
          itemBuilder: (ctx, i) {
            final ch = widget.list[i];
            final (live, _) = widget.state.epg.nowAndNext(ch, DateTime.now());
            return ListTile(
              selected: i == _index,
              selectedColor: KidColors.accent,
              leading: ChannelLogo(ch, size: 34),
              title: Text('${widget.state.numberOf(ch)}. ${ch.name}'),
              subtitle: live == null ? null : Text(live.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _index = i);
                _open();
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _token++;
    _hideTimer?.cancel();
    _digitTimer?.cancel();
    _care.dispose();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _key,
        child: CareView(
          controller: _care,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _overlay ? setState(() => _overlay = false) : _showOverlay(),
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -300) _zap(1);
              if (v > 300) _zap(-1);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: c != null && c.value.isInitialized
                      ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                      : _error == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        ),
                ),
                AnimatedOpacity(
                  opacity: _overlay ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  // Pe TV butoanele nu iau focusul: telecomanda e pentru posturi (▲▼, OK, cifre).
                  child: IgnorePointer(
                    ignoring: !_overlay,
                    child: ExcludeFocus(child: _buildOverlay()),
                  ),
                ),
                if (_digits.isNotEmpty)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_digits, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final ch = _channel;
    final now = DateTime.now();
    final (live, next) = widget.state.epg.nowAndNext(ch, now);
    final fav = widget.state.favorites.contains(ch.key);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xAA000000), Colors.transparent, Colors.transparent, Color(0xE6000000)],
          stops: [0, 0.25, 0.55, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Text(hhmm(now), style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? KidColors.live : null),
                  onPressed: () => setState(() => widget.state.toggleFavorite(ch)),
                ),
                IconButton(icon: const Icon(Icons.list), onPressed: _openList),
                IconButton(icon: const Icon(Icons.screen_rotation), onPressed: _toggleOrientation),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ChannelLogo(ch, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.state.numberOf(ch)}  ${ch.name}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (live != null) ...[
                          const SizedBox(height: 4),
                          Text('Acum: ${live.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(hhmm(live.start), style: const TextStyle(fontSize: 11, color: KidColors.textDim)),
                              const SizedBox(width: 8),
                              Expanded(child: ProgressLine(live.progress(now))),
                              const SizedBox(width: 8),
                              Text(hhmm(live.stop), style: const TextStyle(fontSize: 11, color: KidColors.textDim)),
                            ],
                          ),
                        ] else
                          Text(
                            ch.categories.isEmpty ? 'În direct' : ch.categories.join(' · '),
                            style: const TextStyle(color: KidColors.textDim),
                          ),
                        if (next != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Urmează ${hhmm(next.start)}: ${next.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: KidColors.textDim, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => _zap(-1)),
                      IconButton.filledTonal(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => _zap(1)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
