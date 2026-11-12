import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../radio_data.dart';
import '../services.dart';
import '../shelf.dart';
import '../theme.dart';
import 'now_playing.dart';

List<Widget> radioShelves() {
  final cc = localCountryCode();
  return [
    _RadioShelf(
      title: '${countryName(cc)} · Noticias',
      topic: RadioTopic.news,
      countryCode: cc,
    ),
    _RadioShelf(
      title: '${countryName(cc)} · Música',
      topic: RadioTopic.music,
      countryCode: cc,
    ),
    _RadioShelf(
      title: 'Internacionales · Noticias',
      topic: RadioTopic.news,
      exclude: cc,
    ),
    _RadioShelf(
      title: 'Internacionales · Música',
      topic: RadioTopic.music,
      exclude: cc,
    ),
    for (final g in radioGenres)
      _RadioShelf(
        title: 'Música · ${g.$1}',
        params: {'tag': g.$2, 'order': 'votes', 'limit': '40'},
      ),
  ];
}

class _RadioShelf extends StatefulWidget {
  final String title;
  final RadioTopic? topic;
  final String? countryCode;
  final Map<String, String> params;
  final String? exclude;
  const _RadioShelf({
    required this.title,
    this.topic,
    this.countryCode,
    this.params = const {},
    this.exclude,
  });

  @override
  State<_RadioShelf> createState() => _RadioShelfState();
}

class _RadioShelfState extends State<_RadioShelf> {
  late Future<List<Track>> _f = _load();
  bool _all = false;

  Future<List<Track>> _load() => widget.topic == null
      ? fetchStations(widget.params, excludeCountry: widget.exclude)
      : fetchStationsByTopic(
          topic: widget.topic!,
          countryCode: widget.countryCode,
          excludeCountry: widget.exclude,
        );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Row(
              children: [
                Flexible(child: Text(widget.title, style: kH2)),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          );
        }
        final list = snap.data ?? const <Track>[];
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: kH2),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _f = _load()),
                  child: Text(
                    snap.hasError
                        ? 'No se pudieron cargar. Toca para reintentar.'
                        : 'No hay emisoras para esta lista.',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }
        return Shelf(
          title: widget.title,
          count: list.length,
          limit: 10,
          inset: 0,
          collapsedWidth: 130,
          heightOf: (w) => w + 68,
          expanded: _all,
          onToggle: () => setState(() => _all = !_all),
          itemBuilder: (i, w) => _StationCard(list, i, w),
        );
      },
    );
  }
}

class _StationCard extends StatelessWidget {
  final List<Track> list;
  final int i;
  final double w;
  const _StationCard(this.list, this.i, this.w);

  @override
  Widget build(BuildContext context) {
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
            AspectRatio(aspectRatio: 1, child: _Logo(t.thumb)),
            const SizedBox(height: 8),
            Text(t.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14)),
            if (t.artist.isNotEmpty)
              Text(t.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted)),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String url;
  const _Logo(this.url);

  @override
  Widget build(BuildContext context) {
    const icon =
        Center(child: Icon(Icons.radio_rounded, color: kMuted, size: 40));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: kCard,
        padding: const EdgeInsets.all(14),
        child: url.isEmpty
            ? icon
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => icon,
                errorWidget: (_, __, ___) => icon,
              ),
      ),
    );
  }
}
