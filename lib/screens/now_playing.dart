import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../downloads.dart';
import '../lyrics.dart';
import '../models.dart';
import '../playlist_dialogs.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'artist.dart';

final _showLyrics = ValueNotifier<bool>(false);

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const _PlayerPage(),
    ),
  );
}

class _PlayerPage extends StatefulWidget {
  const _PlayerPage();

  @override
  State<_PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<_PlayerPage> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      setState(() => _dragOffset += details.delta.dy);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > 100 || details.velocity.pixelsPerSecond.dy > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _dragOffset, 0),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: NowPlaying(showHandle: false),
                ),
              ],
            ),
          ),
        ),
      );
}

String _fmt(Duration d) {
  if (d.isNegative) d = Duration.zero;
  return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class NowPlaying extends StatelessWidget {
  final bool showHandle;

  const NowPlaying({super.key, this.showHandle = true});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, store, downloads, _showLyrics]),
      builder: (context, _) {
        final t = player.current;
        if (t == null) return const SizedBox.shrink();
        final fav = store.isFav(t.id);
        final showLy = _showLyrics.value && t.streamUrl == null;
        final dlError = downloads.errors[t.id];
        return SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > constraints.maxHeight) {
                  return _landscapeContent(
                    context,
                    t,
                    fav,
                    showLy,
                    dlError,
                  );
                }
                return Column(
                  children: [
                    if (showHandle)
                      Container(
                        width: 36,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    if (showLy)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: LyricsView(key: ValueKey(t.id), track: t),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      AspectRatio(
                        aspectRatio: 1,
                        child: Cover(t.thumb, radius: 16),
                      ),
                      const Spacer(),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              _ArtistName(track: t),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => showTrackHeartOptions(
                            context,
                            t,
                            isFavorite: fav,
                          ),
                          icon: Icon(
                            fav ? Icons.favorite : Icons.favorite_border,
                            color: kAccent,
                          ),
                        ),
                      ],
                    ),
                    if (player.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(player.error!,
                            style:
                                const TextStyle(color: kAccent, fontSize: 12)),
                      ),
                    if (dlError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Descarga fallida: $dlError',
                            style:
                                const TextStyle(color: kAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    t.streamUrl != null
                        ? const _LiveBadge()
                        : _Progress(track: t),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: player.toggleShuffle,
                          icon: Icon(Icons.shuffle_rounded,
                              color: player.shuffle ? kAccent : Colors.white70),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 60, height: 60),
                          padding: EdgeInsets.zero,
                          iconSize: 40,
                          onPressed: () => player.prev(),
                          icon: const Icon(Icons.fast_rewind_rounded),
                        ),
                        player.loading
                            ? const SizedBox(
                                width: 64,
                                height: 64,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 3),
                                ),
                              )
                            : IconButton(
                                iconSize: 64,
                                onPressed: player.toggle,
                                icon: Icon(player.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                              ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 60, height: 60),
                          padding: EdgeInsets.zero,
                          iconSize: 40,
                          onPressed: () => player.next(),
                          icon: const Icon(Icons.fast_forward_rounded),
                        ),
                        IconButton(
                          onPressed: player.cycleLoop,
                          icon: Icon(
                            player.loop == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: player.loop == LoopMode.off
                                ? Colors.white70
                                : kAccent,
                          ),
                        ),
                      ],
                    ),
                    if (t.streamUrl == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _showLyrics.value = !_showLyrics.value,
                            icon: Icon(Icons.lyrics_rounded,
                                color: showLy ? kAccent : Colors.white70),
                          ),
                          _DownloadButton(t),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _landscapeContent(
    BuildContext context,
    Track track,
    bool favorite,
    bool showLyrics,
    String? downloadError,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Cover(track.thumb, radius: 16),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        _ArtistName(track: track),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => showTrackHeartOptions(
                      context,
                      track,
                      isFavorite: favorite,
                    ),
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                      color: kAccent,
                    ),
                  ),
                ],
              ),
              if (player.error != null)
                Text(player.error!,
                    style: const TextStyle(color: kAccent, fontSize: 12)),
              if (downloadError != null)
                Text(
                  'Descarga fallida: $downloadError',
                  style: const TextStyle(color: kAccent, fontSize: 12),
                ),
              const SizedBox(height: 8),
              if (showLyrics)
                SizedBox(
                  height: 100,
                  child: LyricsView(key: ValueKey(track.id), track: track),
                )
              else
                track.streamUrl != null
                    ? const _LiveBadge()
                    : _Progress(track: track),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: player.toggleShuffle,
                    icon: Icon(Icons.shuffle_rounded,
                        color: player.shuffle ? kAccent : Colors.white70),
                  ),
                  IconButton(
                    constraints:
                        const BoxConstraints.tightFor(width: 60, height: 60),
                    padding: EdgeInsets.zero,
                    iconSize: 40,
                    onPressed: player.prev,
                    icon: const Icon(Icons.fast_rewind_rounded),
                  ),
                  player.loading
                      ? const SizedBox(
                          width: 56,
                          height: 56,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        )
                      : IconButton(
                          iconSize: 56,
                          onPressed: player.toggle,
                          icon: Icon(player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                        ),
                  IconButton(
                    constraints:
                        const BoxConstraints.tightFor(width: 60, height: 60),
                    padding: EdgeInsets.zero,
                    iconSize: 40,
                    onPressed: player.next,
                    icon: const Icon(Icons.fast_forward_rounded),
                  ),
                  IconButton(
                    onPressed: player.cycleLoop,
                    icon: Icon(
                      player.loop == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.loop == LoopMode.off
                          ? Colors.white70
                          : kAccent,
                    ),
                  ),
                ],
              ),
              if (track.streamUrl == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _showLyrics.value = !_showLyrics.value,
                      icon: Icon(Icons.lyrics_rounded,
                          color: showLyrics ? kAccent : Colors.white70),
                    ),
                    _DownloadButton(track),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final Track t;
  const _DownloadButton(this.t);

  @override
  Widget build(BuildContext context) {
    if (downloads.isDownloaded(t.id)) {
      return IconButton(
        onPressed: () => showDownloadOptions(context, [t]),
        icon: const Icon(Icons.download_done_rounded, color: kAccent),
      );
    }
    final p = downloads.progress[t.id];
    if (p != null) {
      if (downloads.paused.contains(t.id)) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Tooltip(
            message: 'En pausa, esperando Wi-Fi',
            child: Icon(Icons.wifi_tethering_error_rounded, color: kMuted),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            value: p > 0 ? p : null,
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return IconButton(
      onPressed: () => showDownloadOptions(context, [t]),
      icon: const Icon(Icons.download_rounded, color: Colors.white70),
    );
  }
}

class LyricsView extends StatefulWidget {
  final Track track;
  const LyricsView({super.key, required this.track});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late Future<Lyrics?> _f = lyricsService.get(widget.track);

  Future<void> _retry() async {
    await lyricsService.forget(widget.track.id);
    if (!mounted) return;
    setState(() => _f = lyricsService.get(widget.track));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Lyrics?>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ly = snap.data;
        if (ly == null) {
          final tried =
              lyricsService.tried[widget.track.id] ?? const <String>[];
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sin letra disponible',
                    style: TextStyle(color: kMuted, fontSize: 16)),
                if (tried.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(tried.join('\n'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMuted, fontSize: 10)),
                  ),
                TextButton(
                  onPressed: _retry,
                  child: const Text('Volver a buscar',
                      style: TextStyle(color: kAccent)),
                ),
              ],
            ),
          );
        }
        final Widget body = ly.synced.isNotEmpty
            ? _SyncedLyrics(lines: ly.synced, seekable: !ly.estimated)
            : SingleChildScrollView(
                child: Text(
                  ly.plain,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                ),
              );
        return Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ly.estimated
                        ? '${ly.source} · sincronización aproximada · guardada'
                        : '${ly.source} · guardada',
                    style: const TextStyle(color: kMuted, fontSize: 11),
                  ),
                  TextButton(
                    onPressed: _retry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Volver a buscar',
                        style: TextStyle(color: kAccent, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SyncedLyrics extends StatefulWidget {
  final List<LyricLine> lines;
  final bool seekable;
  const _SyncedLyrics({required this.lines, this.seekable = true});

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  late final List<GlobalKey> _keys =
      List.generate(widget.lines.length, (_) => GlobalKey());
  int _cur = -1;
  StreamSubscription<Duration>? _sub;
  late AudioPlayer _audio;

  @override
  void initState() {
    super.initState();
    _audio = player.audio;
    _subscribeToPosition();
    player.addListener(_onPlayerChanged);
  }

  void _subscribeToPosition() {
    _sub?.cancel();
    _sub = _audio.positionStream.listen(_onPos);
    _onPos(_audio.position);
  }

  void _onPlayerChanged() {
    if (_audio == player.audio) return;
    _audio = player.audio;
    _subscribeToPosition();
  }

  @override
  void dispose() {
    player.removeListener(_onPlayerChanged);
    _sub?.cancel();
    super.dispose();
  }

  void _onPos(Duration pos) {
    final l = widget.lines;
    var idx = -1;
    for (var i = 0; i < l.length; i++) {
      if (l[i].at <= pos) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx == _cur) return;
    setState(() => _cur = idx);
    if (idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.4,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < widget.lines.length; i++)
            GestureDetector(
              onTap: widget.seekable
                  ? () => player.seek(widget.lines[i].at)
                  : null,
              child: Container(
                key: _keys[i],
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  widget.lines[i].text.isEmpty ? '♪' : widget.lines[i].text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: i == _cur ? Colors.white : kMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistName extends StatelessWidget {
  final Track track;

  const _ArtistName({required this.track});

  Future<void> _openArtist(BuildContext context) async {
    final channelId = track.channelId;
    final artist = channelId != null && channelId.isNotEmpty
        ? Artist(
            name: track.artist,
            image: track.thumb,
            channelId: channelId,
          )
        : await music.findArtist(track.artist);
    if (!context.mounted) return;
    if (artist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el artista.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
    );
  }

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed:
            track.artist.trim().isEmpty ? null : () => _openArtist(context),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: kMuted,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, color: kMuted),
        ),
      );
}

class _Progress extends StatefulWidget {
  final Track track;
  const _Progress({required this.track});

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.audio.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = player.audio.duration ??
            Duration(seconds: widget.track.seconds ?? 0);
        final max =
            dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final value =
            (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
        final shown = Duration(milliseconds: value.round());
        return Column(
          children: [
            Slider(
              value: value,
              max: max,
              onChanged: dur.inMilliseconds > 0
                  ? (v) => setState(() => _drag = v)
                  : null,
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _drag = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(shown),
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                  Text('-${_fmt(dur - shown)}',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IcyMetadata?>(
      stream: player.audio.icyMetadataStream,
      builder: (context, snap) {
        final now = snap.data?.info?.title ?? '';
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: kAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text('EN DIRECTO',
                    style: TextStyle(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
            if (now.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(now,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 14)),
              ),
          ],
        );
      },
    );
  }
}
