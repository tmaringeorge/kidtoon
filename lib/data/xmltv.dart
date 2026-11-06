import 'package:xml/xml_events.dart';

import 'm3u_parser.dart';
import 'models.dart';

/// Ghid TV: emisiuni pe canal, căutare după tvg-id sau după nume.
class Epg {
  Epg(this._byId, this._idByName);
  static final empty = Epg({}, {});

  final Map<String, List<Programme>> _byId;
  final Map<String, String> _idByName;

  bool get isEmpty => _byId.isEmpty;

  static String normalize(String name) =>
      M3uParser.cleanName(name)
          .toLowerCase()
          .replaceAll(RegExp(r'\b(hd|fhd|uhd|4k|sd|tv)\b'), '')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<Programme> programmesFor(Channel ch) {
    final id = ch.tvgId;
    if (id != null) {
      final direct = _byId[id] ?? _byId[id.split('@').first];
      if (direct != null) return direct;
    }
    final byName = _idByName[normalize(ch.name)];
    return byName == null ? const [] : (_byId[byName] ?? const []);
  }

  (Programme?, Programme?) nowAndNext(Channel ch, DateTime now) {
    final list = programmesFor(ch);
    final idx = list.indexWhere((p) => p.isLive(now));
    if (idx < 0) {
      final next = list.where((p) => p.start.isAfter(now)).firstOrNull;
      return (null, next);
    }
    return (list[idx], idx + 1 < list.length ? list[idx + 1] : null);
  }

  static Epg merge(List<Epg> parts) {
    if (parts.isEmpty) return empty;
    if (parts.length == 1) return parts.first;
    final ids = <String, List<Programme>>{};
    final names = <String, String>{};
    for (final p in parts) {
      ids.addAll(p._byId);
      names.addAll(p._idByName);
    }
    return Epg(ids, names);
  }
}

/// Parser XMLTV în flux; păstrează doar o fereastră de timp în jurul lui „acum”.
class XmlTvParser {
  static Epg parse(String xml, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final from = t.subtract(const Duration(hours: 3));
    final to = t.add(const Duration(hours: 36));

    final programmes = <String, List<Programme>>{};
    final idByName = <String, String>{};

    String? channelId, progChannel, title, desc, target;
    DateTime? start, stop;

    for (final e in parseEvents(xml)) {
      if (e is XmlStartElementEvent) {
        String? attr(String n) => e.attributes.where((a) => a.name == n).firstOrNull?.value;
        switch (e.name) {
          case 'channel':
            channelId = attr('id');
          case 'display-name':
            if (channelId != null) target = 'display-name';
          case 'programme':
            progChannel = attr('channel');
            start = parseTime(attr('start'));
            stop = parseTime(attr('stop'));
            title = null;
            desc = null;
            if (e.isSelfClosing) progChannel = null;
          case 'title':
            if (progChannel != null && title == null) target = 'title';
          case 'desc':
            if (progChannel != null && desc == null) target = 'desc';
        }
      } else if (e is XmlTextEvent || e is XmlCDATAEvent) {
        final text = (e is XmlTextEvent ? e.value : (e as XmlCDATAEvent).value).trim();
        if (text.isEmpty) continue;
        switch (target) {
          case 'display-name':
            idByName.putIfAbsent(Epg.normalize(text), () => channelId!);
          case 'title':
            title = text;
          case 'desc':
            desc = text;
        }
      } else if (e is XmlEndElementEvent) {
        if (e.name == 'channel') channelId = null;
        if (e.name == 'programme') {
          final ch = progChannel, tt = title, s = start, st = stop;
          if (ch != null && tt != null && s != null && st != null && st.isAfter(from) && s.isBefore(to)) {
            programmes.putIfAbsent(ch, () => []).add(Programme(s, st, tt, desc));
          }
          progChannel = null;
        }
        target = null;
      }
    }
    for (final l in programmes.values) {
      l.sort((a, b) => a.start.compareTo(b.start));
    }
    return Epg(programmes, idByName);
  }

  /// Format XMLTV: „20241101203000 +0200”.
  static DateTime? parseTime(String? v) {
    if (v == null) return null;
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?').firstMatch(v.trim());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    var dt = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
    final tz = m.group(7);
    if (tz != null) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final offset = Duration(hours: int.parse(tz.substring(1, 3)), minutes: int.parse(tz.substring(3, 5)));
      dt = sign > 0 ? dt.subtract(offset) : dt.add(offset);
    }
    return dt.toLocal();
  }
}
