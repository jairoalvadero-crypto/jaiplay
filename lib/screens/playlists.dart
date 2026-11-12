import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../downloads.dart';
import '../models.dart';
import '../playlist_dialogs.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class PlaylistsLibraryScreen extends StatelessWidget {
  const PlaylistsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Playlists'),
          actions: [
            IconButton(
              tooltip: 'Crear playlist',
              onPressed: () => _createPlaylist(context),
              icon: const Icon(Icons.add_rounded, color: kAccent),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de playlists',
              icon: const Icon(Icons.more_vert_rounded, color: kMuted),
              onSelected: (value) {
                if (value == 'create') _createPlaylist(context);
                if (value == 'import') _importPlaylist(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'create',
                  child: Text('Crear playlist'),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Text('Importar desde un enlace'),
                ),
              ],
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (store.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'Crea una playlist o importa un enlace público de '
                    'YouTube Music, Spotify o Apple Music.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted),
                  ),
                )
              else
                for (final playlist in store.playlists)
                  _PlaylistListTile(playlist: playlist),
            ],
          ),
        ),
        bottomNavigationBar: const MiniPlayer(),
      );
}

class _PlaylistListTile extends StatelessWidget {
  final UserPlaylist playlist;

  const _PlaylistListTile({required this.playlist});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _PlaylistCover(
          playlist: playlist,
          size: 54,
          radius: 8,
        ),
        title:
            Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${playlist.tracks.length} canciones',
          style: const TextStyle(color: kMuted),
        ),
        trailing: IconButton(
          tooltip: 'Opciones de ${playlist.name}',
          icon: const Icon(Icons.more_vert_rounded, color: kMuted),
          onPressed: () => _showPlaylistOptions(context, playlist),
        ),
        onTap: () => _openPlaylist(context, playlist),
      );
}

Future<void> _createPlaylist(BuildContext context) async {
  final name = await showPlaylistNameDialog(context);
  if (name == null || !context.mounted) return;
  try {
    final playlist = await store.createPlaylist(name);
    if (!context.mounted) return;
    _openPlaylist(context, playlist);
  } catch (error) {
    if (!context.mounted) return;
    _showError(context, 'No se pudo crear la playlist: $error');
  }
}

Future<void> _importPlaylist(BuildContext context) async {
  final link = await showDialog<String>(
    context: context,
    builder: (_) => const _ImportPlaylistDialog(),
  );
  if (link == null || !context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final (title, tracks, skipped) = await music.importPlaylist(link);
    final playlist = await store.createPlaylist(title, tracks: tracks);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playlist importada: ${tracks.length} canciones añadidas; '
            '$skipped no se encontraron o no se pudieron buscar en JaiPlay.',
          ),
        ),
      );
    }
    _openPlaylist(context, playlist);
  } catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _showError(context, 'No se pudo importar la playlist: $error');
  }
}

class PlaylistScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final playlist = store.playlistById(playlistId);
          if (playlist == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('La playlist ya no existe.')),
            );
          }
          return Scaffold(
            extendBody: true,
            appBar: AppBar(
              title: Text(playlist.name),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (action) => _managePlaylist(
                    context,
                    playlist,
                    action,
                    closeAfterDelete: action == 'delete',
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'rename', child: Text('Cambiar nombre')),
                    PopupMenuItem(
                        value: 'cover', child: Text('Cambiar carátula')),
                    PopupMenuItem(
                        value: 'reset-cover',
                        child: Text('Usar carátula de la primera canción')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Center(
                  child: _PlaylistCover(
                    playlist: playlist,
                    size: 190,
                    radius: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(playlist.name, style: kTitle),
                Text(
                  '${playlist.tracks.length} canciones',
                  style: const TextStyle(color: kMuted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: playlist.tracks.isEmpty
                            ? null
                            : () => player.playQueue(playlist.tracks, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Reproducir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Añadir canciones',
                      onPressed: () => _addSongs(context, playlist),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (playlist.tracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Añade canciones desde tus listas o busca música.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted),
                    ),
                  )
                else
                  for (var i = 0; i < playlist.tracks.length; i++)
                    _PlaylistTrackTile(
                      playlist: playlist,
                      track: playlist.tracks[i],
                      onTap: () => player.playQueue(playlist.tracks, i),
                    ),
              ],
            ),
            bottomNavigationBar: const MiniPlayer(),
          );
        },
      );
}

