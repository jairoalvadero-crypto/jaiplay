import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'artist.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  Timer? _deb;
  List<String> _sugg = [];
  List<Track>? _results;
  Artist? _artist;
  bool _busy = false;

  @override
  void dispose() {
    _deb?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _deb?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _sugg = [];
        _results = null;
        _artist = null;
      });
      return;
    }
    _deb = Timer(const Duration(milliseconds: 300), () async {
      try {
        final s = await music.suggestions(q);
        if (mounted && _c.text == q) {
          setState(() {
            _sugg = s;
            _results = null;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _submit(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final query = q.trim();
    _c.text = query;
    store.addRecentSearch(query);
    setState(() {
      _busy = true;
      _sugg = [];
      _artist = null;
    });
    try {
      final r = await music.search(query);
      if (mounted) setState(() => _results = r);
      music.findArtist(query).then((a) {
        if (mounted && _c.text == query) setState(() => _artist = a);
      });
    } catch (_) {
      if (mounted) setState(() => _results = []);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_busy) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_results != null) {
      final r = _results!;
      body = r.isEmpty
          ? const Center(
              child: Text('Sin resultados', style: TextStyle(color: kMuted)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: r.length + (_artist == null ? 0 : 2),
              itemBuilder: (context, i) {
                final a = _artist;
                if (a != null) {
                  if (i == 0) return _ArtistTile(a);
                  if (i == 1) return const SectionHeader('Canciones');
                }
                final idx = i - (a == null ? 0 : 2);
                return TrackTile(r[idx], onTap: () {
                  final track = r[idx];
                  store.addRecentSearch(
                    '${track.displayTitle} ${track.artist}'.trim(),
                  );
                  player.shuffle = false;
                  player.playQueue(r, idx);
                });
              },
            );
    } else {
      final items = _sugg.isNotEmpty ? _sugg : trending;
      body = ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (_sugg.isEmpty && store.recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Búsquedas recientes', style: kH2),
                  TextButton(
                    onPressed: store.clearRecentSearches,
                    child: const Text('Borrar'),
                  ),
                ],
              ),
            ),
            for (final query in store.recentSearches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, color: kMuted),
                title: Text(query),
                trailing: const Icon(Icons.north_west_rounded, color: kMuted),
                onTap: () => _submit(query),
              ),
          ],
          if (_sugg.isEmpty) const SectionHeader('Tendencias de búsqueda'),
          for (final s in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search, color: kMuted),
              title: Text(s),
              trailing: const Icon(Icons.chevron_right, color: kMuted),
              onTap: () => _submit(s),
            ),
        ],
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: 'Buscar canciones, artistas',
            prefixIcon: const Icon(Icons.search, color: kMuted),
            filled: true,
            fillColor: kCard,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  const _ArtistTile(this.artist);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Cover(artist.image, size: 56, radius: 28),
      title: Text(artist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: const Text('Artista', style: TextStyle(color: kMuted)),
      trailing: const Icon(Icons.chevron_right, color: kMuted),
      onTap: () {
        store.addRecentSearch(artist.name);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        );
      },
    );
  }
}
