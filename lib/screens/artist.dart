import 'dart:math';

import 'package:flutter/material.dart';

import '../artist_data.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'collection.dart';
import 'now_playing.dart';

class ArtistScreen extends StatefulWidget {
  final Artist artist;
  ArtistScreen({super.key, required Artist artist})
      : artist = canonicalArtist(artist);

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  late final Future<ArtistPage?> _page = loadArtistPage(widget.artist);
  late final Future<List<Track>> _songs = _loadSongs();
  late final Future<List<Track>> _clips = loadVideoclips(widget.artist);
  bool _allSongs = false;
  bool _allSingles = false;
  bool _allRelated = false;

  Future<List<Track>> _loadSongs() async {
    final p = await _page;
    if (p != null && p.topSongs.isNotEmpty) return p.topSongs;
    return music.artistTracks(widget.artist);
  }

  void _play(List<Track> list, bool shuffle) {
    if (list.isEmpty) return;
    player.shuffle = shuffle;
    player.playQueue(list, shuffle ? Random().nextInt(list.length) : 0);
    openNowPlaying(context);
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 340,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<ArtistPage?>(
                  future: _page,
                  builder: (_, s) => Cover(s.data?.image ?? artist.image),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Colors.black
                      ],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 12,
                  child: Text(
                    artist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: kTitle.copyWith(fontSize: 34),
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final f = store.isFollowing(artist.channelId);
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => store.toggleFollow(artist),
                    icon: Icon(f ? Icons.check_rounded : Icons.add_rounded),
                    label: Text(f ? 'Siguiendo' : 'Seguir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: f ? kCard : kAccent,
                      foregroundColor: f ? kAccent : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              );
            },
          ),
          FutureBuilder<List<Track>>(
            future: _songs,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _songsSection(snap.data ?? []);
            },
          ),
          FutureBuilder<ArtistPage?>(
            future: _page,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final p = snap.data;
              if (p == null) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Text('No se pudo cargar el catálogo del artista.',
                      style: TextStyle(color: kMuted)),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.albums.isNotEmpty)
                    _Shelf(
                      title: 'Álbumes',
                      count: p.albums.length,
                      collapsedWidth: 140,
                      heightOf: (w) => w + 72,
                      itemBuilder: (i, w) => _releaseCard(p.albums[i], w),
                    ),
                  FutureBuilder<List<Track>>(
                    future: _clips,
                    builder: (context, cs) {
                      final clips = cs.data ?? const <Track>[];
                      if (clips.isEmpty) return const SizedBox.shrink();
                      return _Shelf(
                        title: 'Videoclips',
                        count: clips.length,
                        collapsedWidth: 220,
                        heightOf: (w) => w * 9 / 16 + 56,
                        itemBuilder: (i, w) => _clipCard(clips, i, w),
                      );
                    },
                  ),
                  if (p.singles.isNotEmpty)
                    _Shelf(
                      title: 'Singles y EPs',
                      count: p.singles.length,
                      limit: 10,
                      collapsedWidth: 140,
                      heightOf: (w) => w + 72,
                      expanded: _allSingles,
                      onToggle: () =>
                          setState(() => _allSingles = !_allSingles),
                      itemBuilder: (i, w) => _releaseCard(p.singles[i], w),
                    ),
                  if (p.related.isNotEmpty)
                    _Shelf(
                      title: 'Artistas similares',
                      count: p.related.length,
                      limit: 10,
                      collapsedWidth: 110,
                      heightOf: (w) => w + 40,
                      expanded: _allRelated,
                      onToggle: () =>
                          setState(() => _allRelated = !_allRelated),
                      itemBuilder: (i, w) => _artistCard(p.related[i], w),
                    ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Widget _songsSection(List<Track> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('No se encontraron canciones.',
              style: TextStyle(color: kMuted)),
        ),
      );
    }
    final shown = _allSongs ? list.length : min(4, list.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _play(list, false),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _play(list, true),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatorio'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCard,
                    foregroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SectionHeader('Canciones populares'),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown; i++)
                  TrackTile(list[i], onTap: () {
                    player.shuffle = false;
                    player.playQueue(list, i);
                  }),
              ],
            ),
          ),
          if (list.length > 4)
            InkWell(
              onTap: () => setState(() => _allSongs = !_allSongs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(_allSongs ? 'Mostrar menos' : 'Mostrar más',
                        style: const TextStyle(color: kAccent, fontSize: 15)),
                    const SizedBox(width: 4),
                    Icon(
                      _allSongs
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: kAccent,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _releaseCard(Release r, double w) {
    return SizedBox(
      width: w,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReleaseScreen(release: r, artist: widget.artist),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1, child: Cover(r.image, radius: 10)),
            const SizedBox(height: 8),
            Text(r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            if (r.sub.isNotEmpty)
              Text(r.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }

  Widget _clipCard(List<Track> list, int i, double w) {
    final t = list[i];
    return SizedBox(
      width: w,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          player.shuffle = false;
          player.playQueue(list, i);
          openNowPlaying(context);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: Cover(t.thumb, radius: 10)),
            const SizedBox(height: 8),
            Text(t.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _artistCard(Artist a, double w) {
    return SizedBox(
      width: w,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: a)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 1, child: Cover(a.image, radius: w / 2)),
            const SizedBox(height: 8),
            Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal con titulo. Si hay mas de [limit] elementos, tocar el
/// titulo despliega todo en cuadricula.
class _Shelf extends StatelessWidget {
  final String title;
  final int count;
  final int limit;
  final double collapsedWidth;
  final double Function(double w) heightOf;
  final Widget Function(int i, double w) itemBuilder;
  final bool expanded;
  final VoidCallback? onToggle;

  const _Shelf({
    required this.title,
    required this.count,
    required this.collapsedWidth,
    required this.heightOf,
    required this.itemBuilder,
    this.limit = 1000,
    this.expanded = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final canExpand = onToggle != null && count > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canExpand ? onToggle : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: kH2),
                if (canExpand) ...[
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kAccent,
                  ),
                ],
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final w3 = (c.maxWidth - 40 - 24) / 3;
            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        children: [
                          for (var i = 0; i < count; i++) itemBuilder(i, w3),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: heightOf(collapsedWidth),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 20, right: 8),
                        itemCount: min(count, limit),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: itemBuilder(i, collapsedWidth),
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }
}

/// Canciones de un album, single o EP.
class ReleaseScreen extends StatefulWidget {
  final Release release;
  final Artist artist;
  const ReleaseScreen({super.key, required this.release, required this.artist});

  @override
  State<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends State<ReleaseScreen> {
  late final Future<List<Track>> _f =
      loadAlbumTracks(widget.release, widget.artist);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _f,
      builder: (context, snap) {
        final done = snap.connectionState == ConnectionState.done;
        final list = snap.data ?? const <Track>[];
        if (done && list.isNotEmpty) {
          return CollectionScreen(
            title: widget.release.title,
            subtitle: widget.artist.name,
            tracks: list,
            savedAlbum: SavedAlbum(
              id: widget.release.id,
              title: widget.release.title,
              image: widget.release.image,
              subtitle: widget.release.sub,
              artistName: widget.artist.name,
              artistImage: widget.artist.image,
              artistChannelId: widget.artist.channelId,
            ),
          );
        }
        return Scaffold(
          extendBody: true,
          appBar: AppBar(title: Text(widget.release.title)),
          body: Center(
            child: done
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No se pudo cargar este lanzamiento.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted)),
                  )
                : const CircularProgressIndicator(),
          ),
          bottomNavigationBar: const MiniPlayer(),
        );
      },
    );
  }
}
