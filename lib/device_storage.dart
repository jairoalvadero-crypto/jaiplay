import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_tags.dart';
import 'downloads.dart';
import 'models.dart';

const _deviceStorage = MethodChannel('com.jaiplay.app/device_storage');

Future<bool> saveTrackToDevice(Track track) async {
  await _downloadIfNeeded(track);
  final path = downloads.pathFor(track.id);
  if (path == null) throw StateError('No se encontró la canción descargada.');
  final extension = path.substring(path.lastIndexOf('.'));
  final tagged = await _taggedCopy(path, track);
  try {
    final uri = await _deviceStorage.invokeMethod<String>(
      'pickAudioFile',
      {'name': '${_safeName(track.displayTitle)}$extension'},
    );
    if (uri == null) return false;
    await _deviceStorage.invokeMethod<void>(
      'writeAudioFile',
      {'uri': uri, 'path': tagged.path},
    );
    return true;
  } finally {
    await tagged.delete();
  }
}

Future<bool> saveAlbumToDevice(List<Track> tracks) async {
  if (tracks.isEmpty) throw StateError('El álbum no contiene canciones.');
  final uri = await _deviceStorage.invokeMethod<String>('pickAudioDirectory');
  if (uri == null) return false;
  final files = <Map<String, String>>[];
  final taggedFiles = <File>[];
  try {
    for (final track in tracks) {
      await _downloadIfNeeded(track);
      final path = downloads.pathFor(track.id);
      if (path == null) {
        throw StateError('No se encontró descargada «${track.displayTitle}».');
      }
      final tagged = await _taggedCopy(path, track);
      taggedFiles.add(tagged);
      files.add({
        'path': tagged.path,
        'name':
            '${_safeName(track.displayTitle)}${path.substring(path.lastIndexOf('.'))}',
      });
    }
    await _deviceStorage.invokeMethod<void>(
      'writeAudioFilesToDirectory',
      {'uri': uri, 'files': files},
    );
    return true;
  } finally {
    for (final file in taggedFiles) {
      await file.delete();
    }
  }
}

Future<void> _downloadIfNeeded(Track track) async {
  await downloads.download(track);
  final error = downloads.errors[track.id];
  if (error != null) {
    throw StateError('No se pudo descargar «${track.displayTitle}»: $error');
  }
  if (!downloads.isDownloaded(track.id)) {
    throw StateError('La descarga de «${track.displayTitle}» no terminó.');
  }
}

String _safeName(String value) =>
    value.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();

Future<File> _taggedCopy(String path, Track track) async {
  final directory = await getTemporaryDirectory();
  final extension = path.substring(path.lastIndexOf('.'));
  final file = File(
      '${directory.path}/jaiplay-${track.id}-${DateTime.now().microsecondsSinceEpoch}$extension');
  await File(path).copy(file.path);
  try {
    await writeAudioTags(
      file,
      title: track.displayTitle,
      artist: track.artist,
      album: track.album,
    );
    return file;
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}
