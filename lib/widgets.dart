import 'dart:io' as io;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'downloads.dart';
import 'device_storage.dart';
import 'models.dart';
import 'playlist_dialogs.dart';
import 'screens/collection.dart';
import 'screens/now_playing.dart';
import 'services.dart';
import 'theme.dart';

final miniPlayerVisible = ValueNotifier<bool>(true);

class Cover extends StatelessWidget {
  final String url;
  final double? size;
  final double radius;
  const Cover(this.url, {super.key, this.size, this.radius = 0});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final localPath = uri?.scheme == 'file'
        ? uri!.toFilePath()
        : (url.startsWith('/') ? url : null);
    final placeholder = Container(
      width: size,
      height: size,
      color: kCard,
      child: const Icon(Icons.music_note, color: kMuted),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? placeholder
          : localPath != null
              ? kIsWeb
                  ? placeholder
                  : Image.file(
                      io.File(localPath),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder,
                    )
              : CachedNetworkImage(
                  imageUrl: url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: kH2),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: const Text('Ver todo',
                  style: TextStyle(color: kAccent, fontSize: 14)),
            ),
        ],
      ),
    );
  }
}

void openCollection(BuildContext context, Collection c) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CollectionScreen(
          title: c.title, subtitle: c.subtitle, query: c.query),
    ),
  );
}

/// Tarjeta cuadrada con la portada de la primera canción de la búsqueda.
class CollectionCard extends StatelessWidget {
  final Collection c;
  final double size;
  const CollectionCard(this.c, {super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openCollection(context, c),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<List<Track>>(
              future: music.search(c.query),
              builder: (_, snap) {
                final list = snap.data;
                final url =
                    (list == null || list.isEmpty) ? '' : list.first.thumb;
                return Cover(url, size: size, radius: 12);
              },
            ),
            const SizedBox(height: 8),
            Text(c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            Text(c.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  const TrackTile(this.track, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        onTap();
        openNowPlaying(context);
      },
      leading: Cover(track.thumb, size: 48, radius: 6),
      title: Text(track.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15)),
      subtitle: Text(track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: kMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Opciones de descarga',
            onPressed: () => showDownloadOptions(context, [track]),
            icon: const Icon(Icons.download_rounded, color: kMuted, size: 20),
          ),
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => IconButton(
              onPressed: () => store.toggleFav(track),
              icon: Icon(
                store.isFav(track.id) ? Icons.favorite : Icons.favorite_border,
                color: store.isFav(track.id) ? kAccent : kMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final bool subtle;

  const LiquidGlass({
    super.key,
    required this.child,
    required this.borderRadius,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.3),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: Color.fromRGBO(255, 255, 255, 0.08),
              blurRadius: 2,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: subtle ? 14 : 24,
              sigmaY: subtle ? 14 : 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: subtle
                      ? const [
                          Color.fromRGBO(255, 255, 255, 0.09),
                          Color.fromRGBO(20, 20, 22, 0.3),
                          Color.fromRGBO(255, 255, 255, 0.04),
                        ]
                      : const [
                          Color.fromRGBO(255, 255, 255, 0.16),
                          Color.fromRGBO(36, 36, 40, 0.48),
                          Color.fromRGBO(255, 255, 255, 0.09),
                        ],
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Color.fromRGBO(
                    255,
                    255,
                    255,
                    subtle ? 0.14 : 0.2,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
}

class MiniPlayer extends StatelessWidget {
  final bool compact;
  final bool embedded;
  const MiniPlayer({super.key, this.compact = false, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, miniPlayerVisible]),
      builder: (context, _) {
        final t = player.current;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: t == null || !miniPlayerVisible.value
              ? const SizedBox(width: double.infinity, height: 0)
              : GestureDetector(
                  onTap: () => openNowPlaying(context),
                  child: compact
                      ? _CompactMiniPlayer(track: t)
                      : Container(
                          margin: embedded
                              ? EdgeInsets.zero
                              : const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: Builder(
                            builder: (context) {
                              final content = Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    Cover(t.thumb, size: 42, radius: 8),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(t.displayTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          Text(t.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: kMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    player.loading
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2.5),
                                            ),
                                          )
                                        : IconButton(
                                            onPressed: player.toggle,
                                            icon: Icon(
                                              player.playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 30,
                                            ),
                                          ),
                                    IconButton(
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 60, height: 60),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => player.next(),
                                      icon: const Icon(
                                          Icons.fast_forward_rounded,
                                          size: 40),
                                    ),
                                  ],
                                ),
                              );
                              return embedded
                                  ? content
                                  : LiquidGlass(
                                      subtle: true,
                                      borderRadius: BorderRadius.circular(18),
                                      child: content,
                                    );
                            },
                          ),
                        ),
                ),
        );
      },
    );
  }
}

