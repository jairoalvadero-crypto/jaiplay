import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../radio_data.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'now_playing.dart';
import 'radio_shelves.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  Future<List<Track>>? _searchResults;
  String _searchQuery = '';
  bool _searching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _searchQuery = query;
        _searchResults = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searchQuery = query;
      _searchResults = null;
      _searching = true;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || query != _searchQuery) return;
      _runSearch(query);
    });
  }

  void _runSearch(String query) {
    setState(() {
      _searching = true;
      _searchResults = searchStations(query);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = null;
      _searching = false;
    });
  }

  Future<void> _randomStation(BuildContext context) async {
    final rnd = Random();
    final c = stations[rnd.nextInt(stations.length)];
    try {
      final list = await music.search(c.query);
      player.shuffle = true;
      await player.playQueue(list, rnd.nextInt(list.length));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la radio')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Radio', style: kTitle),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (value) {
              _searchDebounce?.cancel();
              final query = value.trim();
              if (query.length >= 2) _runSearch(query);
            },
            decoration: InputDecoration(
              hintText: 'Buscar emisoras',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: kCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_searchController.text.trim().length == 1)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Escribe al menos 2 caracteres.',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            ),
          if (_searchController.text.trim().length >= 2) ...[
            const SizedBox(height: 8),
            _StationSearchResults(
              query: _searchQuery,
              future: _searchResults,
              searching: _searching,
              onRetry: () => _runSearch(_searchQuery),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF7A0F1E), Color(0xFF2A0509)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text('Radio JaiPlay',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Música sin parar, a tu aire',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _randomStation(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Escuchar ahora'),
                ),
              ],
            ),
          ),
          ...radioShelves(),
          const SectionHeader('Mixes por género'),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final s = stations[i];
                return GestureDetector(
                  onTap: () => openCollection(context, s),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.bottomLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Color(s.color),
                          Color(s.color).withOpacity(0.45)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(s.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                );
              },
            ),
          ),
          const SectionHeader('Mixes'),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mixes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => CollectionCard(mixes[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationSearchResults extends StatelessWidget {
  final String query;
  final Future<List<Track>>? future;
  final bool searching;
  final VoidCallback onRetry;

  const _StationSearchResults({
    required this.query,
    required this.future,
    required this.searching,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (searching && future == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final request = future;
    if (request == null) return const SizedBox.shrink();
    return FutureBuilder<List<Track>>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.error_outline_rounded, color: kAccent),
            title: const Text('No se pudieron buscar emisoras'),
            subtitle: Text(
              '${snapshot.error}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Reintentar',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          );
        }
        final stations = snapshot.data ?? const <Track>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Resultados para «$query»'),
            if (stations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'No se encontraron emisoras. Prueba con otro nombre.',
                  style: TextStyle(color: kMuted),
                ),
              )
            else
              for (var i = 0; i < stations.length; i++)
                _SearchStationTile(stations: stations, index: i),
          ],
        );
      },
    );
  }
}

class _SearchStationTile extends StatelessWidget {
  final List<Track> stations;
  final int index;

  const _SearchStationTile({required this.stations, required this.index});

  @override
  Widget build(BuildContext context) {
    final station = stations[index];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        player.shuffle = false;
        player.playQueue(stations, index);
        openNowPlaying(context);
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          color: kCard,
          child: station.thumb.isEmpty
              ? const Icon(Icons.radio_rounded, color: kMuted)
              : CachedNetworkImage(
                  imageUrl: station.thumb,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.radio_rounded, color: kMuted),
                  placeholder: (_, __) =>
                      const Icon(Icons.radio_rounded, color: kMuted),
                ),
        ),
      ),
      title: Text(
        station.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        station.artist.isEmpty ? 'Emisora en directo' : station.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: kMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.play_circle_outline_rounded, color: kAccent),
    );
  }
}
