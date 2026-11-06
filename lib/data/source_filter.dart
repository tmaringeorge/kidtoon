/// Filtru de siguranță: ascunde stream-urile care sunt, cu mare probabilitate,
/// retransmisii neautorizate (domenii de unică folosință, panouri IPTV etc).
class SourceFilter {
  static const _blockedSuffixes = ['.cfd', '.sbs', '.click', '.xyz', '.top', '.shop', '.online'];
  static const _blockedParts = ['cool-tv', 'vip-acasatv', 'xykt-fix', 'megogo', 'vcdn.biz'];
  static final _xtream = RegExp(r'/(live/)?[A-Za-z0-9]{4,}/[A-Za-z0-9]{4,}/\d+(\.(ts|m3u8))?$');

  static bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (_blockedSuffixes.any(host.endsWith)) return false;
    if (_blockedParts.any(host.contains)) return false;
    if (_xtream.hasMatch(uri.path)) return false;
    return true;
  }
}
