import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../artist_data.dart';
import '../models.dart';
import '../services.dart';
import '../settings.dart' as preferences;
import '../theme.dart';
import '../widgets.dart';
import 'artist.dart';
import 'now_playing.dart';

const _genrePatterns = <String, List<String>>{
  'Pop': [r'\bpop\b', r'pop latino', r'electropop'],
  'Rock': [r'\brock\b', r'\bmetal\b', r'\bpunk\b'],
  'Hip-Hop': [r'hip.?hop', r'\brap\b', r'\btrap\b'],
  'Reggaeton': [r'reggaeton', r'regueton', r'urbano latino'],
  'Flamenco': [r'flamenco', r'cante jondo'],
  'Electrónica': [r'electr[oó]nica', r'electronic', r'\bedm\b', r'techno'],
  'Latino': [r'm[uú]sica latina', r'latin music', r'latino'],
  'Jazz': [r'\bjazz\b', r'\bswing\b'],
  'Clásica': [r'cl[aá]sica', r'classical', r'orquesta sinf[oó]nica'],
  'Indie': [r'\bindie\b', r'indie pop', r'indie rock'],
};
const _newMusicPlaylist =
    'https://open.spotify.com/playlist/37i9dQZF1DX4JAvHpjipBk';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_WeeklyRecommendations> _recommendations =
      _loadWeeklyRecommendations();
  String? _observedRecentId;
  bool _hasRecommendationSnapshot = false;

  @override
  void initState() {
    super.initState();
    _observedRecentId = store.recents.isEmpty ? null : store.recents.first.id;
    store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final recentId = store.recents.isEmpty ? null : store.recents.first.id;
    if (recentId == _observedRecentId) return;
    _observedRecentId = recentId;
    if (_hasRecommendationSnapshot || !mounted) return;
    setState(() => _recommendations = _loadWeeklyRecommendations());
  }

  String _weekKey(DateTime date) {
    final daysSinceFriday = (date.weekday - DateTime.friday + 7) % 7;
    final friday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysSinceFriday));
    return '${friday.year}-${friday.month.toString().padLeft(2, '0')}-'
        '${friday.day.toString().padLeft(2, '0')}';
  }

  Future<_WeeklyRecommendations> _loadWeeklyRecommendations() async {
    final preferences = await SharedPreferences.getInstance();
    final week = _weekKey(DateTime.now());
    const cacheKey = 'weekly_home_recommendations_v2';
    const weekKey = 'weekly_home_week_v2';
    final cached = preferences.getString(cacheKey);
    _WeeklyRecommendations? previous;
    if (cached != null) {
      try {
        previous = _WeeklyRecommendations.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
        if (preferences.getString(weekKey) == week && previous.hasContent) {
          _hasRecommendationSnapshot = true;
          return previous;
        }
      } on FormatException {
        await preferences.remove(weekKey);
        await preferences.remove(cacheKey);
      } on TypeError {
        await preferences.remove(weekKey);
        await preferences.remove(cacheKey);
      }
    }

    List<Track> newSongs;
    try {
      final (_, tracks, _) = await music.importPlaylist(
        _newMusicPlaylist,
        maxTracks: 12,
      );
      newSongs = tracks;
    } catch (error) {
      if (previous != null && previous.hasContent) {
        _hasRecommendationSnapshot = true;
        return previous;
      }
      rethrow;
    }

    final favoriteArtists = store.mostListenedArtists.take(10).toList();
    final discoveryArtists = <String, Artist>{
      for (final artist in favoriteArtists) _artistKey(artist): artist,
      for (final track in store.recents)
        if (track.artist.trim().isNotEmpty)
          _artistKey(
            Artist(
              name: track.artist,
              image: track.thumb,
              channelId: track.channelId ?? '',
            ),
          ): Artist(
            name: track.artist,
            image: track.thumb,
            channelId: track.channelId ?? '',
          ),
    }.values.take(12).toList();

    final resolvedArtists = <Artist>[];
    for (final artist in discoveryArtists) {
      if (artist.channelId.isNotEmpty) {
        resolvedArtists.add(artist);
      } else {
        final resolved = await music.findArtist(artist.name);
        if (resolved != null) resolvedArtists.add(resolved);
      }
    }

    final profiles = <(Artist, ArtistPage)>[];
    for (var start = 0; start < resolvedArtists.length; start += 4) {
      final batch = resolvedArtists.skip(start).take(4);
      final results = await Future.wait([
        for (final artist in batch)
          loadArtistPage(artist, refresh: true).then(
            (page) => page == null ? null : (artist, page),
          ),
      ]);
      profiles.addAll(results.whereType<(Artist, ArtistPage)>());
    }

    final novelty = <_AlbumPick>[];
    final byGenre = <String, List<_AlbumPick>>{
      for (final genre in _genrePatterns.keys) genre: <_AlbumPick>[],
    };
    final seenAlbums = <String>{};
    final currentYear = DateTime.now().year;
    for (final (artist, page) in profiles) {
      final genreText = [
        artist.name,
        page.description,
        for (final track in page.topSongs) track.title,
      ].join(' ').toLowerCase();
      final picks = [
        for (final release in [...page.albums, ...page.singles])
          if (seenAlbums.add(release.id)) _AlbumPick(artist, release),
      ];
      for (final pick in picks) {
        final year = int.tryParse(
          RegExp(r'\b(?:19|20)\d{2}\b')
                  .firstMatch(pick.release.sub)
                  ?.group(0) ??
              '',
        );
        if (year != null && year >= currentYear - 1) novelty.add(pick);
      }
      for (final entry in _genrePatterns.entries) {
        if (!entry.value
            .any((pattern) => RegExp(pattern).hasMatch(genreText))) {
          continue;
        }
        final albums = byGenre[entry.key]!;
        for (final release in page.albums) {
          if (albums.length >= 10) break;
          if (albums.any((pick) => pick.release.id == release.id)) continue;
          albums.add(_AlbumPick(artist, release));
        }
      }
    }
    novelty.sort((a, b) => _releaseYear(b).compareTo(_releaseYear(a)));
    final recommendations = _WeeklyRecommendations(
      artists: favoriteArtists,
      newSongs: newSongs,
      newReleases: novelty.take(10).toList(),
      byGenre: {
        for (final entry in byGenre.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.take(10).toList(),
      },
    );
    _hasRecommendationSnapshot = recommendations.hasContent;
    if (!recommendations.hasContent) return recommendations;
    final saved = await preferences.setString(
      cacheKey,
      jsonEncode(recommendations.toJson()),
    );
    if (!saved) {
      throw StateError('No se pudieron guardar las recomendaciones semanales.');
    }
    final savedWeek = await preferences.setString(weekKey, week);
    if (!savedWeek) {
      throw StateError('No se pudo guardar la fecha de actualización semanal.');
    }
    return recommendations;
  }

  String _artistKey(Artist artist) => artist.channelId.isNotEmpty
      ? artist.channelId
      : artist.name.toLowerCase();

  int _releaseYear(_AlbumPick pick) =>
      int.tryParse(
        RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(pick.release.sub)?.group(0) ??
            '',
      ) ??
      0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, preferences.appSettings]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_greeting(), style: kTitle),
                ),
                Image.asset(
                  'assets/icon.png',
                  width: 52,
                  height: 52,
                  cacheWidth: 156,
                ),
              ],
            ),
            if (store.recents.isNotEmpty) ...[
              const SectionHeader('Reproducciones recientes'),
              SizedBox(
                height: 184,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: store.recents.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final track = store.recents[index];
                    return _RecentTrackCard(
                      track: track,
                      onTap: () {
                        player.playQueue(store.recents, index);
                        openNowPlaying(context);
                      },
                    );
                  },
                ),
              ),
            ],
            FutureBuilder<_WeeklyRecommendations>(
              future: _recommendations,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No se pudieron actualizar tus recomendaciones: '
                      '${snapshot.error}',
                      style: const TextStyle(color: kMuted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final recommendations = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recommendations.artists.isNotEmpty) ...[
                      const SectionHeader('Artistas favoritos'),
                      SizedBox(
                        height: 132,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendations.artists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) => _ArtistCard(
                            artist: recommendations.artists[index],
                          ),
                        ),
                      ),
                    ],
                    if (recommendations.newSongs.isNotEmpty)
                      _NewSongsShelf(tracks: recommendations.newSongs),
                    if (recommendations.newReleases.isNotEmpty)
                      _AlbumShelf(
                        title: 'Novedades para ti',
                        picks: recommendations.newReleases,
                      ),
                    for (final entry in recommendations.byGenre.entries)
                      _AlbumShelf(
                        title: entry.key,
                        picks: entry.value,
                      ),
                    if (recommendations.artists.isEmpty &&
                        recommendations.newReleases.isEmpty &&
                        recommendations.byGenre.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'Escucha música para crear recomendaciones '
                          'personalizadas. Se actualizarán cada semana.',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'Buenos días'
        : hour >= 12 && hour < 20
            ? 'Buenas tardes'
            : 'Buenas noches';
    final name = preferences.appSettings.displayName.trim();
    return name.isEmpty ? greeting : '$greeting, $name';
  }
}

