import 'package:flutter/material.dart';

import 'models.dart';
import 'services.dart';
import 'theme.dart';

Future<void> showTrackHeartOptions(
  BuildContext context,
  Track track, {
  required bool isFavorite,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: kAccent),
              title: Text(
                  isFavorite ? 'Quitar de Favoritos' : 'Dejar en Favoritos'),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            const Divider(height: 1),
            const ListTile(
              title: Text('Añadir a una playlist', style: kH2),
            ),
            for (final playlist in store.playlists)
              ListTile(
                leading: const Icon(
                  Icons.queue_music_rounded,
                  color: kAccent,
                ),
                title: Text(playlist.name),
                subtitle: Text('${playlist.tracks.length} canciones'),
                onTap: () => Navigator.pop(context, 'playlist:${playlist.id}'),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: kAccent),
              title: const Text('Crear playlist con esta canción'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  try {
    if (action == 'favorite') {
      store.toggleFav(track);
      return;
    }
    if (action == 'create') {
      final name = await showPlaylistNameDialog(context);
      if (name == null || !context.mounted) return;
      await store.createPlaylist(name, tracks: [track]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist "$name" creada con la canción')),
        );
      }
      return;
    }
    if (action.startsWith('playlist:')) {
      final id = action.substring('playlist:'.length);
      await store.addTracksToPlaylist(id, [track]);
      if (context.mounted) {
        final playlist = store.playlistById(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              playlist == null
                  ? 'Canción añadida a la playlist'
                  : 'Canción añadida a "${playlist.name}"',
            ),
          ),
        );
      }
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo completar la acción: $error')),
    );
  }
}

Future<String?> showPlaylistNameDialog(BuildContext context,
    {String initialName = ''}) async {
  final controller = TextEditingController(text: initialName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initialName.isEmpty ? 'Nueva playlist' : 'Cambiar nombre'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}

Future<String?> showPlaylistChooser(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: kCard,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => store.playlists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Text('Crea una playlist desde Biblioteca primero.'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    const ListTile(
                      title: Text('Añadir a playlist', style: kH2),
                    ),
                    for (final playlist in store.playlists)
                      ListTile(
                        leading: const Icon(
                          Icons.queue_music_rounded,
                          color: kAccent,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.tracks.length} canciones'),
                        onTap: () => Navigator.pop(context, playlist.id),
                      ),
                  ],
                ),
        ),
      ),
    );
