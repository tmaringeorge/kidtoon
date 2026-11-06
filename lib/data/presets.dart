import 'models.dart';

/// Surse publice sugerate în Setări (utilizatorul alege dacă le adaugă).
class Presets {
  /// Lista pornită implicit: desene animate și emisiuni pentru copii, publice.
  static final kids = PlaylistSource(
    name: 'Desene animate (iptv-org · Copii)',
    url: 'https://iptv-org.github.io/iptv/categories/kids.m3u',
  );

  static final playlists = [
    PlaylistSource(name: 'iptv-org · Copii', url: 'https://iptv-org.github.io/iptv/categories/kids.m3u'),
    PlaylistSource(name: 'iptv-org · Animație', url: 'https://iptv-org.github.io/iptv/categories/animation.m3u'),
    PlaylistSource(name: 'iptv-org · Educație', url: 'https://iptv-org.github.io/iptv/categories/education.m3u'),
    PlaylistSource(name: 'iptv-org · Familie', url: 'https://iptv-org.github.io/iptv/categories/family.m3u'),
    PlaylistSource(
      name: 'iptv-org · România (filtrat pentru copii)',
      url: 'https://iptv-org.github.io/iptv/countries/ro.m3u',
    ),
  ];

  static const epg = ['https://epgshare01.online/epgshare01/epg_ripper_RO1.xml.gz'];
}
