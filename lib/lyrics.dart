import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class LyricLine {
  final Duration at;
  final String text;
  const LyricLine(this.at, this.text);
}

class Lyrics {
  final List<LyricLine> synced;
  final String plain;
  final String source;
  final bool estimated;
  const Lyrics(this.synced, this.plain, this.source, {this.estimated = false});

  Map<String, dynamic> toJson() => {
        'version': 2,
        'plain': plain,
        'source': source,
        'estimated': estimated,
        'lines': [
          for (final l in synced) [l.at.inMilliseconds, l.text],
        ],
      };

  factory Lyrics.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 2) {
      throw const FormatException('Unsupported lyrics cache version');
    }
    return Lyrics(
      [
        for (final x in (j['lines'] as List))
          LyricLine(Duration(milliseconds: x[0] as int), x[1] as String),
      ],
      j['plain'] as String,
      j['source'] as String,
      estimated: (j['estimated'] as bool?) ?? false,
    );
  }
}

final lyricsService = LyricsService();

const _browserUa =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

/// Busca primero letras sincronizadas y usa fuentes de texto como alternativa.
class LyricsService {
  final _cache = <String, Future<Lyrics?>>{};
  final _client = http.Client();
  io.Directory? _dir;

  /// Lo ultimo que se intento por cancion (se muestra si no hay letra).
  final Map<String, List<String>> tried = {};

  static final _tag = RegExp(r'<\d+:\d+(?:\.\d+)?>');
  static final _lrc = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
  static final _wordTag = RegExp(r'<(\d+):(\d+(?:\.\d+)?)>');
  static final _offset =
      RegExp(r'^\[offset:([+-]?\d+)\]$', caseSensitive: false);

  Future<Lyrics?> get(Track t) => _cache.putIfAbsent(t.id, () => _load(t));

  Future<Lyrics?> _load(Track t) async {
    final saved = await _readDisk(t.id);
    if (saved != null) return saved;
    final found = await _fetch(t);
    if (found != null) {
      _writeDisk(t.id, found);
    } else {
      _cache.remove(t.id); // sin letra: se vuelve a intentar la proxima vez
    }
    return found;
  }

  /// Borra la letra guardada de una cancion (para buscarla otra vez).
  Future<void> forget(String id) async {
    _cache.remove(id);
    tried.remove(id);
    try {
      final f = await _file(id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<io.File> _file(String id) async {
    var d = _dir;
    if (d == null) {
      final docs = await getApplicationDocumentsDirectory();
      d = io.Directory('${docs.path}/lyrics');
      _dir = d;
    }
    if (!await d.exists()) await d.create(recursive: true);
    return io.File('${d.path}/$id.json');
  }

  Future<Lyrics?> _readDisk(String id) async {
    try {
      final f = await _file(id);
      if (!await f.exists()) return null;
      return Lyrics.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String id, Lyrics l) async {
    try {
      final f = await _file(id);
      await f.writeAsString(jsonEncode(l.toJson()));
    } catch (_) {}
  }

  static const _acc = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static String _fold(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      b.write(_acc[ch] ?? ch);
    }
    return b.toString();
  }

  static String _slug(String s) => _fold(s)
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String _clean(String s) => s
      .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'\s*\|.*$'), '')
      .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _song(String s) => s
      .replaceAll(
          RegExp(r'\s+(?:ft|feat|featuring)\.?\s.*$', caseSensitive: false), '')
      .replaceAll(
          RegExp(r'\s*-\s*(?:remaster(?:ed)?|live|version|sped up|slowed).*$',
              caseSensitive: false),
          '')
      .trim();

  Future<Lyrics?> _fetch(Track t) async {
    final dbg = tried.putIfAbsent(t.id, () => <String>[]);
    dbg.clear();
    final title = _clean(t.title);
    final trackTitle = _clean(t.displayTitle);
    final artist = _clean(t.artist)
        .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
        .trim();
    final artistGuess = artist;
    final songGuess = _song(trackTitle.isNotEmpty ? trackTitle : title);
    final queryTitle = _song(title);

    // 1) LRCLIB
    if (artistGuess.isNotEmpty && songGuess.isNotEmpty) {
      try {
        final uri = Uri.https('lrclib.net', '/api/get', {
          'artist_name': artistGuess,
          'track_name': songGuess,
          if (t.seconds != null) 'duration': '${t.seconds}',
        });
        final r = await _client.get(uri, headers: {
          'User-Agent': 'JaiPlay/1.0'
        }).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final data = jsonDecode(utf8.decode(r.bodyBytes));
          if (data is Map<String, dynamic>) {
            final found = _pick(
              [data],
              t.seconds,
              expectedArtist: artistGuess,
              expectedTitle: songGuess,
            );
            if (found != null && found.synced.isNotEmpty) return found;
          }
        }
      } catch (e) {
        dbg.add('LRCLIB exact: $e');
      }
    }

    final searchQueries = <Map<String, String>>[
      if (artistGuess.isNotEmpty)
        {'artist_name': artistGuess, 'track_name': songGuess},
      {'q': songGuess},
      if (artistGuess.isNotEmpty) {'q': '$artistGuess $songGuess'},
      if (queryTitle != songGuess) {'q': queryTitle},
      {'q': title},
    ];
    final seenQueries = <String>{};
    for (final params in searchQueries) {
      final queryKey =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      if (!seenQueries.add(queryKey)) continue;
      try {
        final uri = Uri.https('lrclib.net', '/api/search', params);
        final r = await _client.get(uri, headers: {
          'User-Agent': 'JaiPlay/1.0'
        }).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) {
          dbg.add('LRCLIB search HTTP ${r.statusCode}');
          continue;
        }
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        if (data is! List) continue;
        final found = _pick(
          data.whereType<Map<String, dynamic>>().toList(),
          t.seconds,
          expectedArtist: artistGuess,
          expectedTitle: songGuess,
        );
        if (found != null && found.synced.isNotEmpty) return found;
      } catch (e) {
        dbg.add('LRCLIB search: $e');
      }
    }

