/// Un post TV dintr-o listă M3U.
class Channel {
  Channel({
    required this.key,
    required this.name,
    required this.url,
    required this.categories,
    required this.sourceName,
    this.logo,
    this.tvgId,
    this.userAgent,
    this.referrer,
  });

  final String key;
  final String name;
  final String url;
  final String? logo;
  final String? tvgId;
  final List<String> categories;
  final String? userAgent;
  final String? referrer;
  final String sourceName;

  Map<String, String> get httpHeaders => {'User-Agent': ?userAgent, 'Referer': ?referrer};
}

/// O emisiune din ghidul TV (XMLTV).
class Programme {
  Programme(this.start, this.stop, this.title, this.description);
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;

  bool isLive(DateTime now) => !now.isBefore(start) && now.isBefore(stop);

  double progress(DateTime now) {
    final total = stop.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }
}

/// O listă de canale adăugată de utilizator.
class PlaylistSource {
  PlaylistSource({required this.name, required this.url, this.enabled = true});
  final String name;
  final String url;
  final bool enabled;

  PlaylistSource copyWith({bool? enabled}) => PlaylistSource(name: name, url: url, enabled: enabled ?? this.enabled);

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'enabled': enabled};
  factory PlaylistSource.fromJson(Map<String, dynamic> j) =>
      PlaylistSource(name: j['name'] as String, url: j['url'] as String, enabled: j['enabled'] as bool? ?? true);
}

class ParsedPlaylist {
  ParsedPlaylist(this.channels, this.epgUrls);
  final List<Channel> channels;
  final List<String> epgUrls;
}