class _PlaylistTrackTile extends StatelessWidget {
  final UserPlaylist playlist;
  final Track track;
  final VoidCallback onTap;

  const _PlaylistTrackTile({
    required this.playlist,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Cover(track.thumb, size: 48, radius: 6),
        title: Text(track.displayTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kMuted)),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Quitar de la playlist',
          icon: const Icon(Icons.remove_circle_outline, color: kMuted),
          onPressed: () async {
            try {
              await store.removeTrackFromPlaylist(playlist.id, track.id);
            } catch (error) {
              if (context.mounted) {
                _showError(context, 'No se pudo quitar la canción: $error');
              }
            }
          },
        ),
      );
}

class _PlaylistCover extends StatelessWidget {
  final UserPlaylist playlist;
  final double size;
  final double radius;

  const _PlaylistCover({
    required this.playlist,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => Cover(
        playlist.cover,
        size: size,
        radius: radius,
      );
}

class _ImportPlaylistDialog extends StatefulWidget {
  const _ImportPlaylistDialog();

  @override
  State<_ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends State<_ImportPlaylistDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Importar playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pega el enlace de una playlist pública de YouTube Music, '
              'Spotify o Apple Music. Las canciones se buscarán en JaiPlay.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://open.spotify.com/playlist/…',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final uri = Uri.tryParse(_controller.text.trim());
              if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                setState(() => _error = 'Pega un enlace válido.');
                return;
              }
              Navigator.pop(context, _controller.text.trim());
            },
            child: const Text('Importar'),
          ),
        ],
      );
}

class _PlaylistSearchScreen extends StatefulWidget {
  final String playlistId;

  const _PlaylistSearchScreen({required this.playlistId});

  @override
  State<_PlaylistSearchScreen> createState() => _PlaylistSearchScreenState();
}

