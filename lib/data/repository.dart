import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'm3u_parser.dart';
import 'models.dart';
import 'source_filter.dart';
import 'xmltv.dart';

class LoadResult {
  LoadResult(this.channels, this.epgUrls, this.errors, this.filteredOut);
  final List<Channel> channels;
  final List<String> epgUrls;
  final List<String> errors;
  final int filteredOut;
}

class Repository {
  static const builtInAsset = 'assets/copii.m3u';
  static const builtInName = 'Lista KidToon';
  static const userAgent = 'KidToon/1.0 (Android)';

  final _client = http.Client();

  Future<LoadResult> loadChannels({required bool builtIn, required List<PlaylistSource> playlists}) async {
    final errors = <String>[];
    final parsed = <ParsedPlaylist>[];
    if (builtIn) {
      parsed.add(M3uParser.parse(await rootBundle.loadString(builtInAsset), builtInName));
    }
    final remote = await Future.wait(
      playlists.where((p) => p.enabled).map((src) async {
        try {
          final bytes = await _fetchCached(src.url, const Duration(hours: 6));
          return M3uParser.parse(utf8.decode(bytes, allowMalformed: true), src.name);
        } catch (e) {
          errors.add('${src.name}: $e');
          return null;
        }
      }),
    );
    parsed.addAll(remote.whereType<ParsedPlaylist>());

    final all = parsed.expand((p) => p.channels).toList();
    final allowed = all.where((c) => SourceFilter.isAllowed(c.url)).toList();
    final seen = <String>{};
    final unique = allowed.where((c) => seen.add(c.url)).toList();
    return LoadResult(unique, parsed.expand((p) => p.epgUrls).toSet().toList(), errors, all.length - allowed.length);
  }

  Future<Epg> loadEpg(List<String> urls) async {
    if (urls.isEmpty) return Epg.empty;
    final parts = await Future.wait(
      urls.map((url) async {
        try {
          var bytes = await _fetchCached(url, const Duration(hours: 12));
          if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) bytes = gzip.decode(bytes);
          final text = utf8.decode(bytes, allowMalformed: true);
          // Fișierele XMLTV pot fi mari: parsarea rulează în alt isolate.
          return await compute(_parseEpg, text);
        } catch (_) {
          return null;
        }
      }),
    );
    return Epg.merge(parts.whereType<Epg>().toList());
  }

  static Epg _parseEpg(String text) => XmlTvParser.parse(text);

  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      if (f is File) await f.setLastModified(DateTime.fromMillisecondsSinceEpoch(0));
    }
  }

  Future<Directory> _cacheDir() async =>
      Directory('${(await getTemporaryDirectory()).path}/downloads').create(recursive: true);

  /// Descarcă și păstrează în cache; la eroare de rețea folosește copia veche.
  Future<List<int>> _fetchCached(String url, Duration maxAge) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/${sha1.convert(utf8.encode(url))}');
    final exists = await file.exists();
    if (exists && DateTime.now().difference(await file.lastModified()) < maxAge) {
      return file.readAsBytes();
    }
    try {
      final resp = await _client
          .get(Uri.parse(url), headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return resp.bodyBytes;
    } catch (e) {
      if (exists) return file.readAsBytes();
      rethrow;
    }
  }
}