class _RecentTrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _RecentTrackCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Cover(track.thumb, size: 132, radius: 12),
              const SizedBox(height: 7),
              Text(track.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _NewSongsShelf extends StatelessWidget {
  final List<Track> tracks;

  const _NewSongsShelf({required this.tracks});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Mejores canciones nuevas'),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Spotify · New Music Friday · se actualiza cada viernes',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return _RecentTrackCard(
                  track: track,
                  onTap: () {
                    player.playQueue(tracks, index);
                    openNowPlaying(context);
                  },
                );
              },
            ),
          ),
        ],
      );
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;

  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        ),
        child: SizedBox(
          width: 90,
          child: Column(
            children: [
              Cover(artist.image, size: 76, radius: 38),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _AlbumPick {
  final Artist artist;
  final Release release;

  const _AlbumPick(this.artist, this.release);

  Map<String, dynamic> toJson() => {
        'artist': artist.toJson(),
        'release': {
          'id': release.id,
          'title': release.title,
          'image': release.image,
          'sub': release.sub,
        },
      };

  factory _AlbumPick.fromJson(Map<String, dynamic> json) {
    final release = Map<String, dynamic>.from(json['release'] as Map);
    return _AlbumPick(
      Artist.fromJson(Map<String, dynamic>.from(json['artist'] as Map)),
      Release(
        release['id'] as String,
        release['title'] as String,
        release['image'] as String,
        release['sub'] as String,
      ),
    );
  }
}

class _WeeklyRecommendations {
  final List<Artist> artists;
  final List<Track> newSongs;
  final List<_AlbumPick> newReleases;
  final Map<String, List<_AlbumPick>> byGenre;

  const _WeeklyRecommendations({
    required this.artists,
    required this.newSongs,
    required this.newReleases,
    required this.byGenre,
  });

  bool get hasContent =>
      newSongs.isNotEmpty ||
      artists.isNotEmpty ||
      newReleases.isNotEmpty ||
      byGenre.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'artists': [for (final artist in artists) artist.toJson()],
        'newSongs': [for (final track in newSongs) track.toJson()],
        'newReleases': [for (final pick in newReleases) pick.toJson()],
        'byGenre': {
          for (final entry in byGenre.entries)
            entry.key: [for (final pick in entry.value) pick.toJson()],
        },
      };

  factory _WeeklyRecommendations.fromJson(Map<String, dynamic> json) {
    final genres = Map<String, dynamic>.from(json['byGenre'] as Map);
    return _WeeklyRecommendations(
      artists: [
        for (final artist in json['artists'] as List)
          Artist.fromJson(Map<String, dynamic>.from(artist as Map)),
      ],
      newSongs: [
        for (final track in (json['newSongs'] as List? ?? const []))
          Track.fromJson(Map<String, dynamic>.from(track as Map)),
      ],
      newReleases: [
        for (final pick in json['newReleases'] as List)
          _AlbumPick.fromJson(Map<String, dynamic>.from(pick as Map)),
      ],
      byGenre: {
        for (final entry in genres.entries)
          entry.key: [
            for (final pick in entry.value as List)
              _AlbumPick.fromJson(Map<String, dynamic>.from(pick as Map)),
          ],
      },
    );
  }
}

class _AlbumShelf extends StatelessWidget {
  final String title;
  final List<_AlbumPick> picks;

  const _AlbumShelf({required this.title, required this.picks});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: picks.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final pick = picks[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReleaseScreen(
                        release: pick.release,
                        artist: pick.artist,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 148,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Cover(pick.release.image, size: 148, radius: 12),
                        const SizedBox(height: 7),
                        Text(pick.release.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(pick.artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: kMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
}