class _PlaylistSearchScreenState extends State<_PlaylistSearchScreen> {
  final _controller = TextEditingController();
  Future<List<Track>>? _search;
  final Set<String> _added = {};
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    setState(() {
      _error = null;
      _search = music.search(clean);
    });
  }

  Future<void> _add(Track track) async {
    try {
      await store.addTracksToPlaylist(widget.playlistId, [track]);
      if (mounted) setState(() => _added.add(track.id));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Buscar canciones')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: 'Canción o artista',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => _submit(_controller.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: kAccent)),
              ),
            Expanded(
              child: _search == null
                  ? const Center(
                      child: Text('Busca canciones para añadirlas.',
                          style: TextStyle(color: kMuted)),
                    )
                  : FutureBuilder<List<Track>>(
                      future: _search,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No se pudo completar la búsqueda: ${snapshot.error}',
                                style: const TextStyle(color: kMuted),
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return ListView(
                          children: [
                            for (final track in snapshot.data!)
                              ListTile(
                                leading:
                                    Cover(track.thumb, size: 48, radius: 6),
                                title: Text(track.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  onPressed: _added.contains(track.id)
                                      ? null
                                      : () => _add(track),
                                  icon: Icon(
                                    _added.contains(track.id)
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    color: _added.contains(track.id)
                                        ? kMuted
                                        : kAccent,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}

Future<void> _addSongs(BuildContext context, UserPlaylist playlist) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Añadir canciones', style: kH2)),
          ListTile(
            leading: const Icon(Icons.search_rounded, color: kAccent),
            title: const Text('Buscar canciones'),
            onTap: () => Navigator.pop(context, 'search'),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_rounded, color: kAccent),
            title: const Text('Elegir de Favoritos'),
            onTap: () => Navigator.pop(context, 'favorites'),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: kAccent),
            title: const Text('Elegir de Recientes'),
            onTap: () => Navigator.pop(context, 'recents'),
          ),
          ListTile(
            leading: const Icon(Icons.download_done_rounded, color: kAccent),
            title: const Text('Elegir de Descargas'),
            onTap: () => Navigator.pop(context, 'downloads'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || source == null) return;
  if (source == 'search') {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlaylistSearchScreen(playlistId: playlist.id),
      ),
    );
    return;
  }
  final tracks = switch (source) {
    'favorites' => store.favs,
    'recents' => store.recents,
    'downloads' => downloads.tracks,
    _ => const <Track>[],
  };
  final selected = await showDialog<List<Track>>(
    context: context,
    builder: (_) => _TrackSelectionDialog(
      title: switch (source) {
        'favorites' => 'Favoritos',
        'recents' => 'Recientes',
        _ => 'Descargas',
      },
      tracks: tracks,
    ),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;
  try {
    await store.addTracksToPlaylist(playlist.id, selected);
  } catch (error) {
    if (context.mounted) {
      _showError(context, 'No se pudieron añadir las canciones: $error');
    }
  }
}

class _TrackSelectionDialog extends StatefulWidget {
  final String title;
  final List<Track> tracks;

  const _TrackSelectionDialog({required this.title, required this.tracks});

  @override
  State<_TrackSelectionDialog> createState() => _TrackSelectionDialogState();
}

class _TrackSelectionDialogState extends State<_TrackSelectionDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Añadir de ${widget.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: widget.tracks.isEmpty
              ? const Text('No hay canciones disponibles.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final track in widget.tracks)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedIds.contains(track.id),
                        secondary: Cover(track.thumb, size: 40, radius: 5),
                        title: Text(track.displayTitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onChanged: (selected) => setState(() {
                          if (selected == true) {
                            _selectedIds.add(track.id);
                          } else {
                            _selectedIds.remove(track.id);
                          }
                        }),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      widget.tracks
                          .where((track) => _selectedIds.contains(track.id))
                          .toList(),
                    ),
            child: Text('Añadir (${_selectedIds.length})'),
          ),
        ],
      );
}

void _openPlaylist(BuildContext context, UserPlaylist playlist) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PlaylistScreen(playlistId: playlist.id),
    ),
  );
}

Future<void> _showPlaylistOptions(
    BuildContext context, UserPlaylist playlist) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: _PlaylistCover(playlist: playlist, size: 44, radius: 6),
            title: Text(playlist.name),
            subtitle: Text('${playlist.tracks.length} canciones'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Cambiar nombre'),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: const Text('Cambiar carátula'),
            onTap: () => Navigator.pop(context, 'cover'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Eliminar playlist'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (action != null && context.mounted) {
    await _managePlaylist(context, playlist, action);
  }
}

Future<void> _managePlaylist(
  BuildContext context,
  UserPlaylist playlist,
  String action, {
  bool closeAfterDelete = false,
}) async {
  try {
    switch (action) {
      case 'rename':
        final name = await showPlaylistNameDialog(
          context,
          initialName: playlist.name,
        );
        if (name != null) await store.renamePlaylist(playlist.id, name);
        break;
      case 'cover':
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1200,
          maxHeight: 1200,
        );
        if (image == null) return;
        final directory = await getApplicationSupportDirectory();
        final covers = io.Directory('${directory.path}/playlist-covers');
        await covers.create(recursive: true);
        final candidate =
            image.name.contains('.') ? image.name.split('.').last : 'jpg';
        final extension = RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(candidate)
            ? candidate.toLowerCase()
            : 'jpg';
        final target = io.File('${covers.path}/${playlist.id}.$extension');
        await io.File(image.path).copy(target.path);
        await store.setPlaylistCover(playlist.id, target.path);
        break;
      case 'reset-cover':
        await store.clearPlaylistCover(playlist.id);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar playlist'),
            content: Text('¿Quieres eliminar "${playlist.name}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar')),
            ],
          ),
        );
        if (confirmed == true) {
          await store.deletePlaylist(playlist.id);
          if (closeAfterDelete &&
              context.mounted &&
              Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        break;
    }
  } catch (error) {
    if (context.mounted) _showError(context, 'No se pudo actualizar: $error');
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
