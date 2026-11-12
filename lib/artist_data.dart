import 'package:youtube_explode_dart/youtube_explode_dart.dart' show Video;
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

import 'models.dart';
import 'services.dart';

const _timeout = Duration(seconds: 25);
final _ym = YoutubeMusicExplode();
final _pages = <String, ArtistPage>{};
final _albums = <String, List<Track>>{};
final _clipsCache = <String, List<Track>>{};

class Release {
  final String id;
  final String title;
  final String image;
  final String sub;
  const Release(this.id, this.title, this.image, this.sub);
}

class ArtistPage {
  final String? image;
  final String description;
  final List<Track> topSongs;
  final List<Release> albums;
  final List<Release> singles;
  final List<Artist> related;
  const ArtistPage(this.image, this.description, this.topSongs, this.albums,
      this.singles, this.related);
}

String _thumb(String id) => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

Track _track(Video v, String artist, {String? thumb, String? album}) => Track(
      id: v.id.value,
      title: v.title,
      artist: artist,
      thumb: thumb ?? _thumb(v.id.value),
      seconds: v.duration?.inSeconds,
      album: album,
      channelId: v.channelId.value,
    );

String _normalizedArtistName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

Future<MusicArtistProfile> _loadArtistProfile(String channelId) async {
  var profile = await _ym.music.getArtistProfile(channelId).timeout(_timeout);
  if (profile.id != channelId) {
    try {
      profile = await _ym.music.getArtistProfile(profile.id).timeout(_timeout);
    } catch (_) {}
  }
  return profile;
}

/// Pagina del artista en YouTube Music. Devuelve null si falla.
Future<ArtistPage?> loadArtistPage(Artist a, {bool refresh = false}) async {
  a = canonicalArtist(a);
  final hit = refresh ? null : _pages[a.channelId];
  if (hit != null &&
      (a.channelId != kazeOfficialChannelId ||
          hit.albums.isNotEmpty ||
          hit.singles.isNotEmpty)) {
    return hit;
  }
  try {
    var p = await _loadArtistProfile(a.channelId);
    if (p.releases.isEmpty) {
      final expectedName = _normalizedArtistName(a.name);
      final queries = a.channelId == kazeOfficialChannelId
          ? const ['putokaze', 'KAZE']
          : [a.name];
      final candidates = <String, MusicArtist>{};
      for (final query in queries) {
        final results = await _ym.music.searchArtists(query).timeout(_timeout);
        for (final candidate in results) {
          if (_normalizedArtistName(candidate.name) == expectedName) {
            candidates.putIfAbsent(candidate.id, () => candidate);
          }
        }
      }
      for (final candidate in candidates.values.take(8)) {
        if (candidate.id == p.id || candidate.id == a.channelId) continue;
        try {
          final candidateProfile = await _loadArtistProfile(candidate.id);
          if (candidateProfile.releases.isNotEmpty) {
            p = candidateProfile;
            break;
          }
        } catch (_) {
          continue;
        }
      }
    }
    final name = p.name.isNotEmpty ? p.name : a.name;
    final albums = <Release>[];
    final singles = <Release>[];
    for (final r in p.releases) {
      final kind = switch (r.type) {
        MusicReleaseType.album => 'Álbum',
        MusicReleaseType.single => 'Single',
        MusicReleaseType.ep => 'EP',
        MusicReleaseType.other => '',
      };
      final rel = Release(
        r.id,
        r.title,
        r.thumbnailUrl ?? '',
        [kind, r.year ?? ''].where((x) => x.isNotEmpty).join(' • '),
      );
      if (r.type == MusicReleaseType.single || r.type == MusicReleaseType.ep) {
        singles.add(rel);
      } else {
        albums.add(rel);
      }
    }
    final page = ArtistPage(
      p.thumbnailUrl,
      p.description ?? '',
      [for (final s in p.topSongs) _track(s.video, name)],
      albums,
      singles,
      [
        for (final r in p.relatedArtists)
          Artist(name: r.name, image: r.thumbnailUrl ?? '', channelId: r.id),
      ],
    );
    _pages[a.channelId] = page;
    return page;
  } catch (_) {
    return null;
  }
}

/// Canciones de un album, single o EP.
Future<List<Track>> loadAlbumTracks(Release r, Artist a) async {
  final hit = _albums[r.id];
  if (hit != null) return hit;
  final page = await _ym.music.getAlbum(r.id).timeout(_timeout);
  final cover =
      (page.thumbnailUrl?.isNotEmpty ?? false) ? page.thumbnailUrl! : r.image;
  final list = [
    for (final v in page.tracks)
      _track(v, v.author.isNotEmpty ? v.author : a.name,
          thumb: cover.isNotEmpty ? cover : null, album: r.title),
  ];
  if (list.isNotEmpty) _albums[r.id] = list;
  return list;
}

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Videoclips: se buscan en YouTube y se quedan los que parecen del artista.
Future<List<Track>> loadVideoclips(Artist a) async {
  final hit = _clipsCache[a.channelId];
  if (hit != null) return hit;
  try {
    final na = _n(a.name);
    if (na.isEmpty) return [];
    final lists = await Future.wait([
      music.search('${a.name} official video'),
      music.search('${a.name} videoclip oficial'),
    ]);
    final seen = <String>{};
    final out = <Track>[];
    for (final t in [for (final l in lists) ...l]) {
      if (!seen.add(t.id)) continue;
      final title = t.title.toLowerCase();
      final mine = t.channelId == a.channelId ||
          _n(t.artist).contains(na) ||
          _n(t.title).contains(na);
      final clip = RegExp(r'video|clip').hasMatch(title) &&
          !RegExp(r'audio|lyric|letra|visuali[sz]er|live|directo')
              .hasMatch(title);
      if (mine && clip) out.add(t);
      if (out.length >= 12) break;
    }
    _clipsCache[a.channelId] = out;
    return out;
  } catch (_) {
    return [];
  }
}
