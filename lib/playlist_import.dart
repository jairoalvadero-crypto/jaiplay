import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ImportedPlaylistTrack {
  final String title;
  final String artist;
  final int? seconds;

  const ImportedPlaylistTrack({
    required this.title,
    required this.artist,
    this.seconds,
  });
}

class ImportedPlaylist {
  final String name;
  final List<ImportedPlaylistTrack> tracks;

  const ImportedPlaylist({required this.name, required this.tracks});
}

class PlaylistImportService {
  final http.Client _client;

  PlaylistImportService({http.Client? client})
      : _client = client ?? http.Client();

  Future<ImportedPlaylist> fetch(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Pega un enlace HTTPS válido.');
    }

    final host = uri.host.toLowerCase();
    if (host == 'open.spotify.com' || host == 'www.spotify.com') {
      final segments = uri.pathSegments;
      final playlistIndex = segments.indexOf('playlist');
      if (host != 'open.spotify.com' ||
          playlistIndex < 0 ||
          playlistIndex + 1 >= segments.length) {
        throw const FormatException(
          'Pega un enlace directo de una playlist pública de Spotify.',
        );
      }

      final id = segments[playlistIndex + 1];
      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
        throw const FormatException('El enlace de Spotify no es válido.');
      }
      final response = await _client.get(
        Uri.https('open.spotify.com', '/embed/playlist/$id'),
        headers: const {'User-Agent': 'JaiPlay/1.0'},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(
          'Spotify no ha permitido leer la playlist pública '
          '(HTTP ${response.statusCode}).',
        );
      }
      return parseSpotifyEmbed(utf8.decode(response.bodyBytes));
    }

    if (host == 'music.apple.com' || host == 'www.music.apple.com') {
      if (host != 'music.apple.com' ||
          !uri.pathSegments.contains('playlist') ||
          !uri.pathSegments.any((segment) => segment.startsWith('pl.'))) {
        throw const FormatException(
          'Pega un enlace directo de una playlist pública de Apple Music.',
        );
      }
      final response = await _client.get(uri, headers: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(
          'Apple Music no ha permitido leer la playlist pública '
          '(HTTP ${response.statusCode}).',
        );
      }
      return parseAppleMusicPage(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    }

    throw const FormatException(
      'El enlace debe ser de Spotify, Apple Music o YouTube Music.',
    );
  }

  static ImportedPlaylist parseSpotifyEmbed(String html) {
    final tracks = <ImportedPlaylistTrack>[];
    final starts =
        RegExp(r'"uri":"spotify:track:[^"]+"').allMatches(html).toList();
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i].start;
      final end = i + 1 < starts.length
          ? starts[i + 1].start
          : (start + 12000).clamp(start, html.length);
      final section = html.substring(start, end);
      final titleMatch =
          RegExp(r'"title":"((?:\\.|[^"])*)"').firstMatch(section);
      final artistMatch =
          RegExp(r'"subtitle":"((?:\\.|[^"])*)"').firstMatch(section);
      if (titleMatch == null || artistMatch == null) continue;
      final title = _decodeJsonString(titleMatch.group(1)!);
      final artist = _decodeJsonString(artistMatch.group(1)!);
      final durationMs = int.tryParse(
        RegExp(r'"duration":(\d+)').firstMatch(section)?.group(1) ?? '',
      );
      if (title.isNotEmpty && artist.isNotEmpty) {
        tracks.add(ImportedPlaylistTrack(
          title: title,
          artist: artist,
          seconds: durationMs == null ? null : (durationMs / 1000).round(),
        ));
      }
    }
    if (tracks.isEmpty) {
      throw StateError(
        'No se encontraron canciones. Comprueba que la playlist de Spotify '
        'sea pública y que el enlace sea correcto.',
      );
    }
    return ImportedPlaylist(
      name: _spotifyTitle(html) ?? 'Playlist de Spotify',
      tracks: tracks,
    );
  }

  static ImportedPlaylist parseAppleMusicPage(String html) {
    final tracks = <ImportedPlaylistTrack>[];
    final lockups =
        RegExp(r'"id":"track-lockup - [^"]+"').allMatches(html).toList();
    for (var i = 0; i < lockups.length; i++) {
      final start = lockups[i].start;
      final end = i + 1 < lockups.length
          ? lockups[i + 1].start
          : (start + 12000).clamp(start, html.length);
      final section = html.substring(start, end);
      final titleMatch =
          RegExp(r'"title":"((?:\\.|[^"])*)"').firstMatch(section);
      final artistMatch =
          RegExp(r'"artistName":"((?:\\.|[^"])*)"').firstMatch(section);
      if (titleMatch == null || artistMatch == null) continue;
      final title = _decodeJsonString(titleMatch.group(1)!);
      final artist = _decodeJsonString(artistMatch.group(1)!);
      if (title.isNotEmpty && artist.isNotEmpty) {
        final duration =
            RegExp(r'"duration":"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"')
                .firstMatch(section);
        final seconds = duration == null
            ? null
            : (int.tryParse(duration.group(1) ?? '0') ?? 0) * 3600 +
                (int.tryParse(duration.group(2) ?? '0') ?? 0) * 60 +
                (int.tryParse(duration.group(3) ?? '0') ?? 0);
        tracks.add(ImportedPlaylistTrack(
          title: title,
          artist: artist,
          seconds: seconds == 0 ? null : seconds,
        ));
      }
    }
    if (tracks.isEmpty) {
      throw StateError(
        'No se encontraron canciones. Comprueba que la playlist de Apple '
        'Music sea pública y que el enlace sea correcto.',
      );
    }
    return ImportedPlaylist(
      name: _appleMusicTitle(html) ?? 'Playlist de Apple Music',
      tracks: tracks,
    );
  }

  static String? _spotifyTitle(String html) {
    final match =
        RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(html);
    if (match == null) return null;
    final title = _decodeHtml(match.group(1)!)
        .replaceFirst(
            RegExp(r'\s*[-|]\s*Spotify\s*$', caseSensitive: false), '')
        .trim();
    return title.isEmpty ? null : title;
  }

  static String? _appleMusicTitle(String html) {
    final tag = RegExp(
      r'<meta\s+property="og:title"\s+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (tag == null) return null;
    final title = _decodeHtml(tag.group(1)!)
        .replaceFirst(RegExp(r'\s+on Apple Music$', caseSensitive: false), '')
        .trim();
    return title.isEmpty ? null : title;
  }

  static String _decodeJsonString(String value) {
    try {
      return (jsonDecode('"$value"') as String).trim();
    } on FormatException {
      return value.trim();
    }
  }

  static String _decodeHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) => String.fromCharCode(int.parse(match.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-f]+);', caseSensitive: false),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      );
}

