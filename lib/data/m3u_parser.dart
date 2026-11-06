import 'categories.dart';
import 'models.dart';

/// Parser pentru liste M3U extinse (formatul iptv-org și al majorității
/// furnizorilor): tvg-id, tvg-logo, group-title, url-tvg, user-agent, referrer.
class M3uParser {
  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  static ParsedPlaylist parse(String text, String sourceName) {
    final channels = <Channel>[];
    final epgUrls = <String>[];
    String? info, ua, ref, grp;

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTM3U')) {
        _attrs(line).forEach((k, v) {
          if (k == 'url-tvg' || k == 'x-tvg-url') {
            epgUrls.addAll(v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
          }
        });
      } else if (line.startsWith('#EXTINF')) {
        info = line;
        ua = null;
        ref = null;
        grp = null;
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring('#EXTVLCOPT:'.length);
        if (opt.startsWith('http-user-agent=')) ua = opt.substring(opt.indexOf('=') + 1);
        if (opt.startsWith('http-referrer=')) ref = opt.substring(opt.indexOf('=') + 1);
      } else if (line.startsWith('#EXTGRP:')) {
        grp = line.substring(8).trim();
      } else if (line.startsWith('#')) {
        continue;
      } else {
        if (info != null) {
          final ch = _build(info, line, ua, ref, grp, sourceName);
          if (ch != null) channels.add(ch);
        }
        info = null;
      }
    }
    return ParsedPlaylist(channels, epgUrls.toSet().toList());
  }

  static Map<String, String> _attrs(String line) => {
    for (final m in _attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!,
  };

  static Channel? _build(String info, String url, String? ua, String? ref, String? grp, String source) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    final a = _attrs(info);
    var name = _nameOf(info);
    if (name.isEmpty) name = a['tvg-name'] ?? '';
    if (name.isEmpty) return null;
    final groups = (a['group-title'] ?? grp ?? '')
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'undefined')
        .map(Categories.localize)
        .toSet()
        .toList();
    final tvgId = (a['tvg-id']?.isNotEmpty ?? false) ? a['tvg-id'] : null;
    final logo = (a['tvg-logo']?.isNotEmpty ?? false) ? a['tvg-logo'] : null;
    return Channel(
      key: '${tvgId ?? name}|${url.hashCode.toRadixString(16)}',
      name: cleanName(name),
      url: url,
      logo: logo,
      tvgId: tvgId,
      categories: groups,
      userAgent: ua ?? a['http-user-agent'],
      referrer: ref ?? a['http-referrer'],
      sourceName: source,
    );
  }

  static String _nameOf(String info) {
    // Numele e după prima virgulă din afara ghilimelelor (poate conține și el virgule).
    var inQuotes = false;
    for (var i = 0; i < info.length; i++) {
      final c = info[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        return info.substring(i + 1).trim();
      }
    }
    return '';
  }

  /// Scoate sufixe ca „(1080p)” sau „[Not 24/7]”.
  static String cleanName(String name) =>
      name.replaceAll(RegExp(r'\s*\((\d{3,4}[pi])\)'), '').replaceAll(RegExp(r'\s*\[[^\]]*]'), '').trim();
}
