import 'package:flutter/material.dart';

import '../artist_data.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'artist.dart';

class FavoriteAlbumsScreen extends StatelessWidget {
  const FavoriteAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        appBar: AppBar(title: const Text('Álbumes favoritos')),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final albums = store.favoriteAlbums;
            if (albums.isEmpty) {
              return const Center(
                child: Text(
                  'Los álbumes que guardes como favoritos aparecerán aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final artist = Artist(
                  name: album.artistName,
                  image: album.artistImage,
                  channelId: album.artistChannelId,
                );
                final release = Release(
                  album.id,
                  album.title,
                  album.image,
                  album.subtitle,
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Cover(album.image, size: 56, radius: 8),
                  title: Text(album.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(album.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMuted)),
                  trailing: IconButton(
                    tooltip: 'Quitar de álbumes favoritos',
                    onPressed: () => store.toggleAlbumFavorite(album),
                    icon: const Icon(Icons.favorite, color: kAccent),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ReleaseScreen(release: release, artist: artist),
                    ),
                  ),
                );
              },
            );
          },
        ),
        bottomNavigationBar: const MiniPlayer(),
      );
}