    // 2) Lyrics.ovh returns plain text where synchronized lyrics are absent.
    if (artistGuess.isNotEmpty && songGuess.isNotEmpty) {
      try {
        final uri = Uri.https(
          'api.lyrics.ovh',
          '/v1/$artistGuess/$songGuess',
        );
        final r = await _client.get(uri, headers: {
          'User-Agent': 'JaiPlay/1.0'
        }).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final data = jsonDecode(utf8.decode(r.bodyBytes));
          if (data is Map<String, dynamic>) {
            final text = (data['lyrics'] as String?)?.trim() ?? '';
            if (text.length >= 20) {
              return Lyrics(const [], text, 'Lyrics.ovh');
            }
          }
        } else {
          dbg.add('Lyrics.ovh HTTP ${r.statusCode}');
        }
      } catch (e) {
        dbg.add('Lyrics.ovh: $e');
      }
    }

    // 3) Letras.com
    final combos = <List<String>>[
      [artistGuess, songGuess],
      if (artist.isNotEmpty) [artist, songGuess],
      [artistGuess, queryTitle],
    ];
    final seen = <String>{};
    for (final c in combos) {
      final a = _slug(c[0]);
      final s = _slug(c[1]);
      if (a.isEmpty || s.isEmpty) continue;
      final url = 'https://www.letras.com/$a/$s/';
      if (!seen.add(url)) continue;
      try {
        final r = await _client.get(Uri.parse(url), headers: {
          'User-Agent': _browserUa,
          'Accept-Language': 'es-ES,es;q=0.9',
        }).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) {
          dbg.add('${r.statusCode}  letras.com/$a/$s');
          continue;
        }
        final txt =
            _parseLetras(utf8.decode(r.bodyBytes, allowMalformed: true));
        if (txt == null) {
          dbg.add('sin texto  letras.com/$a/$s');
          continue;
        }
        return Lyrics(const [], txt, 'Letras.com');
      } catch (_) {
        dbg.add('error  letras.com/$a/$s');
      }
    }
    return null;
  }

  static String? _parseLetras(String html) {
    final m = RegExp(
      r'<div[^>]*class="[^"]*(?:lyric-original|cnt-letra)[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    var t = m
        .group(1)!
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    t = _unescape(t).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return t.length < 20 ? null : t;
  }

  static String _unescape(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)));

  static Duration _dur(String m, String s) => Duration(
      milliseconds: ((int.parse(m) * 60 + double.parse(s)) * 1000).round());

  static Lyrics? _pick(
    List<Map<String, dynamic>> list,
    int? secs, {
    required String expectedArtist,
    required String expectedTitle,
  }) {
    Map<String, dynamic>? best;
    var bestScore = double.negativeInfinity;
    for (final m in list) {
      if (m['instrumental'] == true) continue;
      final synced = (m['syncedLyrics'] as String?) ?? '';
      final plain = (m['plainLyrics'] as String?) ?? '';
      if (synced.isEmpty && plain.isEmpty) continue;
      final actualTitle = (m['trackName'] as String?) ?? '';
      final actualArtist = (m['artistName'] as String?) ?? '';
      final titleScore = _matchScore(expectedTitle, actualTitle);
      final artistScore = expectedArtist.trim().isEmpty
          ? 1
          : _matchScore(expectedArtist, actualArtist);
      if (titleScore < 0.65 || artistScore < 0.45) continue;

      var score = titleScore * 6 + artistScore * 3;
      if (synced.isNotEmpty) score += 2;
      final dur = (m['duration'] as num?)?.toDouble();
      if (secs != null && dur != null) {
        final diff = (dur - secs).abs();
        if (diff > 20) continue;
        score += diff <= 3
            ? 3
            : diff <= 8
                ? 2
                : 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    if (best == null) return null;
    final synced = (best['syncedLyrics'] as String?) ?? '';
    final plain = (best['plainLyrics'] as String?) ?? '';
    final lines = parseSyncedLyrics(synced);
    if (lines.isEmpty) {
      final p = plain.replaceAll(_tag, '').trim();
      return p.isEmpty ? null : Lyrics(const [], p, 'LRCLIB');
    }
    return Lyrics(lines, plain, 'LRCLIB');
  }

  static double _matchScore(String expected, String actual) {
    final left = _normalizeMatch(expected);
    final right = _normalizeMatch(actual);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    if (left.contains(right) || right.contains(left)) return 0.85;

    final expectedTokens =
        left.split(' ').where((token) => token.length > 1).toSet();
    final actualTokens =
        right.split(' ').where((token) => token.length > 1).toSet();
    if (expectedTokens.isEmpty || actualTokens.isEmpty) return 0;
    final intersection = expectedTokens.intersection(actualTokens).length;
    return intersection / expectedTokens.union(actualTokens).length;
  }

  static String _normalizeMatch(String value) => _fold(
        value
            .toLowerCase()
            .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
            .replaceAll(
                RegExp(r'\b(official|audio|video|lyrics?|vevo|topic)\b'), ' ')
            .replaceAll(
              RegExp(r'\b(remaster(?:ed)?|live|version|sped up|slowed)\b'),
              ' ',
            ),
      ).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

List<LyricLine> parseSyncedLyrics(String source) {
  final lines = <LyricLine>[];
  var offsetMs = 0;
  for (final raw in source.split('\n')) {
    final offset = LyricsService._offset.firstMatch(raw.trim());
    if (offset != null) {
      offsetMs = int.tryParse(offset.group(1)!) ?? 0;
      continue;
    }
    final timestamps = LyricsService._lrc.allMatches(raw).toList();
    final inlineTimestamp =
        timestamps.isEmpty ? LyricsService._wordTag.firstMatch(raw) : null;
    if (timestamps.isEmpty && inlineTimestamp == null) continue;
    final text = raw
        .replaceAll(LyricsService._lrc, '')
        .replaceAll(LyricsService._tag, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) continue;
    final lineTimestamps = timestamps.isEmpty ? [inlineTimestamp!] : timestamps;
    for (final timestamp in lineTimestamps) {
      final at = LyricsService._dur(
        timestamp.group(1)!,
        timestamp.group(2)!,
      );
      final adjusted = at + Duration(milliseconds: offsetMs);
      lines.add(LyricLine(
        adjusted.isNegative ? Duration.zero : adjusted,
        text,
      ));
    }
  }
  lines.sort((a, b) => a.at.compareTo(b.at));
  return lines;
}