class _CompactMiniPlayer extends StatelessWidget {
  final Track track;
  const _CompactMiniPlayer({required this.track});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: LiquidGlass(
          subtle: true,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Row(
              children: [
                Cover(track.thumb, size: 36, radius: 7),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (player.loading)
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                    onPressed: player.toggle,
                    icon: Icon(
                      player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 23,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

void showTrackMenu(BuildContext context, Track t) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([store, downloads]),
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Cover(t.thumb, size: 44, radius: 6),
              title: Text(t.displayTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted)),
            ),
            const Divider(height: 1, color: Color(0xFF2C2C2E)),
            ListTile(
              leading: Icon(
                store.isFav(t.id) ? Icons.favorite : Icons.favorite_border,
                color: kAccent,
              ),
              title: Text(store.isFav(t.id)
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos'),
              onTap: () => store.toggleFav(t),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: kAccent),
              title: const Text('Añadir a playlist'),
              onTap: () async {
                Navigator.pop(ctx);
                final playlistId = await showPlaylistChooser(context);
                if (playlistId == null) return;
                try {
                  await store.addTracksToPlaylist(playlistId, [t]);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Canción añadida a la playlist')),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('No se pudo añadir la canción: $error')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                downloads.isDownloaded(t.id)
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                color: kAccent,
              ),
              title: const Text('Opciones de descarga'),
              onTap: () {
                Navigator.pop(ctx);
                showDownloadOptions(context, [t]);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void showDownloadOptions(
  BuildContext context,
  List<Track> tracks, {
  bool album = false,
}) {
  if (tracks.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: downloads,
        builder: (context, _) {
          final allDownloaded =
              tracks.every((track) => downloads.isDownloaded(track.id));
          final active =
              tracks.any((track) => downloads.progress.containsKey(track.id));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  album ? Icons.album_rounded : Icons.music_note_rounded,
                  color: kAccent,
                ),
                title: Text(
                    album ? 'Descargar álbum' : tracks.first.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    album ? '${tracks.length} canciones' : tracks.first.artist),
              ),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              ListTile(
                leading: const Icon(Icons.download_for_offline_rounded,
                    color: kAccent),
                title: Text(allDownloaded
                    ? 'Descargado en JaiPlay · Quitar'
                    : 'Descargar en JaiPlay'),
                enabled: !active,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (allDownloaded) {
                    for (final track in tracks) {
                      downloads.remove(track.id);
                    }
                  } else {
                    _runDownloadAction(context, tracks, album: album);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined, color: kAccent),
                title: const Text('Guardar en el dispositivo'),
                enabled: !active,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _runDeviceSave(context, tracks, album: album);
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> _runDownloadAction(
  BuildContext context,
  List<Track> tracks, {
  required bool album,
}) async {
  for (final track in tracks) {
    await downloads.download(track);
    final error = downloads.errors[track.id];
    if (error != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar ${track.displayTitle}: $error'),
        ),
      );
      return;
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(album
          ? 'Álbum descargado en JaiPlay'
          : 'Canción descargada en JaiPlay'),
    ),
  );
}

Future<void> _runDeviceSave(
  BuildContext context,
  List<Track> tracks, {
  required bool album,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final saved = album
        ? await saveAlbumToDevice(tracks)
        : await saveTrackToDevice(tracks.single);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(album
              ? 'Álbum guardado en el dispositivo'
              : 'Canción guardada en el dispositivo'),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo guardar en el dispositivo: $error')),
    );
  }
}