class ImportedPlaylistMatcher {
  static const _accents = {
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

  static Track? bestMatch(ImportedPlaylistTrack source, List<Track> results) {
    Track? best;
    var bestScore = double.negativeInfinity;
    for (final result in results) {
      final titleScore = _textScore(source.title, result.displayTitle);
      final artistScore = _textScore(source.artist, result.artist);
      if (titleScore < 0.45 || artistScore < 0.12) continue;

      var score = titleScore * 5 + artistScore * 3;
      if (source.seconds != null && result.seconds != null) {
        final difference = (source.seconds! - result.seconds!).abs();
        if (difference > 30) {
          score -= difference > 60 ? 2 : 1;
        } else if (difference <= 8) {
          score += 1.5;
        } else if (difference <= 15) {
          score += 0.75;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
    }
    return best;
  }

  static bool isConfident(ImportedPlaylistTrack source, Track? candidate) {
    if (candidate == null) return false;
    return _textScore(source.title, candidate.displayTitle) >= 0.78 &&
        _textScore(source.artist, candidate.artist) >= 0.25;
  }

  static double _textScore(String expected, String actual) {
    String normalize(String value) {
      var folded = value.toLowerCase();
      for (final entry in _accents.entries) {
        folded = folded.replaceAll(entry.key, entry.value);
      }
      return folded
          .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
          .replaceAll(
            RegExp(
              r'\b(feat(?:uring)?|ft|official|audio|video|lyrics?|vevo|topic|'
              r'remaster(?:ed)?|live|version|hd|4k)\b',
            ),
            ' ',
          )
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
    }

    final left = normalize(expected);
    final right = normalize(actual);
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;
    if (left.contains(right) || right.contains(left)) return 0.9;
    final leftTokens =
        left.split(' ').where((token) => token.length > 1).toSet();
    final rightTokens =
        right.split(' ').where((token) => token.length > 1).toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0;
    final common = leftTokens.intersection(rightTokens).length;
    final dice = (2 * common) / (leftTokens.length + rightTokens.length);
    final coverage = common / leftTokens.length;
    return (dice * 0.6 + coverage * 0.4).clamp(0.0, 1.0);
  }
}
