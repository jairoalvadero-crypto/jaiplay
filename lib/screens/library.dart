import 'package:flutter/material.dart';

import '../downloads.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'artists.dart';
import 'collection.dart';
import 'favorite_albums.dart';
import 'playlists.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  void _open(BuildContext c, String title, List<Track> tracks) =>
      Navigator.push(
        c,
        MaterialPageRoute(
          builder: (_) => CollectionScreen(title: title, tracks: tracks),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, downloads]),
        builder: (context, _) {
          final recents = store.recents;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text('Biblioteca', style: kTitle),
              const SizedBox(height: 12),
              _Row(
                Icons.queue_music_rounded,
                'Playlists',
                '${store.playlists.length}',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlaylistsLibraryScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _Row(
                  Icons.person_rounded,
                  'Artistas',
                  '${store.artists.length}',
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FollowedArtistsScreen()),
                      )),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _Row(Icons.favorite_rounded, 'Favoritos', '${store.favs.length}',
                  () => _open(context, 'Favoritos', store.favs)),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _Row(
                Icons.album_rounded,
                'Álbumes favoritos',
                '${store.favoriteAlbums.length}',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FavoriteAlbumsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _Row(Icons.history_rounded, 'Recientes', '${recents.length}',
                  () => _open(context, 'Recientes', recents)),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _Row(
                  Icons.download_done_rounded,
                  'Descargas',
                  '${downloads.tracks.length}',
                  () => _open(context, 'Descargas', downloads.tracks)),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              if (recents.isNotEmpty) ...[
                SectionHeader('Recientes',
                    onMore: () => _open(context, 'Recientes', recents)),
                for (var i = 0; i < recents.length && i < 5; i++)
                  TrackTile(recents[i],
                      onTap: () => player.playQueue(recents, i)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final VoidCallback onTap;
  const _Row(this.icon, this.label, this.count, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: kAccent),
      title: Text(label, style: const TextStyle(fontSize: 18)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: const TextStyle(color: kMuted)),
          const Icon(Icons.chevron_right, color: kMuted),
        ],
      ),
    );
  }
}
