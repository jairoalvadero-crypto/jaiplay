import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

import 'audio_handler.dart';
import 'data.dart';
import 'cloud.dart';
import 'downloads.dart';
import 'equalizer_bands.dart';
import 'models.dart';
import 'playlist_import.dart';
import 'settings.dart';

final music = MusicService();
final store = Store();
final player = PlayerService();

class _TrackUnavailableException implements Exception {
  final String message;

  const _TrackUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Búsqueda y URLs de audio desde YouTube.
class MusicService {
  final _yt = YoutubeExplode();
  final _youtubeMusic = YoutubeMusicExplode();
  final _playlistImporter = PlaylistImportService();
  final _cache = <String, List<Track>>{};

  // <FILTRO>
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

  static String _fold(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  static RegExp _rx(List<String> p) =>
      RegExp('(?<![a-z0-9])(?:${p.join('|')})(?![a-z0-9])');

  static final _hard = _rx(hardBlock);
  static final _soft = _rx(softBlock);
  static final _hint = _rx(musicHints);
  static final _chanHint = _rx(chanHints);
  static final _long = _rx(longFormWords);
  static final _dashRx = RegExp(r'\s[-–—]\s');
  static final _topic = RegExp(r'\s*-\s*topic$');

  static String _core(String s) => s
      .replaceAll(RegExp(r'\s*-\s*topic$'), '')
      .replaceAll(RegExp(r'vevo|official|oficial|music|musica|records'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();

  /// Puntua el resultado: suma por señales de musica, resta por lo contrario.
  /// Hasta 10 min exige 2 puntos, hasta 30 min exige 3 y mas de 30 min
  /// exige 3 y que el titulo sea de mix/album/concierto.
  static bool _isMusic(Track t) {
    final secs = t.seconds;
    if (secs == null || secs < 60) return false;
    final title = _fold(t.title);
    final chan = _fold(t.artist);
    if (_hard.hasMatch('$title $chan')) return false;

    var neg = _soft.allMatches(title).length * 2;
    if (neg > 4) neg = 4;

    var pos = 0;
    if (_topic.hasMatch(chan)) pos += 5;
    var h = _hint.allMatches(title).length;
    if (h > 2) h = 2;
    pos += h * 2;
    if (_chanHint.hasMatch(chan)) pos += 2;

    final parts = title.split(_dashRx);
    if (parts.length >= 2) {
      pos += 1;
      final left = _core(parts.first);
      final c = _core(chan);
      if (left.length >= 3 &&
          c.length >= 3 &&
          (c.contains(left) || left.contains(c))) {
        pos += 3;
      }
    }
    if (secs >= 120 && secs <= 420) pos += 1;

    final net = pos - neg;
    if (secs <= 600) return net >= 2;
    if (secs <= 1800) return net >= 3;
    return net >= 3 && _long.hasMatch(title);
  }

  static bool _okLength(Track t) => _isMusic(t);
  // </FILTRO>

  Future<List<Track>> search(String q) async =>
      (await _searchRaw(q)).where(_okLength).toList();

  Future<(String, List<Track>)> importYoutubePlaylist(String link) async {
    final uri = Uri.tryParse(link.trim());
    const hosts = {
      'youtube.com',
      'www.youtube.com',
      'music.youtube.com',
      'm.youtube.com',
    };
    final playlistId = uri?.queryParameters['list'];
    if (uri == null ||
        uri.scheme != 'https' ||
        !hosts.contains(uri.host.toLowerCase()) ||
        playlistId == null ||
        playlistId.isEmpty) {
      throw FormatException(
          'Pega un enlace válido de una playlist de YouTube.');
    }

    final playlist = await _yt.playlists.get(playlistId);
    final tracks = <Track>[];
    await for (final video in _yt.playlists.getVideos(playlistId)) {
      tracks.add(Track(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        thumb: video.thumbnails.highResUrl,
        seconds: video.duration?.inSeconds,
        channelId: video.channelId.value,
      ));
    }
    if (tracks.isEmpty) {
      throw StateError('La playlist no contiene canciones disponibles.');
    }
    return (playlist.title, tracks);
  }

  Future<(String, List<Track>, int)> importPlaylist(
    String link, {
    int? maxTracks,
  }) async {
    if (maxTracks != null && maxTracks < 1) {
      throw ArgumentError.value(
          maxTracks, 'maxTracks', 'Debe ser mayor que 0.');
    }
    final uri = Uri.tryParse(link.trim());
    const youtubeHosts = {
      'youtube.com',
      'www.youtube.com',
      'music.youtube.com',
      'm.youtube.com',
    };
    if (uri != null && youtubeHosts.contains(uri.host.toLowerCase())) {
      final (title, tracks) = await importYoutubePlaylist(link);
      final selected = maxTracks == null
          ? tracks
          : tracks.take(maxTracks).toList(growable: false);
      return (title, selected, tracks.length - selected.length);
    }

    final source = await _playlistImporter.fetch(link);
    final sourceTracks = maxTracks == null
        ? source.tracks
        : source.tracks.take(maxTracks).toList(growable: false);
    final resolved = List<Track?>.filled(sourceTracks.length, null);
    var nextIndex = 0;
    Object? searchFailure;

    Future<void> resolveTracks() async {
      while (true) {
        final index = nextIndex++;
        if (index >= sourceTracks.length) return;
        final sourceTrack = sourceTracks[index];
        final title = sourceTrack.title
            .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final queries = <String>{
          '$title ${sourceTrack.artist}',
          '${sourceTrack.artist} $title',
        };
        for (final query in queries) {
          try {
            final video = await _youtubeMusic.music.searchSong(
              query,
              expectedArtist: sourceTrack.artist,
              expectedTitle: title,
            );
            if (video == null) continue;
            final candidate = Track(
              id: video.id.value,
              title: video.title,
              artist: video.author,
              thumb: video.thumbnails.highResUrl,
              seconds: video.duration?.inSeconds,
              channelId: video.channelId.value,
            );
            if (ImportedPlaylistMatcher.isConfident(sourceTrack, candidate)) {
              resolved[index] = candidate;
              break;
            }
          } catch (error) {
            searchFailure ??= error;
            break;
          }
        }
      }
    }

    await Future.wait(
      List.generate(
        sourceTracks.length < 3 ? sourceTracks.length : 3,
        (_) => resolveTracks(),
      ),
    );
    final tracks = resolved.whereType<Track>().toList();
    if (tracks.isEmpty) {
      if (searchFailure != null) {
        throw StateError(
          'Se leyó la playlist, pero YouTube Music no permitió buscar sus '
          'canciones. Espera unos minutos y vuelve a intentarlo.',
        );
      }
      throw StateError(
        'Se leyó la playlist, pero no se pudo encontrar ninguna canción '
        'reproducible en JaiPlay.',
      );
    }
    return (source.name, tracks, sourceTracks.length - tracks.length);
  }

  Future<List<Track>> _searchRaw(String q, {int pages = 1}) async {
    final cached = _cache[q];
    if (cached != null && pages == 1) return cached;
    var page = await _yt.search.search(q);
    final videos = [...page];
    for (var i = 1; i < pages; i++) {
      final next = await page.nextPage();
      if (next == null) break;
      page = next;
      videos.addAll(page);
    }
    final list = videos
        .where((video) => !video.isLive)
        .map((video) => Track(
              id: video.id.value,
              title: video.title,
              artist: video.author,
              thumb: video.thumbnails.highResUrl,
              seconds: video.duration?.inSeconds,
              channelId: video.channelId.value,
            ))
        .toList();
    if (pages == 1) _cache[q] = list;
    return list;
  }

  final _clientOrder = <String, YoutubeApiClient>{
    'visionOs': YoutubeApiClient.visionOs,
    'android': YoutubeApiClient.android,
  };

  Future<Playable> resolve(String id) async {
    final log = <String>[];
    var allClientsReportUnavailable = true;
    for (final e in _clientOrder.entries) {
      try {
        final m = await _yt.videos.streamsClient.getManifest(id,
            ytClients: [e.value]).timeout(const Duration(seconds: 15));
        final audio = m.audioOnly.toList()
          ..sort((a, b) {
            final am = a.container.name == 'mp4' ? 1 : 0;
            final bm = b.container.name == 'mp4' ? 1 : 0;
            if (am != bm) return bm - am;
            return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
          });
        if (audio.isEmpty) {
          allClientsReportUnavailable = false;
          log.add('${e.key}: sin audio');
          continue;
        }
        final st = audio.first;
        final ua = e.value.payload['context']?['client']?['userAgent'];
        final headers = <String, String>{
          if (ua is String) 'user-agent': ua,
          for (final h in e.value.headers.entries) h.key: '${h.value}',
        };
        return Playable(st.url, headers, '${e.key}/${st.tag}',
            st.size.totalBytes, 'audio/${st.container.name}');
      } catch (err) {
        if (err is! VideoUnavailableException) {
          allClientsReportUnavailable = false;
        }
        final t = err.toString().split('\n').first;
        log.add('${e.key}: ${t.length > 90 ? t.substring(0, 90) : t}');
      }
    }
    if (allClientsReportUnavailable && log.isNotEmpty) {
      throw _TrackUnavailableException(log.join(' | '));
    }
    throw Exception(log.join(' | '));
  }

  Future<Playable> resolveTrack(Track track) async {
    try {
      return await resolve(track.id);
    } on _TrackUnavailableException catch (originalError) {
      final title = track.displayTitle;
      final excludedIds = <String>{track.id};
      final queries = [
        '$title ${track.artist}',
        '${track.artist} $title official audio',
        '$title ${track.artist} topic',
      ];
      for (final query in queries) {
        final video = await _youtubeMusic.music.searchSong(
          query,
          expectedArtist: track.artist,
          expectedTitle: title,
          excludedVideoIds: excludedIds,
        );
        if (video == null || !excludedIds.add(video.id.value)) continue;
        try {
          return await resolve(video.id.value);
        } on _TrackUnavailableException {
          continue;
        }
      }
      throw StateError(
        'El video no está disponible para reproducirse y no se encontró '
        'otra versión disponible. ${originalError.message}',
      );
    }
  }

  final _artistCache = <String, Artist?>{};

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\s*-\s*topic$'), '')
      .replaceAll(RegExp(r'vevo|oficial|official'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _cleanName(String s) => s
      .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*VEVO$', caseSensitive: false), '')
      .trim();

  Future<Artist?> findArtist(String q) async {
    final nq = _norm(q);
    if (nq.length < 3) return null;
    if (_artistCache.containsKey(nq)) return _artistCache[nq];
    if (nq == 'kaze') {
      final artist = canonicalArtist(
        const Artist(name: 'Kaze', image: '', channelId: ''),
      );
      _artistCache[nq] = artist;
      return artist;
    }
    Artist? result;
    try {
      final tracks = await search(q);
      Track? hit;
      for (final t in tracks) {
        if (t.channelId != null && _norm(t.artist) == nq) {
          hit = t;
          break;
        }
      }
      if (hit == null) {
        for (final t in tracks) {
          final na = _norm(t.artist);
          if (t.channelId != null &&
              na.length >= 3 &&
              (na.contains(nq) || nq.contains(na))) {
            hit = t;
            break;
          }
        }
      }
      if (hit != null) {
        final cid = hit.channelId!;
        try {
          final ch = await _yt.channels.get(cid);
          result = Artist(
              name: _cleanName(ch.title), image: ch.logoUrl, channelId: cid);
        } catch (_) {
          result = Artist(
              name: _cleanName(hit.artist), image: hit.thumb, channelId: cid);
        }
      }
    } catch (_) {}
    _artistCache[nq] = result;
    return result;
  }

  Future<List<Track>> artistTracks(Artist a) async {
    final na = _norm(a.name);
    final lists =
        await Future.wait([search(a.name), search('${a.name} canciones')]);
    final seen = <String>{};
    final all = [
      for (final l in lists) ...l,
    ].where((t) => seen.add(t.id)).toList();
    final mine = all
        .where((t) =>
            t.channelId == a.channelId ||
            _norm(t.artist) == na ||
            _norm(t.artist).contains(na))
        .toList();
    return mine.isNotEmpty ? mine : all;
  }

  Future<List<String>> suggestions(String q) =>
      _yt.search.getQuerySuggestions(q);
}

/// Favoritos y recientes guardados en el móvil.
class Store extends ChangeNotifier {
  late SharedPreferences _sp;
  List<Track> recents = [];
  List<String> recentSearches = [];
  List<Track> favs = [];
  List<Artist> artists = [];
  List<UserPlaylist> playlists = [];
  List<SavedAlbum> favoriteAlbums = [];
  final Map<String, int> _listeningSeconds = {};
  final Map<String, Artist> _listeningArtists = {};
  int _pendingListeningSeconds = 0;
  bool applying = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!applying) cloud.markChanged();
  }

  Map<String, dynamic> snapshot() => {
        'favs': [for (final t in favs) t.toJson()],
        'recents': [for (final t in recents) t.toJson()],
        'recentSearches': recentSearches,
        'artists': [for (final a in artists) a.toJson()],
        'favoriteAlbums': [for (final album in favoriteAlbums) album.toJson()],
      };

  List<Track> _tracks(dynamic v) => [
        for (final j in (v as List? ?? const []))
          Track.fromJson(Map<String, dynamic>.from(j as Map)),
      ];

  List<SavedAlbum> _savedAlbumsOf(dynamic v) => [
        for (final json in (v as List? ?? const []))
          SavedAlbum.fromJson(Map<String, dynamic>.from(json as Map)),
      ];

  List<Artist> _artistsOf(dynamic v) => [
        for (final j in (v as List? ?? const []))
          Artist.fromJson(Map<String, dynamic>.from(j as Map)),
      ];

  void _saveAll() {
    _write('favs', favs);
    _write('recents', recents);
    _sp.setStringList('recent_searches', recentSearches);
    _sp.setStringList(
        'artists', artists.map((x) => jsonEncode(x.toJson())).toList());
    _sp.setStringList(
      'favorite_albums',
      favoriteAlbums.map((album) => jsonEncode(album.toJson())).toList(),
    );
  }

  /// Sustituye lo del movil por lo de la nube.
  void applyRemote(Map<String, dynamic> d) {
    applying = true;
    favs = _tracks(d['favs']);
    recents = _tracks(d['recents']);
    if (d.containsKey('recentSearches')) {
      recentSearches = _searchesOf(d['recentSearches']);
    }
    artists = _artistsOf(d['artists']);
    if (d.containsKey('favoriteAlbums')) {
      favoriteAlbums = _savedAlbumsOf(d['favoriteAlbums']);
    }
    _saveAll();
    notifyListeners();
    applying = false;
  }

  /// Junta lo del movil con lo de la nube.
  void mergeRemote(Map<String, dynamic> d) {
    applying = true;
    final fid = <String>{};
    favs =
        [...favs, ..._tracks(d['favs'])].where((t) => fid.add(t.id)).toList();
    final rid = <String>{};
    recents = [...recents, ..._tracks(d['recents'])]
        .where((t) => rid.add(t.id))
        .take(30)
        .toList();
    final searchIds = <String>{};
    recentSearches = [
      ...recentSearches,
      ..._searchesOf(d['recentSearches']),
    ].where((query) => searchIds.add(query.toLowerCase())).take(30).toList();
    final cid = <String>{};
    artists = [...artists, ..._artistsOf(d['artists'])]
        .where((a) => cid.add(a.channelId))
        .toList();
    final albumIds = <String>{};
    favoriteAlbums = [
      ...favoriteAlbums,
      ..._savedAlbumsOf(d['favoriteAlbums']),
    ].where((album) => albumIds.add(album.id)).toList();
    _saveAll();
    notifyListeners();
    applying = false;
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    recents = _read('recents');
    recentSearches = _sp.getStringList('recent_searches') ?? [];
    favs = _read('favs');
    artists = [];
    favoriteAlbums = [
      for (final value in _sp.getStringList('favorite_albums') ?? [])
        SavedAlbum.fromJson(jsonDecode(value) as Map<String, dynamic>),
    ];
    _loadListeningStats();
    try {
      final rawPlaylists = _sp.getString('user_playlists');
      if (rawPlaylists != null) {
        final decoded = jsonDecode(rawPlaylists) as List;
        playlists = [
          for (final value in decoded)
            UserPlaylist.fromJson(Map<String, dynamic>.from(value as Map)),
        ];
      }
    } catch (error) {
      throw FormatException('No se pudieron cargar las playlists: $error');
    }
    for (final s in _sp.getStringList('artists') ?? <String>[]) {
      try {
        artists.add(Artist.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
  }

  List<Track> _read(String k) => (_sp.getStringList(k) ?? [])
      .map((s) => Track.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  void _write(String k, List<Track> l) =>
      _sp.setStringList(k, l.map((t) => jsonEncode(t.toJson())).toList());

  Future<void> _commitPlaylists(List<UserPlaylist> updated) async {
    final previous = playlists;
    playlists = updated;
    try {
      final saved = await _sp.setString(
        'user_playlists',
        jsonEncode(playlists.map((playlist) => playlist.toJson()).toList()),
      );
      if (!saved) throw StateError('No se pudieron guardar las playlists.');
    } catch (_) {
      playlists = previous;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<UserPlaylist> createPlaylist(String name,
      {List<Track> tracks = const []}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre de la playlist no puede estar vacío.');
    }
    final playlist = UserPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: cleanName,
      tracks: List.of(tracks),
    );
    await _commitPlaylists([playlist, ...playlists]);
    return playlist;
  }

  UserPlaylist? playlistById(String id) {
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  Future<void> addTracksToPlaylist(String id, List<Track> tracks) async {
    final playlist = playlistById(id);
    if (playlist == null) throw StateError('No se encontró la playlist.');
    final known = playlist.tracks.map((track) => track.id).toSet();
    final additions = tracks.where((track) => known.add(track.id));
    final updated = playlist.copyWith(
      tracks: [...playlist.tracks, ...additions],
    );
    await _commitPlaylists(
      playlists.map((item) => item.id == id ? updated : item).toList(),
    );
  }

  Future<void> removeTrackFromPlaylist(String id, String trackId) async {
    final playlist = playlistById(id);
    if (playlist == null) throw StateError('No se encontró la playlist.');
    final updated = playlist.copyWith(
      tracks: playlist.tracks.where((track) => track.id != trackId).toList(),
    );
    await _commitPlaylists(
      playlists.map((item) => item.id == id ? updated : item).toList(),
    );
  }

  Future<void> renamePlaylist(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('El nombre de la playlist no puede estar vacío.');
    }
    final playlist = playlistById(id);
    if (playlist == null) throw StateError('No se encontró la playlist.');
    final updated = playlist.copyWith(name: cleanName);
    await _commitPlaylists(
      playlists.map((item) => item.id == id ? updated : item).toList(),
    );
  }

  Future<void> setPlaylistCover(String id, String path) async {
    final playlist = playlistById(id);
    if (playlist == null) throw StateError('No se encontró la playlist.');
    final updated = playlist.copyWith(customCoverPath: path);
    await _commitPlaylists(
      playlists.map((item) => item.id == id ? updated : item).toList(),
    );
  }

  Future<void> clearPlaylistCover(String id) async {
    final playlist = playlistById(id);
    if (playlist == null) throw StateError('No se encontró la playlist.');
    final updated = playlist.copyWith(clearCustomCover: true);
    await _commitPlaylists(
      playlists.map((item) => item.id == id ? updated : item).toList(),
    );
  }

  Future<void> deletePlaylist(String id) async {
    if (!playlists.any((playlist) => playlist.id == id)) {
      throw StateError('No se encontró la playlist.');
    }
    await _commitPlaylists(
      playlists.where((playlist) => playlist.id != id).toList(),
    );
  }

  void addRecent(Track t) {
    recents.removeWhere((x) => x.id == t.id);
    recents.insert(0, t);
    if (recents.length > 30) recents = recents.sublist(0, 30);
    _write('recents', recents);
    notifyListeners();
  }

  void addRecentSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    recentSearches.removeWhere(
      (recent) => recent.toLowerCase() == cleanQuery.toLowerCase(),
    );
    recentSearches.insert(0, cleanQuery);
    if (recentSearches.length > 30) {
      recentSearches = recentSearches.sublist(0, 30);
    }
    _sp.setStringList('recent_searches', recentSearches);
    notifyListeners();
  }

  void clearRecentSearches() {
    if (recentSearches.isEmpty) return;
    recentSearches = [];
    _sp.setStringList('recent_searches', recentSearches);
    notifyListeners();
  }

  List<String> _searchesOf(dynamic value) => [
        for (final query in (value as List? ?? const []))
          if (query is String && query.trim().isNotEmpty) query.trim(),
      ];

  void _loadListeningStats() {
    final raw = _sp.getString('artist_listening_stats');
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('El historial de escucha no es válido.');
    }
    for (final entry in decoded.entries) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      final seconds = value['seconds'];
      if (seconds is! int || seconds < 0) continue;
      _listeningSeconds[entry.key.toString()] = seconds;
      _listeningArtists[entry.key.toString()] =
          Artist.fromJson(Map<String, dynamic>.from(value['artist'] as Map));
    }
  }

  List<Artist> get mostListenedArtists {
    final keys = _listeningSeconds.keys.toList()
      ..sort((a, b) => _listeningSeconds[b]!.compareTo(_listeningSeconds[a]!));
    return [for (final key in keys) _listeningArtists[key]!];
  }

  int listeningSecondsFor(Artist artist) {
    final key = artist.channelId.isNotEmpty
        ? artist.channelId
        : 'name:${artist.name.toLowerCase().trim()}';
    return _listeningSeconds[key] ?? 0;
  }

  Future<void> recordListeningTime(Track track, int seconds) async {
    if (seconds <= 0 || track.streamUrl != null) return;
    final name = track.artist.trim();
    if (name.isEmpty) return;
    final key = track.channelId?.isNotEmpty == true
        ? track.channelId!
        : 'name:${name.toLowerCase()}';
    _listeningSeconds.update(key, (value) => value + seconds,
        ifAbsent: () => seconds);
    _listeningArtists[key] = Artist(
      name: name,
      image: track.thumb,
      channelId: track.channelId ?? '',
    );
    _pendingListeningSeconds += seconds;
    if (_pendingListeningSeconds >= 10) {
      _pendingListeningSeconds = 0;
      await _persistListeningStats();
    }
  }

  Future<void> _persistListeningStats() async {
    final data = <String, dynamic>{
      for (final entry in _listeningSeconds.entries)
        entry.key: {
          'seconds': entry.value,
          'artist': _listeningArtists[entry.key]!.toJson(),
        },
    };
    final saved =
        await _sp.setString('artist_listening_stats', jsonEncode(data));
    if (!saved) throw StateError('No se pudo guardar el historial de escucha.');
  }

  Future<void> flushListeningStats() async {
    if (_pendingListeningSeconds == 0) return;
    final pending = _pendingListeningSeconds;
    _pendingListeningSeconds = 0;
    try {
      await _persistListeningStats();
    } catch (_) {
      _pendingListeningSeconds += pending;
      rethrow;
    }
  }

  bool isFav(String id) => favs.any((t) => t.id == id);

  bool isAlbumFavorite(String id) =>
      favoriteAlbums.any((album) => album.id == id);

  void toggleAlbumFavorite(SavedAlbum album) {
    if (isAlbumFavorite(album.id)) {
      favoriteAlbums.removeWhere((saved) => saved.id == album.id);
    } else {
      favoriteAlbums.insert(0, album);
    }
    _sp.setStringList(
      'favorite_albums',
      favoriteAlbums.map((saved) => jsonEncode(saved.toJson())).toList(),
    );
    notifyListeners();
  }

  void toggleFav(Track t) {
    if (isFav(t.id)) {
      favs.removeWhere((x) => x.id == t.id);
    } else {
      favs.insert(0, t);
    }
    _write('favs', favs);
    notifyListeners();
  }

  bool isFollowing(String channelId) =>
      artists.any((a) => a.channelId == channelId);

  void toggleFollow(Artist a) {
    if (isFollowing(a.channelId)) {
      artists.removeWhere((x) => x.channelId == a.channelId);
    } else {
      artists.insert(0, a);
    }
    _sp.setStringList(
        'artists', artists.map((x) => jsonEncode(x.toJson())).toList());
    notifyListeners();
  }
}

/// Cola de reproducción + control del reproductor.
const _ua = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

class _PlaybackDeck {
  final AndroidEqualizer equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [equalizer, loudnessEnhancer],
    ),
  );
}

class PlayerService extends ChangeNotifier {
  static const _crossfadeDuration = Duration(seconds: 5);
  _PlaybackDeck _activeDeck = _PlaybackDeck();
  _PlaybackDeck _standbyDeck = _PlaybackDeck();
  Timer? _crossfadeTimer;
  final Stopwatch _crossfadeClock = Stopwatch();
  int? _preparedIndex;
  int? _candidateIndex;
  int _preparationVersion = 0;
  bool _preparingNext = false;
  bool _transitioning = false;
  List<Track> queue = [];
  int index = -1;
  bool shuffle = false;
  LoopMode loop = LoopMode.off;
  bool loading = false;
  String? error;
  Duration? _lastListenPosition;
  Duration _listenRemainder = Duration.zero;
  String? _listenTrackId;

  AudioPlayer get audio => _activeDeck.player;
  AndroidEqualizer get equalizer => _activeDeck.equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _activeDeck.loudnessEnhancer;
  AudioPlayer get _p => _activeDeck.player;
  bool get playing => _p.playing;
  Track? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;

  PlayerService() {
    _listenDeck(_activeDeck);
    _listenDeck(_standbyDeck);
    appSettings.addListener(_onAudioSettingsChanged);
  }

  void _onAudioSettingsChanged() {
    if (!appSettings.crossfadeEnabled) {
      _cancelCrossfade();
      unawaited(_p.setVolume(1));
      return;
    }
    unawaited(_prepareNextTrack());
  }

  void _listenDeck(_PlaybackDeck deck) {
    deck.player.positionStream.listen((position) {
      if (deck != _activeDeck) return;
      _recordListeningProgress(position);
      _updateCrossfade(position);
    });
    deck.player.playerStateStream.listen((state) {
      if (deck != _activeDeck) return;
      if (state.processingState == ProcessingState.completed &&
          !_transitioning) {
        next(auto: true);
      }
      if (!state.playing) _flushListeningStats();
      notifyListeners();
    });
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _crossfadeClock
      ..stop()
      ..reset();
    _transitioning = false;
    _preparedIndex = null;
    _candidateIndex = null;
    _preparingNext = false;
    _preparationVersion++;
    unawaited(_standbyDeck.player.stop());
    unawaited(_standbyDeck.player.setVolume(0));
    unawaited(_standbyDeck.player.setSpeed(1));
    unawaited(_activeDeck.player.setVolume(1));
    unawaited(_activeDeck.player.setSpeed(1));
  }

  int? _followingIndex() {
    if (_candidateIndex != null) return _candidateIndex;
    if (queue.length < 2 || loop == LoopMode.one) return null;
    if (shuffle) {
      var next = Random().nextInt(queue.length);
      if (next == index) next = (next + 1) % queue.length;
      return next;
    }
    final next = index + 1;
    if (next < queue.length) return next;
    return loop == LoopMode.all ? 0 : null;
  }

  Future<AudioSource> _audioSourceFor(Track track) async {
    final tag = _mediaItemFor(track);
    if (track.streamUrl != null) {
      return AudioSource.uri(Uri.parse(track.streamUrl!), tag: tag);
    }
    final local = downloads.pathFor(track.id);
    if (local != null) return AudioSource.uri(Uri.file(local), tag: tag);
    final playable = await music.resolveTrack(track);
    return AudioSource.uri(playable.url, headers: playable.headers, tag: tag);
  }

  MediaItem _mediaItemFor(Track track) => MediaItem(
        id: track.id,
        title: track.displayTitle,
        artist: track.artist,
        duration:
            track.seconds == null ? null : Duration(seconds: track.seconds!),
        artUri: track.thumb.isEmpty ? null : Uri.parse(track.thumb),
      );

  Future<void> _prepareNextTrack() async {
    if (!appSettings.crossfadeEnabled ||
        _preparingNext ||
        _preparedIndex != null ||
        current?.streamUrl != null) {
      return;
    }
    final candidate = _followingIndex();
    if (candidate == null || queue[candidate].streamUrl != null) return;
    _candidateIndex = candidate;
    _preparingNext = true;
    final version = _preparationVersion;
    try {
      final source = await _audioSourceFor(queue[candidate]);
      if (!appSettings.crossfadeEnabled ||
          version != _preparationVersion ||
          candidate != _candidateIndex ||
          candidate != _followingIndex()) {
        return;
      }
      await _standbyDeck.player.setAudioSource(source);
      if (version != _preparationVersion) {
        await _standbyDeck.player.stop();
        return;
      }
      await _standbyDeck.player.setVolume(0);
      await _applySoundSettings(_standbyDeck);
      _preparedIndex = candidate;
    } catch (e) {
      error = 'No se pudo preparar el crossfade: $e';
      notifyListeners();
    } finally {
      if (version == _preparationVersion) {
        _preparingNext = false;
        if (_preparedIndex == null) _candidateIndex = null;
      }
    }
  }

  void _updateCrossfade(Duration position) {
    if (!appSettings.crossfadeEnabled || _transitioning) return;
    final duration = _p.duration;
    if (duration == null) return;
    final remaining = duration - position;
    if (remaining <= _crossfadeDuration) {
      if (_preparedIndex == _followingIndex()) {
        _beginCrossfade();
      } else if (!_preparingNext) {
        unawaited(_prepareNextTrack());
      }
    } else if (remaining <= const Duration(seconds: 20) &&
        _preparedIndex == null &&
        !_preparingNext) {
      unawaited(_prepareNextTrack());
    }
  }

  void _beginCrossfade() {
    if (_transitioning || _preparedIndex == null) return;
    final nextIndex = _preparedIndex!;
    final oldDeck = _activeDeck;
    final nextDeck = _standbyDeck;
    _transitioning = true;
    _crossfadeClock
      ..reset()
      ..start();
    nextDeck.player.play();
    _crossfadeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final amount = (_crossfadeClock.elapsed.inMilliseconds /
              _crossfadeDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      unawaited(oldDeck.player.setVolume(1 - amount));
      unawaited(nextDeck.player.setVolume(amount));
      unawaited(oldDeck.player.setSpeed(1 + amount * 0.12));
      if (amount < 1) return;
      timer.cancel();
      _crossfadeTimer = null;
      _crossfadeClock
        ..stop()
        ..reset();
      _activeDeck = nextDeck;
      _standbyDeck = oldDeck;
      _transitioning = false;
      _preparedIndex = null;
      _candidateIndex = null;
      unawaited(oldDeck.player.setSpeed(1));
      index = nextIndex;
      _lastListenPosition = null;
      _listenRemainder = Duration.zero;
      _listenTrackId = null;
      final nextTrack = queue[index];
      store.addRecent(nextTrack);
      audioHandler.publishMediaItem(_mediaItemFor(nextTrack));
      notifyListeners();
      unawaited(oldDeck.player.stop());
      unawaited(oldDeck.player.setVolume(0));
      unawaited(_prepareNextTrack());
    });
  }

  void _flushListeningStats() {
    unawaited(store.flushListeningStats().catchError((Object e) {
      error = 'No se pudo guardar el historial de escucha: $e';
      notifyListeners();
    }));
  }

  void _recordListeningProgress(Duration position) {
    final track = current;
    if (!_p.playing || track == null || track.streamUrl != null) {
      _lastListenPosition = position;
      return;
    }
    if (_listenTrackId != track.id) {
      _listenTrackId = track.id;
      _lastListenPosition = position;
      _listenRemainder = Duration.zero;
      return;
    }
    final previous = _lastListenPosition;
    _lastListenPosition = position;
    if (previous == null) return;
    final elapsed = position - previous;
    if (elapsed <= Duration.zero || elapsed > const Duration(seconds: 2)) {
      return;
    }
    _listenRemainder += elapsed;
    final wholeSeconds = _listenRemainder.inSeconds;
    if (wholeSeconds > 0) {
      _listenRemainder -= Duration(seconds: wholeSeconds);
      unawaited(store.recordListeningTime(track, wholeSeconds).catchError(
        (Object e) {
          error = 'No se pudo guardar el historial de escucha: $e';
          notifyListeners();
        },
      ));
    }
  }

  Future<void> playQueue(List<Track> tracks, int start) async {
    if (tracks.isEmpty) return;
    _cancelCrossfade();
    queue = List.of(tracks);
    audioHandler.publishQueue(queue
        .map((t) => MediaItem(
              id: t.id,
              title: t.displayTitle,
              artist: t.artist,
              duration:
                  t.seconds == null ? null : Duration(seconds: t.seconds!),
              artUri: t.thumb.isEmpty ? null : Uri.parse(t.thumb),
            ))
        .toList());
    await _load(start);
  }

  Future<void> _load(int i) async {
    _cancelCrossfade();
    index = i;
    loading = true;
    error = null;
    try {
      await store.flushListeningStats();
    } catch (e) {
      error = 'No se pudo guardar el historial de escucha: $e';
    }
    _lastListenPosition = null;
    _listenRemainder = Duration.zero;
    _listenTrackId = null;
    notifyListeners();
    final t = queue[i];
    if (t.streamUrl == null) store.addRecent(t);
    var via = '?';
    try {
      final tag = _mediaItemFor(t);
      audioHandler.publishMediaItem(tag);
      if (t.streamUrl != null) {
        via = 'radio';
      } else if (downloads.pathFor(t.id) != null) {
        via = 'local';
      } else {
        via = 'stream';
      }
      final source = await _audioSourceFor(t);
      if (index != i) return;
      await _p.setAudioSource(source);
      try {
        await _applySoundSettings(_activeDeck);
      } catch (e) {
        error = 'No se pudo aplicar el perfil de sonido o amplificador: $e';
      }
      _p.play();
      unawaited(_prepareNextTrack());
    } catch (e) {
      if (index == i) error = 'Error: $e [$via]';
    }
    if (index == i) loading = false;
    notifyListeners();
  }

  Future<void> setAmplifierGain(double value) async {
    await appSettings.setAmplifierGain(value);
    await Future.wait([
      _applyLoudnessEnhancer(gainDb: value, deck: _activeDeck),
      _applyLoudnessEnhancer(gainDb: value, deck: _standbyDeck),
    ]);
  }

  Future<void> _applyLoudnessEnhancer({
    double? gainDb,
    _PlaybackDeck? deck,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final gain = gainDb ?? appSettings.amplifierGainDb;
    final enhancer = (deck ?? _activeDeck).loudnessEnhancer;
    await enhancer.setTargetGain(gain);
    await enhancer.setEnabled(gain > 0);
  }

  Future<void> applyEqualizerSettings({
    String? preset,
    List<double>? manualGains,
  }) async {
    await Future.wait([
      _applyEqualizer(
          preset: preset, manualGains: manualGains, deck: _activeDeck),
      _applyEqualizer(
          preset: preset, manualGains: manualGains, deck: _standbyDeck),
    ]);
  }

  Future<void> _applyEqualizer({
    String? preset,
    List<double>? manualGains,
    _PlaybackDeck? deck,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final selectedPreset = preset ?? appSettings.equalizerPreset;
    final eq = (deck ?? _activeDeck).equalizer;
    final parameters = await eq.parameters;
    if (selectedPreset == 'Desactivado') {
      await eq.setEnabled(false);
      return;
    }
    await eq.setEnabled(true);
    final gains = selectedPreset == 'Manual'
        ? normalizeEqualizerGains(
            manualGains ?? appSettings.manualEqualizerGains,
          )
        : equalizerPresetGains(selectedPreset);
    for (final band in parameters.bands) {
      final gain = equalizerGainAtFrequency(gains, band.centerFrequency);
      await band.setGain(
        gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble(),
      );
    }
  }

  Future<void> _applySoundSettings(_PlaybackDeck deck) async {
    await _applyEqualizer(deck: deck);
    await _applyLoudnessEnhancer(deck: deck);
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (_transitioning && !auto) {
      final nextIndex = _followingIndex();
      if (nextIndex != null) await _load(nextIndex);
      return;
    }
    if (_transitioning) return;
    if (!auto &&
        _preparedIndex != null &&
        _preparedIndex == _followingIndex()) {
      await _load(_preparedIndex!);
      return;
    }
    if (auto && loop == LoopMode.one) {
      await _p.seek(Duration.zero);
      _p.play();
      return;
    }
    if (auto && _preparedIndex != null) {
      final oldDeck = _activeDeck;
      _activeDeck = _standbyDeck;
      _standbyDeck = oldDeck;
      index = _preparedIndex!;
      _preparedIndex = null;
      _candidateIndex = null;
      _lastListenPosition = null;
      _listenRemainder = Duration.zero;
      _listenTrackId = null;
      await _p.setVolume(1);
      await _p.play();
      final track = queue[index];
      store.addRecent(track);
      audioHandler.publishMediaItem(_mediaItemFor(track));
      notifyListeners();
      unawaited(oldDeck.player.stop());
      unawaited(oldDeck.player.setVolume(0));
      unawaited(_prepareNextTrack());
      return;
    }
    final candidate = auto ? _followingIndex() : null;
    _cancelCrossfade();
    int? n = candidate;
    if (n == null && shuffle && queue.length > 1) {
      n = Random().nextInt(queue.length);
      if (n == index) n = (n + 1) % queue.length;
    } else if (n == null) {
      n = index + 1;
      if (n >= queue.length) {
        if (loop == LoopMode.all) {
          n = 0;
        } else if (auto) {
          return;
        } else {
          n = 0;
        }
      }
    }
    await _load(n);
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    if (_p.position > const Duration(seconds: 3)) {
      await _p.seek(Duration.zero);
      return;
    }
    await _load(index > 0 ? index - 1 : 0);
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (_p.playing) {
      await pausePlayback();
    } else {
      await resumePlayback();
    }
  }

  Future<void> pausePlayback() async {
    await _p.pause();
    if (_transitioning) {
      await _standbyDeck.player.pause();
      _crossfadeClock.stop();
    }
  }

  Future<void> resumePlayback() async {
    if (_p.processingState == ProcessingState.completed) {
      await _p.seek(Duration.zero);
    }
    if (_transitioning) {
      _crossfadeClock.start();
      await Future.wait([
        _p.play(),
        _standbyDeck.player.play(),
      ]);
    } else {
      _p.play();
    }
  }

  Future<void> seek(Duration position) async {
    if (_transitioning) _cancelCrossfade();
    await _p.seek(position);
  }

  Future<void> stopPlayback() async {
    _cancelCrossfade();
    await Future.wait([
      _activeDeck.player.stop(),
      _standbyDeck.player.stop(),
    ]);
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _cancelCrossfade();
    unawaited(_prepareNextTrack());
    notifyListeners();
  }

  void cycleLoop() {
    loop = switch (loop) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _cancelCrossfade();
    unawaited(_prepareNextTrack());
    notifyListeners();
  }
}

class Playable {
  final Uri url;
  final Map<String, String> headers;
  final String via;
  final int length;
  final String type;
  const Playable(this.url, this.headers, this.via, this.length, this.type);
}

const _chunk = 512 * 1024;
final _httpClient = http.Client();

class _HttpRangeSource extends StreamAudioSource {
  final Playable pl;
  _HttpRangeSource(this.pl, {dynamic tag}) : super(tag: tag);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    var to = end ?? pl.length;
    if (pl.length > 0 && to > pl.length) to = pl.length;
    if (to - from > _chunk) to = from + _chunk;
    var req = http.Request('GET', pl.url)
      ..headers.addAll({...pl.headers, 'Range': 'bytes=$from-${to - 1}'});
    var res = await _httpClient.send(req);
    if (res.statusCode == 403) {
      final u2 = pl.url.replace(queryParameters: {
        ...pl.url.queryParameters,
        'range': '$from-${to - 1}',
      });
      req = http.Request('GET', u2)..headers.addAll(pl.headers);
      res = await _httpClient.send(req);
    }
    if (res.statusCode != 200 && res.statusCode != 206) {
      throw Exception(
          'HTTP ${res.statusCode} en ${pl.via} bytes=$from-${to - 1}');
    }
    return StreamAudioResponse(
      sourceLength: pl.length > 0 ? pl.length : null,
      contentLength: to - from,
      offset: from,
      stream: res.stream,
      contentType: pl.type,
    );
  }
}

const _androidSdkless = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'ANDROID',
      'clientVersion': '20.10.38',
      'userAgent':
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      'hl': 'en',
      'timeZone': 'UTC',
      'utcOffsetMinutes': 0,
    },
  },
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
