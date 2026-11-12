import 'dart:math';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'now_playing.dart';

/// Pantalla de lista (playlist / género / favoritos...).
class CollectionScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? query;
  final List<Track>? tracks;
  final SavedAlbum? savedAlbum;

  const CollectionScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.query,
    this.tracks,
    this.savedAlbum,
  });

  Future<List<Track>> _load() =>
      tracks != null ? Future.value(tracks!) : music.search(query!);

  void _play(BuildContext context, List<Track> list, bool shuffle) {
    if (list.isEmpty) return;
    player.shuffle = shuffle;
    player.playQueue(list, shuffle ? Random().nextInt(list.length) : 0);
    openNowPlaying(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Track>>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Sin conexión o error al cargar',
                  style: TextStyle(color: kMuted)),
            );
          }
          final list = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              if (list.isNotEmpty)
                Center(
                  child: Cover(list.first.thumb, size: 170, radius: 12),
                ),
              const SizedBox(height: 16),
              Text(title, style: kTitle),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(color: kMuted, fontSize: 15)),
              if (savedAlbum != null) ...[
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              store.toggleAlbumFavorite(savedAlbum!),
                          icon: Icon(
                            store.isAlbumFavorite(savedAlbum!.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kAccent,
                          ),
                          label: Text(
                            store.isAlbumFavorite(savedAlbum!.id)
                                ? 'En favoritos'
                                : 'Guardar álbum',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              showDownloadOptions(context, list, album: true),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Descargar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _play(context, list, false),
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
                      onPressed: () => _play(context, list, true),
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
              const SizedBox(height: 12),
              for (var i = 0; i < list.length; i++)
                TrackTile(list[i], onTap: () {
                  player.shuffle = false;
                  player.playQueue(list, i);
                }),
            ],
          );
        },
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
