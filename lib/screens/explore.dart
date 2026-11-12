import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'collection.dart';
import 'now_playing.dart';
import 'search.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  void _open(BuildContext c, String title, String query) => Navigator.push(
        c,
        MaterialPageRoute(
          builder: (_) => CollectionScreen(title: title, query: query),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Explorar', style: kTitle),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen())),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: kMuted),
                    SizedBox(width: 8),
                    Text('Buscar canciones, artistas',
                        style: TextStyle(color: kMuted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _FeatureCarousel(),
          _SectionTitle('Las mejores canciones nuevas',
              () => _open(context, 'Canciones nuevas', newSongsQuery)),
          const _SongPages(),
          const _SectionTitle('Nuevo esta semana', null),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: newThisWeek.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => CollectionCard(newThisWeek[i], size: 200),
            ),
          ),
          const _SectionTitle('Explorar por categoría', null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                crossAxisCount:
                    (constraints.maxWidth / 250).floor().clamp(2, 4),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _Chip(Icons.queue_music_rounded, 'Listas',
                      () => _open(context, 'Listas', 'playlist éxitos mix')),
                  _Chip(
                      Icons.local_fire_department_rounded,
                      'Nuevos lanzamientos',
                      () =>
                          _open(context, 'Nuevos lanzamientos', newSongsQuery)),
                  _Chip(
                      Icons.mic_external_on_rounded,
                      'Artistas',
                      () => _open(
                          context, 'Artistas', 'artistas populares canciones')),
                  _Chip(Icons.category_rounded, 'Géneros', () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GenresScreen()));
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _SectionTitle(this.title, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Flexible(child: Text(title, style: kH2)),
            if (onTap != null) const Icon(Icons.chevron_right, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel();

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  final _pc = PageController(viewportFraction: 0.82);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final imgH = (c.maxWidth * 0.82 - 20) / 1.45;
        return SizedBox(
          height: imgH + 96,
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: featureCards.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _FeatureCard(featureCards[i]),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final FeatureCard card;
  const _FeatureCard(this.card);

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  late final Future<List<Track>> _f = music.search(widget.card.query);

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CollectionScreen(
              title: c.title, subtitle: c.subtitle, query: c.query),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.kicker,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 11,
                  color: kMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          Text(c.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, color: kMuted)),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<List<Track>>(
                    future: _f,
                    builder: (_, s) {
                      final l = s.data;
                      return Cover(
                          (l == null || l.isEmpty) ? '' : l.first.thumb);
                    },
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Text(c.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongPages extends StatefulWidget {
  const _SongPages();

  @override
  State<_SongPages> createState() => _SongPagesState();
}

class _SongPagesState extends State<_SongPages> {
  final _pc = PageController(viewportFraction: 0.8);
  late final Future<List<Track>> _f = music.search(newSongsQuery);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 300, child: Center(child: CircularProgressIndicator()));
        }
        final list = (snap.data ?? []).take(12).toList();
        if (list.isEmpty) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: Text('Sin conexión o sin resultados',
                  style: TextStyle(color: kMuted)),
            ),
          );
        }
        final pages = <List<Track>>[
          for (var i = 0; i < list.length; i += 4)
            list.sublist(i, i + 4 > list.length ? list.length : i + 4),
        ];
        return SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: pages.length,
            itemBuilder: (_, p) {
              final rows = pages[p];
              return Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: [
                    for (var j = 0; j < rows.length; j++) ...[
                      _SongRow(rows[j], () {
                        player.shuffle = false;
                        player.playQueue(list, p * 4 + j);
                        openNowPlaying(context);
                      }),
                      if (j < rows.length - 1)
                        const Divider(
                            height: 1, indent: 68, color: Color(0xFF2C2C2E)),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SongRow extends StatelessWidget {
  final Track t;
  final VoidCallback onTap;
  const _SongRow(this.t, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 73,
        child: Row(
          children: [
            Cover(t.thumb, size: 56, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16)),
                  Text(t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: kMuted)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => showTrackMenu(context, t),
              icon: const Icon(Icons.more_horiz, color: kMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Chip(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Géneros')),
      body: ListView.builder(
        itemCount: genres.length,
        itemBuilder: (_, i) {
          final Collection g = genres[i];
          return ListTile(
            title: Text(g.title),
            trailing: const Icon(Icons.chevron_right, color: kMuted),
            onTap: () => openCollection(context, g),
          );
        },
      ),
    );
  }
}
