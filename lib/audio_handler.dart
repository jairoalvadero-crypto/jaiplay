import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'models.dart';
import 'services.dart';

late JaiPlayAudioHandler audioHandler;

/// Conecta la pantalla de bloqueo y la notificacion con PlayerService.
class JaiPlayAudioHandler extends BaseAudioHandler with SeekHandler {
  static const _queueId = 'jaiplay:queue';
  static const _favoritesId = 'jaiplay:favorites';
  static const _recentId = 'jaiplay:recent';
  static const _playlistsId = 'jaiplay:playlists';
  static const _playlistPrefix = 'jaiplay:playlist:';
  AudioPlayer? _boundPlayer;
  StreamSubscription<PlaybackEvent>? _playbackSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  JaiPlayAudioHandler() {
    player.addListener(_bindPlayer);
    _bindPlayer();
  }

  void _bindPlayer() {
    final p = player.audio;
    if (_boundPlayer == p) return;
    _playbackSubscription?.cancel();
    _durationSubscription?.cancel();
    _boundPlayer = p;
    _playbackSubscription =
        p.playbackEventStream.listen((_) => _broadcast(), onError: (_) {});
    _durationSubscription = p.durationStream.listen((d) {
      final m = mediaItem.value;
      if (m != null && d != null && m.duration != d) {
        unawaited(updateMediaItem(m.copyWith(duration: d)));
      }
    });
    _broadcast();
  }

  void publishQueue(List<MediaItem> items) => queue.add(items);

  void publishMediaItem(MediaItem item) => mediaItem.add(item);

  MediaItem _folder(String id, String title) =>
      MediaItem(id: id, title: title, playable: false);

  MediaItem _trackItem(Track track) => MediaItem(
        id: track.id,
        title: track.displayTitle,
        artist: track.artist,
        duration:
            track.seconds == null ? null : Duration(seconds: track.seconds!),
        artUri: track.thumb.isEmpty ? null : Uri.tryParse(track.thumb),
      );

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return [
          _folder(_queueId, 'Cola de reproducción'),
          _folder(_favoritesId, 'Favoritos'),
          _folder(_recentId, 'Reproducidas recientemente'),
          _folder(_playlistsId, 'Mis playlists'),
        ];
      case AudioService.recentRootId:
        return store.recents.isEmpty ? [] : [_trackItem(store.recents.first)];
      case _queueId:
        return player.queue.map(_trackItem).toList();
      case _favoritesId:
        return store.favs.map(_trackItem).toList();
      case _recentId:
        return store.recents.map(_trackItem).toList();
      default:
        if (parentMediaId == _playlistsId) {
          return store.playlists
              .map((playlist) => _folder(
                    '$_playlistPrefix${playlist.id}',
                    playlist.name,
                  ))
              .toList();
        }
        if (parentMediaId.startsWith(_playlistPrefix)) {
          final playlist = store
              .playlistById(parentMediaId.substring(_playlistPrefix.length));
          return playlist?.tracks.map(_trackItem).toList() ?? [];
        }
        return [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final tracks = [
      ...player.queue,
      ...store.favs,
      ...store.recents,
      for (final playlist in store.playlists) ...playlist.tracks,
    ];
    for (final track in tracks) {
      if (track.id == mediaId) return _trackItem(track);
    }
    return null;
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    final currentQueue = player.queue;
    final queueIndex = currentQueue.indexWhere((track) => track.id == mediaId);
    if (queueIndex >= 0) {
      await player.playQueue(currentQueue, queueIndex);
      return;
    }

    final favoritesIndex =
        store.favs.indexWhere((track) => track.id == mediaId);
    if (favoritesIndex >= 0) {
      await player.playQueue(store.favs, favoritesIndex);
      return;
    }

    final recentsIndex =
        store.recents.indexWhere((track) => track.id == mediaId);
    if (recentsIndex >= 0) {
      await player.playQueue(store.recents, recentsIndex);
      return;
    }

    for (final playlist in store.playlists) {
      final index = playlist.tracks.indexWhere((track) => track.id == mediaId);
      if (index >= 0) {
        await player.playQueue(playlist.tracks, index);
        return;
      }
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) =>
      playFromMediaId(mediaItem.id);

  void _broadcast() {
    final p = player.audio;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (p.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[p.processingState]!,
      playing: p.playing,
      updatePosition: p.position,
      bufferedPosition: p.bufferedPosition,
      speed: p.speed,
      queueIndex: player.index,
    ));
  }

  @override
  Future<void> play() async {
    final p = player.audio;
    if (p.processingState == ProcessingState.completed) {
      await p.seek(Duration.zero);
    }
    await player.resumePlayback();
  }

  @override
  Future<void> pause() => player.pausePlayback();

  @override
  Future<void> stop() async {
    await player.stopPlayback();
    mediaItem.add(null);
    queue.add(const []);
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.prev();
}
